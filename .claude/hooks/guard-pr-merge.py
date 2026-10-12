#!/usr/bin/env python3
"""PreToolUse フック: 「マージしたつもりで main に入っていない」を止める。

## なぜ（2026-10-12）

利用者が「投稿してOK」と言ったあと、投稿タスク x276 を commit した。だが **PR #971 は 19:52 にもうマージ済み**で、
x276 はその後のコミットだった。それでも #971 に merge を打ち、API は `merged: true` を返した
（**マージ済みの PR に打っても成功が返る**）。それを「main に入った」と報告した。
**Mac は main のタスクしか走らせない**ので、約 25 分 何も起きなかった。
新しい PR #973 を作ってマージしたら、**38 秒で投稿された。** 遅れは全部こちら側だった。

> もうさっきから30分くらい経ってる気がするけど、何が Mac の投稿を妨げてるか、ちゃんと自分で分析できてる？

## 何を止めるか

`mcp__github__merge_pull_request` の直前に PR を読み、次のどれかなら止める。

1. **PR がもうマージ済み・閉じている** → 新しいコミットは入らない。新しい PR を作れ
2. **手元のブランチの最新コミットが、PR の head と違う**（push 漏れ・PR 作成後のコミット）
   → そのコミットは PR に入っていない。push して PR の head を揃えてから打て

## 安全側の設計

  - GitHub が読めない・git が使えないときは素通しする（作業を壊さない）
"""

import json
import os
import subprocess
import sys
import urllib.request

ALLOW = 0
BLOCK = 2


def main():
    try:
        data = json.load(sys.stdin)
        ti = data.get("tool_input", {})
        owner, repo, num = ti["owner"], ti["repo"], int(ti["pullNumber"])
    except Exception:
        return ALLOW
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/{owner}/{repo}/pulls/{num}",
                                     headers={"Accept": "application/vnd.github+json", "User-Agent": "guard-pr-merge"})
        with urllib.request.urlopen(req, timeout=15) as r:
            pr = json.load(r)
    except Exception:
        return ALLOW
    problems = []
    if pr.get("merged") or pr.get("state") != "open":
        problems.append(f"PR #{num} は{'もうマージ済み' if pr.get('merged') else '閉じている'}"
                        f"（{pr.get('merged_at') or pr.get('closed_at')}）。ここに打っても新しいコミットは main に入らない。"
                        "**新しい PR を作る。**")
    head_ref = (pr.get("head") or {}).get("ref")
    head_sha = (pr.get("head") or {}).get("sha")
    try:
        cwd = os.environ.get("CLAUDE_PROJECT_DIR") or "."
        branch = subprocess.run(["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True, timeout=10).stdout.strip()
        local = subprocess.run(["git", "-C", cwd, "rev-parse", "HEAD"], capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        branch = local = ""
    if branch and branch == head_ref and local and head_sha and local != head_sha and not pr.get("merged"):
        problems.append(f"手元の最新コミット {local[:8]} が PR #{num} の head {head_sha[:8]} と違う。"
                        "**そのコミットは PR に入っていない。** push して、CI を待ってから打つ")
    if not problems:
        return ALLOW
    print("PR のマージを止めた（.claude/hooks/guard-pr-merge.py・CLAUDE.md 最上位ルール 12）\n", file=sys.stderr)
    for p in problems:
        print("- " + p, file=sys.stderr)
    print("\n**マージしたら、`git fetch origin main && git ls-tree --name-only origin/main ops/tasks/ | grep <タスク名>` で"
          "main に入ったことを実物で確かめてから報告する。** merged:true は証拠にならない（最上位ルール 13）。", file=sys.stderr)
    return BLOCK


if __name__ == "__main__":
    sys.exit(main())
