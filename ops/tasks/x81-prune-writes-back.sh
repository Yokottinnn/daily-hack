#!/bin/bash
# **`mutual-prune` が外した相手を `reply-followers.json` にも反映する。費用 $0。**
#
# ## なぜ（x79 の実測）
#
#   mutual-prune が外した 6 件 のうち
#     reply-followers.json にも居る: 2 件
#       → まだ「フォロー中」の扱い : **2 件**
#     reply-followers.json に無い  : 4 件（別経路でフォローした相手）
#
# **フォロー系ジョブは `reply-followers.json` を見て「既にフォロー済み」を判定する。**
# 外したのにそちらが古いままだと、**判定がずれる**（再フォローや二重処理の元）。
#
# `mutual-prune` は自分専用の `mutual-prune-state.json` にだけ書いていた。
# **もう一方にも印を付けるようにする。**
#
# ## やること（2 つ）
#
#   ① `mutual-prune.js` に、最後の書き込みのところで **もう一方にも反映する処理**を足す
#   ② **いま既にずれている分を、その場で直す**（次の 6 時 を待たない・最上位ルール 9）
#
# ## 付ける印
#
#   still_following  : false
#   unfollowed_at    : mutual-prune-state.json の日時（既に在ればそのまま）
#   unfollow_source  : "mutual-prune"
#   unfollow_reason  : "休眠 41 日" などの理由
#
# **既存のキーは消さない。** 既に外れている扱いの行は触らない。
#
# ## やらないこと
#
# **外さない。フォローしない。上限や判定条件を変えない。LLM を呼ばない（$0）。**
# **ブラウザを触らない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/prune-writes-back.md"
NODE_BIN="/usr/local/bin/node"
MP="$S/mutual-prune.js"
MPS="$D/mutual-prune-state.json"
RF="$D/reply-followers.json"
PATCH="$S/.x81-patch.js"
FIX="$S/.x81-reconcile.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
trap 'rm -f "$PATCH" "$FIX" "$MP.x81-new.js"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# ─── ① 本体に足すパッチ ───
cat > "$PATCH" <<'JSEOF'
const fs = require("fs");
const p = process.argv[2];
const src = fs.readFileSync(p, "utf8");

if (src.includes("x81")) { console.log("  **既に入っている。当てない。**"); process.exit(3); }

const OLD = '  try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); } catch (e) {}';
if (src.split(OLD).length - 1 !== 1) {
  console.log("  **目印が 1 箇所 でないので当てない。**");
  process.exit(4);
}

const ADD = [
  OLD,
  '',
  '  // 2026-09-15 x81: 外した相手を reply-followers.json にも反映する。',
  '  // フォロー系ジョブはそちらを見て「既にフォロー済み」を判定するため、',
  '  // 印を付けないと外したのに「フォロー中」と誤認される。',
  '  try {',
  '    if (fs.existsSync(FOLLOW_STATE)) {',
  '      const rf = JSON.parse(fs.readFileSync(FOLLOW_STATE, "utf8"));',
  '      const lower = {};',
  '      for (const k of Object.keys(rf)) lower[k.toLowerCase()] = k;',
  '      let touched = 0;',
  '      for (const [h2, d2] of Object.entries(state)) {',
  '        if (!d2 || !d2.unfollowed_at) continue;',
  '        const key = lower[String(h2).toLowerCase()];',
  '        if (!key) continue;',
  '        const e2 = rf[key] || {};',
  '        if (e2.unfollowed_at && e2.still_following === false) continue;',
  '        e2.still_following = false;',
  '        e2.unfollowed_at = e2.unfollowed_at || d2.unfollowed_at;',
  '        e2.unfollow_source = "mutual-prune";',
  '        e2.unfollow_reason = d2.why || null;',
  '        rf[key] = e2;',
  '        touched++;',
  '      }',
  '      if (touched) {',
  '        const tmp2 = FOLLOW_STATE + ".tmp";',
  '        fs.writeFileSync(tmp2, JSON.stringify(rf, null, 2));',
  '        fs.renameSync(tmp2, FOLLOW_STATE);',
  '      }',
  '      log("reply-followers.json に反映: " + touched + " 件");',
  '    }',
  '  } catch (e) { log("reply-followers 反映に失敗: " + String(e.message).slice(0, 80)); }',
].join("\n");

fs.writeFileSync(p + ".x81-new.js", src.replace(OLD, ADD));
console.log("  当てた（検査待ち）");
JSEOF

# ─── ② いまずれている分を直す ───
cat > "$FIX" <<'JSEOF'
const fs = require("fs");
const [, , mpsPath, rfPath] = process.argv;
if (!fs.existsSync(mpsPath) || !fs.existsSync(rfPath)) { console.log("  片方が無いので何もしない"); process.exit(0); }
const mps = JSON.parse(fs.readFileSync(mpsPath, "utf8"));
const rf = JSON.parse(fs.readFileSync(rfPath, "utf8"));
const lower = {};
for (const k of Object.keys(rf)) lower[k.toLowerCase()] = k;
let touched = 0, absent = 0, already = 0;
for (const [h, d] of Object.entries(mps)) {
  if (!d || !d.unfollowed_at) continue;
  const key = lower[String(h).toLowerCase()];
  if (!key) { absent++; continue; }
  const e = rf[key] || {};
  if (e.unfollowed_at && e.still_following === false) { already++; continue; }
  e.still_following = false;
  e.unfollowed_at = e.unfollowed_at || d.unfollowed_at;
  e.unfollow_source = "mutual-prune";
  e.unfollow_reason = d.why || null;
  rf[key] = e;
  touched++;
}
console.log("  直した   : **" + touched + " 件**");
console.log("  既に済み : " + already + " 件");
console.log("  向こうに無い: " + absent + " 件（別経路でフォローした相手）");
if (touched) {
  const tmp = rfPath + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(rf, null, 2));
  fs.renameSync(tmp, rfPath);
  console.log("  書き込んだ");
}
JSEOF

{
echo "# \`mutual-prune\` が外した相手を \`reply-followers.json\` にも反映する"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x79 の実測: 外した 6 件 のうち **2 件 が「フォロー中」のまま**残っていた。"
echo "> **フォロー系ジョブはそちらを見て判定する。** 古いままだと判定がずれる。"
echo
echo "**外さない。上限も判定条件も変えない。**"

# ═══════════ 0. 当てる前 ═══════════
echo
echo "## 0. 当てる前"
echo
echo '```'
if [ -f "$MP" ]; then
  echo "  mutual-prune.js: $(wc -l < "$MP" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$MP" 2>/dev/null)"
  echo "  x81 の印: $(grep -c 'x81' "$MP" 2>/dev/null || echo 0) 箇所"
else
  echo "  **$MP が無い。**"
fi
[ -f "$MPS" ] && echo "  mutual-prune-state.json: $("$NODE_BIN" -e 'console.log(Object.keys(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))).length)' "$MPS" 2>/dev/null) 件"
echo '```'

# ═══════════ 1. 本体に足す ═══════════
echo
echo "## 1. 本体に足す（**次の 6 時 から効く**）"
echo
echo '```'
if [ ! -f "$MP" ]; then
  echo "  対象が無い。"
elif ! "$NODE_BIN" --check "$PATCH" 2>/dev/null; then
  echo "  **パッチが構文エラー。当てない。**"
  "$NODE_BIN" --check "$PATCH" 2>&1 | head -5 | sed 's/^/    /'
else
  "$NODE_BIN" "$PATCH" "$MP" 2>&1 | clean
  if [ -f "$MP.x81-new.js" ]; then
    echo
    echo "  --- 検査して置き換える ---"
    if "$NODE_BIN" --check "$MP.x81-new.js" 2>/dev/null; then
      cp "$MP" "$MP.bak-$STAMP"
      mv "$MP.x81-new.js" "$MP"
      echo "    **置き換えた**（退避 $(basename "$MP").bak-$STAMP）"
    else
      echo "    **構文エラー。置き換えない**"
      "$NODE_BIN" --check "$MP.x81-new.js" 2>&1 | head -4 | sed 's/^/      /'
      rm -f "$MP.x81-new.js"
    fi
  fi
fi
echo '```'

# ═══════════ 2. いま直す ═══════════
echo
echo "## 2. いまずれている分を直す（**次の 6 時 を待たない**・最上位ルール 9）"
echo
echo '```'
if [ -f "$RF" ]; then
  cp "$RF" "$RF.bak-$STAMP" && echo "  退避: $(basename "$RF").bak-$STAMP"
  echo
fi
if "$NODE_BIN" --check "$FIX" 2>/dev/null; then
  "$NODE_BIN" "$FIX" "$MPS" "$RF" 2>&1 | clean
else
  echo "  **直す側が構文エラー。何もしない。**"
fi
echo '```'

# ═══════════ 3. 結果 ═══════════
echo
echo "## 3. 結果（**状態で確かめる**・ルール 13）"
echo
echo '```'
if [ -f "$MPS" ] && [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const mp = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rf = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const lower = {};
for (const [k, v] of Object.entries(rf)) lower[k.toLowerCase()] = v || {};
let both = 0, stale = 0, ok = 0, absent = 0;
for (const h of Object.keys(mp)) {
  const e = lower[h.toLowerCase()];
  if (!e) { absent++; continue; }
  both++;
  if (e.still_following === true && !e.unfollowed_at) stale++; else ok++;
}
console.log("  mutual-prune が外した相手のうち");
console.log("    reply-followers.json にも居る: " + both + " 件");
console.log("      → そちらも外れている扱い  : **" + ok + " 件**");
console.log("      → まだフォロー中の扱い     : **" + stale + " 件**");
console.log("    向こうに無い                 : " + absent + " 件");
console.log("");
console.log(stale === 0 ? "  → **ずれが解消した。**" : "  → **まだずれている。** bak から戻せる");
console.log("");
const cnt = Object.values(rf).filter((e) => e && e.unfollow_source === "mutual-prune").length;
console.log("  unfollow_source=mutual-prune の件数: **" + cnt + " 件**");
' "$MPS" "$RF" 2>&1 | clean
fi
echo
echo "  --- 本体に入ったか ---"
[ -f "$MP" ] && grep -n 'reply-followers.json に反映' "$MP" 2>/dev/null | head -2 | cut -c1-120 | sed 's/^/    /'
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**JSON に印を付けるだけ。LLM を呼ばない。外さない。ブラウザも触らない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**\`mutual-prune\` 自体も \$0**（DOM 操作のみ）。外す件数の上限も変えていない"
echo "（1 回 8 件・1 日 16 件。実績は 2026-09-13 に 6 件）。"
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44。"
} > "$OUT" 2>&1

echo "mutual-prune の反映 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
