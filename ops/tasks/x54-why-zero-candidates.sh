#!/bin/bash
# **`trend-detect` が候補を 0 件 しか返さない理由を切り分ける。測るだけ。費用 $0。**
#
# ## これが返信の真因（2026-09-13 10:44 に実測）
#
#   {"ok":true,"count":0,"candidates":[]}
#   [2026-09-13T10:44:20] no candidates
#   走らせる前: 859 件 → 後: 859 件   **今回 出た数: 0 件**
#
# **`ok:true` で 0 件。** エラーではなく「探したが無かった」と言っている。
# 修理（x43）も禁止リスト（x44）も、**候補が無ければ出番が来ない。**
#
# ## 切り分ける順番（**直さない。どこで 0 になるかを見るだけ**）
#
#   1. 何を検索しているのか（検索語・ハッシュタグ・対象アカウント）
#   2. その検索語で X が実際に何件 返すのか（**生の件数**）
#   3. 除外（NG フィルタ・cooldown・既返信）で何件 落ちるのか
#   4. どの段階で 0 になるのか
#
# **「検索語が古い」「DOM が変わった」「除外が厳しすぎる」のどれかを確定させる。**
# 推測で緩めない。
#
# ## ルール 15 を守る
#
# **このタスクは測るだけ。5 分 以内で終わる。** 直す側は結果を見てから別タスクにする。
# `x50` は 5 つの仕事を 1 本に詰めて 15 分 かかり、heartbeat を 49 分 止めた。
#
# ## やらないこと
#
# **投稿しない。フォローしない。設定を書き換えない。LLM を呼ばない（$0）。**
# **`timeout` を使わない**（macOS に無い・ルール 14）。一時ファイルは `.js` のまま。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/why-zero-candidates.md"
NODE_BIN="/usr/local/bin/node"
TD="$S/trend-detect.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

# timeout を使わない打ち切り（ルール 14）
descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

{
echo "# \`trend-detect\` が 0 件 になる段階を切り分ける"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`{\"ok\":true,\"count\":0,\"candidates\":[]}\`"
echo ">"
echo "> **\`ok:true\` で 0 件。** エラーではなく「探したが無かった」と言っている。"
echo "> 修理も禁止リストも、**候補が無ければ出番が来ない。**"
echo
echo "**測るだけ。直さない。**"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
[ -f /tmp/x-login-in-progress ] && echo "  login ロック: **在る**" || echo "  login ロック: 無い"
[ -f "$TD" ] && echo "  trend-detect.js: 在る（$(wc -l < "$TD" | tr -d ' ') 行）" || echo "  trend-detect.js: **無い**"
echo '```'

# ═══════════ 1. 何を検索しているのか ═══════════
echo
echo "## 1. 何を検索しているのか（**設定の実物**）"
echo
echo '```'
if [ ! -f "$TD" ]; then
  echo "  **$TD が無い。**"
else
  echo "  --- 検索語・URL の組み立て ---"
  grep -nE 'search\?q=|/search|query|keyword|hashtag|SEARCH|QUERIES' "$TD" 2>/dev/null \
    | head -18 | cut -c1-220 | sed 's/^/    /' | clean
  echo
  echo "  --- 読み込んでいる設定ファイル ---"
  grep -noE '[A-Za-z0-9_.-]+\.json' "$TD" 2>/dev/null | awk -F: '{print $2}' | sort -u | sed 's/^/    /'
  echo
  echo "  --- 除外・フィルタの条件 ---"
  grep -nE 'skip|filter|exclude|cooldown|already|除外|見送' "$TD" 2>/dev/null \
    | head -14 | cut -c1-200 | sed 's/^/    /' | clean
fi
echo '```'
echo
echo '```'
echo "  --- 検索語の設定ファイルの中身と更新日 ---"
for f in trend-keywords.json search-queries.json hashtags.json trend-config.json \
         comment-targets.json quick-reply-targets.json target-config.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  printf '  %-26s 最終更新 %s\n' "$f" "$(stat -f '%Y-%m-%d %H:%M' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null || stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  head -c 500 "$P" 2>/dev/null | sed 's/^/    /' | clean
  echo
done
echo
echo "  --- data/ にある trend / search / keyword 系 ---"
ls -1 "$D" 2>/dev/null | grep -iE 'trend|search|keyword|query|candidate' | head -12 | sed 's/^/    /'
echo '```'

# ═══════════ 2. 実際に走らせて、途中経過を見る ═══════════
echo
echo "## 2. 走らせて、途中経過を全部 出す（**最大 4 分**）"
echo
echo "前回は最後の 1 行しか見ていなかった。**全部 出す。**"
echo
echo '```'
if [ ! -f "$TD" ]; then
  echo "  走らせられない。"
elif ! cdp_ok; then
  echo "  CDP が落ちている。走らせない。"
else
  R="${TMPDIR:-/tmp}/td54.$$"
  ( cd "$W" && DEBUG=1 VERBOSE=1 run_limited 240 "$R" "$NODE_BIN" "$TD" ) || true
  rc=$?
  echo "  --- 出力 全文（先頭 60 行） ---"
  head -60 "$R" 2>/dev/null | cut -c1-260 | sed 's/^/    /' | clean
  echo
  echo "  --- 出力 末尾 20 行 ---"
  tail -20 "$R" 2>/dev/null | cut -c1-260 | sed 's/^/    /' | clean
  [ "$rc" = "124" ] && echo "  **4 分 で打ち切った。**"
  echo
  echo "  --- 件数らしき行だけ ---"
  grep -aiE 'count|件|found|scraped|candidate|hit|result|0 ' "$R" 2>/dev/null \
    | head -20 | cut -c1-220 | sed 's/^/    /' | clean
  rm -f "$R"
fi
echo '```'

# ═══════════ 3. ログの履歴 ═══════════
echo
echo "## 3. いつから 0 件 になったのか"
echo
echo "**前は候補が取れていた。** x41（02:14）では \`from 2 candidates\`、"
echo "9/09 には \`from 15 candidates\` だった。**減り方を見る。**"
echo
echo '```'
for L in trend-detect comment-warmup; do
  F="$W/logs/$L.log"
  [ -f "$F" ] || { printf '  %-20s ログ無し\n' "$L"; continue; }
  echo "  [$L] 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$F" 2>/dev/null)"
  echo "    --- 候補の件数が出ている行（直近 20 件） ---"
  grep -aoE '(from [0-9]+ candidates|"count":[0-9]+|no candidates|picked [0-9]+ / max [0-9]+)' "$F" 2>/dev/null \
    | tail -20 | sed 's/^/      /'
  echo
done
echo '```'

# ═══════════ 4. 候補プールのファイル ═══════════
echo
echo "## 4. 候補プールの実体"
echo
echo '```'
FOUND=0
for f in trend-candidates.json comment-candidates.json candidates.json trend-state.json \
         comment-state.json replied.json reply-cooldown.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  FOUND=1
  CNT="$("$NODE_BIN" -e '
const fs=require("fs");
try{ const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(Array.isArray(d)) console.log(d.length);
  else if(d&&typeof d==="object"){const a=Object.values(d).find(v=>Array.isArray(v));console.log(a?a.length:Object.keys(d).length);}
  else console.log("?");
}catch(e){ console.log("読めない"); }' "$P" 2>/dev/null)"
  printf '  %-26s %6s 件 / 最終更新 %s\n' "$f" "$CNT" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
[ "$FOUND" = "0" ] && echo "  **候補プールらしきファイルが 1 つも無い。**"
echo
echo "  --- 直近 1 時間 に更新された data/ のファイル ---"
find "$D" -maxdepth 1 -type f -newermt '-60M' 2>/dev/null | head -12 | sed 's|.*/|    |'
echo '```'

# ═══════════ 5. 判定の指針 ═══════════
echo
echo "## 5. 読み方"
echo
echo "| §2 の出力 | 意味 | 直す場所 |"
echo "| --- | --- | --- |"
echo "| 検索ページを開けているが**ヒット 0** | **検索語が古い／狭い** | 検索語の設定 |"
echo "| 検索ページの**DOM が読めない**（scraped 0） | **セレクタが古い** | \`trend-detect.js\` |"
echo "| 生は取れているが**除外で全滅** | **フィルタが厳しすぎる** | NG ルール・cooldown |"
echo "| ログインに落ちている | **認証** | 再ログイン |"
echo
echo "**どれか 1 つに絞れてから直す。** 推測で緩めない。"
echo
echo "## 6. 費用"
echo
echo "**LLM を一切 呼ばない。DOM を読むだけ。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "定時の返信ループは **推定** 1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8"
echo "（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。**候補が 0 件 の間は実額 \$0。**"
} > "$OUT" 2>&1

echo "候補 0 件 の切り分け / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
