#!/bin/bash
# **「通った 8〜22 件」と「記録 1〜4 件」の差を測る。読むだけ。費用 $0。**
#
# ## 食い違い（`x194` / `x195` の実測）
#
#   ログのファネル   competitor **8〜22 件/日** ＋ hashtag 0〜4 件/日
#   followed.json    **1〜4 件/日**
#   → **5〜10 倍 合わない**
#
# **毎日 180 回 試して、実っているのが 1〜4 件 なら、それ自体が最大の損失。**
# 比率の判定はもう どちらにも依存しないので急ぎではないが、
# **フォロワーを増やす効率の話としては、ここが一番 効く。**
#
# ## 考えられるのはこの 3 つ
#
#   A. **ログが嘘**       「OK」と数えた後に実際はボタンが付いていない
#                         （弾かれた理由に `follow button click didn't change to
#                           unfollow` が **50 件** ある＝検知はしている）
#   B. **記録が嘘**       フォローはできているが `followed.json` に書かれていない
#   C. **どちらも本当**   別のジョブ（`unfollow-cleanup` 等）が同じ日に外している
#
# ## 決め手: **OK になった相手が、いまフォロー中の一覧に居るか**
#
# 居れば **B（記録が漏れているだけ。実害は小さい）**。
# 居なければ **A（押せていない。180 回 が無駄になっている）**。
#
# ## ログの書き方を知らないので、まず そのまま出す
#
# **`OK` の行がどう書かれているかを、私は確かめていない。**
# 当て推量でパターンを書くと、0 件 と出ても「無い」のか「当たっていない」のか
# 区別がつかない（`x189` で実際に踏んだ）。**生の行をそのまま出してから数える。**
#
# ## やらないこと
#
# **フォローしない。外さない。設定も触らない。ブラウザも触らない**（ファイル読みだけ）。
# **LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
CL="$L/competitor-follower-follow.log"
HL="$L/hashtag-follow.log"
LF="$D/follow-balance-lists.json"
FOLLOWED="$D/followed.json"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-ok-vs-recorded.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
XTRACT="$W/.x196-xtract-$STAMP.js"
OKTMP="$W/.x196-ok-$STAMP.txt"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

cntI() { c="$(grep -ac "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# 「通った」と「記録」の差を測る（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> ログのファネルは **8〜22 件/日**、\`followed.json\` は **1〜4 件/日**。**5〜10 倍 合わない。**"
echo "> **決め手は「OK になった相手が、いまフォロー中の一覧に居るか」。**"
echo "> **読むだけ。フォローも外しもしない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 1. ログの生の行（**当て推量しないために、まず そのまま出す**）"
echo
echo "\`OK\` がどう書かれているかを確かめていないので、**末尾を切らずに見る。**"
echo
echo "### 1-A. competitor-follower-follow（末尾 45 行）"
echo
echo '```'
if [ -f "$CL" ]; then
  tail -45 "$CL" 2>/dev/null | tr -d '\000' | cut -c1-230 | clean | sed 's/^/  /'
else
  echo "  **ログが無い: $CL**"
fi
echo '```'
echo
echo "### 1-B. 成功らしき行の書き方（**重複を潰して形だけ見る**）"
echo
echo '```'
if [ -f "$CL" ]; then
  grep -a -iE 'OK|✅|followed|フォローした|follow ok|→ follow' "$CL" 2>/dev/null \
    | grep -av '=== end:' | tr -d '\000' \
    | sed -E 's/^\[[^]]*\] ?//' \
    | sed -E 's/@[A-Za-z0-9_]{2,15}/@H/g; s/[0-9]+/N/g' \
    | cut -c1-120 | sort | uniq -c | sort -rn | head -14 | sed 's/^/  /' | clean
else
  echo "  （ログが無い）"
fi
echo '```'

echo
echo "## 2. 日ごとの突き合わせ"
echo
echo '```'
printf '  %-12s %10s %10s %10s\n' "日付" "end の OK" "記録" "押せず"
grep -a '' "$CL" 2>/dev/null | tr -d '\000' | awk '
  match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { d = substr($0, RSTART, RLENGTH) }
  d == "" { next }
  match($0, /=== end: [0-9]+\/[0-9]+ OK ===/) {
    s = substr($0, RSTART + 9, RLENGTH - 16); split(s, a, "/"); ok[d] += a[1] + 0
  }
  /did.?n.?t change to unfollow/ { miss[d]++ }
  { seen[d] = 1 }
  END {
    n = 0; for (k in seen) ks[n++] = k
    for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (ks[i] > ks[j]) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
    st = (n > 10 ? n - 10 : 0)
    for (i = st; i < n; i++) { k = ks[i]; printf("OKROW %s %d %d\n", k, ok[k], miss[k]) }
  }
' > "$OKTMP" 2>/dev/null
node -e '
  const fs = require("fs");
  // **`node -e` では argv[1] が第 1 引数**（ファイル実行のときと 1 つ ずれる。
  // `--` を置いても消費されないので、付けない）
  // followed.json を harvest と同じ歩き方で日ごとに数える
  let root; try { root = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { root = null; }
  const byHandle = new Map(); const seen = new Set();
  const walk = (node, keyHint) => {
    if (!node || typeof node !== "object" || seen.has(node)) return;
    seen.add(node);
    if (Array.isArray(node)) { for (const v of node) walk(v, null); return; }
    const at = node.followed_at || node.at || node.created_at || node.followedAt;
    const isLeaf = !Object.values(node).some((v) => v && typeof v === "object");
    const h = node.handle || node.screen_name || node.username || (isLeaf ? keyHint : null);
    if (h && typeof h === "string" && /^[A-Za-z0-9_]{1,15}$/.test(h.replace(/^@/, ""))) {
      const k = h.replace(/^@/, "").toLowerCase();
      const prev = byHandle.get(k);
      if (!prev || (at && !prev.at)) byHandle.set(k, { at: at || (prev && prev.at) || null });
    }
    for (const [k, v] of Object.entries(node)) walk(v, typeof k === "string" ? k : null);
  };
  if (root) walk(root, null);
  const day = (ms) => new Date(ms + 9 * 3600 * 1000).toISOString().slice(0, 10);
  const rec = new Map();
  for (const [, v] of byHandle) {
    if (!v.at) continue;
    const t = new Date(v.at).getTime();
    if (!Number.isFinite(t)) continue;
    const k = day(t); rec.set(k, (rec.get(k) || 0) + 1);
  }
  let lines = [];
  try { lines = fs.readFileSync(process.argv[2], "utf8").split("\n"); } catch (e) {}
  let sOk = 0, sRec = 0, sMiss = 0;
  for (const ln of lines) {
    const m = ln.match(/^OKROW (\S+) (\d+) (\d+)$/);
    if (!m) continue;
    const [, d, ok, miss] = m;
    const r = rec.get(d) || 0;
    sOk += +ok; sRec += r; sMiss += +miss;
    console.log("  " + d.padEnd(12) + String(ok).padStart(10) + String(r).padStart(10) + String(miss).padStart(10));
  }
  console.log("  " + "合計".padEnd(11) + String(sOk).padStart(10) + String(sRec).padStart(10) + String(sMiss).padStart(10));
  console.log("");
  console.log("  ※ 「記録」は competitor だけでなく **全経路ぶん**（hashtag も followback も含む）");
  console.log("  ※ それでも end の OK より小さいなら、**OK が実っていない**");
' "$FOLLOWED" "$OKTMP" 2>&1 | clean
rm -f "$OKTMP"
echo '```'

echo
echo "## 3. **決め手**: OK になった相手が、いまフォロー中の一覧に居るか"
echo
echo "居れば **B（記録の漏れ。実害は小さい）**、居なければ **A（押せていない）**。"
echo
cat > "$XTRACT" <<'XEOF'
const fs = require("fs");
const logPath = process.argv[2];
const listPath = process.argv[3];

let txt = "";
try { txt = fs.readFileSync(logPath, "utf8"); } catch (e) { console.log("  ログが読めない"); process.exit(0); }
const lines = txt.split("\n");

// **直近 3 日 に絞る**（古い相手はもう外されている可能性があるため）
const days = [...new Set(lines.map((l) => (l.match(/\d{4}-\d{2}-\d{2}/) || [])[0]).filter(Boolean))].sort();
const recent = new Set(days.slice(-3));

// **成功らしき行を広めに拾う。** 弾かれた行（❌）は除く
const okRe = /(OK|✅|followed|フォローした|follow ok)/i;
const hRe = /(?:@|x\.com\/|twitter\.com\/)([A-Za-z0-9_]{2,15})/g;
const hits = new Map();
let okLines = 0;
for (const l of lines) {
  const d = (l.match(/\d{4}-\d{2}-\d{2}/) || [])[0];
  if (!d || !recent.has(d)) continue;
  if (l.includes("=== end:")) continue;
  if (l.includes("❌")) continue;
  if (!okRe.test(l)) continue;
  okLines++;
  let m;
  hRe.lastIndex = 0;
  while ((m = hRe.exec(l)) !== null) {
    const h = m[1].toLowerCase();
    if (h === "intent" || h === "i" || h === "home" || h === "search") continue;
    if (!hits.has(h)) hits.set(h, d);
  }
}

console.log("  対象の日: " + [...recent].join(" "));
console.log("  成功らしき行: " + okLines + " 行 / そこから取れたハンドル: " + hits.size + " 件");
if (!okLines) {
  console.log("");
  console.log("  **成功の行が 1 行も取れていない。** §1-B の形を見てパターンを直すこと。");
  console.log("  （0 件 は「無い」ではなく「当たっていない」かもしれない）");
  process.exit(0);
}
if (!hits.size) {
  console.log("");
  console.log("  **行はあるがハンドルが書かれていない。** §1-A の生の行を見ること。");
  process.exit(0);
}

let lst;
try { lst = JSON.parse(fs.readFileSync(listPath, "utf8")); }
catch (e) { console.log("  一覧のキャッシュが読めない。突き合わせできない"); process.exit(0); }
const following = new Set((lst.following || []).map((h) => String(h).toLowerCase()));
const followers = new Set((lst.followers || []).map((h) => String(h).toLowerCase()));
const ageM = (Date.now() - new Date(lst.at || 0).getTime()) / 60000;

let inFollowing = 0, notIn = 0, andFollower = 0;
for (const [h] of hits) {
  if (following.has(h)) { inFollowing++; if (followers.has(h)) andFollower++; }
  else notIn++;
}
console.log("");
console.log("  一覧のキャッシュ: " + (isFinite(ageM) ? ageM.toFixed(0) : "?") + " 分 前 / フォロー中 " + following.size + " 件");
console.log("");
console.log("  いまフォロー中に **居る**   " + inFollowing + " 件（うち相互 " + andFollower + " 件）");
console.log("  いまフォロー中に **居ない** " + notIn + " 件");
console.log("");
const pct = hits.size ? Math.round((inFollowing / hits.size) * 100) : 0;
if (pct >= 70) {
  console.log("  → **B。押せている。`followed.json` への書き込みが漏れている**");
} else if (pct <= 30) {
  console.log("  → **A の疑いが濃い。押せていないか、すぐ外されている**");
  console.log("     ※ ただし **こちらの unfollow ジョブが外した**可能性も残る。");
  console.log("       `follow-balance-state.json` と突き合わせるのが次の一手");
} else {
  console.log("  → **判断がつかない（" + pct + "%）。** 母数が小さいか、混在している");
}
XEOF
echo '```'
if [ -f "$CL" ] && [ -f "$LF" ]; then
  node "$XTRACT" "$CL" "$LF" 2>&1 | clean
else
  echo "  ログか一覧のキャッシュが無い"
fi
echo '```'
rm -f "$XTRACT"

echo
echo "## 4. 参考: 押せなかった記録"
echo
echo '```'
printf '  「クリックしても フォロー中 に変わらなかった」  %s 件（competitor 全期間）\n' "$(cntI "change to unfollow" "$CL")"
printf '  「ボタンが無い」                                %s 件\n' "$(cntI "no follow button" "$CL")"
printf '  competitor のログ  %s bytes / 更新 %s\n' "$(wc -c < "$CL" 2>/dev/null | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$CL" 2>/dev/null)"
printf '  hashtag のログ     %s bytes / 更新 %s\n' "$(wc -c < "$HL" 2>/dev/null | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$HL" 2>/dev/null)"
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 の出方 | どれか | 次にやること |"
echo "| --- | --- | --- |"
echo "| **70% 以上 が一覧に居る** | **B. 記録の漏れ** | \`followed.json\` の書き込みを直す。**実害は小さい** |"
echo "| **30% 以下** | **A. 押せていない** | **180 回 が無駄になっている。** ここを直すのが最優先 |"
echo "| 成功の行が 0 行 | **測れていない** | §1-B の形を見てパターンを直す（**0 は「無い」ではない**）|"
echo
echo "**フォローしていない。外していない。設定も変えていない。**"
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$XTRACT" "$OKTMP"

if grep -aq '決め手' "$OUT" 2>/dev/null; then
  echo "OK と記録の差を測った / $(basename "$OUT")"
else
  echo "**測れていない。レポートを確認すること** / $(basename "$OUT")"
fi
