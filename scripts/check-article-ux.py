#!/usr/bin/env python3
"""
check-article-ux.py — 記事の UX 上の抜けをビルド後 HTML から機械的に検出する。

## なぜ必要か

skills/photo_card_ui_v1.md に「一覧・選択肢は .event-pick 写真背景カードを使う」
「表の施設名にはリンクを張る」と書き、QA ルールブックにも grep コマンドを載せた。
それでも次に書いた記事（lalaport-guide-2026）で守られなかった。

原因は単純で、**ドキュメントに書いただけで誰も実行しないから**。
SEO 監視が「Secret 未設定で毎回 skip され続けた」のと同じ構造で、
実行されないルールは存在しないのと同じだった。だから機械で落とす。

## 検出する項目

1. 冒頭付近の .highlight-grid が 4 枚以上 → .event-pick 写真カードにすべき
2. .event-pick のリンク先 id がビルド後 HTML に存在しない／重複している
   （見出しが .section-with-mascot 内にある h2 は id が振られないため頻出）
3. 施設名・サービス名が並ぶ表なのに、1 つもリンクが無い
4. .event-pick があるのに .event-picks-credit（画像出典）が無い

Usage:
  npm run build && python3.11 scripts/check-article-ux.py
  python3.11 scripts/check-article-ux.py dist/posts/<slug>/index.html
"""
import re, sys, glob, pathlib

def body_of(html):
    m = re.search(r'<article[^>]*>(.*?)</article>', html, re.S)
    return m.group(1) if m else html


def check(path):
    html = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    html = re.sub(r"<script.*?</script>", "", html, flags=re.S | re.I)
    body = body_of(html)
    ids = set(re.findall(r'id="([^"]+)"', html))
    issues = []

    # --- 1. 冒頭の highlight-grid が大きい ---
    for m in re.finditer(r'<div class="highlight-grid[^"]*">(.*?)</div>\s*</div>', body, re.S):
        n = m.group(1).count("highlight-item")
        # 記事の前半3割以内に出てくる大きめのグリッドは「選択肢一覧」の可能性が高い
        if n >= 4 and m.start() < len(body) * 0.3:
            issues.append(
                f".highlight-grid が冒頭に {n} 枚。選択肢の一覧なら .event-pick "
                f"（写真背景＋リンク）にすべき → skills/photo_card_ui_v1.md")

    # --- 2. event-pick のアンカー ---
    anchors = re.findall(r'class="event-pick"[^>]*href="#([^"]+)"', body)
    for a in anchors:
        if a not in ids:
            issues.append(f".event-pick のリンク先 #{a} が存在しない"
                          f"（.section-with-mascot 内の h2 には id が振られない点に注意）")
    if len(anchors) != len(set(anchors)):
        dup = [a for a in set(anchors) if anchors.count(a) > 1]
        issues.append(f".event-pick のリンク先が重複: {', '.join('#'+d for d in dup)}")

    # --- 3. リンクの無い一覧表 ---
    # 誤検知を避けるため「固有名詞が並ぶ一覧」に限定する。
    # 時系列表（時期/内容）や料金表（メダル/還元率）は対象外。直後に出典リンクがある表も除外。
    SKIP_HEAD = re.compile(r"時期|日程|状況|何が起きるか|メダル|還元率|年間積算|ブランド|位置づけ")
    for m in re.finditer(r"<table[^>]*>(.*?)</table>", body, re.S):
        t = m.group(1)
        rows = t.count("<tr")
        if rows < 5 or "<a " in t:
            continue
        thead = re.sub(r"<[^>]+>", " ", (re.search(r"<thead.*?</thead>", t, re.S) or re.match("", "")).group(0) if re.search(r"<thead.*?</thead>", t, re.S) else "")
        if SKIP_HEAD.search(thead):
            continue
        # 表の直後300文字に出典リンクがあれば、一覧そのものではなく資料表と判断
        after = body[m.end():m.end() + 300]
        if "source-note" in after and "<a " in after:
            continue
        head = re.sub(r"<[^>]+>", " ", t[:200])
        head = re.sub(r"\s+", " ", head).strip()[:50]
        issues.append(f"{rows}行の表にリンクが1つも無い（{head}…）"
                      f" → 施設名・サービス名は公式ページへリンクする")

    # --- 4. 画像出典 ---
    if anchors and "event-picks-credit" not in body:
        issues.append(".event-pick を使っているのに .event-picks-credit（画像出典）が無い")

    return issues


def main():
    targets = sys.argv[1:] or sorted(glob.glob("dist/posts/*/index.html"))
    if not targets:
        print("dist/ が無い。先に npm run build を実行すること。", file=sys.stderr)
        return 2
    bad = 0
    for t in targets:
        iss = check(t)
        if iss:
            bad += 1
            print(f"\n⚠ {pathlib.Path(t).parent.name}")
            for i in iss:
                print(f"    • {i}")
    if bad:
        print(f"\n{bad} 記事に指摘あり。")
        return 1
    print(f"✓ {len(targets)} 記事すべて OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
