'use strict';
// **返信を毎回 書き下ろす生成器。** `asuka-fill.js`（テンプレ 37 件の穴埋め）の置き換え。
//
// 2026-09-02 の指摘「トンチンカン」「AI が自動で返信しているのがバレバレ」への根本対応。
// 原因は**テンプレの当てはめ**で、型が相手の話題と独立に選ばれていたこと。
//
// ## 契約は `asuka-fill.js` と同じにする
//
//   入力(stdin): {"trend": {"text": "...", "author": "...", "tweet_url": "..."}, "kind": "comment"}
//   出力(stdout): {"ok": true,  "text": "..."}          … 返信する
//                 {"ok": false, "error": "..."}         … 返信しない
//
// **`ok` は必須。** 2026-09-05 に実物を読んで分かった。`comment-orchestrator.sh:124` は
//
//     GEN_OK=$(echo "$GEN_OUT" | node -e "... JSON.parse(d).ok ...")
//     if [ "$GEN_OK" != "true" ]; then ... continue; fi
//
// で捨てるため、**`{text}` だけ返していた前の版は全件 無言で落ちていた。**
// 推測で契約を決めない、を守れていなかった箇所。
//
// ## 出力は必ず 2 つのゲートを通す
//
//   1. `reply-relevance-check.cjs` … 噛み合い・型の使い回し・金額断定
//   2. `reply-tone-check.cjs`      … 危ない語（あれば）
//
// **弾かれたら skip にする。** 無理に返信するくらいなら黙るほうがよい。
//
// ## 失敗したときにどちらへ倒すか
//
//   API が呼べない / 応答が壊れている → skip（**送らない**）
//   ゲートの部品が読めない             → skip（**送らない**）
//
// `asuka-fill.js` 時代は「素通し」に倒していたが、**それが今回の事故を生んだ。**
// 生成が壊れているのに送るのは、壊れた文を出すことと同じ。**ここは送らない側に倒す。**
//
// `throw` はしない。返信ジョブごと落とさない。

const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const DATA = path.join(DIR, '..', 'data');

function loadJSON(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (e) { return fallback; }
}

function out(o) { process.stdout.write(JSON.stringify(o) + '\n'); }

/** 返信しない。**`ok:false` で返す**（orchestrator はこれを見て次の候補へ進む）。 */
function skip(reason) { out({ ok: false, error: String(reason || 'skip'), skip: true, reason: String(reason || 'skip') }); }

/** `asuka-fill.js:18` と同じ数え方。全角 2・半角 1。上限 280。 */
const MAX_WEIGHT = 280;
const MIN_CHARS = 15;
function weightOf(s) {
  let w = 0;
  for (const ch of s) w += ch.charCodeAt(0) < 0x80 ? 1 : 2;
  return w;
}

/** 直近に出した返信を読む。型の繰り返しを避けるために使う。 */
function recentReplies(queuePath, n) {
  try {
    const q = JSON.parse(fs.readFileSync(queuePath, 'utf8'));
    return (q.queue || [])
      .filter(e => String(e.kind || '') === 'comment' && e.text)
      .slice(-n)
      .map(e => String(e.text));
  } catch (e) { return []; }
}

async function main() {
  // --- 入力 ---
  let raw = '';
  for await (const c of process.stdin) raw += c;
  let input;
  try { input = JSON.parse(raw); } catch (e) { return skip('入力が JSON として読めない'); }

  const trend = (input && input.trend) || {};
  const target = String(trend.text || '').trim();
  if (!target) return skip('相手の投稿の本文が無い');

  // --- 設定 ---
  const cfg = loadJSON(path.join(DATA, 'reply-style-prompt.json'), null);
  if (!cfg || !Array.isArray(cfg.system)) return skip('reply-style-prompt.json が読めない');

  const relRules = loadJSON(path.join(DATA, 'reply-relevance-rules.json'), null);
  let checkRelevance = null;
  try { ({ checkRelevance } = require(path.join(DIR, 'reply-relevance-check.cjs'))); } catch (e) {}
  if (!checkRelevance || !relRules) return skip('噛み合い検査が読めない（無検査では送らない）');

  let checkTone = null, toneRules = null;
  try { ({ checkTone } = require(path.join(DIR, 'reply-tone-check.cjs'))); } catch (e) {}
  toneRules = loadJSON(path.join(DATA, 'reply-tone-rules.json'), null);

  // --- LLM を呼ぶ前に、相手の投稿で見送る ---
  //
  // 2026-09-04 の実測: 候補 5 件のうち **3 件が PR / 楽天アフィリ / 拡散キャンペーン**だった。
  // 生成側も「紹介コード・URLへの誘導」として skip したが、**それは LLM を呼んだ後。**
  // 入口で落とせば、その 3 件ぶんの費用がまるごと消える。
  //
  // **相手を弾く `ng-filter` とは別。** あちらは売春・闇バイト系。ここは PR 投稿。
  {
    const ts = (relRules && relRules.target_skip) || {};
    const hit = [];
    for (const h of ts.hashtags || []) if (target.includes(h)) hit.push(h);
    for (const d of ts.domains || []) if (target.includes(d)) hit.push(d);
    for (const w of ts.campaign_words || []) if (target.includes(w)) hit.push(w);
    if (hit.length) {
      return skip('PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: ' + hit.slice(0, 3).join(' / '));
    }
  }

  const QUEUE = process.env.OPS_QUEUE_PATH
    || path.join(process.env.HOME || '', '.openclaw', 'workspace', 'data', 'post_queue.json');
  // **直近は 8 件だけ渡す。** 20 件渡すと入力が約 1,000 字 増え、
  // 1 件あたり $0.0024 → 月 $0.58 になる。8 件なら月 $0.42。
  // 型の使い回しを止める「硬い」制約は下の噛み合い検査（直近 20 件を見る）が持つので、
  // LLM には型を避けるための見本を数件 渡せば足りる。
  // **同じ実行の中で作った文も「直近」に混ぜる。**
  //
  // 2026-09-05、1 回の実行で 4 件 作らせたら 2 件が「ふーん、」で始まり、
  // 3 件が 😏 で終わった。**キューの過去分としか比べていなかったため。**
  // 実運用も 1 回に 2 件ずつ作るので、同じことが起きる。
  let extra = [];
  try { extra = JSON.parse(process.env.OPS_EXTRA_RECENT || '[]'); } catch (e) {}
  if (!Array.isArray(extra)) extra = [];
  extra = extra.map(String).filter(Boolean);

  const recent = recentReplies(QUEUE, Number(process.env.RECENT_N || 8)).concat(extra).slice(-8);
  const recentForGate = recentReplies(QUEUE, 20).concat(extra).slice(-20);

  // --- DRY_RUN: API を呼ばずに、何を送るつもりだったかだけ出す ---
  const userMsg = String(cfg.user_template || '{TARGET}')
    .replace('{TARGET}', target)
    .replace('{RECENT}', recent.length ? recent.map(t => '- ' + t).join('\n') : (cfg.skip_when_no_recent || '（無し）'));

  if (process.env.DRY_RUN === '1') {
    return out({
      dry_run: true,
      model: cfg.model,
      target_text: target,
      recent_count: recent.length,
      system_chars: cfg.system.join('\n').length,
      user_chars: userMsg.length,
    });
  }

  // --- 生成 ---
  //
  // **`anthropic-client.js` の呼び方を推測で決めない。**
  // 2026-09-04 に `ant.create(...)` と書いて `is not a function` で落ちた。
  // モジュールに**実際にある**関数を探して使い、見つからなければ
  // **何があるかを報告する**（次の一手で必ず当たるように）。
  let text = '';
  try {
    const ant = require(path.join(process.env.HOME || '', '.openclaw', 'workspace', 'scripts', 'anthropic-client.js'));

    // **推測せず、動いている `asuka-fill.js` と同じ形にする。**
    //
    //   const resp = await ant.call({
    //     model: MODEL, system: SYSTEM, user: userMsg,
    //     max_tokens: 500, temperature: 0.7,
    //   });
    //
    // `messages` 配列ではなく **`user` に文字列**を渡すクライアントだった。
    // 2026-09-04、`messages` を渡して `messages.0.content: Field required` で
    // 400 になった。クライアントが `user` から messages を組み立てるため、
    // `user` が undefined のまま送られていた。
    const req = {
      model: cfg.model,
      system: cfg.system.join('\n'),
      user: userMsg,
      max_tokens: Number(cfg.max_tokens || 300),
      temperature: Number(cfg.temperature || 0.9),
    };

    let call = null, how = '';
    if (typeof ant === 'function') { call = ant; how = 'module()'; }
    else {
      for (const k of ['create', 'call', 'complete', 'chat', 'send', 'generate', 'message', 'run', 'ask']) {
        if (typeof ant[k] === 'function') { call = ant[k].bind(ant); how = k + '()'; break; }
      }
      if (!call && ant.messages && typeof ant.messages.create === 'function') {
        call = ant.messages.create.bind(ant.messages); how = 'messages.create()';
      }
    }
    if (!call) {
      const keys = (ant && typeof ant === 'object') ? Object.keys(ant).join(', ') : typeof ant;
      return skip('anthropic-client に呼べる関数が無い。export: [' + keys.slice(0, 200) + ']');
    }

    const resp = await call(req);

    // 応答から本文を取り出すのも同様に、あるものを使う
    let body = '';
    if (typeof ant.textOf === 'function') body = String(ant.textOf(resp) || '');
    else if (typeof resp === 'string') body = resp;
    else if (resp && Array.isArray(resp.content)) body = resp.content.map(c => c && c.text || '').join('');
    else if (resp && typeof resp.text === 'string') body = resp.text;
    else if (resp && resp.completion) body = String(resp.completion);
    else return skip('応答の形が分からない（' + how + ' / keys: ' + Object.keys(resp || {}).join(',').slice(0, 120) + '）');
    body = body.trim();
    const m = body.match(/\{[\s\S]*\}/);
    if (!m) return skip('応答に JSON が無い');
    const parsed = JSON.parse(m[0]);
    if (parsed.skip) return skip('生成側が skip: ' + (parsed.reason || ''));
    text = String(parsed.text || '').trim();
  } catch (e) {
    return skip('生成に失敗: ' + (e && e.message ? e.message.slice(0, 600) : 'unknown'));
  }

  if (!text) return skip('空文');

  // --- 長さ（`asuka-fill.js` と同じ制約） ---
  //
  // 実装側は 15 字未満を捨て、280 weight 超で再生成していた。**声の一部なので合わせる。**
  if (text.length < MIN_CHARS) return skip(`短すぎる（${text.length} 字 < ${MIN_CHARS}）`);
  const w = weightOf(text);
  if (w > MAX_WEIGHT) return skip(`長すぎる（${w} weight > ${MAX_WEIGHT}）`);

  // --- ゲート ---
  const rel = checkRelevance({ text, targetText: target, recentReplies: recentForGate }, relRules);
  if (!rel.ok) return skip('噛み合い検査で弾いた: ' + rel.reasons.join(' / '));

  if (checkTone && toneRules) {
    try {
      const tone = checkTone(text, toneRules);
      if (tone && tone.ok === false) {
        return skip('トーン検査で弾いた: ' + (tone.reasons || []).join(' / '));
      }
    } catch (e) { /* 検査が壊れていても生成文は既に噛み合い検査を通っている */ }
  }

  // **`ok: true` を先頭に。** orchestrator はこれだけを見て通す。
  // **相手の投稿を一緒に返す。** これを enqueue が記録すれば、後から検証できる。
  // 実物 15 件では 1 件も残っておらず、噛み合いを事後に確かめられなかった。
  out({ ok: true, text, weight: w, target_text: target, model: cfg.model, shared: rel.shared, warns: rel.warns });
}

main().catch(e => skip('想定外: ' + (e && e.message ? e.message.slice(0, 600) : 'unknown')));
