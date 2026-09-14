#!/bin/bash
# **`mutual-prune` の記録を正しい口で数える。測るだけ。費用 $0。**
#
# ## x78 の確認ミス（**私のミス**）
#
# x78 は `reply-followers.json` の `unfollow_source` を見て
# 「**mutual-prune が外した記録は 0 件**」と書いた。**これは誤り。**
#
# `x51` の実装（132 行目）では、書き先は**専用のファイル**。
#
#   const STATE        = path.join(WS, "data", "mutual-prune-state.json");   // ← 書く
#   const FOLLOW_STATE = path.join(WS, "data", "reply-followers.json");      // 読むだけ
#
# **ログは「6 件 外した」と言っている。** 記録が無いのではなく、見る場所が違った。
#
# ## 確かめるもの
#
#   1. `mutual-prune-state.json` の中身（**何件・いつ・理由**）
#   2. ログの「外れた」件数と**一致するか**
#   3. 外した相手が `reply-followers.json` にも居るか
#      （居るなら `still_following` が古いままになっていないか）
#
# ## なぜ 3 が要るか
#
# フォロー系ジョブは `reply-followers.json` を見て「既にフォロー済み」を判定する。
# **mutual-prune が外したのにそちらが古いままだと、判定がずれる。**
# x61 の洗い替えが効いていれば問題ないが、**確かめていないので確かめる。**
#
# ## やらないこと
#
# **外さない。書き換えない。kickstart しない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-prune-state.md"
NODE_BIN="/usr/local/bin/node"
MPS="$D/mutual-prune-state.json"
RF="$D/reply-followers.json"
MPL="$L/mutual-prune.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`mutual-prune\` の記録を正しい口で数える"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x78 は \`reply-followers.json\` を見て「記録は 0 件」と書いた。**これは誤り。**"
echo "> \`x51\` の実装では書き先は **\`mutual-prune-state.json\`**（専用ファイル）。"
echo ">"
echo "> **ログは「6 件 外した」と言っている。** 記録が無いのではなく、見る場所が違った。"
echo
echo "**測るだけ。書き換えない。**"

# ═══════════ 1. 専用の状態ファイル ═══════════
echo
echo "## 1. \`mutual-prune-state.json\`（**正しい口**）"
echo
echo '```'
if [ ! -f "$MPS" ]; then
  echo "  **$MPS が無い。**"
  ls -1 "$D" 2>/dev/null | grep -i mutual | sed 's/^/    候補: /' || echo "    mutual を含むファイルも無い"
else
  printf '  %s bytes / 最終更新 %s\n' "$(wc -c < "$MPS" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$MPS" 2>/dev/null)"
  echo
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rows = Object.entries(j).map(([k, v]) => (v && typeof v === "object" ? { handle: k, ...v } : { handle: k, v }));
console.log("  記録: **" + rows.length + " 件**");
console.log("");
const keys = {};
for (const r of rows) for (const k of Object.keys(r)) keys[k] = (keys[k] || 0) + 1;
console.log("  フィールド: " + JSON.stringify(keys));
console.log("");
const why = {};
for (const r of rows) { const w = String(r.why || "(無し)").replace(/[0-9]+/g, "N"); why[w] = (why[w] || 0) + 1; }
console.log("  --- 理由の内訳 ---");
for (const k of Object.keys(why).sort((a, b) => why[b] - why[a])) console.log("    " + String(why[k]).padStart(3) + " 件  " + k);
console.log("");
console.log("  --- 直近 10 件 ---");
const sorted = rows.filter((r) => r.unfollowed_at).sort((a, b) => String(a.unfollowed_at).localeCompare(String(b.unfollowed_at)));
for (const r of sorted.slice(-10)) {
  console.log("    " + String(r.unfollowed_at).slice(0, 16)
    + "  理由=" + String(r.why || "?").slice(0, 28).padEnd(28)
    + " followers=" + (r.followers === undefined ? "?" : r.followers)
    + " 最終投稿=" + (r.idle_days === undefined ? "?" : r.idle_days + " 日前"));
}
' "$MPS" 2>&1 | clean
fi
echo '```'

# ═══════════ 2. ログと一致するか ═══════════
echo
echo "## 2. ログと一致するか（**2 つの口を突き合わせる**）"
echo
echo '```'
if [ -f "$MPL" ]; then
  A="$(grep -c '外れた' "$MPL" 2>/dev/null || echo 0)"
  B="$(grep -cE 'done: [0-9]+ 件 外した' "$MPL" 2>/dev/null || echo 0)"
  echo "  ログの「外れた」行      : $A 件"
  echo "  ログの「done: N 件 外した」: $B 回"
  grep -oE 'done: [0-9]+ 件 外した' "$MPL" 2>/dev/null | tail -6 | sed 's/^/    /'
  echo
  if [ -f "$MPS" ]; then
    C="$("$NODE_BIN" -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(Object.keys(j).length)' "$MPS" 2>/dev/null || echo "?")"
    echo "  状態ファイルの件数      : $C 件"
    echo
    if [ "$A" = "$C" ]; then
      echo "  → **一致している。** ログと状態ファイルが同じ数を言っている"
    else
      echo "  → **一致しない。** どちらかが取りこぼしている（$A vs $C）"
      echo "     ログは「押した回数」、状態ファイルは「記録した件数」なので、"
      echo "     押したのに書けなかった分が在るかもしれない"
    fi
  fi
else
  echo "  **$MPL が無い。**"
fi
echo '```'

# ═══════════ 3. もう一方の状態ファイルとの整合 ═══════════
echo
echo "## 3. \`reply-followers.json\` 側は古くなっていないか"
echo
echo "フォロー系ジョブは **\`reply-followers.json\` を見て「既にフォロー済み」を判定する。**"
echo "**mutual-prune が外したのにそちらが古いままだと、判定がずれる。**"
echo
echo '```'
if [ -f "$MPS" ] && [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const mp = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rf = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const rfLower = {};
for (const [k, v] of Object.entries(rf)) rfLower[k.toLowerCase()] = v || {};
let both = 0, stale = 0, ok = 0, absent = 0;
const staleList = [];
for (const h of Object.keys(mp)) {
  const e = rfLower[h.toLowerCase()];
  if (!e) { absent++; continue; }
  both++;
  if (e.still_following === true && !e.unfollowed_at) { stale++; staleList.push(h); }
  else ok++;
}
console.log("  mutual-prune が外した相手のうち");
console.log("    reply-followers.json にも居る: " + both + " 件");
console.log("      → そちらも外れている扱い  : " + ok + " 件");
console.log("      → **まだフォロー中の扱い** : " + stale + " 件");
console.log("    reply-followers.json に無い  : " + absent + " 件（別経路でフォローした相手）");
console.log("");
if (stale) {
  console.log("  → **ずれている。** 次の洗い替え（x61 系）で直るはずだが、");
  console.log("     それまでは「フォロー中」と誤認する");
} else {
  console.log("  → **ずれていない。** 判定に影響は無い");
}
' "$MPS" "$RF" 2>&1 | clean
else
  echo "  どちらかのファイルが無いので比べられない"
fi
echo '```'

# ═══════════ 4. 次はいつ走るか ═══════════
echo
echo "## 4. 次はいつ走るか"
echo
echo '```'
echo "  StartInterval=43200 秒（12 時間）/ RunAtLoad=false"
if [ -f "$MPL" ]; then
  echo "  ログの最終更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$MPL" 2>/dev/null)"
  echo "  いま          : $(date '+%Y-%m-%d %H:%M')"
fi
echo '```'
echo
echo "**12 時間 間隔なので、1 日 最大 2 回 × 8 件 = 16 件 が上限。**"
echo "上限は安全弁であって予想ではない（実績は 2026-09-13 に 6 件）。"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**JSON とログを読むだけ。LLM を呼ばない。外さない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**\`mutual-prune\` 自体も \$0**（DOM 操作のみ・LLM を呼ばない）。"
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44。"
} > "$OUT" 2>&1

echo "mutual-prune の記録（正しい口） / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
