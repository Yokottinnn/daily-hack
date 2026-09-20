#!/bin/bash
# **選別済みの 58 件 を、種の候補として並べる。測るだけ。費用 $0。**
#
# ## なぜここを見るのか
#
# x96 で `influencers.json` は 7 件 しか無く、**候補プールが空**だと分かった。
# x97 で `comment-state.json` に **`targets` 配列 58 件** があると分かった。
#
# **これが本来の候補プール。** 返信経路（`comment-orchestrator`）は
# **21.9%（n=146）** で競合の平均より高く、**そこで使われている 58 件 は
# ジャンルの選別を通っている。**
#
# ## 選ぶ基準（x96・x97 で確定したこと）
#
# ### ① 規模では選ばない
#
#   okamiler_pn  18.2%  平均フォロワー 7757
#   ukk_hx        4.2%  平均フォロワー 6993
#
# **ほぼ同じ規模で 4 倍 違う。** 効いているのはジャンルの近さ。
#
# ### ② ただし「実証済みの範囲」からは出ない
#
# x97 で、いまの種のうち 2 つ の実数が分かった。
#
#   POIKATSU_OTAKE  **90000**   返り率 10.0%
#   money_yossy     **38000**   返り率  8.6%
#
# **いまの 7 種 はどれも 9 万 以下。** 25〜34 万 のブランド公式は範囲の外で、
# そこに踏み込むと `ukk_hx`（4.2%）を作り直すおそれがある。
#
# ### ③ ブランド公式より個人
#
# 種は「**その人のフォロワーを追う**」入口。
# ブランド公式のフォロワーは一般層で、**自分で選んでフォローした人の集まりではない。**
#
# ## ハンドルを伏せない
#
# **公開アカウントの候補一覧であり、伏せると選べない**（x96・x97 と同じ判断）。
# **フォローした相手のハンドル（`reply-followers.json` のキー）は出さない。**
#
# ## やらないこと
#
# **配列を書き換えない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/comment-targets.md"
CS="$D/comment-state.json"
HF="$L/hashtag-follow.log"
CW="$L/comment-warmup.log"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }

# フォロワー数が分かっているものを、ログから先に集めておく
KNOWN="${TMPDIR:-/tmp}/.x98-known-followers.txt"
: > "$KNOWN"
if [ -f "$HF" ]; then
  grep -oE '@[A-Za-z0-9_]{3,15}: ❌ follower count out of range \([0-9]+' "$HF" 2>/dev/null \
    | sed -E 's/@([A-Za-z0-9_]+): .*\(([0-9]+)/\1 \2/' >> "$KNOWN"
fi
if [ -f "$CW" ]; then
  grep -oE '@[A-Za-z0-9_]{3,15}[^0-9]{0,40}\(([0-9]+) followers' "$CW" 2>/dev/null \
    | sed -E 's/@([A-Za-z0-9_]+).*\(([0-9]+) followers/\1 \2/' >> "$KNOWN"
fi

{
echo "# 選別済み 58 件 を種の候補として見る"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`influencers.json\` は 7 件 しか無く候補プールが空だった（x96）。"
echo "> \`comment-state.json\` の **\`targets\` 58 件** が本来の候補プール。"
echo "> 返信経路は **21.9%（n=146）** で、**ここはジャンルの選別を通っている。**"
echo
echo "**測るだけ。書き換えない。フォローしない。**"

# ═══════════ 1. 58 件 の実物 ═══════════
echo
echo "## 1. \`targets\` の中身（**構造から先に出す**）"
echo
echo '```'
if [ ! -f "$CS" ]; then
  echo "  **$CS が無い。**"
  ls -1 "$D" 2>/dev/null | grep -i comment | head -8 | sed 's/^/    /'
else
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { console.log("  **読めない: " + e.message.slice(0,120) + "**"); process.exit(0); }
const t = j.targets;
if (!Array.isArray(t)) { console.log("  **targets が配列ではない: " + typeof t + "**"); process.exit(0); }
console.log("  targets: " + t.length + " 件");
console.log("");
console.log("  --- 1 件目の実物（**フィールドを当て推量しない**）---");
console.log("    " + JSON.stringify(t[0]).slice(0, 400));
console.log("");
const keys = {};
for (const r of t) {
  if (r && typeof r === "object") for (const k of Object.keys(r)) keys[k] = (keys[k] || 0) + 1;
}
if (Object.keys(keys).length) {
  console.log("  --- キーと件数 ---");
  for (const [k, n] of Object.entries(keys).sort((a, b) => b[1] - a[1])) {
    console.log("    " + String(k).padEnd(26) + " " + n + " 件");
  }
} else {
  console.log("  （要素は文字列のみ。ハンドルの配列）");
}
' "$CS" 2>&1 | secrets
fi
echo '```'

# ═══════════ 2. 58 件 一覧（フォロワー数が分かるものは併記） ═══════════
echo
echo "## 2. 58 件 の一覧（**分かっているフォロワー数を併記**）"
echo
echo '```'
if [ -f "$CS" ]; then
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { process.exit(0); }
const t = Array.isArray(j.targets) ? j.targets : [];
// ログから拾ったフォロワー数
const known = {};
try {
  for (const line of fs.readFileSync(process.argv[2], "utf8").split("\n")) {
    const m = line.trim().split(/\s+/);
    if (m.length === 2 && /^[0-9]+$/.test(m[1])) known[m[0]] = Math.max(known[m[0]] || 0, Number(m[1]));
  }
} catch {}
const SEEDS = new Set(["himawari56757","ukk_hx","POIKATSU_OTAKE","tokufree3","okamiler_pn","money_yossy","haiji_doctor"]);
const handleOf = (r) => {
  if (typeof r === "string") return r.replace(/^@/, "");
  if (r && typeof r === "object") {
    for (const k of ["handle", "username", "screen_name", "user", "id", "name"]) {
      if (typeof r[k] === "string") return r[k].replace(/^@/, "");
    }
  }
  return null;
};
const rows = [];
for (const r of t) {
  const h = handleOf(r);
  if (!h) continue;
  rows.push({ h, f: known[h] ?? null, seed: SEEDS.has(h) });
}
console.log("    " + "ハンドル".padEnd(22) + "フォロワー   備考");
console.log("    " + "-".repeat(58));
// フォロワー数が分かるものを上に、多い順
rows.sort((a, b) => (b.f ?? -1) - (a.f ?? -1));
for (const r of rows) {
  const f = r.f === null ? "（未取得）" : String(r.f);
  let note = "";
  if (r.seed) note = "**いまの種**";
  else if (r.f !== null && r.f >= 100 && r.f <= 90000) note = "← 実証済みの帯（9 万 以下）";
  else if (r.f !== null && r.f > 90000) note = "帯の外（大きすぎる）";
  console.log("    " + r.h.padEnd(22) + f.padStart(9) + "   " + note);
}
console.log("");
const un = rows.filter((r) => r.f === null).length;
console.log("    計 " + rows.length + " 件 / **フォロワー数が未取得: " + un + " 件**");
' "$CS" "$KNOWN" 2>&1 | secrets
fi
echo '```'
echo
echo "**未取得が多ければ、次に DOM で数を取る必要がある**（それも \$0）。"
echo "分かっているものだけで 3 つ 選べるなら、そこで決められる。"

# ═══════════ 3. 返信で何回 選ばれたか（ジャンルの近さの代理指標） ═══════════
echo
echo "## 3. 返信で**何回 選ばれたか**（ジャンルの近さの代理指標）"
echo
echo '```'
if [ -f "$CW" ]; then
  grep -oE 'processing #[0-9]+/[0-9]+ for @[A-Za-z0-9_]{3,15}' "$CW" 2>/dev/null \
    | sed -E 's/.*@([A-Za-z0-9_]+)/\1/' | sort | uniq -c | sort -rn | head -25 \
    | awk '{ printf("    %3d 回  %s\n", $1, $2) }'
else
  echo "    **comment-warmup.log が無い。**"
fi
echo '```'
echo
echo "**繰り返し選ばれている人は、picker のジャンル判定を何度も通っている。**"
echo "ただし**返信の相手として良いことと、種として良いことは別**なので、"
echo "これだけでは決めない。フォロワー数と合わせて見る。"

# ═══════════ 3-B. 日ごとのフォロワー数が残っていないか ═══════════
#
# **`follower-snapshot` は 2026-09-09 〜 09-19 の 11 日間 止まっていた。**
# そのため `follower-snapshot.log` は 9/8 の次が 9/20 で、**+37 は 12 日ぶんの塊。**
# 「直近 数日 で伸びた」が本当かを、ログ以外の口から確かめる。
echo
echo "## 3-B. 日ごとのフォロワー数が**別の口に残っていないか**"
echo
echo '```'
SNAPD="$D/follower-snapshots"
if [ -d "$SNAPD" ]; then
  echo "  $SNAPD"
  echo "  ファイル数: $(ls -1 "$SNAPD" 2>/dev/null | grep -c . || true) 件"
  echo
  echo "  --- 直近 20 件（日付と、中に入っている人数）---"
  ls -1 "$SNAPD" 2>/dev/null | sort | tail -20 | while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    N="$(/usr/local/bin/node -e '
const fs=require("fs");
try{const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const a=Array.isArray(j)?j:(j.followers||j.list||j.following||[]);
console.log(typeof j.count==="number"?j.count:(Array.isArray(a)?a.length:"?"));}catch(e){console.log("?")}
' "$SNAPD/$f" 2>/dev/null)"
    printf '    %-28s %6s 人\n' "$f" "${N:-?}"
  done
else
  echo "  **$SNAPD が無い。** data/ の候補:"
  ls -1 "$D" 2>/dev/null | grep -i -E 'snapshot|follower' | head -8 | sed 's/^/    /'
fi
echo
echo "  --- 9/09〜9/19 のファイルがあるか（**止まっていた期間**）---"
FOUND=0
for d in 09 10 11 12 13 14 15 16 17 18 19; do
  [ -e "$SNAPD/2026-09-$d.json" ] && { echo "    2026-09-$d.json  **在る**"; FOUND=$((FOUND+1)); }
done
[ "$FOUND" = "0" ] && echo "    **1 件も無い。** 日ごとの数はこの期間 残っていない"
echo '```'
echo
echo "**在れば日ごとの伸びが出せる。無ければ、いまの 264 が最初の再開点。**"
echo "その場合、日ごとの傾向は**明日以降の記録でしか出せない。**"

# ═══════════ 4. 判断の材料（再掲） ═══════════
echo
echo "## 4. 判断の材料（**同じ紙に残す**）"
echo
echo '```'
echo "    いまの 7 種"
echo "      himawari56757   26.0%   残す"
echo "      haiji_doctor    20.8%   残す"
echo "      okamiler_pn     18.2%   残す"
echo "      tokufree3       16.2%   残す"
echo "      POIKATSU_OTAKE  10.0%   **外す**（フォロワー 90000）"
echo "      money_yossy      8.6%   **外す**（フォロワー 38000）"
echo "      ukk_hx           4.2%   **外す**"
echo
echo "    群で見ると"
echo "      外す 3 つ  mature  89 件 →  7 人   7.9%"
echo "      残す 4 つ  mature 133 件 → 28 人  21.1%"
echo
echo "    選ぶ基準"
echo "      ① 規模では選ばない（同規模で 4 倍 違う実例がある）"
echo "      ② ただし 9 万 以下（実証済みの帯）から出ない"
echo "      ③ ブランド公式より個人"
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**JSON とログを読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**差し替える場合も \$0。** \`competitor-follower-follow\` は DOM 操作のみで"
echo "LLM を呼ばないため、**フォロー数を変えても API 費用は動かない。**"
echo "返信ループの実測は 1 回 \$0.003 ／ 1 日 \$0.021 ／ 1 か月 約 \$0.63（別勘定・変わらない）。"
} > "$OUT" 2>&1

rm -f "$KNOWN" 2>/dev/null || true
echo "選別済み 58 件 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
