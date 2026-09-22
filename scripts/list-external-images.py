#!/usr/bin/env python3
"""**記事が外部サイトから直に読んでいる画像を数えて、一覧を作り直す。**

    python3 scripts/list-external-images.py           # 数だけ見る
    python3 scripts/list-external-images.py --write   # ops/data/external-images.txt を更新

**他所のサイトの画像は、こちらの都合と関係なく消える。**
消えても**ビルドも検査も通る**ので、誰も気づけない。
生死の確認は `ops/tasks/t154-check-external-images.sh`（Mac で走る）。
"""
import collections
import pathlib
import re
import sys

SKIP = re.compile(r"youtube|twitter\.com|platform\.twitter")
POSTS = pathlib.Path(__file__).resolve().parent.parent / "src/content/posts"
OUT = pathlib.Path(__file__).resolve().parent.parent / "ops/data/external-images.txt"


def collect():
    rows = []
    for p in sorted(POSTS.glob("*.md")):
        for m in re.finditer(r'<img[^>]+src="(https://[^"]+)"', p.read_text()):
            u = m.group(1)
            if SKIP.search(u):
                continue
            rows.append((p.stem, u))
    return rows


def main():
    rows = collect()
    hosts = collections.Counter(u.split("/")[2] for _, u in rows)
    slugs = {s for s, _ in rows}
    print(f"外部ホットリンクの画像: {len(rows)} 件 / {len(slugs)} 記事")
    for h, n in hosts.most_common(15):
        print(f"  {n:>2}  {h}")
    if "--write" in sys.argv:
        head = OUT.read_text().split("\n")
        keep = [l for l in head if l.startswith("#") or not l.strip()]
        # 先頭のコメント塊だけ残して書き直す
        top = []
        for l in keep:
            if l.startswith("#") or not l.strip():
                top.append(l)
            else:
                break
        OUT.write_text("\n".join(top).rstrip() + "\n"
                       + "\n".join(f"{s}\t{u}" for s, u in rows) + "\n")
        print(f"→ {OUT} を更新した")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # `| head` で切られたとき。**落とさない**
        try:
            sys.stdout.close()
        finally:
            sys.exit(0)
