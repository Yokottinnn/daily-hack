# 返信の生成器を全文生成に配線する（2026-09-06 20:52 JST・費用 $0）

> **`asuka-reply.cjs` は Mac に一度も入っていなかった**（x01 で判明）。
> あのまま起動していたら、**確実に古いテンプレ経路で返信が出ていた。**
> **起動しない。** 試験生成の文面を利用者が見てから。

## 0. 私が壊した NG ルールを戻す

`x01` で `reply-ng-rules.json` を 4160 → 3246 B に置換した。
**リポジトリ側が古く（PR #229）、Mac 側が新しかった（8/28 更新）。**
**直す前に、自分が壊したものを戻す。**

```
  戻した: 3246 → 4160 B
  出どころ: reply-ng-rules.json.bak.20260906-201513
```

**リポジトリ側の `ops/data/reply-ng-rules.json` も、Mac の版に合わせて更新すること。**
（このタスクはリポジトリを書き換えない。次に人がやる）

### 戻したあとの中身の頭

```json
{
  "_readme": "返信してはいけない相手を種類で弾くためのルール。ops/tasks が Mac の data/ へ配る。",
  "_policy": "誤って弾くより、誤って返信する方が高くつく。迷ったら弾く（fail-closed）。",
  "version": 1,
  "updated": "2026-08-23",
  "hard_ng_words": {
    "_note": "1 語でも一致したら即 NG。売春・性的サービスの勧誘に固有の語だけを入れる。",
    "words": [
      "パパ活",
      "ぱぱ活",
      "P活",
      "ママ活",
      "円光",
      "援交",
      "援助交際",
      "援助希望",
      "割り切り",
      "わりきり",
      "即会い",
      "即アポ",
      "即ホ",

```

## 1. 配線の前の状態

```bash
80:# 2026-05-13: 直近5件の chosen_template_id を queue から抽出して asuka-fill に渡す (単調化防止)
111:  GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS="$RECENT_IDS" /usr/local/bin/node scripts/asuka-fill.js 2>&1)
```

- 生成器の呼び出し: **1 箇所**（`asuka-fill.js`）

## 2. 差し替えに必要なものが揃っているか

**揃っていなければ差し替えない。** 呼んだ瞬間に落ちる状態にしない。

```
  OK    scripts/asuka-reply.cjs
  OK    scripts/reply-relevance-check.cjs
  OK    scripts/tone-gate.cjs
  OK    scripts/ng-filter-candidates.cjs
  OK    data/reply-style-prompt.json
  OK    data/reply-relevance-rules.json
  OK    data/reply-ng-rules.json
  OK    data/reply-tone-rules.json
  OK    scripts/anthropic-client.js
```

## 3. 配線する（**1 行だけ**）

`asuka-fill.js` → `asuka-reply.cjs`。
**`RECENT_TEMPLATE_IDS` は落とす**（テンプレ方式の変数で、全文生成では使わない）。
**`2>&1` を `2>>$LOG` に変える**——標準エラーが JSON に混ざると、
`GEN_OK` の判定が必ず false になる（`tone-gate.cjs` は既にそうしている）。

- 退避: `comment-orchestrator.sh.bak.20260906-205207`

  置換した

## 4. 配線したあとの確認

```bash
46:CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
80:# 2026-05-13: 直近5件の chosen_template_id を queue から抽出して asuka-fill に渡す (単調化防止)
111:  GEN_OUT=$(echo "$GEN_INPUT" | /usr/local/bin/node scripts/asuka-reply.cjs 2>>"$LOG")
113:  GEN_OUT=$(printf %s "$GEN_OUT" | /usr/local/bin/node scripts/tone-gate.cjs 2>>"$LOG")
```

- `asuka-fill.js` の残り: **0 箇所**（0 なら完全に外れた）
- `asuka-reply.cjs` の呼び出し: **1 箇所**

### シェルの構文が通るか

```
  構文OK
```

## 5. ジョブは触っていない

```
  comment-warmup: **未ロード（触っていない）**
```

**次は試験生成。** 少数だけ生成して文面をチャットに出し、
**利用者が読んでから**起動する。ここまでは 1 度も LLM を呼んでいない。

---

**返信を生成していない。投稿していない。ジョブも起動していない（$0）。**
