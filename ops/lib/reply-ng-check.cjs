// 返信してはいけない相手かを判定する。
//
// **誤って弾くより、誤って返信する方が高くつく。** 迷ったら弾く。
// ただし「ポイ活」「節約」など正当なアカウントを巻き込まないよう、
// never_ng_words を含む相手には soft / emoji 判定を効かせない。
// hard_ng_words だけは never があっても無効にしない（売春固有の語のため）。
//
// 使い方:
//   const { isNg } = require('./reply-ng-check.js');
//   const v = isNg({ bio, text, links, createdAt, following, followers });
//   if (v.ng) { skip(v.reason); }

const fs = require('fs');
const path = require('path');

function loadRules(p) {
  const f = p || path.join(__dirname, '..', 'data', 'reply-ng-rules.json');
  return JSON.parse(fs.readFileSync(f, 'utf8'));
}

function isNg(target, rulesOrPath) {
  const R = (rulesOrPath && typeof rulesOrPath === 'object')
    ? rulesOrPath : loadRules(rulesOrPath);

  const bio = String(target.bio || '');
  const text = String(target.text || '');
  const hay = bio + '\n' + text;
  const links = []
    .concat(target.links || [])
    .concat(hay.match(/https?:\/\/[^\s]+/g) || [])
    .join(' ')
    .toLowerCase();

  // 1. hard — 1 語で NG。除外語があっても効く
  for (const w of R.hard_ng_words.words) {
    if (hay.includes(w)) return { ng: true, reason: 'hard', hit: w };
  }

  // 2. リンク先 — 外部の出会い系・LINE 誘導
  for (const d of R.ng_link_domains.domains) {
    if (links.includes(d)) return { ng: true, reason: 'link', hit: d };
  }

  // 3. 構造 — 文面に依らない特徴
  const S = R.structural_ng || {};
  if (S.min_account_age_days && target.createdAt) {
    const days = (Date.now() - new Date(target.createdAt).getTime()) / 86400000;
    if (days < S.min_account_age_days) {
      return { ng: true, reason: 'new_account', hit: Math.floor(days) + '日' };
    }
  }
  if (S.max_following_to_follower_ratio &&
      Number(target.followers) > 0 && Number(target.following) > 0) {
    const r = Number(target.following) / Number(target.followers);
    if (r > S.max_following_to_follower_ratio) {
      return { ng: true, reason: 'ratio', hit: r.toFixed(1) };
    }
  }

  // 4. 除外 — ここから先は正当なアカウントを守るため効かせない
  const safe = (R.never_ng_words.words || []).some((w) => hay.includes(w));
  if (safe) return { ng: false, reason: 'never_ng' };

  // 5. soft — 閾値以上で NG
  const softHits = R.soft_ng_words.words.filter((w) => hay.includes(w));
  if (softHits.length >= R.soft_ng_words.threshold) {
    return { ng: true, reason: 'soft', hit: softHits.join(',') };
  }

  // 6. 絵文字 — 閾値以上で NG
  const emoHits = R.ng_emoji.emoji.filter((e) => hay.includes(e));
  if (emoHits.length >= R.ng_emoji.threshold) {
    return { ng: true, reason: 'emoji', hit: emoHits.join('') };
  }

  return { ng: false, reason: 'ok' };
}

module.exports = { isNg, loadRules };
