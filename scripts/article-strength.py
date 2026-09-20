#!/usr/bin/env python3
"""記事の「弱さ」を機械で測る。

**「クロール済み - インデックス未登録」は、見には来たが載せないと判断された状態。**
サイトマップの問題ではないので、再送信では動かない。効くのは中身のほう。

何が足りないのかを**推測ではなく数で**出す。

    python3 scripts/article-strength.py            # 全記事
    python3 scripts/article-strength.py <slug> ... # 指定した記事だけ

| 列 | 何を数えているか |
| --- | --- |
| `文字` | 本文の文字数（HTML タグとフロントマターを除く） |
| `被リンク` | **他の記事からこの記事へのリンク数**。少ないほど載りにくい |
| `発リンク` | この記事から他の記事へのリンク数 |
| `外部` | 外部サイトへのリンク数（出典の厚み） |
| `画像` | 記事内の画像の数 |
| `表` | 表の数 |
| `h2` | 見出しの数 |
"""
import pathlib
import re
import sys

POSTS = pathlib.Path("src/content/posts")
TAG = re.compile(r"<[^>]+>")
FM = re.compile(r"\A---\n.*?\n---\n", re.S)


def body_of(p: pathlib.Path) -> str:
    return FM.sub("", p.read_text(encoding="utf-8"))


def main() -> None:
    files = sorted(POSTS.glob("*.md"))
    bodies = {f.stem: body_of(f) for f in files}

    # **被リンクは全記事を走査しないと数えられない**
    inbound: dict[str, int] = {s: 0 for s in bodies}
    for src, b in bodies.items():
        for m in re.finditer(r'/posts/([a-z0-9-]+)/', b):
            t = m.group(1)
            if t in inbound and t != src:
                inbound[t] += 1

    want = set(sys.argv[1:])
    rows = []
    for slug, b in bodies.items():
        if want and slug not in want:
            continue
        text = TAG.sub("", b)
        rows.append({
            "slug": slug,
            "chars": len(re.sub(r"\s+", "", text)),
            "in": inbound[slug],
            "out": len({m.group(1) for m in re.finditer(r"/posts/([a-z0-9-]+)/", b)}),
            "ext": len(re.findall(r'href="https?://(?!daily-hack)', b)),
            "img": len(re.findall(r"<img\b", b)),
            "tbl": len(re.findall(r"<table\b", b)) + len(re.findall(r"^\|.*\|$", b, re.M)) // 8,
            "h2": len(re.findall(r"^##\s", b, re.M)) + len(re.findall(r"<h2\b", b)),
        })

    rows.sort(key=lambda r: (r["in"], r["chars"]))
    print(f"{'被リンク':>6} {'文字':>6} {'発':>3} {'外部':>4} {'画像':>4} {'表':>3} {'h2':>3}  記事")
    for r in rows:
        print(f"{r['in']:>6} {r['chars']:>6} {r['out']:>3} {r['ext']:>4} "
              f"{r['img']:>4} {r['tbl']:>3} {r['h2']:>3}  {r['slug']}")

    if want:
        n = len(rows)
        avg = {k: sum(r[k] for r in rows) / n for k in ("in", "chars", "ext", "img")}
        print(f"\n指定 {n} 本の平均: 被リンク {avg['in']:.1f} / 文字 {avg['chars']:.0f} / "
              f"外部 {avg['ext']:.1f} / 画像 {avg['img']:.1f}")


if __name__ == "__main__":
    main()
