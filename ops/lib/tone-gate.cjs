// **生成した返信文を送る前に検査する門。**
//
// comment-orchestrator.sh の asuka-fill.js の直後、enqueue の直前に挟む。
//
//   GEN_OUT=$(... asuka-fill.js ...)
//   GEN_OUT=$(printf '%s' "$GEN_OUT" | node scripts/tone-gate.cjs 2>>"$LOG")
//
// stdin  : asuka-fill.js の出力 JSON  {ok, text, template_id, weight, attempts}
// stdout : 同じ形の JSON。**弾いたときは ok:false にして返す**
// stderr : 何を、どの理由で弾いた／警告したか
//
// ## 失敗したときにどちらへ倒すか
//
//   ルールや判定モジュールが読めない  → **素通し**（今日と同じ状態に戻るだけ）
//   入力が JSON として読めない        → **素通し**（呼び出し側の形を壊さない）
//   文が読めて block に当たった       → **弾く**（ok:false）
//
// **設備の故障では止めない。中身が危なければ止める。**
// ここで例外を投げると返信ジョブごと落ちるため、throw は一切しない。

const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  const passthrough = (why) => {
    process.stderr.write(`  tone-gate: ${why}ので素通しする\n`);
    process.stdout.write(input || '');
  };

  if (!input || !input.trim()) return passthrough('入力が空な');

  let obj;
  try {
    obj = JSON.parse(input);
  } catch (e) {
    return passthrough(`入力を JSON として読めない(${e.message})`);
  }

  // 生成に失敗している場合は触らずそのまま返す
  if (!obj || obj.ok === false) {
    process.stdout.write(input);
    return;
  }

  const text = obj.text || obj.reply || '';
  if (!text) {
    process.stdout.write(input);
    return;
  }

  let checkTone, rules;
  try {
    ({ checkTone } = require(path.join(__dirname, 'reply-tone-check.cjs')));
    rules = JSON.parse(
      fs.readFileSync(path.join(__dirname, '..', 'data', 'reply-tone-rules.json'), 'utf8')
    );
  } catch (e) {
    return passthrough(`判定を読めない(${e.message})`);
  }

  let v;
  try {
    v = checkTone(text, rules);
  } catch (e) {
    return passthrough(`判定に失敗した(${e.message})`);
  }

  const fmt = (lv) =>
    v.reasons
      .filter((x) => x.level === lv)
      .map((x) => `${x.kind}=${String(x.hit).slice(0, 30)}`)
      .join(' ');

  if (v.block) {
    process.stderr.write(`  tone-gate: **送らない** (${fmt('block')})\n`);
    process.stderr.write(`    弾いた文: ${String(text).slice(0, 80)}\n`);
    process.stdout.write(
      JSON.stringify({
        ...obj,
        ok: false,
        error: `tone-gate blocked: ${fmt('block')}`,
        blocked_text: text,
      })
    );
    return;
  }

  if (v.warn) {
    process.stderr.write(`  tone-gate: 送るが記録する (${fmt('warn')})\n`);
  } else {
    process.stderr.write(`  tone-gate: 通過\n`);
  }
  process.stdout.write(input);
});
