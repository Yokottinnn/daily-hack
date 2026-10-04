#!/bin/bash
# **follow-balance.js に「外されたら外し返す」と「期日を過ぎたフォロバ無しを外す」を足す。費用 $0。**
#
# ## 指示（2026-10-04）
#
#   > 1. フォローしてフォローバックされてないアカウント
#   > 2. もしくは、相互フォローしていたけどフォローを外されたアカウント
#   > のフォローを外すという行為を、どれぐらいの期限で、どれぐらいの頻度でモニタリングしてやってる？
#   → x225 の結果を見せ、「外されたら外し返す見張りを作る」「期日を過ぎた 370 件を外す流れに入れる」を選んでもらった
#
# ## いまの穴（x225・x226 で実物を読んだ）
#
#   * 相互だった人に外されても、**それを見張る仕組みが無い**。follow-balance は毎回フォロワーと照らすので
#     片思いとしては拾うが、片思いの中で順番が後ろなら 1 回 20 件の枠に入らない
#   * reply-followback-check は「返していない」と判定して **7〜14 日後の外す予定日** を書くが、
#     **それを読んで外すジョブが止まっている**。予定日を過ぎた 371 件が残っている
#
# ## 足すもの（外す操作・上限・比率の決め方は変えない）
#
#   ① 毎回、フォロワーの一覧を **読み切れたときだけ** 記録する（follow-balance-followers-prev.json）。
#      読み切れた＝走査の件数 ≥ ヘッダーのフォロワー数。読み切れていなければ記録も比較もしない
#   ② 前回はフォロワーだった・今回いない・こちらはフォロー中 → 「外された」として **片思いの先頭** に並べる
#   ③ reply-followers.json で「返していない（no）」かつ外す予定日を過ぎ、まだ外していない人 → その次に並べる
#   ④ 外せたら reply-followers.json にも unfollowed_at を書く（予定を持ち続けないように）
#
#   守る条件（ホワイトリスト・フォローして 7 日の猶予）はそのまま効く。1 回に外すのは今までどおり 20 件まで（11:45 / 18:45）。
#
# **当たったかを文字列で確かめ、node --check が通らなければ元に戻す。** 控えを残す。
# **ジョブは走らせない。外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
F="$S/follow-balance.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$F.bak-x227-$STAMP"
TMP="$S/.follow-balance-x227-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-gone-and-due.md"

{
echo "# follow-balance.js に「外されたら外し返す」「期日超えを外す」を足す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo '```'
if [ ! -f "$F" ]; then echo "  **follow-balance.js が無い**"; echo '```'; exit 1; fi
if grep -q 'x227:' "$F"; then echo "  もう当たっている（x227: の印がある）。何もしない"; echo '```'; exit 0; fi
cp "$F" "$BAK" && printf '  控え: %s\n' "$(basename "$BAK")"
node -e '
const fs = require("fs");
const [src, dst] = process.argv.slice(1);
let s = fs.readFileSync(src, "utf8");
const n = [0, 0, 0, 0];
const rep = (i, a, b) => { const k = s.split(a).length - 1; if (k === 1) { s = s.replace(a, b); n[i] = 1; } else n[i] = k === 0 ? 0 : -k; };

// ① ② ③ 片思いの並べ替え（片思いと相互を数えた直後）
const A1 = `  log("片思い: " + oneWay.length + " 件 / 相互: " + mutual.length + " 件");\n`;
rep(0, A1, A1 +
`  // x227: 外された人（前回はフォロワー・今回いない）と、フォロバ判定で外す予定日を過ぎた人を、片思いの先頭に並べる（2026-10-04 に指示）
  const FPREV = path.join(WS, "data", "follow-balance-followers-prev.json");
  // **フォロワーを読み切れたときだけ比べる。** 読み切れていないと、相互を「外された」と取り違える
  const fComplete = !!(hdr && Number.isFinite(hdr.followers) && followers.size >= hdr.followers);
  let prevF = null;
  try { prevF = new Set((JSON.parse(fs.readFileSync(FPREV, "utf8")).followers || []).map((x) => String(x).toLowerCase())); } catch (e) { prevF = null; }
  const x227Gone = new Set();
  if (fComplete && prevF) for (const h of oneWay) if (prevF.has(h.toLowerCase())) x227Gone.add(h.toLowerCase());
  const x227Due = new Set();
  try {
    const rf = JSON.parse(fs.readFileSync(ENGAGED, "utf8"));
    for (const [k, v] of Object.entries(rf)) {
      if (!v || typeof v !== "object" || v.followback_status !== "no" || v.unfollowed_at || !v.scheduled_unfollow_at) continue;
      if (new Date(v.scheduled_unfollow_at).getTime() < now) x227Due.add(String(k).replace(/^@/, "").toLowerCase());
    }
  } catch (e) {}
  const x227Rank = (h) => x227Gone.has(h.toLowerCase()) ? 0 : x227Due.has(h.toLowerCase()) ? 1 : 2;
  oneWay.sort((a, b) => x227Rank(a) - x227Rank(b));
  const x227Why = (h) => { const r = x227Rank(h); return r === 0 ? "外された（前回はフォロワー・今回いない）" : r === 1 ? "フォロバ無し・外す予定日を過ぎた" : "返していない（片思い）"; };
  const x227Unf = [];
  log("外された: " + x227Gone.size + " 件" +
      (fComplete ? (prevF ? "" : "（前回の記録が無い。今回は記録だけ）") : "（フォロワーを読み切れていない " + followers.size + " / " + (hdr && hdr.followers) + "。比べない）") +
      " / 外す予定日を過ぎたフォロバ無し: 記録 " + x227Due.size + " 件 → いまも片思い " + oneWay.filter((h) => x227Due.has(h.toLowerCase())).length + " 件");
  if (fComplete && !DRY) {
    try { fs.writeFileSync(FPREV, JSON.stringify({ at: new Date().toISOString(), followers: [...followers] })); JSON.parse(fs.readFileSync(FPREV, "utf8")); }
    catch (e) { log("（フォロワーの記録を書けない: " + String(e.message).slice(0, 60) + "）"); }
  }
`);

// 片思いの理由を並べ替えに合わせる
rep(1, `    cuts.push({ h, why: "返していない（片思い）", rank: 1 });`,
       `    cuts.push({ h, why: x227Why(h), rank: 1 });   // x227: 理由を「外された」「予定日を過ぎた」と分ける`);

// ④ 外せた人を覚える
const A3 = `        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };\n`;
rep(2, A3, A3 + `        x227Unf.push({ h, why: c.why });   // x227\n`);

// ④ reply-followers.json に書き戻す
const A4 = `  try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}\n`;
rep(3, A4, A4 +
`  // x227: 外した人を reply-followers.json にも書く（フォロバ判定の側が「外す予定」を持ち続けないように）
  if (x227Unf.length) {
    try {
      const rf = JSON.parse(fs.readFileSync(ENGAGED, "utf8"));
      const low = {}; for (const k of Object.keys(rf)) low[String(k).replace(/^@/, "").toLowerCase()] = k;
      let wrote = 0;
      for (const u of x227Unf) {
        const k = low[u.h.toLowerCase()];
        if (!k || !rf[k] || typeof rf[k] !== "object") continue;
        rf[k].unfollowed_at = new Date().toISOString(); rf[k].unfollow_source = "follow-balance"; rf[k].unfollow_reason = u.why; wrote++;
      }
      const tmp = ENGAGED.replace(/\\.json$/, ".x227tmp.json");
      fs.writeFileSync(tmp, JSON.stringify(rf, null, 2)); JSON.parse(fs.readFileSync(tmp, "utf8"));
      fs.renameSync(tmp, ENGAGED);
      log("reply-followers.json に反映: " + wrote + " 件");
    } catch (e) { log("reply-followers.json に反映できない: " + String(e.message).slice(0, 80)); }
  }
`);
fs.writeFileSync(dst, s);
console.log("  当たった数（1 なら当たり）: 並べ替え " + n[0] + " ／ 理由 " + n[1] + " ／ 覚える " + n[2] + " ／ 書き戻し " + n[3]);
if (n.some((x) => x !== 1)) process.exit(3);
' "$F" "$TMP"; RC=$?
if [ "$RC" -ne 0 ]; then
  echo "  **当たる場所が 1 か所ずつ見つからない。置かない**（元のまま）"
  rm -f "$TMP"; echo '```'; exit 1
fi
CK="$(node --check "$TMP" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -ne 0 ]; then echo "  **構文が通らない。置かない**（元のまま）"; rm -f "$TMP"; echo '```'; exit 1; fi
mv "$TMP" "$F"
printf '  置いた。%s 行 ／ x227 の印 %s 個\n' "$(wc -l < "$F" | tr -d ' ')" "$(grep -c 'x227' "$F" | head -1)"
echo '```'
echo
echo "## 足したところ"
echo
echo '```'
grep -n -A3 'x227: 外された人' "$F" | cut -c1-200
grep -n 'x227: 理由を\|x227Unf.push\|x227: 外した人を' "$F" | cut -c1-200
echo '```'
echo
echo "- **ジョブは走らせていない。** 次の定時（11:45 / 18:45）から効く。1 回目は「前回の記録が無い」ので、外された人の判定は 2 回目から"
echo "- 戻すときは \`$(basename "$BAK")\` を follow-balance.js に戻す"
echo
echo "**外していない。フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '置いた。' "$OUT"; then echo "follow-balance.js に外し返しと期日超えを足した / $(basename "$OUT")"
elif grep -q 'もう当たっている' "$OUT"; then echo "もう足してあった / $(basename "$OUT")"
else echo "**足せていない。元のまま** / $(basename "$OUT")"; exit 1; fi
