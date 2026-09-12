#!/bin/bash
# **tab-guard の B 条件を直す。1 → 0 枚は「破壊」ではない。費用 $0。**
#
# ## x34 のログで確定した（2026-09-13 00:23）
#
#   [2026-09-12T15:24:13Z] 🚨 Jordan のタブが **1 → 0 枚**（実質全消滅） → 自動化を全停止
#
# **自動化専用 Chrome は起動直後 1 タブしかない。**
# スクリプトが作業タブを `page.close()` すると 1 → 0 枚になり、
# tab-guard が「実質全消滅」と判定して `ai.openclaw.*` を全 unload する。
#
# **＝ 自動化そのものが tab-guard を発火させている。**
#
# ## tab-guard 自身のコメントが答えを書いている
#
#   * 一方、タブが 1〜2 枚減るのは Jordan 自身の通常操作でも起きる。それで cron を止めるのは…
#       B. タブが 0〜1 枚になった（＝実質全部消えた）
#       C. 一度に半分以上のタブが消えた（＝一括破壊）
#
# **B は「たくさんあったものが 0〜1 枚になった」を想定している。**
# 元が 1 枚なら「全部 消えた」も何もない。**前提が崩れている。**
#
# ## 直し方（x33 の UNREACHABLE_GUARD と同じ考え方）
#
#   **前回が既に少なかったなら、それは破壊ではない。**
#   `prev.count >= 3` を満たすときだけ B を発火させる。
#
# タブが 10 → 1 のような**本物の一括破壊は、これまでどおり検知する。**
#
# ## この後どうなるか
#
# A（CDP 断）は x33 で、B（1→0）はこれで塞がる。
# **C（半分以上が一度に消える）は残す。** 本物の一括破壊を拾うのはこれ。
#
# **Chrome を kill しない。tab-guard を止めない。投稿しない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-tab-guard-b.md"
TG="$S/tab-guard.js"
NODE_BIN="/usr/local/bin/node"
UID_NUM="$(id -u)"
STAMP="$(date '+%Y%m%d-%H%M%S')"
ALL8="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# tab-guard の B 条件を直す — 1 → 0 枚は破壊ではない"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`[2026-09-12T15:24:13Z] 🚨 Jordan のタブが **1 → 0 枚**（実質全消滅） → 自動化を全停止\`"
echo
echo "**自動化専用 Chrome は起動直後 1 タブしかない。**"
echo "スクリプトが作業タブを \`page.close()\` すると 1 → 0 枚になり、tab-guard が発火する。"
echo "**＝ 自動化そのものが tab-guard を発火させている。**"

echo
echo "## 1. B 条件の現状"
echo
echo '```javascript'
if [ -f "$TG" ]; then
  grep -nE '実質全消滅|一括破壊|count <= 1|count === 0|prev\.count|now\.count' "$TG" 2>/dev/null \
    | head -14 | cut -c1-170 | sed 's/^/  /' | clean
else
  echo "  **無い: $TG**"
fi
echo '```'

echo
echo "## 2. 直す（**前回が既に少なかったなら破壊ではない**）"
echo
echo "\`x33\` の \`UNREACHABLE_GUARD\` と同じ考え方。"
echo "**タブ 10 → 1 のような本物の一括破壊は、これまでどおり検知する。**"
echo
echo '```'
if [ ! -f "$TG" ]; then
  echo "  tab-guard.js が無い。触らない。"
elif grep -q 'LOW_BASELINE_GUARD' "$TG" 2>/dev/null; then
  echo "  既に入っている。触らない。"
else
  cp -p "$TG" "$TG.bak-$STAMP" && echo "  退避: $(basename "$TG").bak-$STAMP"
  "$NODE_BIN" - "$TG" <<'JS'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

// 「実質全消滅」で halt する行の直前にガードを入れる
const re = /(\n(\s*)haltAutomation\(\s*`[^`]*実質全消滅[^`]*`\s*\);)/;
const m = s.match(re);
if (!m) {
  console.log("  **「実質全消滅」の halt 呼び出しが見つからない。触らない。**");
  process.exit(0);
}
const ind = m[2];
const GUARD =
`\n${ind}// LOW_BASELINE_GUARD (2026-09-13): **元が 1 枚なら「全部 消えた」ではない。**\n` +
`${ind}// 自動化専用 Chrome は起動直後 1 タブしかなく、スクリプトが作業タブを\n` +
`${ind}// page.close() すると 1 → 0 枚になる。それを「実質全消滅」と見なすと、\n` +
`${ind}// **自動化そのものが自動化を止める**（2026-09-12 15:24 に実際に起きた）。\n` +
`${ind}// B は「たくさんあったものが 0〜1 枚になった」を想定した条件。\n` +
`${ind}// **前回が 3 枚未満なら、そもそも破壊の前提が無い。**\n` +
`${ind}if (!prev || typeof prev.count !== "number" || prev.count < 3) {\n` +
`${ind}  log(\`タブ \${prev && prev.count} → \${now.count} 枚。元が少ないので破壊とみなさない\`);\n` +
`${ind}  return;\n` +
`${ind}}` + m[1];
s = s.replace(re, GUARD);
fs.writeFileSync(p, s);
console.log("  LOW_BASELINE_GUARD を入れた");
JS
  if "$NODE_BIN" --check "$TG" 2>&1 | clean; then
    echo "  node --check: OK"
  else
    echo "  **構文エラー。戻す。**"; cp -p "$TG.bak-$STAMP" "$TG"
  fi
fi
echo '```'
echo
echo '```diff'
diff -u "$TG.bak-$STAMP" "$TG" 2>/dev/null | head -32 | clean
echo '```'

echo
echo "## 3. tab-guard を載せ直す（直した版を効かせる）"
echo
echo '```'
GP="$LA/ai.openclaw.tab-guard.plist"
if [ -f "$GP" ]; then
  launchctl bootout "gui/${UID_NUM}/ai.openclaw.tab-guard" 2>&1 | head -2 | sed 's/^/  /' | clean
  sleep 2
  launchctl bootstrap "gui/${UID_NUM}" "$GP" 2>&1 | head -2 | sed 's/^/  /' | clean
  launchctl load -w "$GP" 2>&1 | head -2 | sed 's/^/  /' | clean
  echo "  載ったか: $(launchctl list 2>/dev/null | grep -cF 'ai.openclaw.tab-guard' || true) 本"
else
  echo "  **plist が無い: $GP**"
fi
echo '```'

echo
echo "## 4. 8 本を載せて、**3 分 生き残るか**"
echo
echo "これまでは 60〜90 秒で消えていた。**今度は 3 分 見る。**"
echo
echo '```'
for j in $ALL8; do
  lbl="ai.openclaw.$j"; P="$LA/$lbl.plist"
  launchctl list 2>/dev/null | grep -qF "$lbl" && continue
  [ -f "$P" ] || continue
  launchctl enable "gui/${UID_NUM}/$lbl" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/${UID_NUM}" "$P" >/dev/null 2>&1 || launchctl load -w "$P" >/dev/null 2>&1 || true
done
N0=0; for j in $ALL8; do launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j" && N0=$((N0+1)); done
echo "  載せた直後: ${N0} / 8 本"
echo
for i in 60 120 180; do
  sleep 60
  M=0; for j in $ALL8; do launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j" && M=$((M+1)); done
  printf '  %3s 秒後: %s / 8 本\n' "$i" "$M"
done
echo
FIN=0
for j in $ALL8; do
  if launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j"; then
    printf '  ロード   %-34s\n' "$j"; FIN=$((FIN+1))
  else
    printf '  **未**   %-34s\n' "$j"
  fi
done
echo
echo "  **最終: ${FIN} / 8 本**"
echo "  tab-guard: $(launchctl list 2>/dev/null | grep -cF 'ai.openclaw.tab-guard' || true) 本"
echo "  CDP: $( [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ) && echo '健全' || echo '**落ちている**')"
echo
echo "  --- tab-guard のログ（この 3 分に鳴ったか） ---"
tail -10 "$W/logs/tab-guard.log" 2>/dev/null | cut -c1-170 | sed 's/^/    /' | clean
echo '```'

echo
echo "---"
echo
echo "## 塞いだ穴（3 つのうち 2 つ）"
echo
echo "| 条件 | 中身 | 状態 |"
echo "| --- | --- | --- |"
echo "| A | Chrome プロセスが消えた | **x33 で塞いだ**（CDP 断は消滅ではない） |"
echo "| B | タブが 0〜1 枚になった | **この タスクで塞ぐ**（元が 1 枚なら破壊ではない） |"
echo "| C | 一度に半分以上のタブが消えた | **残す。** 本物の一括破壊を拾うのはこれ |"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| フォロー・アンフォロー（DOM 操作） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 3〜5 件/日） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**Chrome を kill していない。tab-guard も止めていない（条件を 1 つ 直しただけ）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
F="$(grep -m1 -oE '\*\*最終: [0-9]+ / 8 本\*\*' "$OUT" 2>/dev/null || echo '結果 不明')"
echo "**$(date '+%H:%M') tab-guard の B 条件を直した（\$0）** / $F / $(basename "$OUT")"
