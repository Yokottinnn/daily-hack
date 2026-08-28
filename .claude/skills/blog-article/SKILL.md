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

## 0. 絶対に外さない 8 つ

| # | ルール | 破ると |
| --- | --- | --- |
| 1 | **アイキャッチを必ず作る**（`/images/<slug>/eyecatch.jpg`・1600×900） | 記事と無関係の共通画像が表紙になる |
| 2 | **1 セクション 1 ビジュアル**（h2/h3 ごとに画像・表・X 埋め込みのどれか） | 文字だけの壁になる |
| 3 | **施設名・サービス名が並ぶ表は公式へリンク** | `check-article-ux.py` が落とす |
| 4 | **画像は必ず出典を書く**（`figcaption > cite` / `source-note` / `event-picks-credit`） | ライセンス違反 |
| 5 | **公開前に `npm run build` → `check-article-ux.py` を通す** | 崩れたまま出る |
| 6 | **使う画像は必ず自分の目で見る**（`Read` で開く） | 題材違い・不適切な画像がそのまま表紙になる |
| 7 | **対象が複数なら 1 対象 1 セクション**（表だけで済ませない） | 「一覧はあるが、個々が分からない」記事になる |
| 8 | **X の実投稿と YouTube を埋め込む**（実在するものだけ） | 一次の声が無く、どこにでもある要約記事になる |

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

### 対象が複数の記事は「タイル合成」にする

**施設一覧・イベント一覧のように対象が複数ある記事は、1 枚の写真では中身が伝わらない。**
`scripts/gen-mosaic-hero.py` が 3×2 のタイルに敷いて合成する。

```bash
python3.11 scripts/gen-mosaic-hero.py OUT.jpg KICKER TITLE1 TITLE2 SUB CREDIT img1 … img6
```

- **6 枚そろわないなら合成しない。** 足りないまま作ると同じ画像が繰り返されて破綻する
- タイルは**対象そのものの写真**を使う。街の風景で代用すると「施設一覧」に見えない
- 施設写真は Commons に無いことが多い。**公式サイトのギャラリーから取る**
  （既存記事と同じ方式。クレジットは「画像: 各施設公式サイト」）
- **`og:image` を当てにしない。** 2026-08-27 に 6 施設で試したところ、
  5 枚中 4 枚がロゴやサイト共通バナーだった。**`og:image` は SNS シェア用の
  ブランド画像であって施設写真ではない。** ページ内の `<img>` と CSS の `url()` から
  横長で 640×360 以上のものを拾うこと

#### タイルは 6 枚とも見える配置にする

**3×2 のタイルの上に見出しを重ねると、左の 2 枚が文字で潰れて 4 枚しか見えない。**
2026-08-27 のサウナ記事で実際にそうなった。**「6 枚使った」ではなく
「6 枚見える」が要件。**

```bash
python3 scripts/gen-tile6-hero.py OUT.jpg KICKER T1 T2 SUB CREDIT img1 … img6
# 左に見出し帯（幅 596px・不透明）｜右に 2 列 × 3 行のタイル（各 491×294）
```

見出しとタイルの領域を**重ねずに分ける**。作ったら必ず `Read` で開いて、
**6 枚を数える。**

タイルは**別々の対象**にする。同じ施設の写真を 2 枚入れると「6 施設ぶん」に見えない。

#### 表紙の隅の文字は、まず生成器のコードを読む

2026-08-27 に、表紙の右下に出た `@heng_ji31590` を**「拾ってきた写真に入っていた
第三者の透かし」だと判断して、その写真を記事から外した。** 誤りだった。
`scripts/gen-mosaic-hero.py` が**このサイト自身のハンドルとして刻印している**もので、
写真には何も入っていなかった。

```bash
grep -n 'heng_ji31590' scripts/gen-*.py   # 生成器が何を描いているか先に見る
```

- **合成後の画像だけを見て、素材の欠陥だと決めない。** 素材を等倍で開いて確かめる
- 素材を外す前に、**外す理由が素材の側にあることを確認する**

それでも**本物の透かしは弾く。** 公式サイトから拾った写真でも、中身が第三者の
ストック写真のことがある。切り抜いて消すのは出典表示を削る行為なので不可。
その施設の写真として使わない。

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

### 合成はクラウドセッションでもできる。取れないのは「素材」だけ

**「日本語フォントが無い」は誤り。** 2026-08-27 に `fc-list` を `noto|cjk` で絞って
探したせいで見落としていた。実際には IPA ゴシックが入っている。

```bash
ls /usr/share/fonts/opentype/ipafont-gothic/ipag.ttf   # 日本語フォント
pip install Pillow                                     # pypi は NO_PROXY に入っている
```

**だから合成・確認・作り直しはこのセッションで完結する。** 何度でも作り直して
`Read` で見ればよく、1 往復 30 分かかる `ops/tasks` を回す必要はない。

**Mac に投げるのは「外から取ってくる」ところだけ。** クラウドセッションは
egress が塞がれていて（`WebFetch` は全ホストで `EGRESS_BLOCKED`、`curl` は
CONNECT 403）、公式サイトの写真も Commons の画像も取れない。

```text
素材を取る    → ops/tasks で Mac（30 分以内に走る）
合成・確認     → このセッション（Pillow ＋ IPA ゴシック）
```

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

### 対象が複数あるなら、1 対象 1 セクション

**一覧表を出して終わりにしない。** 表は「全体を見渡す」ためのもので、
読者が本当に知りたいのは「自分が行く 1 つ」のこと。

対象ごとに小見出しを立て、次を書く。

| 書くこと | 補足 |
| --- | --- |
| 見出しに**対象名をそのまま入れる** | 「高輪SAUNAS」で検索した人がここに着地する |
| 料金・最寄駅・男女の別 | 表と同じ値。**節だけ読んでも完結させる** |
| その施設だけの特徴 | 「日本初のトラムサウナ」のように 1 つ具体を出す |
| 公式へのリンク | 必ず張る |

**対象が 15 個あるなら 15 節書く。** 多いから表でまとめる、は逆。
検索は対象名で来るので、節が無いとその流入を丸ごと落とす。

節の並びはこの順で固定する。**節ごとにばらつかせない。**

```text
### ① 施設名（開業日・都県）
写真（あれば。figcaption に出典）
仕様表（最寄・料金・男女の 2 列）
その施設だけの一文
X の実投稿 か YouTube（あれば）
```

**素材が無い節は素材無しで出す。** 埋めるために別の施設の写真を流用したり、
一般的なサウナ写真で代用したりしない。

### X の実投稿を埋め込む

**行った人の声が無い記事は、どこにでもある要約記事になる。**
対象ごとに、その施設に触れている実投稿を 1 つ埋め込む。

```html
<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">（投稿本文）</p>
&mdash; 表示名 (@handle) <a href="https://twitter.com/handle/status/ID">日付</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
```

`blockquote.twitter-tweet` は `global.css` に定義済みで、`widgets.js` が
読み込めなくても**カードとして読める形で出る。**

- **実在する投稿だけ。** URL を組み立てて作らない。**捏造は記事全体の信用を壊す**
- **本文・投稿者・日付は syndication API で取る。** 検索結果の抜粋を信じない

  ```bash
  curl -s "https://cdn.syndication.twimg.com/tweet-result?id=<TWEET_ID>&lang=ja&token=a"
  # → text / user.name / user.screen_name / created_at
  ```

- クラウドからは x.com に到達できないので、`ops/tasks` 経由で Mac に探させる
- 宣伝ではなく**体験の投稿**を選ぶ。公式の告知だけ並べても読者の役に立たない

### YouTube の Vlog を埋め込む

サウナ・施設・イベントの記事は、**映像があると滞在時間が伸びる。**
その対象を扱った動画があれば埋め込む。

```html
<div class="yt-embed"><iframe src="https://www.youtube-nocookie.com/embed/<VIDEO_ID>"
  title="（動画タイトル）" loading="lazy" allowfullscreen
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe></div>
```

`.yt-embed` は `global.css` に定義済み（16:9・角丸・最大 720px）。**インラインの
`style` を書かない。**

- **実在する動画 ID だけ。** 存在しない ID は再生できず、崩れて気づかれる
- **タイトルは oEmbed で照合する。** スクレイプしたタイトルは文字化けすることがあり、
  それを信じると**別の施設の動画を貼る。** 2026-08-27 に 3 本がこれで弾かれた
  （`suien` → 麻布十番の別店、`kaizoku` → **山賊**サウナ、`monnaka` → 幕張の別店）

  ```bash
  curl -s "https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=<ID>"
  # → title と author_name が返る。対象施設と一致しなければ使わない
  ```

- `youtube-nocookie.com` を使う

### 読者の「次の疑問」を先回りする

**記事の中で強い事実を出したら、そこから派生する検索を必ず拾う。**

| 記事が出した事実 | 読者が次に検索すること | 立てるべき節 |
| --- | --- | --- |
| 男性専用が半分以上 | 「サウナ 女性 入れる」 | **女性が利用できる施設だけの節** |
| 料金に 6.7 倍の開き | 「サウナ 安い」 | 予算別の節 |
| 7 月に集中 | 「サウナ 新店 いつ」 | これから開く施設の節 |

**言いっぱなしにしない。** 「男性専用が多い」で終わると、女性の読者はそこで離脱する。

### 使う部品

| 用途 | マークアップ |
| --- | --- |
| 比較表 | `<div class="cmp-table-wrap"><table class="cmp-table">`。推す行は `<tr class="recommended">` |
| 1 対象の仕様（最寄・料金など） | `<table class="cmp-table spec-table">` に `<tbody>` だけ。ラベルは `<th>` |
| 写真 | `<figure class="rn-figure">` + `figcaption` に `<cite>出典: <a …></cite>` |
| 手順・分類の解説 | `<ul class="checklist"><li><div class="checklist-body"><strong>①…</strong><p>…</p>` |
| 年表・時系列 | `<div class="tower-timeline"><div class="tl-year"><p class="tl-label">…<ul class="tl-items">` |
| 少数の紹介（3件程度） | `<div class="highlight-item"><span class="highlight-tag">…</span><h4>…</h4><p>…</p>` |
| 出典 | `<p class="source-note">出典：<a …>…</a>／…</p>` |
| 関連記事 | `<aside class="related-block">`（`related-block-thumb` に画像を入れる） |

**マークアップは記憶で書かず、上の 3 本から実物をコピーして中身を差し替える。**

#### 生の HTML ブロックの中で `**` は効かない

Markdown の強調は**HTML ブロックの内側では処理されない。**`<table>` や `<div>` の
中に `**〜**` を書くと、そのまま `**` として表示される。`check-md-bold.py` が
拾うが、**HTML を書いたら最初から `<strong>` を使う。**

`**〜**` が効かないもう 1 つの型が、**閉じ側の直前に句読点や引用符が来る**場合。

```text
✗ **"まちのリビング"**がコンセプト   → 「**まちのリビング**」がコンセプト
✗ **無料。**18:30〜                 → **無料**。18:30〜
```

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

#### ビルドの成否を先に見る。落ちていても検査 2 本は通る

**検査スクリプトは `dist` を読む。** ビルドが落ちると `dist` は前回のまま残るので、
**古い HTML を見て「OK」と言ってくる。** 2026-08-28 に `description` が
160 字の上限を超えてビルドが落ちたのに、検査 2 本は通った。

```bash
npm run build 2>&1 | tail -2      # ← ここで "Complete!" を確認してから検査へ進む
```

`&&` でつないで、ビルドが落ちたら検査に進まないようにするのが安全。

#### フロントマターの上限

| 項目 | 上限 |
| --- | --- |
| `title` | 100 字 |
| `description` | **160 字**（超えるとビルドが落ちる） |

#### ページ内リンクの id は、ビルド後 HTML から取る

`### ① PARADISE 大手町（2/1・東京）` から自動生成される id は
`-paradise-大手町21東京` で、**丸数字も記号も落ちる。** 推測で書くと必ず外す。

```bash
npm run build
python3 - <<'EOF'
import re
h=open('dist/posts/<slug>/index.html',encoding='utf-8').read()
ids=set(re.findall(r'id="([^"]+)"',h)); hrefs=set(re.findall(r'href="#([^"]+)"',h))
print('リンク切れ:',[x for x in hrefs if x not in ids])
EOF
```

**未解決ゼロを機械で確認する。** 目で追わない。
`♻️` のような絵文字は**異体字セレクタが id に残る**ので、なおさら手では書けない。

さらに手で確認する。

- **`eyecatchUrl` のファイルが実在するか**（`ls public/images/<slug>/eyecatch.jpg`）
- **アイキャッチと記事内画像を `Read` で開いて、題材が記事と合っているか**
- **埋め込んだ X 投稿と YouTube が実在するか**（URL / 動画 ID を目で追う。組み立てた URL は必ず壊れる）
- **対象ごとの節がそろっているか**（15 施設なら 15 節。表だけで済ませていないか）
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
