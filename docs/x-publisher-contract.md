# X 投稿キューの契約（`auto-x-publisher.js` / `queue-manager.js`）

**投稿タスクを書く前にここを読む。** 推測で積むと、エラーも出さずに
「候補なし」で黙って終わる。**それを 2026-08-30 に 3 回やって 2 時間 20 分 失った**
（経緯は [`x-post-latency-postmortem.md`](x-post-latency-postmortem.md)）。

実体は Mac の `~/.openclaw/workspace/scripts/`。クラウドからは読めないので、
**ここに写しを固定する。** 値はすべて実機の出力から取ったものであり、推測ではない。

最終更新: 2026-08-30（`t004` のレポート `post-sauna-v3.md` / `post-sauna.md` の実出力より）

## 1. いちばん間違えるところ

> **`blog-promo` は kind の名前ではない。「モード」の名前である。**

```javascript
// auto-x-publisher.js
  6: *   kind = blog-promo (== thread + blog-promo- prefix)
 42: if (!["blog-promo", "trend_post", "trend_qt"].includes(KIND)) {
 43:   console.error("usage: node auto-x-publisher.js <blog-promo|trend_post|trend_qt>");
136:        e.kind === "thread" &&
137:        (e.id || "").startsWith("blog-promo-") &&
```

| | コマンドライン引数 | キューに積む `kind` |
| --- | --- | --- |
| ブログ告知 | `blog-promo` | **`thread`** |

**そして `id` は `blog-promo-` で始めなければ候補にならない。**

積む形を間違えると、publisher はエラーではなくこれを返す。**成功に見えるので気づきにくい。**

```json
{"ok":true,"action":"skip","reason":"no candidate","kind":"blog-promo"}
```

## 2. 確定している契約

| 項目 | 値 | 根拠 |
| --- | --- | --- |
| モード引数 | `blog-promo` / `trend_post` / `trend_qt` | `auto-x-publisher.js:42` |
| ブログ告知の `kind` | **`"thread"`** | 同 `:136` |
| ブログ告知の `id` | **`blog-promo-` 接頭辞が必須** | 同 `:137`、`:6` |
| enqueue の必須フィールド | `id`, `kind`, `text` | `queue-manager.js:145` |
| 承認不要な kind | `["comment", "reply"]` | 同 `:108`（`NO_APPROVAL`） |
| enqueue 直後の status | `pending` | `t004` 実測 |
| 同日ガード | その日すでに `posted` な `thread` があれば skip | `auto-x-publisher.js:131-132` |

### 積み方の例

```bash
# ✅ 正しい形
node -e '
const [id,text,dir]=process.argv.slice(1);          # ← slice(1)。slice(2) ではない
const o={id, kind:"thread", text};                   # ← kind は thread
o.images=["1-summary","2-maihama"].map(f=>`${dir}/${f}.jpg`);
console.log(JSON.stringify(o));
' "blog-promo-sauna-openings-2026-$(date +%Y%m%d-%H%M%S)" "$TEXT" "$IMGDIR" \
  | node scripts/queue-manager.js enqueue

node scripts/auto-x-publisher.js blog-promo          # ← ここは blog-promo
```

> **`node -e 'code' A B C` は `process.argv = [execPath, A, B, C]`。**
> スクリプトのパスが入らないので **`slice(1)`** が正しい。
> `slice(2)` にすると先頭の引数が落ちる（`t002` で `id` に本文が入った）。

## 3. まだ確定していないもの（**埋めるまで当て推量で使わない**）

| 項目 | 状況 | 確定させる方法 |
| --- | --- | --- |
| 画像のフィールド名 | **未確定。** `t004` の全文検索は `images` を返したが根拠が弱い | `auto-x-publisher.js` の 205〜245 行（blog-promo の画像処理）を dump する |
| 候補条件の `status` | **未確定。** 136〜137 行の前後が未取得 | 同 120〜150 行を丸ごと dump する |
| リプライの親を渡すキー | **未確定** | `grep -n 'reply\|in_reply\|thread_parent' auto-x-publisher.js queue-manager.js` |

**当面の逃げ方**: 画像キーは候補（`images` / `imagePaths` / `imageFiles` / `media` /
`attachments`）を**全部入れて積む。** 余分なキーは無視されるだけだが、
足りないと**画像なしで投稿されてしまう。**

リプライのキーは逃げが利かない。**見つからないなら積まない。**
無視されると [2/2] が**独立ツイートとして出て**、スレッドが繋がらない。

## 4. 書く前のチェックリスト

- [ ] `kind` は `"thread"` か（`"blog-promo"` にしていないか）
- [ ] `id` は `blog-promo-` で始まっているか
- [ ] `node -e` の argv は `slice(1)` か
- [ ] publisher に渡すのは **kind ではなくモード名**（`blog-promo`）か
- [ ] 画像キーは候補を全部入れたか
- [ ] 投稿前後に件数を数え、2 件以上なら止める仕掛けが入っているか
- [ ] **人が手で投稿した可能性を考えたか**
      （キューの件数ガードは **X 上の手動投稿を検知できない**。
      2026-08-30 に利用者が手で投稿し、タスクを main から消して止めた）

## 5. 関連

- `ops/tasks` の実行モデル: [`ops-task-runner.md`](ops-task-runner.md)
- 遅延の経緯と対策: [`x-post-latency-postmortem.md`](x-post-latency-postmortem.md)
- 画像の作り方: `.claude/skills/x-post-images/SKILL.md`
