#!/usr/bin/env python3
"""**「予定」のまま置き去りになっている記述を洗い出す。**

2026-09-21、東京湾大華火祭の節が **6月公開時のまま**だったのを利用者に指摘された。

    チケット発売: 7月（上旬）発売予定     ← 実際は抽選が3回とも終わっていた
    料金: 5,000〜10,000円の予定           ← 実際の区民優先Aは 0円

**ビルドも検査も通る。** 中身が古いだけなので、機械で拾わないと誰も気づけない。

    python3 scripts/check-stale-wording.py              # 全記事
    python3 scripts/check-stale-wording.py <slug> ...   # 記事を指定

**これは「直せ」ではなく「見に行け」の合図。** 予定のままでよいものもある
（来年の話、恒常的な注意書きなど）。**公開からの日数と一緒に出す**ので、
古い記事の「予定」から先に当たること。

出典を取りに行くのは `ops/tasks`（クラウドからは外部 HTTPS が塞がれている）。
`t147-tokyowan-hanabi-latest.sh` が手本で、**公式の本文をそのまま持ち帰る。**
"""
import datetime as dt
import pathlib
import re
import sys

POSTS = pathlib.Path(__file__).resolve().parent.parent / "src/content/posts"

# **語は `ops/data/stale-words.txt` に置いてある。** `refresh-article.mjs` も
# 同じファイルを読む。**パターンを 2 箇所に書かない**（片方だけ直して食い違う）。
WORDS = pathlib.Path(__file__).resolve().parent.parent / "ops/data/stale-words.txt"


def load_words():
    out = []
    for line in WORDS.read_text().split("\n"):
        line = line.split("#", 1)[0].strip()
        if line:
            out.append(re.escape(line))
    if not out:
        raise SystemExit(f"語が 1 つも読めない: {WORDS}")
    return re.compile("|".join(out))


PAT = load_words()

# **日数のしきい値。** 公開直後の「予定」は正しいことが多い
WARN_DAYS = 60


def scan(path: pathlib.Path, today: dt.date):
    src = path.read_text()
    m = re.search(r"^publishDate:\s*(\S+)", src, re.M)
    if not m:
        return None
    try:
        pub = dt.date.fromisoformat(m.group(1).strip('"'))
    except ValueError:
        return None
    upd = pub
    mu = re.search(r"^updatedDate:\s*(\S+)", src, re.M)
    if mu:
        try:
            upd = dt.date.fromisoformat(mu.group(1).strip('"'))
        except ValueError:
            pass

    hits = []
    for i, line in enumerate(src.split("\n"), 1):
        if line.startswith(("title:", "description:", "tags:", "references:")):
            continue
        if not PAT.search(line):
            continue
        text = re.sub(r"<[^>]+>", "", line).strip()
        if len(text) < 8:
            continue
        hits.append((i, text[:96]))
    if not hits:
        return None
    return {"slug": path.stem, "pub": pub, "upd": upd,
            "age": (today - upd).days, "hits": hits}


def main():
    today = dt.date.today()
    targets = sys.argv[1:]
    paths = ([POSTS / f"{t}.md" for t in targets] if targets
             else sorted(POSTS.glob("*.md")))
    rows = [r for r in (scan(p, today) for p in paths if p.exists()) if r]
    rows.sort(key=lambda r: (-r["age"], -len(r["hits"])))

    if not rows:
        print("✓ 「予定」のまま残っている記述は無い")
        return 0

    warn = 0
    for r in rows:
        mark = "⚠" if r["age"] >= WARN_DAYS else "・"
        if r["age"] >= WARN_DAYS:
            warn += 1
        print(f'{mark} {r["slug"]}（最終更新から {r["age"]} 日 / {len(r["hits"])} 箇所）')
        for line_no, text in r["hits"][:4]:
            print(f"    {line_no:>4}: {text}")
        if len(r["hits"]) > 4:
            print(f"    … ほか {len(r['hits']) - 4} 箇所")

    total = sum(len(r["hits"]) for r in rows)
    print(f"\n{len(rows)} 記事 / 計 {total} 箇所。"
          f"うち **{warn} 記事は最終更新から {WARN_DAYS} 日 以上**。")
    print("**まず ⚠ から見に行く。** 出典を取りに行くのは ops/tasks（t147 が手本）。")
    # **落とさない。** 予定のままでよいものもあるので、判断は人がする
    return 0


if __name__ == "__main__":
    sys.exit(main())
