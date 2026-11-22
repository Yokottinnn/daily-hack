# MediaWiki API が空を返す原因（t162・**$0**）

生成: **2026-09-23T08:00:45+0900**

**13 ブランド すべてで空**だった。データではなく呼び方の問題として見る。
**応答の先頭 400 字をそのまま出す。加工しない。**

## ① `-G` ＋ `--data-urlencode`（t159 と同じ書き方）

### prop=images / titles=日本航空

- status **200** / **4163 bytes**

```json
{"continue":{"imcontinue":"72021|Flag_of_the_Soviet_Union.svg","continue":"||"},"query":{"pages":{"72021":{"pageid":72021,"ns":0,"title":"\u65e5\u672c\u822a\u7a7a","images":[{"ns":6,"title":"\u30d5\u30a1\u30a4\u30eb:2020 Summer Olympics text logo.svg"},{"ns":6,"title":"\u30d5\u30a1\u30a4\u30eb:20210628 Haneda Airport 06.jpg"},{"ns":6,"title":"\u30d5\u30a1\u30a4\u30eb:B787-9 JAL Business class seat
```

## ② URL に直接書く（**%エンコード済み**の「日本航空」）

### prop=images（エンコード済み）

- status **200** / **4163 bytes**

```json
{"continue":{"imcontinue":"72021|Flag_of_the_Soviet_Union.svg","continue":"||"},"query":{"pages":{"72021":{"pageid":72021,"ns":0,"title":"\u65e5\u672c\u822a\u7a7a","images":[{"ns":6,"title":"\u30d5\u30a1\u30a4\u30eb:2020 Summer Olympics text logo.svg"},{"ns":6,"title":"\u30d5\u30a1\u30a4\u30eb:20210628 Haneda Airport 06.jpg"},{"ns":6,"title":"\u30d5\u30a1\u30a4\u30eb:B787-9 JAL Business class seat
```

## ③ REST API の summary（`originalimage` が返る）

### rest_v1 summary（エンコード済み）

- status **200** / **2706 bytes**

```json
{"type":"standard","title":"日本航空","displaytitle":"<span lang=\"ja\" dir=\"ltr\"><span class=\"mw-page-title-main\">日本航空</span></span>","namespace":{"id":0,"text":""},"wikibase_item":"Q213140","titles":{"canonical":"日本航空","normalized":"日本航空","display":"<span lang=\"ja\" dir=\"ltr\"><span class=\"mw-page-title-main\">日本航空</span></span>"},"pageid":72021,"thumbn
```

## ④ 英語版で同じこと（`Japan Airlines`）

### en / prop=images

- status **200** / **2685 bytes**

```json
{"batchcomplete":"","query":{"pages":{"197676":{"pageid":197676,"ns":0,"title":"Japan Airlines","images":[{"ns":6,"title":"File:19-DEC-2022 - JL112 ITM-HND (A350-900 - JA10XJ) (02).jpg"},{"ns":6,"title":"File:Aeroflot Tupolev Tu-114 JAL livery APM.jpg"},{"ns":6,"title":"File:Ambox important.svg"},{"ns":6,"title":"File:Aviacionavion.png"},{"ns":6,"title":"File:Boeing 747-146, Japan Air Lines - JAL 
```

## ⑤ UA を外したらどうなるか（弾かれているかの切り分け）

### en / UA 指定なし

- status **200** / **1333 bytes**

```json
{"continue":{"imcontinue":"197676|JAL_First_Class_Suite_777-300ER.JPG","continue":"||"},"query":{"pages":{"197676":{"pageid":197676,"ns":0,"title":"Japan Airlines","images":[{"ns":6,"title":"File:19-DEC-2022 - JL112 ITM-HND (A350-900 - JA10XJ) (02).jpg"},{"ns":6,"title":"File:Aeroflot Tupolev Tu-114 JAL livery APM.jpg"},{"ns":6,"title":"File:Ambox important.svg"},{"ns":6,"title":"File:Aviacionavio
```

---

**読み方**

- `"missing":""` が入っていれば**記事名が違う**（リダイレクトを追う必要がある）
- `"error"` が入っていれば**呼び方が違う**
- status が **403 / 429** なら**弾かれている**（UA かレート）
- ①だけ空で②が返るなら、**`-G --data-urlencode` の書き方が原因**

**次の一手はこの応答を見てから決める。推測でもう 1 往復しない。**
