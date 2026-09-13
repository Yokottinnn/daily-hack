#!/bin/bash
# **フォローの上限・x64 の書き込み・入口却下の内訳を読む。測るだけ。費用 $0。**
#
# ## 3 つまとめて読む（**どれも読むだけ。数秒 で終わる**）
#
# ### 1. x64 は本当に書いたか（**ルール 13: rc=0 は証拠にならない**）
#
# x64 は「置き換えた」とレポートに書いた。**だが書けたかどうかは、
# 次にフォローが走って `followers_at_follow` に数字が入って初めて分かる。**
# `reply-followers.json` を読んで確かめる。
#
# ### 2. 返しの悪い供給元を削るための、いまの上限
#
#   competitor-follower  168 件 フォローして 返し 11.9%   ← 返りが悪いのに いちばん多い
#   comment-orchestrator 135 件 フォローして 返し 21.5%   ← 約 2 倍 返る
#   hashtag-follow        39 件 フォローして 返し 15.4%
#
# **上限がいくつで、どの間隔で回っているのかを実物で読む。** 推測で下げない。
#
# ### 3. 候補の広告率
#
# 今日は picked 16 件 のうち **7 件（44%）が広告投稿で入口却下**だった。
# 却下自体は正しい（$0）が、**picked の枠を無駄にしている。**
# `trend-detect` が拾ってきた候補のうち、どれくらいが広告なのかを数える。
#
# ## やらないこと
#
# **上限を変えない。フォローしない。設定を書き換えない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（ファイルを読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/caps-and-verify-x64.md"
NODE_BIN="/usr/local/bin/node"
RF="$D/reply-followers.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# フォローの上限 ＋ x64 の書き込み確認 ＋ 入口却下の内訳"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **rc=0 は「やった」証拠にならない**（ルール 13）。"
echo "> x64 は「置き換えた」と書いたが、**数字が入るのは次にフォローが走ってから。**"
echo
echo "**測るだけ。上限は触らない。**"

# ═══════════ 1. x64 は本当に書いたか ═══════════
echo
echo "## 1. x64 の書き込み確認（**結果の状態を別の口で見る**）"
echo
echo '```'
for f in competitor-follower-follow.js hashtag-follow.js; do
  P="$S/$f"; [ -f "$P" ] || { echo "  $f: **無い**"; continue; }
  n="$(grep -c 'followers_at_follow' "$P" 2>/dev/null || echo 0)"
  printf '  %-32s コード内の印: %s 箇所 / 最終更新 %s\n' "$f" "$n" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
echo "  --- 退避（戻せる状態か） ---"
ls -1t "$S"/*.bak-* 2>/dev/null | head -4 | sed "s#^$S/#    #"
echo
echo "  --- 実際に数字が入ったか（reply-followers.json） ---"
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows=Object.entries(j).map(([k,v])=>(v&&typeof v==="object"?{handle:k,...v}:{handle:k}));
const has=rows.filter(r=>r.followers_at_follow !== undefined);
console.log("    全体: "+rows.length+" 件 / followers_at_follow を持つ: **"+has.length+" 件**");
if (has.length) {
  const s=has.slice(-5).map(r=>({at:(r.followed_at||"").slice(0,16),f:r.followers_at_follow,g:r.following_at_follow,src:(r.source||"").split(":")[0]}));
  for (const x of s) console.log("      "+x.at+"  followers="+x.f+"  following="+x.g+"  ["+x.src+"]");
} else {
  console.log("    → **まだ 0 件。** x64 を当てた後にフォローが走っていない");
}
const today=new Date().toISOString().slice(0,10);
const t=rows.filter(r=>(r.followed_at||"").startsWith(today));
console.log("");
console.log("    今日フォローした件数: "+t.length+" 件");
' "$RF" 2>&1 | clean
else
  echo "    **$RF が無い。**"
fi
echo '```'
echo
echo "**0 件 でも失敗とは限らない。** 次にフォローが走るまで入らない。"
echo "**下の「いつ回るか」と突き合わせて判断する。**"

# ═══════════ 2. フォローの上限と間隔 ═══════════
echo
echo "## 2. いまの上限と間隔（**実物**）"
echo
echo '```'
for f in competitor-follower-follow.js hashtag-follow.js comment-orchestrator.sh; do
  P="$S/$f"; [ -f "$P" ] || { echo "  $f: **無い**"; continue; }
  echo "  ══ $f"
  grep -nE 'DAILY_CAP|CAP|MAX_|LIMIT|reply_follow_cap|REPLY_FOLLOW|PICKS|FOLLOW_GAP_MS|COMPETITORS *=|skip policy|Dow' "$P" 2>/dev/null \
    | head -12 | cut -c1-190 | sed 's/^/    /' | clean
  echo
done
echo "  --- 直近の実行（ログの最終行） ---"
for f in competitor-follower-follow.log hashtag-follow.log comment-orchestrator.log; do
  P="$L/$f"; [ -f "$P" ] || continue
  printf '    %-34s %s\n' "$f" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)"
  tail -3 "$P" 2>/dev/null | cut -c1-170 | sed 's/^/      /' | clean
  echo
done
echo "  --- plist の間隔 ---"
for lbl in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow ai.openclaw.comment-warmup; do
  P="$LA/$lbl.plist"; [ -f "$P" ] || { echo "    $lbl: **plist が無い**"; continue; }
  echo "    ══ $lbl"
  grep -A3 -E 'StartInterval|StartCalendarInterval|Hour|Minute' "$P" 2>/dev/null \
    | grep -oE '<key>[A-Za-z]+</key>|<integer>[0-9]+</integer>' | tr '\n' ' ' | sed 's/^/      /'
  echo
done
echo '```'

# ═══════════ 3. 候補の広告率 ═══════════
echo
echo "## 3. 候補のうち どれくらいが広告か（**picked の枠を無駄にしている分**）"
echo
echo '```'
CW="$L/comment-warmup.log"
if [ -f "$CW" ]; then
  echo "  --- 日ごとの入口却下（LLM を呼ぶ前に落ちた数） ---"
  awk '
    match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { d = substr($0, RSTART, RLENGTH) }
    d == "" { next }
    match($0, /picked [0-9]+/) { p = substr($0, RSTART + 7, RLENGTH - 7); pick[d] += p + 0 }
    /LLM を呼ばずに見送る/     { ad[d]++ }
    /生成側が skip/            { off[d]++ }
    /enqueue/                  { enq[d]++ }
    { seen[d] = 1 }
    END {
      n = 0
      for (k in seen) ks[n++] = k
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (ks[i] > ks[j]) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
      st = (n > 8 ? n - 8 : 0)
      printf("    %-12s %7s %7s %7s %7s\n", "日付", "picked", "広告", "話題外", "enq")
      for (i = st; i < n; i++) {
        k = ks[i]
        printf("    %-12s %7d %7d %7d %7d\n", k, pick[k], ad[k], off[k], enq[k])
      }
    }
  ' "$CW" 2>/dev/null | clean
  echo
  echo "  --- 入口で落ちた理由に出てきた語（上位 15） ---"
  grep -oE 'LLM を呼ばずに見送る: [^"]{1,80}' "$CW" 2>/dev/null \
    | sed 's/LLM を呼ばずに見送る: //' | tr '/' '\n' | sed 's/^ *//; s/ *$//' \
    | grep -v '^$' | sort | uniq -c | sort -rn | head -15 | sed 's/^/    /' | clean
else
  echo "  **$CW が無い。**"
fi
echo '```'
echo
echo "**この語の一覧が、いま何を掴んでいるかの実物。**"
echo "**探す段階（\`trend-detect\`）で落とせるものが在るかを、ここから決める。**"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**ファイルを読むだけ。LLM を呼ばない。ブラウザも触らない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの**実績**（2026-09-13・\`docs/recurring-job-costs.md\`）:"
echo "1 回 \$0.003 ／ 1 日 **\$0.027**（生成 9 件）／ 1 か月 **約 \$0.81**。"
echo "上限に張り付いた場合は 1 日 \$0.048 ／ 1 か月 \$1.44 だが、**これは安全弁であって予想ではない。**"
} > "$OUT" 2>&1

echo "上限と x64 の確認 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
