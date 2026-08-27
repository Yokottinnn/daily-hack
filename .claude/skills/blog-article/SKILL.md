---
name: blog-article
description: daily-hack のブログ記事を書く・直す・公開するときの必須手順。記事の新規作成、既存記事の加筆・リライト、アイキャッチや記事内画像の用意、公開前の検証で必ず使う。「記事を書いて」「〇〇のまとめを作って」「この投稿を参考にして記事を」「表紙を作って」「記事を直して」に該当したら、本文を1行でも書く前に読むこと。
---

# ブログ記事の作り方（daily-hack）

**このスキルを読まずに記事を書き始めない。** 2026-08-22 に、読まずに書いた記事が
**サウナと無関係の表紙**（カテゴリ共通フォールバック画像）で公開され、差し戻された。
既存のパイプライン（`scripts/gen-*-eyecatch.py`・`fetch-commons-photo.py`・
`check-article-ux.py`）を無視したのが原因。

基準は直近の高品質 3 本。**構成・部品・検証をこの 3 本に合わせる。**

- `src/content/posts/lalaport-guide-2026.md`（表示 338・平均 7.7 位。最も検索に効いている）
- `src/content/posts/outlet-mall-guide-2026.md`
- `src/content/posts/wangan-august-events-2026.md`

迷ったら**この 3 本を開いて真似する。** 記憶で書かない。

## 0. 絶対に外さない 5 つ

| # | ルール | 破ると |
| --- | --- | --- |
| 1 | **アイキャッチを必ず作る**（`/images/<slug>/eyecatch.jpg`・1600×900） | 記事と無関係の共通画像が表紙になる |
| 2 | **1 セクション 1 ビジュアル**（h2/h3 ごとに画像・表・X 埋め込みのどれか） | 文字だけの壁になる |
| 3 | **施設名・サービス名が並ぶ表は公式へリンク** | `check-article-ux.py` が落とす |
| 4 | **画像は必ず出典を書く**（`figcaption > cite` / `source-note` / `event-picks-credit`） | ライセンス違反 |
| 5 | **公開前に `npm run build` → `check-article-ux.py` を通す** | 崩れたまま出る |
| 6 | **使う画像は必ず自分の目で見る**（`Read` で開く） | 題材違い・不適切な画像がそのまま表紙になる |

## 1. アイキャッチ（最優先・後回し禁止）

**`eyecatchUrl` を書かないと、カテゴリ共通のフォールバック画像が表紙になる**
（`src/layouts/PostLayout.astro`）。**ビルドは通るし警告も出ない。** だから気づけない。
記事のテーマと無関係の画像が表紙として公開される。

### フロントマターに必ず両方書く

```yaml
eyecatchUrl: "/images/<slug>/eyecatch.jpg"
eyecatchAlt: "<記事タイトルと同等の説明>"
```

### 作り方

1. **背景写真を Wikimedia Commons から取る。** ライセンス台帳とセットで。

   ```bash
   python3.11 scripts/fetch-commons-photo.py --search "Sauna Finland" --limit 8
   python3.11 scripts/fetch-commons-photo.py --file "File:Xxx.jpg" \
       --key hero --dir public/images/<slug>/photos
   ```

   `_manifest.json` に `lic` / `artist` / `page` が記録される。**手で拾わない。**

2. **写真ヒーロー型で 1600×900 を生成する。**

   ```bash
   python3.11 scripts/gen-photo-hero.py \
     public/images/<slug>/photos/hero.jpg \
     public/images/<slug>/eyecatch.jpg \
     "<キッカー>" "<タイトル1行目>" "<タイトル2行目>" "<サブ>" "<出典クレジット>"
   ```

   構図を変えたいときは既存の `scripts/gen-*-eyecatch.py` を複製して調整する
   （`gen-sauna-eyecatch.py` / `gen-outlet-eyecatch.py` などが実例）。

3. **できた画像を必ず開いて見る。**

   ```text
   Read(file_path="…/eyecatch.jpg")
   ```

   **これを飛ばさない。** 2026-08-22、`sauna openings` の記事で
   検索語 `sauna interior wood` の 1 件目を無条件に採用したところ、
   **19 世紀の木版画「蒸し風呂に入る女性患者たち」**が選ばれた。
   題材が合わないうえ裸体が写っており、表紙として使えるものではなかった。

   **検索語が正しくても、1 件目が使える画像とは限らない。**
   Commons には絵画・古い版画・図版が大量に入っている。

### 候補は「見て選ぶ」

自動で 1 件目を採る運用はしない。`ops/tasks/022-sauna-photo-candidates.sh` が実例で、
**候補を 480px のサムネイルに落としてブランチへ push し、目で見てから決める。**

```text
検索 → 上位数件をサムネイル化して push → Read で見て選ぶ → 本採用して生成 → また見る
```

写真に求める条件。

- **現代の実写。** 版画・絵画・図版は使わない
- **裸体・人物の顔が主題になっていない**
- 横長で使える（カード背景・1600×900 に切っても破綻しない）
- ライセンスが再利用可（`fetch-commons-photo.py` が非フリーを弾くが、`_manifest.json` で確認する）

### クラウドセッションでは生成できない

**このリポジトリのクラウドセッションには日本語フォントが無く（Noto Color Emoji のみ）、
Commons にも到達できない**（egress が塞がれている。2026-08-22 実測）。
`gen-*.py` は macOS のヒラギノを直接参照している。

**だから画像づくりは Mac に投げる。** `ops/tasks/NNN-*.sh` をコミットすれば
30 分以内に Mac で走る（`CLAUDE.md` の「機械的な操作は ops/tasks に置く」）。
タスクは生成した画像を**リポジトリにコミットして push する**ところまで書く。

**画像が用意できるまで記事を公開しない。** 表紙なしで出すのは不可。

## 2. 記事の型

### フロントマター

```yaml
---
title: "<主題>｜<数字の入った具体的な引き>"        # 100字以内
description: "<50〜160字。数字を必ず入れる>"
publishDate: 2026-08-22
category: ["roundups", "comparisons"]              # config の enum のみ
tags: ["<主題>", "<固有名詞>", "2026年版"]
isPR: false
draft: false
eyecatchUrl: "/images/<slug>/eyecatch.jpg"
eyecatchAlt: "<説明>"
author: "hacker-ko"
references: ["<出典URL>", ...]
---
```

### 冒頭（この順を崩さない）

1. **読者の疑問をカギカッコで 2 つ** →「検索しても出てこない」と断じる
2. **「だからアタシが作った」** + 何を土台にしたか（公式資料名を出す）
3. `hakkako-says` で**一番の驚きを先に**言う（`expr-05-smug.png`）

```html
<div class="hakkako-says">
  <div class="hakkako-mascot"><img src="/images/expr-05-smug.png" alt="Daily Hackマスコット" /></div>
  <div class="hakkako-quote">先に一番の驚きを言っとく。<strong>…</strong></div>
</div>
```

### `## 30秒で分かる、〜` ＋ 写真カード 6 枚

**一覧・選択肢は必ず `.event-pick` の写真背景カード。** 文字だけの `.highlight-grid` を
4 枚以上並べるのは禁止（`check-article-ux.py` が落とす）。

```html
<div class="event-picks">
  <a class="event-pick" href="#<リンク先h2のid>" style="--pick-img:url('/images/<slug>/photos/xxx.jpg')">
    <span class="pick-date">総数</span>
    <h4>全国32施設</h4>
    <p>…<strong>数字</strong>…</p>
    <span class="pick-go">詳しく見る →</span>
  </a>
  …6枚…
</div>
<span class="event-picks-credit">カード画像は…より引用。</span>
```

**`href` の id は実在させる。** `.section-with-mascot` の中の h2 には自動で id が
振られないので、**その場合は `<h2 id="...">` を手で書く。**

### 本文セクション

- 見出しは `## <主題>｜<結論>` の形（例: `## 店舗別売上ランキング｜三井不動産の決算資料そのまま`）
- **検索語を見出しに入れる。** 内容が本文にあっても、見出しに語が無いと順位が付かない
  （`docs/analytics/lalaport-keyword-inventory.md` の実測）
- 節ごとに `.section-with-mascot` でマスコットを添える（表情は内容に合わせる）

```html
<div class="section-with-mascot">
  <div class="mascot-wrap"><img src="/images/expr-07-gasp.png" alt="Daily Hackマスコット" /></div>
  <h2 id="見出しのid">見出し</h2>
</div>
```

### 使う部品

| 用途 | マークアップ |
| --- | --- |
| 比較表 | `<div class="cmp-table-wrap"><table class="cmp-table">`。推す行は `<tr class="recommended">` |
| 写真 | `<figure class="rn-figure">` + `figcaption` に `<cite>出典: <a …></cite>` |
| 手順・分類の解説 | `<ul class="checklist"><li><div class="checklist-body"><strong>①…</strong><p>…</p>` |
| 年表・時系列 | `<div class="tower-timeline"><div class="tl-year"><p class="tl-label">…<ul class="tl-items">` |
| 少数の紹介（3件程度） | `<div class="highlight-item"><span class="highlight-tag">…</span><h4>…</h4><p>…</p>` |
| 出典 | `<p class="source-note">出典：<a …>…</a>／…</p>` |
| 関連記事 | `<aside class="related-block">`（`related-block-thumb` に画像を入れる） |

**マークアップは記憶で書かず、上の 3 本から実物をコピーして中身を差し替える。**

### 締め

- **「この記事で『分からない』と書いたこと」** を必ず置く。埋められなかったところを
  埋めたふりで書かない。推測値を載せない
- 関連記事ブロック
- `hakkako-says` で締める（`expr-01-wave.png`）

## 3. 中身の作法

- **数字で答える。** 「多い」ではなく「20 施設中 12＝6 割」。他所が出していない
  切り口の数字を 1 つは作る（順位づけ・比率・倍率）
- **数値が割れたら、割れた理由を書く。** どちらが誤りとは書かない。
  ららぽーと記事の「他サイトと面積・店舗数が食い違う理由」が実例
- **出典は一次情報。** 決算資料・プレスリリース・公式サイト。まとめサイトを根拠にしない
- **一人称は「アタシ」**、マスコットは**ハッカー子**
- 参考にした外部記事・投稿の**本文は流用しない。** 題材を起点に自分で裏を取り直す

## 4. 公開前の検証（全部やる）

```bash
npm run build                                   # 通ること
python3 scripts/check-article-ux.py dist/posts/<slug>/index.html   # 指摘ゼロにする
python3 scripts/check-md-bold.py dist/posts/<slug>/index.html      # ** の崩れ
```

さらに手で確認する。

- **`eyecatchUrl` のファイルが実在するか**（`ls public/images/<slug>/eyecatch.jpg`）
- **アイキャッチと記事内画像を `Read` で開いて、題材が記事と合っているか**
- 生成 HTML のタグ開閉が一致しているか
- **本文の数字を表から機械的に再集計して一致するか**（手で数えない）
- `.event-pick` の `href` の id がビルド後 HTML に存在するか

**どちらもビルド後の HTML を渡す。** `.md` を渡すと `check-md-bold.py` は
ソース中の `**` をすべて拾って大量に誤検出する（2026-08-22 に踏んだ）。

`check-article-ux.py` の指摘を「既存記事も出ているから」で見逃さない。
**新しく書いた記事は指摘ゼロで出す。**

## 4-B. 公開前に実際のページを描画して見る

**ビルドが通ってもページが正しいとは限らない。** 検査スクリプトは HTML の構造しか見ない。
**アイキャッチの文字が本文と食い違っていても、誰も止めてくれない。**

このリポジトリのクラウドセッションでもレンダリングできる。日本語フォント（IPA ゴシック）は
入っており、Chromium も置いてある。

```bash
npx --yes http-server dist -p 4321 --silent &
/opt/pw-browsers/chromium-1194/chrome-linux/chrome --headless --disable-gpu --no-sandbox \
  --hide-scrollbars --window-size=1200,3000 --virtual-time-budget=9000 \
  --screenshot=/tmp/shot.png "http://127.0.0.1:4321/posts/<slug>/"
```

撮ったら **`Read` で開いて見る。** 見るのは次の 4 点。

| 見るところ | ありがちな崩れ |
| --- | --- |
| **アイキャッチの文字と記事タイトルが一致しているか** | 対象を変えたのに画像を作り直していない |
| `.event-pick` の枚数と並び | 3 列グリッドなので **3 の倍数**にする。4 枚だと 3+1 で間延びする |
| 表の折り返し・はみ出し | 列が多い表はスマホ幅で崩れる |
| マスコットと吹き出しの位置 | `hakkako-says` の入れ子を間違えると崩れる |

**2026-08-22、対象を「主要20施設」から「首都圏15施設」に絞ったのに、
アイキャッチは「主要20施設」のまま公開した。** ページを描画して初めて気づいた。
検査 2 本とも通っていた。

## 5. 公開とその後

1. PR を作ってマージ（`main` は保護ブランチ・直 push 不可）
2. 公開 URL が確定したら **X 告知は tweet2 に依頼する**
   （`docs/cross-session-requests.md` に記事 URL・要点 3 つ・画像パスを書く）。
   **blog3 は X に投稿しない**（`CLAUDE.md` 最上位ルール 4・5）
3. `npm run handoff -- "…" --next "…"` で引き継ぎを残す
