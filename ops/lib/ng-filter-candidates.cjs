// 返信候補から NG（売春系など）を弾く。
//
// comment-orchestrator.sh の CANDIDATES を作った直後に挟む。
//   CANDIDATES=$(echo "$CANDIDATES" | node scripts/ng-filter-candidates.cjs 2>>"$LOG")
//
// stdin  : 候補の JSON 配列
// stdout : 弾いたあとの JSON 配列（**stdout には JSON しか出さない**）
// stderr : 何件どの理由で弾いたか（ログへ）
//
// **候補のフィールド名を決め打ちしない。** 候補オブジェクト全体を
// 文字列化して判定に渡すので、text / bio / author / links の
// どこに NG 語があっても拾える。
//
// **壊れたら素通しではなく、素通しを選ぶ。**
// ここで例外を投げると返信ジョブごと落ちる。判定できないときは
// 元の候補をそのまま返し、stderr に理由を書く。
// （弾き漏らしは次の実行で拾えるが、ジョブが落ちると何も動かなくなる）

const fs = require('fs');
const path = require('path');

let input = '';
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  let list;
  try {
    list = JSON.parse(input);
    if (!Array.isArray(list)) throw new Error('配列ではない');
  } catch (e) {
    process.stderr.write(`  ng-filter: 入力を解釈できないので素通しする (${e.message})\n`);
    process.stdout.write(input || '[]');
    return;
  }

  let isNg, rules;
  try {
    ({ isNg } = require(path.join(__dirname, 'reply-ng-check.cjs')));
    rules = JSON.parse(
      fs.readFileSync(path.join(__dirname, '..', 'data', 'reply-ng-rules.json'), 'utf8')
    );
  } catch (e) {
    process.stderr.write(`  ng-filter: 判定を読めないので素通しする (${e.message})\n`);
    process.stdout.write(JSON.stringify(list));
    return;
  }

  const kept = [];
  const dropped = [];
  for (const c of list) {
    let v;
    try {
      // フィールド名に依存しない。候補まるごとを text として渡す
      v = isNg(
        {
          text: JSON.stringify(c),
          bio: c && (c.bio || c.description || ''),
          links: (c && c.links) || [],
          createdAt: c && (c.createdAt || c.created_at),
          following: c && (c.following || c.friends_count),
          followers: c && (c.followers || c.followers_count),
        },
        rules
      );
    } catch (e) {
      process.stderr.write(`  ng-filter: 判定に失敗したので残す (${e.message})\n`);
      kept.push(c);
      continue;
    }
    if (v.ng) dropped.push(v);
    else kept.push(c);
  }

  if (dropped.length) {
    const by = {};
    for (const d of dropped) by[d.reason] = (by[d.reason] || 0) + 1;
    const detail = Object.entries(by).map(([k, n]) => `${k}=${n}`).join(' ');
    process.stderr.write(
      `  ng-filter: ${list.length} 件中 ${dropped.length} 件を弾いた (${detail})\n`
    );
    for (const d of dropped) {
      process.stderr.write(`    弾いた理由 ${d.reason}: ${String(d.hit || '').slice(0, 60)}\n`);
    }
  } else {
    process.stderr.write(`  ng-filter: ${list.length} 件すべて通過\n`);
  }
  process.stdout.write(JSON.stringify(kept));
});
