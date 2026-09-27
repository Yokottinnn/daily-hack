#!/bin/bash
# **なぜ外さないのかを読む。＋ 1 日のフォロー数とアンフォロー数を数える。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# `x160` で分かったこと。
#
#   プロフィール          following 251 / followers 288
#   フォロー側            competitor-follower-follow・hashtag-follow が **載っている**（今日も稼働）
#   アンフォロー側        9 本中 **6 本が載っていない**（ログは 8 月 止まり）
#   載っている 2 本       mutual-prune・reply-followers-cleanup（今日 05:01 / 05:11 に稼働）
#
# **だが、その 2 本がほとんど外していない。**
#
#   {"total_candidates":19,"unfollowed":[],"ghosts":[... 19 件 ...]}
#   {"total_candidates":3, "unfollowed":[],"cancelled":[... 3 件 ...]}
#
# **19 件を「ゴースト」と判定しておきながら 1 件も外していない。**
# **なぜかを読まずに直すと、同じことを繰り返す。**
#
# ## 何を出すか
#
#   ① `mutual-prune.js` の**判定と実行の部分を通しで**（ここに答えが在る）
#   ② `reply-followers-cleanup` の**ゴーストの扱い**（検知だけなのか、外すのか）
#   ③ **今日フォローした数 / 今日アンフォローした数**（収支そのもの）
#   ④ フォロー側の plist が**1 日 何回 撃つか**（追いつくべき量が決まる）
#
# ## やらないこと
#
# **フォローしない。アンフォローしない。設定も変えない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/prune-decision.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

{
echo "# なぜ外さないのか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** フォローもアンフォローもしていない。"

echo
echo "## 1. 今日の収支（**これが問題そのもの**）"
echo
echo '```'
node -e '
  const fs = require("fs");
  const [fp] = process.argv.slice(1);
  const jstDay = (iso) => {
    const t = new Date(iso); if (isNaN(t)) return null;
    const j = new Date(t.getTime() + 9 * 3600 * 1000);
    return j.toISOString().slice(0, 10);
  };
  const today = jstDay(new Date().toISOString());
  let j; try { j = JSON.parse(fs.readFileSync(fp, "utf8")); } catch (e) { console.log("  followed.json が読めない: " + e.message); process.exit(0); }
  const arr = Array.isArray(j) ? j : Object.values(j);
  const rows = arr.filter((x) => x && x.followed_at);
  const byDay = new Map();
  for (const r of rows) { const d = jstDay(r.followed_at); if (d) byDay.set(d, (byDay.get(d) || 0) + 1); }
  const days = [...byDay.keys()].sort().slice(-10);
  console.log("  followed.json の件数: " + rows.length + "（今日 = " + today + " JST）");
  console.log("");
  console.log("  日付         フォローした数");
  for (const d of days) console.log("  " + d + "   " + String(byDay.get(d)).padStart(4) + (d === today ? "   ← 今日" : ""));
' "$D/followed.json" 2>&1 | clean
echo
echo "  --- 今日アンフォローした数（ログの unfollowed 配列を数える）---"
for n in mutual-prune reply-followers-cleanup; do
  f="$L/$n.log"
  [ -f "$f" ] || { printf '  %-26s **ログが無い**\n' "$n"; continue; }
  c="$(node -e '
    const fs=require("fs");
    const lines=fs.readFileSync(process.argv[1],"utf8").split("\n");
    let n=0, runs=0;
    for(const l of lines){
      const i=l.indexOf("{\"ok\"");
      if(i<0) continue;
      try{ const o=JSON.parse(l.slice(i)); if(Array.isArray(o.unfollowed)){ runs++; n+=o.unfollowed.length; } }catch{}
    }
    console.log(runs+" 回の結果行 / 外した合計 "+n+" 件（ログ全体）");
  ' "$f" 2>/dev/null)"
  printf '  %-26s %s\n' "$n" "${c:-読めない}"
done
echo '```'
echo
echo "> **「ログ全体」であって今日ぶんではない。** それでも、フォロー側の 1 日ぶんと比べれば桁が分かる。"

echo
echo "## 2. フォロー側は 1 日 何回 撃つか"
echo
echo '```'
for lb in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  p="$LA/$lb.plist"
  [ -f "$p" ] || { printf '  %-42s **plist が無い**\n' "$lb"; continue; }
  echo "  === $lb ==="
  /usr/libexec/PlistBuddy -c "Print :StartCalendarInterval" "$p" 2>/dev/null | sed 's/^/    /'
  /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$p" 2>/dev/null | sed 's/^/    /'
  echo
done
echo '```'

echo
echo "## 3. \`mutual-prune.js\` の判定と実行（**ここに答えが在る**）"
echo
echo '```javascript'
if [ -f "$S/mutual-prune.js" ]; then
  sed -n '120,314p' "$S/mutual-prune.js" 2>/dev/null | cat -n | sed 's/^/  /' | cut -c1-220 | clean
else
  echo "  **mutual-prune.js が無い**"
fi
echo '```'

echo
echo "## 4. ゴーストは誰が外すのか"
echo
echo "**19 件を検知して 0 件しか外していない。** どこで止まっているかを見る。"
echo
echo '```'
echo "  --- ghost / ghosts を扱っているスクリプト ---"
grep -l -E '"ghosts?"|ghosts\b' "$S"/*.js 2>/dev/null | sed 's|.*/|  |' || echo "  （無い）"
echo '```'
echo
for f in "$S/reply-followers-cleanup.js" "$S/reply-followers.js"; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\` の ghost まわり"
  echo
  echo '```javascript'
  grep -n -B3 -A12 -E 'ghosts?' "$f" 2>/dev/null | head -60 | cut -c1-220 | clean | sed 's/^/  /'
  echo '```'
  echo
done

echo
echo "## 5. 守る側の材料"
echo
echo "**「反応をくれた人」と「フォローから 7 日未満」だけを守る**と決まった（2026-09-27）。"
echo "その 2 つが judgable かを見る。"
echo
echo '```'
node -e '
  const fs = require("fs");
  try {
    const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const arr = Array.isArray(j) ? j : Object.values(j);
    console.log("  reply-followers.json の件数: " + arr.length);
    const s = arr.find((x) => x && typeof x === "object");
    if (s) for (const k of Object.keys(s).slice(0, 16)) {
      let v = s[k]; if (typeof v === "object") v = JSON.stringify(v).slice(0, 50);
      console.log("  " + String(k).padEnd(22) + " " + String(v).slice(0, 60));
    }
  } catch (e) { console.log("  読めない: " + e.message); }
' "$D/reply-followers.json" 2>&1 | clean
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| §3 に \`MAXN\` や比率の門が在り、そこで落ちている | **上限を上げる**か、**門を緩める** |"
echo "| ゴーストを外す口がどこにも無い | **外す側を足す**（検知だけで終わっている） |"
echo "| §1 でフォローが 1 日 数十件 | **同じ数だけ外す仕掛け**が要る |"
echo "| §5 に反応の記録が在る | **守る側の判定に使える** |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'mutual-prune.js の判定' "$OUT" 2>/dev/null; then
  echo "外さない理由と収支を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
