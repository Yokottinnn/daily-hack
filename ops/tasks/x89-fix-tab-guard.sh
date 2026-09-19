#!/bin/bash
# **tab-guard の 2 つのバグを直す。費用 $0（LLM 不使用）。**
#
# ## バグ ①: 10 秒 ごとに落ちて再起動している
#
#   TypeError: Cannot read properties of undefined (reading 'halted')
#       at tab-guard.js:132
#
# `check()` は値を返さず `return;` する経路が 2 つ ある（90 行 と 111 行）。
# 呼び出し側が `if (r.halted)` と書いているため、**毎回 落ちる。**
# `KeepAlive: true` なので launchd が 10 秒 おきに上げ直していた（ログ 20MB）。
#
# ## バグ ②: 再起動すると全ループを外す
#
# 123 行 の保存が `{ count, at }` だけで、**`reachable` を保存していない。**
# そのため 88 行 のガード `prev.reachable === false` は**永久に成立しない**。
#
#   if (!chromeAlive()) {
#     if (prev && prev.reachable === false) { ...return; }   // ← 死んでいる
#     haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
#
# **再起動すれば Chrome プロセスは必ず消える**ので、この条件を毎回 踏む。
# 2026-09-12 と 2026-09-20 の全滅はこれ。
#
# ## 直し方（利用者が選んだ「起動直後は停めない」）
#
#   ① 状態に `reachable` と `chrome_alive_at` を保存する
#   ② **「一度 生きていたのに消えた」ときだけ止める。**
#      直近 15 分 以内に Chrome を生きている状態で見ていなければ、
#      起動直後とみなして止めない
#   ③ 呼び出し側を `if (r && r.halted)` にする
#
# **本来 守りたい「自動化が Jordan の Chrome を殺した」ケースは引き続き止まる。**
# Chrome が動いていれば `chrome_alive_at` が 30 秒 ごとに更新されるため、
# そこから消えれば 15 分 の窓に入る。
#
# ## やらないこと
#
# **判定 B（タブの一括破壊）と C（半分以上 消えた）は触らない。**
# **ループを載せ直さない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-tab-guard.md"
NODE_BIN="/usr/local/bin/node"
TG="$S/tab-guard.js"
PATCH="$S/.x89-patch.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
trap 'rm -f "$PATCH" "$TG.x89-new.js"' EXIT

hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

cat > "$PATCH" <<'JSEOF'
const fs = require("fs");
const p = process.argv[2];
const src = fs.readFileSync(p, "utf8");

if (src.includes("BOOT_GRACE")) {
  console.log("  **既に入っている。当てない。**");
  process.exit(3);
}

// ① 起動直後は停めない（判定 A に証拠を要求する）
const A_OLD = [
  '    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");',
  '    return { halted: true, reason: "chrome_process_gone" };',
].join("\n");
const A_NEW = [
  '    // BOOT_GRACE (2026-09-20 x89): **起動直後は停めない。**',
  '    // 再起動すれば Chrome プロセスは必ず消えるため、この条件を毎回 踏んでいた。',
  '    // 2026-09-12 と 2026-09-20 に、これで ai.openclaw.* が全滅した。',
  '    // **「一度 生きていたのに消えた」ときだけ止める。**',
  '    const aliveAt = prev && prev.chrome_alive_at ? Date.parse(prev.chrome_alive_at) : 0;',
  '    const ALIVE_WINDOW_MS = 15 * 60 * 1000;',
  '    if (!aliveAt || Date.now() - aliveAt > ALIVE_WINDOW_MS) {',
  '      log("Chrome を最近 生きている状態で見ていない（起動直後など）。消滅とみなさず halt しない");',
  '      try {',
  '        fs.writeFileSync(STATE, JSON.stringify({',
  '          count: 0,',
  '          reachable: false,',
  '          chrome_alive_at: (prev && prev.chrome_alive_at) || null,',
  '          at: new Date().toISOString(),',
  '        }, null, 2));',
  '      } catch {}',
  '      return;',
  '    }',
  '    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");',
  '    return { halted: true, reason: "chrome_process_gone" };',
].join("\n");

// ② 状態に reachable と chrome_alive_at を保存する（**ガードを生かす**）
const B_OLD = '  try { fs.writeFileSync(STATE, JSON.stringify({ count: now.count, at: new Date().toISOString() }, null, 2)); } catch {}';
const B_NEW = [
  '  // x89: **`reachable` を保存していなかったため、88 行 のガードが死んでいた。**',
  '  // ここまで来た時点で Chrome は生きているので `chrome_alive_at` も打つ。',
  '  try {',
  '    fs.writeFileSync(STATE, JSON.stringify({',
  '      count: now.count,',
  '      reachable: now.reachable === true,',
  '      chrome_alive_at: new Date().toISOString(),',
  '      at: new Date().toISOString(),',
  '    }, null, 2));',
  '  } catch {}',
].join("\n");

// ③ 値を返さない経路で落ちないようにする
const C_OLD = '      if (r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }';
const C_NEW = '      if (r && r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }';

const count = (s, sub) => s.split(sub).length - 1;
const checks = [["①", A_OLD], ["②", B_OLD], ["③", C_OLD]];
let ng = 0;
for (const [n, old] of checks) {
  const c = count(src, old);
  console.log("  目印 " + n + ": " + c + " 箇所");
  if (c !== 1) ng++;
}
if (ng) {
  console.log("  **1 箇所 でない目印がある。当てない。**");
  process.exit(4);
}

const patched = src.replace(A_OLD, A_NEW).replace(B_OLD, B_NEW).replace(C_OLD, C_NEW);
fs.writeFileSync(p + ".x89-new.js", patched);
console.log("  当てた（検査待ち）");
JSEOF

{
echo "# tab-guard の 2 つのバグを直す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> ① \`check()\` が値を返さない経路で \`r.halted\` が TypeError → **10 秒 ごとに再起動**"
echo "> ② \`reachable\` を保存していないため 88 行 のガードが死んでいて、"
echo ">    **再起動のたびに \`ai.openclaw.*\` を全部 外していた**"
echo
echo "**判定 B（タブの一括破壊）と C（半分以上 消えた）は触らない。**"

# ═══════════ 0. 当てる前 ═══════════
echo
echo "## 0. 当てる前"
echo
echo '```'
if [ -f "$TG" ]; then
  echo "  $(wc -l < "$TG" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$TG" 2>/dev/null)"
  echo "  BOOT_GRACE の印: $(grep -c 'BOOT_GRACE' "$TG" 2>/dev/null || echo 0) 箇所"
else
  echo "  **$TG が無い。**"
fi
echo
echo "  --- いまの状態ファイル ---"
[ -f "$D/tab-guard-state.json" ] && cat "$D/tab-guard-state.json" 2>/dev/null | sed 's/^/    /'
echo
echo "  --- エラーログの大きさ ---"
for f in tab-guard-err.log tab-guard.log tab-guard.out; do
  [ -f "$L/$f" ] && printf '    %-22s %10s bytes\n' "$f" "$(wc -c < "$L/$f" | tr -d ' ')"
done
echo '```'

# ═══════════ 1. 当てる ═══════════
echo
echo "## 1. 当てる（**3 箇所**）"
echo
echo '```'
if [ ! -f "$TG" ]; then
  echo "  対象が無い。"
elif ! "$NODE_BIN" --check "$PATCH" 2>/dev/null; then
  echo "  **パッチが構文エラー。当てない。**"
  "$NODE_BIN" --check "$PATCH" 2>&1 | head -5 | sed 's/^/    /'
else
  "$NODE_BIN" "$PATCH" "$TG" 2>&1 | clean
  if [ -f "$TG.x89-new.js" ]; then
    echo
    echo "  --- 検査して置き換える ---"
    if "$NODE_BIN" --check "$TG.x89-new.js" 2>/dev/null; then
      cp "$TG" "$TG.bak-$STAMP"
      mv "$TG.x89-new.js" "$TG"
      echo "    **置き換えた**（退避 $(basename "$TG").bak-$STAMP）"
    else
      echo "    **構文エラー。置き換えない**"
      "$NODE_BIN" --check "$TG.x89-new.js" 2>&1 | head -4 | sed 's/^/      /'
      rm -f "$TG.x89-new.js"
    fi
  fi
fi
echo '```'

# ═══════════ 2. 当てた後 ═══════════
echo
echo "## 2. 当てた後（**実物**）"
echo
echo '```javascript'
if [ -f "$TG" ]; then
  N="$(grep -n 'BOOT_GRACE' "$TG" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -n "$N" ]; then
    awk -v s="$((N - 4))" -v e="$((N + 18))" 'NR>=s && NR<=e {printf("%4d| %s\n", NR, $0)}' "$TG" \
      | cut -c1-190 | clean
  fi
  echo
  echo "// --- 保存の行 ---"
  grep -n -A 8 'reachable: now.reachable' "$TG" 2>/dev/null | head -10 | cut -c1-190
  echo
  echo "// --- 呼び出し側 ---"
  grep -n 'r && r.halted' "$TG" 2>/dev/null | cut -c1-190
fi
echo '```'

# ═══════════ 3. 載せ直して確かめる ═══════════
echo
echo "## 3. 載せ直して、落ちなくなったかを見る"
echo
echo '```'
LABEL="ai.openclaw.tab-guard"
if [ -f "$TG" ] && grep -q 'BOOT_GRACE' "$TG" 2>/dev/null; then
  launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
  sleep 1
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$LABEL.plist" 2>&1 | head -2 | sed 's/^/  /'
  echo "  載せ直した。**30 秒 待って、落ちていないかを見る**"
  BEFORE="$(wc -c < "$L/tab-guard-err.log" 2>/dev/null || echo 0)"
  sleep 30
  AFTER="$(wc -c < "$L/tab-guard-err.log" 2>/dev/null || echo 0)"
  echo "  エラーログ: $BEFORE → $AFTER bytes（差 $((AFTER - BEFORE))）"
  if [ "$AFTER" -eq "$BEFORE" ]; then
    echo "  → **30 秒 間 エラーが増えていない。落ちていない。**"
  else
    echo "  → **まだ落ちている。** 直近のエラー:"
    tail -6 "$L/tab-guard-err.log" 2>/dev/null | cut -c1-170 | sed 's/^/      /' | clean
  fi
  echo
  launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {print "  PID=" $1 "  最後の終了コード=" $2}'
  echo
  echo "  --- 状態ファイル（reachable が入ったか） ---"
  cat "$D/tab-guard-state.json" 2>/dev/null | sed 's/^/    /'
else
  echo "  当たっていないので載せ直さない。"
fi
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**判定条件を直すだけ。LLM を呼ばない。ループを載せ直さない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44"
echo "（\`MAX_PICKS\` は 4 のまま）。フォロー・アンフォロー系は \$0（DOM 操作のみ）。"
} > "$OUT" 2>&1

echo "tab-guard の修正 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
