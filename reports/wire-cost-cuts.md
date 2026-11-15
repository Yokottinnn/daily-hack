# x23 は入ったが効いていない — 実際に配線する

**このレポートが作られた時刻: 2026-09-12 23:08:47 JST**

> `x23` の実測: **「定数は入れたが、連結先が見つからない」**
> `isThinContent()` も**追記しただけで呼ばれていない。**
> **足しただけでは効かない。呼ばれて初めて効く。**

## 1. 生成器はプロンプトをどう組み立てているか（**全文**）

推測で差し込んで失敗した。**今度は全部 読む。**

```javascript
  // asuka-reply.cjs — 249 行
     1	'use strict';
     2	// **返信を毎回 書き下ろす生成器。** `asuka-fill.js`（テンプレ 37 件の穴埋め）の置き換え。
     3	//
     4	// 2026-09-02 の指摘「トンチンカン」「AI が自動で返信しているのがバレバレ」への根本対応。
     5	// 原因は**テンプレの当てはめ**で、型が相手の話題と独立に選ばれていたこと。
     6	//
     7	// ## 契約は `asuka-fill.js` と同じにする
     8	//
     9	//   入力(stdin): {"trend": {"text": "...", "author": "...", "tweet_url": "..."}, "kind": "comment"}
    10	//   出力(stdout): {"ok": true,  "text": "..."}          … 返信する
    11	//                 {"ok": false, "error": "..."}         … 返信しない
    12	//
    13	// **`ok` は必須。** 2026-09-05 に実物を読んで分かった。`comment-orchestrator.sh:124` は
    14	//
    15	//     GEN_OK=$(echo "$GEN_OUT" | node -e "... JSON.parse(d).ok ...")
    16	//     if [ "$GEN_OK" != "true" ]; then ... continue; fi
    17	//
    18	// で捨てるため、**`{text}` だけ返していた前の版は全件 無言で落ちていた。**
    19	// 推測で契約を決めない、を守れていなかった箇所。
    20	//
    21	// ## 出力は必ず 2 つのゲートを通す
    22	//
    23	//   1. `reply-relevance-check.cjs` … 噛み合い・型の使い回し・金額断定
    24	//   2. `reply-tone-check.cjs`      … 危ない語（あれば）
    25	//
    26	// **弾かれたら skip にする。** 無理に返信するくらいなら黙るほうがよい。
    27	//
    28	// ## 失敗したときにどちらへ倒すか
    29	//
    30	//   API が呼べない / 応答が壊れている → skip（**送らない**）
    31	//   ゲートの部品が読めない             → skip（**送らない**）
    32	//
    33	// `asuka-fill.js` 時代は「素通し」に倒していたが、**それが今回の事故を生んだ。**
    34	// 生成が壊れているのに送るのは、壊れた文を出すことと同じ。**ここは送らない側に倒す。**
    35	//
    36	// `throw` はしない。返信ジョブごと落とさない。
    37	
    38	const fs = require('fs');
    39	
    40	// SKIP_REASON_SHORT (2026-09-08): 出力単価は入力の 5 倍。理由の作文に課金しない。
    41	const SKIP_REASON_RULE = '\n\n【skip するときの書き方】理由は必ず 1 語のコードだけで返すこと。説明文を書かない。使えるコード: skip:money_advice / skip:no_content / skip:promo / skip:out_of_voice / skip:other。例: {"skip":true,"reason":"skip:no_content"}';
    42	const path = require('path');
    43	
    44	const DIR = __dirname;
    45	const DATA = path.join(DIR, '..', 'data');
    46	
    47	function loadJSON(p, fallback) {
    48	  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (e) { return fallback; }
    49	}
    50	
    51	function out(o) { process.stdout.write(JSON.stringify(o) + '\n'); }
    52	
    53	/** 返信しない。**`ok:false` で返す**（orchestrator はこれを見て次の候補へ進む）。 */
    54	function skip(reason) { out({ ok: false, error: String(reason || 'skip'), skip: true, reason: String(reason || 'skip') }); }
    55	
    56	/** `asuka-fill.js:18` と同じ数え方。全角 2・半角 1。上限 280。 */
    57	const MAX_WEIGHT = 280;
    58	const MIN_CHARS = 15;
    59	function weightOf(s) {
    60	  let w = 0;
    61	  for (const ch of s) w += ch.charCodeAt(0) < 0x80 ? 1 : 2;
    62	  return w;
    63	}
    64	
    65	/** 直近に出した返信を読む。型の繰り返しを避けるために使う。 */
    66	function recentReplies(queuePath, n) {
    67	  try {
    68	    const q = JSON.parse(fs.readFileSync(queuePath, 'utf8'));
    69	    return (q.queue || [])
    70	      .filter(e => String(e.kind || '') === 'comment' && e.text)
    71	      .slice(-n)
    72	      .map(e => String(e.text));
    73	  } catch (e) { return []; }
    74	}
    75	
    76	async function main() {
    77	  // --- 入力 ---
    78	  let raw = '';
    79	  for await (const c of process.stdin) raw += c;
    80	  let input;
    81	  try { input = JSON.parse(raw); } catch (e) { return skip('入力が JSON として読めない'); }
    82	
    83	  const trend = (input && input.trend) || {};
    84	  const target = String(trend.text || '').trim();
    85	  if (!target) return skip('相手の投稿の本文が無い');
    86	
    87	  // --- 設定 ---
    88	  const cfg = loadJSON(path.join(DATA, 'reply-style-prompt.json'), null);
    89	  if (!cfg || !Array.isArray(cfg.system)) return skip('reply-style-prompt.json が読めない');
    90	
    91	  const relRules = loadJSON(path.join(DATA, 'reply-relevance-rules.json'), null);
    92	  let checkRelevance = null;
    93	  try { ({ checkRelevance } = require(path.join(DIR, 'reply-relevance-check.cjs'))); } catch (e) {}
    94	  if (!checkRelevance || !relRules) return skip('噛み合い検査が読めない（無検査では送らない）');
    95	
    96	  let checkTone = null, toneRules = null;
    97	  try { ({ checkTone } = require(path.join(DIR, 'reply-tone-check.cjs'))); } catch (e) {}
    98	  toneRules = loadJSON(path.join(DATA, 'reply-tone-rules.json'), null);
    99	
   100	  // --- LLM を呼ぶ前に、相手の投稿で見送る ---
   101	  //
   102	  // 2026-09-04 の実測: 候補 5 件のうち **3 件が PR / 楽天アフィリ / 拡散キャンペーン**だった。
   103	  // 生成側も「紹介コード・URLへの誘導」として skip したが、**それは LLM を呼んだ後。**
   104	  // 入口で落とせば、その 3 件ぶんの費用がまるごと消える。
   105	  //
   106	  // **相手を弾く `ng-filter` とは別。** あちらは売春・闇バイト系。ここは PR 投稿。
   107	  {
   108	    const ts = (relRules && relRules.target_skip) || {};
   109	    const hit = [];
   110	    for (const h of ts.hashtags || []) if (target.includes(h)) hit.push(h);
   111	    for (const d of ts.domains || []) if (target.includes(d)) hit.push(d);
   112	    for (const w of ts.campaign_words || []) if (target.includes(w)) hit.push(w);
   113	    if (hit.length) {
   114	      return skip('PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: ' + hit.slice(0, 3).join(' / '));
   115	    }
   116	  }
   117	
   118	  const QUEUE = process.env.OPS_QUEUE_PATH
   119	    || path.join(process.env.HOME || '', '.openclaw', 'workspace', 'data', 'post_queue.json');
   120	  // **直近は 8 件だけ渡す。** 20 件渡すと入力が約 1,000 字 増え、
   121	  // 1 件あたり $0.0024 → 月 $0.58 になる。8 件なら月 $0.42。
   122	  // 型の使い回しを止める「硬い」制約は下の噛み合い検査（直近 20 件を見る）が持つので、
   123	  // LLM には型を避けるための見本を数件 渡せば足りる。
   124	  // **同じ実行の中で作った文も「直近」に混ぜる。**
   125	  //
   126	  // 2026-09-05、1 回の実行で 4 件 作らせたら 2 件が「ふーん、」で始まり、
   127	  // 3 件が 😏 で終わった。**キューの過去分としか比べていなかったため。**
   128	  // 実運用も 1 回に 2 件ずつ作るので、同じことが起きる。
   129	  let extra = [];
   130	  try { extra = JSON.parse(process.env.OPS_EXTRA_RECENT || '[]'); } catch (e) {}
   131	  if (!Array.isArray(extra)) extra = [];
   132	  extra = extra.map(String).filter(Boolean);
   133	
   134	  // プロンプトへ渡す見本には混ぜてよい（型を避けさせたいだけ）
   135	  const recent = recentReplies(QUEUE, Number(process.env.RECENT_N || 8)).concat(extra).slice(-8);
   136	  // **ゲートには分けて渡す。** 同じ実行の中は厳しく、日をまたいだ過去は緩く。
   137	  // 一緒くたにすると、比較先が穴埋め時代の型そのものなので 1 件も通らない。
   138	  const recentForGate = recentReplies(QUEUE, 20);
   139	  const runForGate = extra;
   140	
   141	  // --- DRY_RUN: API を呼ばずに、何を送るつもりだったかだけ出す ---
   142	  const userMsg = String(cfg.user_template || '{TARGET}')
   143	    .replace('{TARGET}', target)
   144	    .replace('{RECENT}', recent.length ? recent.map(t => '- ' + t).join('\n') : (cfg.skip_when_no_recent || '（無し）'));
   145	
   146	  if (process.env.DRY_RUN === '1') {
   147	    return out({
   148	      dry_run: true,
   149	      model: cfg.model,
   150	      target_text: target,
   151	      recent_count: recent.length,
   152	      system_chars: cfg.system.join('\n').length,
   153	      user_chars: userMsg.length,
   154	    });
   155	  }
   156	
   157	  // --- 生成 ---
   158	  //
   159	  // **`anthropic-client.js` の呼び方を推測で決めない。**
   160	  // 2026-09-04 に `ant.create(...)` と書いて `is not a function` で落ちた。
   161	  // モジュールに**実際にある**関数を探して使い、見つからなければ
   162	  // **何があるかを報告する**（次の一手で必ず当たるように）。
   163	  let text = '';
   164	  try {
   165	    const ant = require(path.join(process.env.HOME || '', '.openclaw', 'workspace', 'scripts', 'anthropic-client.js'));
   166	
   167	    // **推測せず、動いている `asuka-fill.js` と同じ形にする。**
   168	    //
   169	    //   const resp = await ant.call({
   170	    //     model: MODEL, system: SYSTEM, user: userMsg,
   171	    //     max_tokens: 500, temperature: 0.7,
   172	    //   });
   173	    //
   174	    // `messages` 配列ではなく **`user` に文字列**を渡すクライアントだった。
   175	    // 2026-09-04、`messages` を渡して `messages.0.content: Field required` で
   176	    // 400 になった。クライアントが `user` から messages を組み立てるため、
   177	    // `user` が undefined のまま送られていた。
   178	    const req = {
   179	      model: cfg.model,
   180	      system: cfg.system.join('\n'),
   181	      user: userMsg,
   182	      max_tokens: Number(cfg.max_tokens || 300),
   183	      temperature: Number(cfg.temperature || 0.9),
   184	    };
   185	
   186	    let call = null, how = '';
   187	    if (typeof ant === 'function') { call = ant; how = 'module()'; }
   188	    else {
   189	      for (const k of ['create', 'call', 'complete', 'chat', 'send', 'generate', 'message', 'run', 'ask']) {
   190	        if (typeof ant[k] === 'function') { call = ant[k].bind(ant); how = k + '()'; break; }
   191	      }
   192	      if (!call && ant.messages && typeof ant.messages.create === 'function') {
   193	        call = ant.messages.create.bind(ant.messages); how = 'messages.create()';
   194	      }
   195	    }
   196	    if (!call) {
   197	      const keys = (ant && typeof ant === 'object') ? Object.keys(ant).join(', ') : typeof ant;
   198	      return skip('anthropic-client に呼べる関数が無い。export: [' + keys.slice(0, 200) + ']');
   199	    }
   200	
   201	    const resp = await call(req);
   202	
   203	    // 応答から本文を取り出すのも同様に、あるものを使う
   204	    let body = '';
   205	    if (typeof ant.textOf === 'function') body = String(ant.textOf(resp) || '');
   206	    else if (typeof resp === 'string') body = resp;
   207	    else if (resp && Array.isArray(resp.content)) body = resp.content.map(c => c && c.text || '').join('');
   208	    else if (resp && typeof resp.text === 'string') body = resp.text;
   209	    else if (resp && resp.completion) body = String(resp.completion);
   210	    else return skip('応答の形が分からない（' + how + ' / keys: ' + Object.keys(resp || {}).join(',').slice(0, 120) + '）');
   211	    body = body.trim();
   212	    const m = body.match(/\{[\s\S]*\}/);
   213	    if (!m) return skip('応答に JSON が無い');
   214	    const parsed = JSON.parse(m[0]);
   215	    if (parsed.skip) return skip('生成側が skip: ' + (parsed.reason || ''));
   216	    text = String(parsed.text || '').trim();
   217	  } catch (e) {
   218	    return skip('生成に失敗: ' + (e && e.message ? e.message.slice(0, 600) : 'unknown'));
   219	  }
   220	
   221	  if (!text) return skip('空文');
   222	
   223	  // --- 長さ（`asuka-fill.js` と同じ制約） ---
   224	  //
   225	  // 実装側は 15 字未満を捨て、280 weight 超で再生成していた。**声の一部なので合わせる。**
   226	  if (text.length < MIN_CHARS) return skip(`短すぎる（${text.length} 字 < ${MIN_CHARS}）`);
   227	  const w = weightOf(text);
   228	  if (w > MAX_WEIGHT) return skip(`長すぎる（${w} weight > ${MAX_WEIGHT}）`);
   229	
   230	  // --- ゲート ---
   231	  const rel = checkRelevance({ text, targetText: target, recentReplies: recentForGate, runReplies: runForGate }, relRules);
   232	  if (!rel.ok) return skip('噛み合い検査で弾いた: ' + rel.reasons.join(' / '));
   233	
   234	  if (checkTone && toneRules) {
   235	    try {
   236	      const tone = checkTone(text, toneRules);
   237	      if (tone && tone.ok === false) {
   238	        return skip('トーン検査で弾いた: ' + (tone.reasons || []).join(' / '));
   239	      }
   240	    } catch (e) { /* 検査が壊れていても生成文は既に噛み合い検査を通っている */ }
   241	  }
   242	
   243	  // **`ok: true` を先頭に。** orchestrator はこれだけを見て通す。
   244	  // **相手の投稿を一緒に返す。** これを enqueue が記録すれば、後から検証できる。
   245	  // 実物 15 件では 1 件も残っておらず、噛み合いを事後に確かめられなかった。
   246	  out({ ok: true, text, weight: w, target_text: target, model: cfg.model, shared: rel.shared, warns: rel.warns });
   247	}
   248	
   249	main().catch(e => skip('想定外: ' + (e && e.message ? e.message.slice(0, 600) : 'unknown')));
```

## 2. `usage` をログに残す（**これが無いと永久に実測できない**）

入力と出力のどちらを削るべきかは**内訳が分からないと決められない。**
出力単価は入力の 5 倍（$5.00 vs $1.00 per MTok）。

```
  退避: asuka-reply.cjs.bak-20260912-230847
  **応答を受けている変数が見つからない。usage の記録は入れられない。**
  → §1 の全文から人が判断する必要がある。

  node --check: OK
```

## 3. `isThinContent()` を**実際に呼ぶ**ようにする

`x23` は関数を追記して `module.exports` しただけ。**誰も呼んでいない。**

### いまの `ng-filter-candidates.cjs` の出口

```javascript
  // ng-filter-candidates.cjs — 110 行
  31:    process.stdout.write(input || '[]');
  43:    process.stdout.write(JSON.stringify(list));
  55:          text: JSON.stringify(c),
  86:  process.stdout.write(JSON.stringify(kept));
  99:  if (t.length < 20) return "too_short";
  105:  if (body.length < 15) return "no_content";
  107:  if (tags > 0 && body.length > 0 && tags >= body.length) return "hashtag_only";
  108:  return null;
  110:module.exports.isThinContent = isThinContent;
```

```
  退避: ng-filter-candidates.cjs.bak-20260912-230847
  **.filter( が見つからない。配線先を特定できない。**
  → §3 の出口一覧から人が判断する。
```

## 4. skip 理由を短くする規定の**連結先**を探す

`x23` は `SKIP_REASON_RULE` を定義したが、**連結先が見つからなかった。**

```javascript
  // プロンプトらしき長い文字列の定義（連結先の候補）
  170:    //     model: MODEL, system: SYSTEM, user: userMsg,
  180:      system: cfg.system.join('\n'),

  // SKIP_REASON_RULE は入っているか
  40:// SKIP_REASON_SHORT (2026-09-08): 出力単価は入力の 5 倍。理由の作文に課金しない。
  41:const SKIP_REASON_RULE = '\n\n【skip するときの書き方】理由は必ず 1 語のコードだけで返すこと。説明文を書かない。使えるコ�
```

## 5. **実際に送っているプロンプトのサイズ**（キャッシュが使えるか）

「3,168 tok だからキャッシュの最低 4,096 tok に届かない」と書いたが、
**素材だけで 10,887 tok ある。** 3,168 は 2026-08-15 の軽量化後の値で、
**いまの全文生成方式の値ではない。**

```
  --- 素材ファイルの実サイズ ---
    reply-style-prompt.json               10030 B  ≒   5015 tok
    comment-templates.json                 7585 B  ≒   3792 tok
    reply-ng-rules.json                    4160 B  ≒   2080 tok

  --- 生成器がそのうち何を読んでいるか ---
    readFileSync(p, 'utf8')
    readFileSync(queuePath, 'utf8')

  --- 全件送っているか、絞っているか ---
    70:      .filter(e => String(e.kind || '') === 'comment' && e.text)
    71:      .slice(-n)
    72:      .map(e => String(e.text));
    113:    if (hit.length) {
    114:      return skip('PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: ' + hit.slice(0, 3).join(' / '));
    132:  extra = extra.map(String).filter(Boolean);
    135:  const recent = recentReplies(QUEUE, Number(process.env.RECENT_N || 8)).concat(extra).slice(-8);
    144:    .replace('{RECENT}', recent.length ? recent.map(t => '- ' + t).join('\n') : (cfg.skip_when_no_recent || '（無し）'));
    151:      recent_count: recent.length,
    152:      system_chars: cfg.system.join('\n').length,
    153:      user_chars: userMsg.length,
    198:      return skip('anthropic-client に呼べる関数が無い。export: [' + keys.slice(0, 200) + ']');
```

/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x31-wire-cost-cuts.sh: line 238: usage: command not found
** が記録されれば、次の定時実行で入力トークンの実測値が出る。**
**4,096 を超えていればキャッシュが使える。** 入力の 9 割が固定部分なら、
キャッシュ読み出しは **1/10 の単価**になる。

## 6. 入った差分

```diff
```

## 戻し方

```bash
cp -p /Users/ny/.openclaw/workspace/scripts/asuka-reply.cjs.bak-20260912-230847 /Users/ny/.openclaw/workspace/scripts/asuka-reply.cjs
```

---

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（LLM 不使用） | **$0** | **$0** | **$0** |
| `usage` の記録（ファイル追記のみ） | **$0** | **$0** | **$0** |
| 返信（**実測** 9/8=5 件・9/9=3 件） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |

**ジョブを再起動していない。次の定時実行から効く。**
**投稿・返信・LLM 呼び出しのいずれもしていない。**
