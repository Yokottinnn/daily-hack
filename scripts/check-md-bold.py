#!/usr/bin/env python3
"""
check-md-bold.py — ビルド後 HTML に「太字にならず生のまま残った ** 」が無いか検査する。

なぜ必要か:
  日本語記事で **強調。**次の文 のように書くと、閉じ側 `**` の直前が句読点・
  括弧だと CommonMark の right-flanking delimiter 条件を満たさず、太字にならずに
  `**` がそのまま表示される。同様に は**「語」** のように開き側 `**` の直後が
  約物でも left-flanking にならない。

  日本語だと極めて踏みやすいのに、ビルドは通るし見た目も崩れないので気づきにくい。
  実際に同一プロジェクトで3回踏んだ。

  ✗ **入場無料。**アーバンドック   → ** が生表示
  ✓ **入場無料**。アーバンドック
  ✗ デザインモチーフは**「扇」**。 → ** が生表示
  ✓ デザインモチーフは「**扇**」。

Usage:
  npm run build && python3.11 scripts/check-md-bold.py
  python3.11 scripts/check-md-bold.py dist/posts/<slug>/index.html   # 個別指定
"""
import re, sys, glob, pathlib

def check(path):
    html = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    # <script> 内の JS には ** が正当に現れるため除外する
    html = re.sub(r"<script.*?</script>", "", html, flags=re.S | re.I)
    hits = []
    for m in re.finditer(r"\*\*", html):
        i = m.start()
        ctx = re.sub(r"<[^>]+>", "", html[max(0, i - 45):i + 45]).replace("\n", " ")
        hits.append(ctx.strip())
    return hits

def main():
    targets = sys.argv[1:] or sorted(glob.glob("dist/posts/*/index.html"))
    if not targets:
        print("dist/ が見つからない。先に npm run build を実行すること。", file=sys.stderr)
        return 2
    bad = 0
    for t in targets:
        hits = check(t)
        if hits:
            bad += 1
            slug = pathlib.Path(t).parent.name
            print(f"\n✗ {slug} — 太字にならなかった ** が {len(hits)} 箇所")
            for h in dict.fromkeys(hits):   # 重複文脈を畳む
                print(f"    … {h}")
    if bad:
        print(f"\n{bad} 記事に問題あり。")
        print("直し方: 閉じ側 ** の直前の句読点・括弧を ** の外に出す。")
        print("  **無料。**18:30〜  →  **無料**。18:30〜")
        print("  は**「扇」**。      →  は「**扇**」。")
        return 1
    print(f"✓ {len(targets)} 記事すべて OK（生の ** なし）")
    return 0

if __name__ == "__main__":
    sys.exit(main())
