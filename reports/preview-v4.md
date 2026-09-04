# 動いている呼び出し方を読んでから書かせる（2026-09-04 22:21:57 JST）

> t020: `ant.create is not a function` ／ t022: **400 invalid_request_error**
> どちらも**推測で書いた**のが原因。**最初から動いているものを読むべきだった。**
> API は課金前に弾かれているので**費用は $0**。

## 1. `asuka-fill.js` の呼び出し部分（**実際に通っているもの**）

```javascript
  1	  const t16Count = recentFamilies.filter(f => f === "T16").length;
  2	  const t16Note = t16Count >= 2
  3	    ? `\n\n## ⚠️ T16 family (リスペクト型) 直近 ${t16Count} 回連続。**今回は T16/T16b/T16c/T16d/T16e 以外を選ぶこと** (単調化防止強制)`
  4	    : "";
  5	  const recentNote = recentIds.length > 0
  6	    ? `\n\n## 直近選択履歴 (新→旧)\n${recentIds.join(", ")}\n→ 同 family (T16系等) 連続2回まで、3回目は必ず別 family 選ぶこと${t16Note}`
  7	    : "";
  8	  // 2026-08-15 入力トークン削減。
  9	  //   従来は 37 テンプレを JSON.stringify(templates, null, 2) で毎回そのまま送っていた。
  10	  //   実測で入力 5,238tok のうち約 3,561tok がこの塊で、全体の 68% を占めていた。
  11	  //   整形用の空白とキー名（id/category/scenario/template）が繰り返し乗るのが主因。
  12	  //   1行1テンプレの素朴な表記に落とすと、選択に必要な情報（型番・場面・文面）は
  13	  //   保ったままトークンだけ削れる。cooldown 対象は候補から除いて渡す量自体も減らす。
  14	  const recentFamilySet = new Set(recentFamilies);
  15	  const usable = templates.filter(t => !recentFamilySet.has(family(t.id)));
  16	  // 全部が cooldown に当たる異常時は元の一覧に戻す（候補ゼロで生成不能になるのを防ぐ）
  17	  const offered = usable.length >= 5 ? usable : templates;
  18	  const templateLines = offered
  19	    .map(t => `${t.id}|${t.category}|${t.scenario}|${t.template}`)
  20	    .join("\n");
  21	  const userMsg = `## viral post (作者: @${trend.author || "unknown"})\n${trend.text}\n\n## 利用可能テンプレ集 (${offered.length}個、形式: id|category|scenario|template�
  22	
  23	  const maxAttempts = 3;
  24	  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
  25	    const resp = await ant.call({
  26	      model: MODEL,
  27	      system: SYSTEM,
  28	      user: userMsg + (attempt > 1 ? `\n\n[再生成 attempt ${attempt}: 前回の出力が ${MAX_WEIGHT} weight超過 or template違反]` : ""),
  29	      max_tokens: 500,
  30	      temperature: 0.7,
  31	    });
  32	    const text = ant.textOf(resp).trim();
  33	    let parsed;
  34	    try {
  35	      const m = text.match(/\{[\s\S]*\}/);
  36	      parsed = m ? JSON.parse(m[0]) : null;
  37	    } catch { parsed = null; }
  38	    if (!parsed || !parsed.reply || !parsed.chosen_template_id) continue;
  39	    // v3 brand check: reject 私/あたし/わたし in generated reply
  40	    if (/(私|あたし|わたし)/.test(parsed.reply)) {
  41	      // re-attempt — wrong first person
  42	      continue;
  43	    }
  44	    // 2026-07-20 Layer 1: reject unfilled placeholders (e.g. {action} remains → bad tweet like "とは、やるじゃない")
  45	    if (/\{[a-z_]+\}/i.test(parsed.reply)) {
  46	      continue; // unfilled placeholder detected
```

## 2. `anthropic-client.js` の中身

### export しているもの
```javascript
8:function getApiKey() {
13:  const find = (obj) => {
38:function estimateCost(model, usage) {
40:  const baseModel = Object.keys(RATES).find(k => model.startsWith(k));
49:function appendCostLog(entry) {
55:function call({ model, system, user, max_tokens = 1024, temperature = 0.7, caller }) {
64:  return new Promise((resolve, reject) => {
75:    }, (res) => {
77:      res.on("data", c => d += c);
78:      res.on("end", () => {
103:function textOf(response) {
104:  return (response.content || []).filter(b => b.type === "text").map(b => b.text).join("\n");
107:function twitterWeight(text) {
114:module.exports = { call, textOf, twitterWeight };
```

### リクエストの組み立て方
```javascript
38:function estimateCost(model, usage) {
39:  // Find best matching rate (model id may have suffix like "-20251001")
40:  const baseModel = Object.keys(RATES).find(k => model.startsWith(k));
51:    fs.appendFileSync(COST_LOG, JSON.stringify(entry) + "\n");
55:function call({ model, system, user, max_tokens = 1024, temperature = 0.7, caller }) {
57:  const body = JSON.stringify({
58:    model,
59:    max_tokens,
61:    system: system || undefined,
62:    messages: [{ role: "user", content: user }],
65:    const req = https.request({
67:      path: "/v1/messages",
71:        "anthropic-version": "2023-06-01",
73:        "content-length": Buffer.byteLength(body),
84:            const cost = estimateCost(model, parsed.usage);
88:              model,
98:    req.write(body);
```

## 3. もう一度 書かせる

- 部品 6 個・構文 OK
- 候補: **5 件**

---

**相手の投稿**

> おやつははま寿司🐣 いつもの8貫セット🤭 まぐろ軍艦4貫🍣🍣🍣🍣 サーモンゆず塩4貫🐟🐟🐟🐟 これが一番美味�

**返信案**

> 8貫セット300円ちょいはコスパ最強だ。まぐろとサーモンゆず塩の組み合わせ、わかる

- 共有した語: `セット, 300, サーモン`

---

**相手の投稿**

> お昼はマックで🍔🍟🥤 マックチキンセットよ😘 500円でお得🉐 #節約

**返信しない**

```
生成側が skip: マックのセット購入報告だが、500円がお得かどうかは相手の条件次第で、金額を断定できない。同意だけでは情報が足りない
```

---

**相手の投稿**

> 【楽天スーパーセール】#PR この後20:00～、シューズショップASBee 20%OFF  https:// a.r10.to/hP9zyf 各ブランド商品が20%OFFに！ 日

**返信しない**

```
生成側が skip: 紹介コード・URLへの誘導が含まれているため
```

---

**相手の投稿**

> ①300万ポイント山分け🎁 ②楽天市場1,000円OFFクーポン🎁  拡散（ログインしてもらうだけ）で貰える！  ふみふみ希望�

**返信しない**

```
生成側が skip: 紹介コード・URLが含まれており、ユーザーへの誘導コンテンツのため
```

---

**相手の投稿**

> 🐈‍⬛楽天超ミニバイト  クリック　1ポイント 👉️ https:// a.r10.to/hPjL5K  メッセージ → おトク情報 でクリック 引用元

**返信しない**

```
生成側が skip: 紹介コード・URLが含まれており、また相手の投稿は情報共有で、こちらから足せる固有の情報がない
```

---

**投稿していない。** 直すなら `ops/data/reply-style-prompt.json` だけでよい。
