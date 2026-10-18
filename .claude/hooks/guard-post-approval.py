#!/usr/bin/env python3
"""PreToolUse フック: 「投稿して」と言われていない投稿タスクを commit させない。

## なぜ（2026-10-12）

青バッジ報告の下書きを出し、ダイアログで「どちらの文面で出しますか？」「画像はどちらを付けますか？」と聞いた。
利用者は **A と GIF を選んだだけ** なのに、それを投稿の許可だと読み替えて x272 を書き、**確認なしで X に出した。**
利用者が手で削除した。

> 私は投稿の内容がOKだなんて一言も言っていない。ダイアログでお前が方向性を示して、
> それに回答しただけなので、それを「投稿してOK」と捉えるのは絶対に国語として間違っている。

**文書に書くだけでは守られない**（同じ根の事故が 2026-09-22 にも起きている・最上位ルール 18）ので、
投稿タスクを commit する直前で機械的に止める。

## 何を止めるか

`git commit` のとき、ステージされた `ops/tasks/*.sh` のうち **投稿する経路**
（`run-publish.sh` / `post-via-playwright.js` / `post-comment.js`）を呼ぶものに、
次の 2 行が無ければ止める。

    POST_APPROVAL_QUOTE="<利用者が書いた文をそのまま>"
    POST_APPROVAL_AT="<その発言の日時>"

`POST_APPROVAL_QUOTE` は **利用者の発言の引用** で、「投稿して」「投稿しろ」「出して」「ポストして」などの
**投稿を指示する言葉が入っていなければ止める。** ダイアログで選んだ選択肢の名前（「A 短い版」など）は通らない。

## 安全側の設計

  - 入力が読めない・git が使えないときは素通しする（作業を壊さない）
  - 削除・読むだけのタスクは対象外（投稿経路を呼ばないもの）
"""

import json
import re
import subprocess
import sys

ALLOW = 0
BLOCK = 2

POSTING = re.compile(r"run-publish\.sh|post-via-playwright\.js|post-comment\.js")
# 投稿経路を「読むだけ」の行（cat / grep / sed で中身を表示する）は投稿ではない
READ_ONLY_LINE = re.compile(r"^\s*(#|echo|printf|cat |grep |sed -n|awk |head |tail |wc )")
QUOTE = re.compile(r'^\s*POST_APPROVAL_QUOTE="([^"]+)"', re.M)
AT = re.compile(r'^\s*POST_APPROVAL_AT="([^"]+)"', re.M)
# 投稿を指示する言葉。選択肢の名前（「A 短い版」「動く版 GIF」）はここに当たらない
ORDER = re.compile(r"投稿して|投稿しろ|投稿していい|投稿してOK|投稿OK|出して|出していい|ポストして|ツイートして|tweet")
# 2026-10-18: どのレビューページの組を出すか。drafts（ページで利用者が直接 書き換えた文面）の取り込みを確かめるのに使う
SET_KEY = re.compile(r'^\s*POST_SET_KEY="([^"]+)"', re.M)
DRAFT_MAX_AGE_MIN = 60


def check_drafts(path, text):
    """ページの書き換え（drafts）を取り込まないまま投稿する事故を止める（2026-10-18・7 本 取りこぼした）。"""
    import datetime as dt
    k = SET_KEY.search(text)
    if not k:
        return (f"{path}: POST_SET_KEY（レビューページの組の key）が無い。"
                "ページで利用者が直接 書き換えた文面（drafts）を取り込んだかを確かめられない")
    key = k.group(1)
    try:
        with open("scripts/image-review/drafts.json", encoding="utf-8") as f:
            snap = json.load(f)
        with open("scripts/image-review/posts.json", encoding="utf-8") as f:
            posts = json.load(f)
    except Exception as e:
        return f"{path}: drafts.json / posts.json が読めない（{e}）。sync-drafts.mjs で取り込む"
    try:
        at = dt.datetime.fromisoformat(snap.get("syncedAt", "").replace("Z", "+00:00"))
        age = (dt.datetime.now(dt.timezone.utc) - at).total_seconds() / 60
    except Exception:
        age = 1e9
    if age > DRAFT_MAX_AGE_MIN:
        return (f"{path}: ページの書き換え（drafts）の取り込みが {int(age)} 分 前。{DRAFT_MAX_AGE_MIN} 分 以内に"
                "ArtifactData(collection=\"drafts\", out_dir=…) で読み、sync-drafts.mjs で取り込み直す")
    if key not in posts:
        return f"{path}: POST_SET_KEY「{key}」が posts.json に無い"
    for target, d in (snap.get("drafts") or {}).items():
        if not target.startswith(key + "/text-") or (snap.get("acknowledged") or {}).get(target):
            continue
        i = int(target.rsplit("-", 1)[1]) - 1
        cur = posts[key][i] if i < len(posts[key]) else None
        if cur != d.get("text"):
            return f"{path}: ページで書き換えられた {target} が posts.json に入っていない。sync-drafts.mjs で取り込む"
    return None


def posting_lines(text):
    return [l for l in text.splitlines() if POSTING.search(l) and not READ_ONLY_LINE.match(l)]


def check(path, text):
    if not posting_lines(text):
        return None
    q = QUOTE.search(text)
    a = AT.search(text)
    if not q or not a:
        return f"{path}: 投稿する経路を呼んでいるのに POST_APPROVAL_QUOTE / POST_APPROVAL_AT が無い"
    if not ORDER.search(q.group(1)):
        return (f"{path}: POST_APPROVAL_QUOTE「{q.group(1)}」に投稿を指示する言葉が無い。"
                "ダイアログで選んだ選択肢は投稿の許可ではない")
    return check_drafts(path, text)


def main():
    try:
        data = json.load(sys.stdin)
        cmd = data.get("tool_input", {}).get("command", "")
    except Exception:
        return ALLOW
    if not re.search(r"\bgit\b[^;&|]*\bcommit\b", cmd):
        return ALLOW
    try:
        if re.search(r"\bgit\b[^;&|]*\badd\b", cmd):
            # 「git add … && git commit」の 1 行では、add 前のステージしか見えない。add の対象も読む
            targets = re.findall(r"ops/tasks/[\w.\-]+\.sh", cmd)
            if re.search(r"\badd\b[^;&|]*(\s-A\b|\s--all\b|\s\.(\s|$)|\sops/tasks\b)", cmd):
                # 2026-10-18: 「git add -A && git commit」では対象がコマンドに出ないので、未ステージの変更も見る
                st = subprocess.run(["git", "status", "--porcelain", "--", "ops/tasks"], capture_output=True, text=True, timeout=10).stdout
                targets += [l[3:].strip() for l in st.splitlines() if l[3:].strip().endswith(".sh")]
        else:
            targets = []
        staged = subprocess.run(["git", "diff", "--cached", "--name-only"], capture_output=True, text=True, timeout=10).stdout.split()
        paths = sorted({p for p in staged + targets if re.match(r"ops/tasks/.+\.sh$", p)})
    except Exception:
        return ALLOW
    problems = []
    for p in paths:
        try:
            with open(p, encoding="utf-8") as f:
                text = f.read()
        except Exception:
            continue
        r = check(p, text)
        if r:
            problems.append(r)
    if not problems:
        return ALLOW
    print("投稿タスクの commit を止めた（.claude/hooks/guard-post-approval.py・CLAUDE.md 最上位ルール 4）\n", file=sys.stderr)
    for r in problems:
        print("- " + r, file=sys.stderr)
    print("\n**利用者が「投稿して」と書いた発言を、そのまま引用できるときだけ投稿タスクを書く。**"
          "\n文面や画像の版を選んでもらっただけなら、それは投稿の許可ではない。"
          "「この内容で投稿してよいか」を聞いて、返事をもらってから書く。", file=sys.stderr)
    return BLOCK


if __name__ == "__main__":
    sys.exit(main())
