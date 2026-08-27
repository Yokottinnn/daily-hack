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

// **呼び出し元は `asuka-fill.js 2>&1` で stderr を混ぜている。**
// つまり入力は「ログの雑音 + JSON」になりうる。丸ごと JSON.parse すると失敗し、
// 常に素通しになって検査が効かない。
//
// そこで**末尾の釣り合った { … } を探して、そこだけを判定する。**
// 書き戻すときも、その部分だけを差し替えて前後の雑音は保つ
// （呼び出し側がログを読んでいる可能性があるため、形を壊さない）。
function findLastJsonObject(s) {
  for (let end = s.lastIndexOf('}'); end !== -1; end = s.lastIndexOf('}', end - 1)) {
    let depth = 0;
    let inStr = false;
    let esc = false;
    for (let i = end; i >= 0; i--) {
      const ch = s[i];
      if (esc) { esc = false; continue; }
      if (inStr) {
        if (ch === '\\') { esc = true; continue; }
        if (ch === '"') inStr = false;
        continue;
      }
      if (ch === '"') { inStr = true; continue; }
      if (ch === '}') depth++;
      else if (ch === '{') {
        depth--;
        if (depth === 0) {
          const slice = s.slice(i, end + 1);
          try {
            return { obj: JSON.parse(slice), start: i, end: end + 1 };
          } catch (e) {
            break; // この候補は違う。次の } から探し直す
          }
        }
      }
    }
  }
  return null;
}

let input = '';
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  const passthrough = (why) => {
    process.stderr.write(`  tone-gate: ${why}ので素通しする\n`);
    process.stdout.write(input || '');
  };

  if (!input || !input.trim()) return passthrough('入力が空な');

  const found = findLastJsonObject(input);
  if (!found) return passthrough('入力から JSON を取り出せない');
  const obj = found.obj;
  // 判定結果を書き戻すときは、見つけた JSON の部分だけを差し替える
  const splice = (json) =>
    input.slice(0, found.start) + json + input.slice(found.end);

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
      splice(
        JSON.stringify({
          ...obj,
          ok: false,
          error: `tone-gate blocked: ${fmt('block')}`,
          blocked_text: text,
        })
      )
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
