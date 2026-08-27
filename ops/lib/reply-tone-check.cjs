// **こちらが出す返信文を検査する。**
//
// ng-filter（reply-ng-check.cjs）が「誰に返さないか」を決める入口なら、
// これは「何を送らないか」を決める出口。
//
//   checkTone(text, rules) → { block, warn, reasons: [{level, kind, hit}] }
//
// ## 弾く／通すの分け方
//
//   block  凍結・炎上に直結するもの（紹介コード・URL・見下し・闇バイト語・説教）
//   warn   送るが記録するもの（命令形・金額断定・日本語の重複・絵文字過多）
//
// **弾きすぎると返信が 0 件になる。** 命令形はテンプレ本体に含まれているため、
// block にすると大半が落ちる。だから warn に置き、溜まった数でテンプレを直す。
//
// ## 例外の扱い
//
// **ここでは投げない。** 呼び出し側が落ちると返信ジョブごと止まる。
// 判定できない項目は飛ばし、判定できたぶんだけで結論を出す。
// ルールそのものが読めないときの素通しは、呼び出し側（tone-gate.cjs）の役目。

function countEmoji(s) {
  // 絵文字・記号の類をまとめて数える。厳密な分類はしない
  const m = String(s).match(
    /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{FE0F}]/gu
  );
  return m ? m.length : 0;
}

function hitWords(text, words) {
  for (const w of words || []) {
    if (!w) continue;
    if (text.includes(w)) return w;
  }
  return null;
}

function hitRegex(text, patterns) {
  for (const p of patterns || []) {
    if (!p) continue;
    let re;
    try {
      re = new RegExp(p, 'u');
    } catch (e) {
      continue; // 壊れたパターンは飛ばす。ここで投げない
    }
    const m = text.match(re);
    if (m) return m[0];
  }
  return null;
}

function scan(text, group, level, reasons) {
  for (const [kind, def] of Object.entries(group || {})) {
    if (kind.startsWith('_') || !def || typeof def !== 'object') continue;
    const w = hitWords(text, def.words);
    if (w) {
      reasons.push({ level, kind, hit: w });
      continue;
    }
    const r = hitRegex(text, def.regex);
    if (r) reasons.push({ level, kind, hit: r });
  }
}

function checkTone(text, rules) {
  const s = String(text == null ? '' : text);
  const reasons = [];
  const r = rules || {};

  scan(s, r.block_patterns, 'block', reasons);
  scan(s, r.warn_patterns, 'warn', reasons);

  const lim = r.limits || {};
  const emoji = countEmoji(s);
  if (lim.max_emoji != null && emoji > lim.max_emoji) {
    reasons.push({ level: 'warn', kind: 'emoji', hit: `${emoji} 個` });
  }
  if (lim.max_chars != null && s.length > lim.max_chars) {
    reasons.push({ level: 'warn', kind: 'too_long', hit: `${s.length} 字` });
  }
  // 空・極端に短い返信は送る価値がない。**これは block**
  if (lim.min_chars != null && s.trim().length < lim.min_chars) {
    reasons.push({ level: 'block', kind: 'too_short', hit: `${s.trim().length} 字` });
  }

  return {
    block: reasons.some((x) => x.level === 'block'),
    warn: reasons.some((x) => x.level === 'warn'),
    reasons,
  };
}

module.exports = { checkTone, countEmoji };
