#!/bin/bash
# **follow-balance.js を丸ごと書き出す（直す前に、いま入っている本物を読む）。読むだけ。費用 $0。**
#
# ## 指示（2026-10-04）
#
#   > 「外されたら外し返す見張りを作る」「期日を過ぎた 370 件を外す流れに入れる」
#
# 2 つとも follow-balance.js の中を変える。x163 以降 8 回 当て直しているので、
# リポジトリの元の版から推測せず、**Mac に入っている実物を読んでから**直す（最上位ルール 20）。
#
#   ① follow-balance.js の全文（他人のハンドルは伏せる）
#   ② follow-balance-lists.json の形（キー・件数・書いた時刻）
#   ③ reply-followers.json の 1 件の形（キーだけ）と、status=no・期日超えの件数
#
# **外さない。フォローしない。設定を変えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
F="$W/scripts/follow-balance.js"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/dump-follow-balance.md"
mask() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }

{
echo "# follow-balance.js の実物（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## ① 全文（$(wc -l < "$F" | tr -d ' ') 行・更新 $(stat -f '%Sm' -t '%m/%d %H:%M' "$F")）"
echo
echo '```javascript'
awk '{ printf "%4d  %s\n", NR, $0 }' "$F" | mask
echo '```'
echo
echo "## ② follow-balance-lists.json の形"
echo
echo '```'
node -e '
  const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  for (const [k, v] of Object.entries(j)) console.log("  " + k + ": " + (Array.isArray(v) ? "[配列 " + v.length + " 件]" : (v && typeof v === "object") ? "{" + Object.keys(v).length + " キー}" : String(v).slice(0, 60)));
' "$D/follow-balance-lists.json" 2>&1
ls -la "$D"/follow-balance* 2>/dev/null | awk '{print "  " $5 " bytes  " $6 " " $7 " " $8 "  " $9}' | sed "s#$D/##"
echo '```'
echo
echo "## ③ reply-followers.json の形"
echo
echo '```'
node -e '
  const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const vals = Object.values(j); const keys = {};
  for (const v of vals) if (v && typeof v === "object") for (const k of Object.keys(v)) keys[k] = (keys[k] || 0) + 1;
  console.log("  トップ: " + (Array.isArray(j) ? "配列" : "オブジェクト（キー＝ハンドル）") + " ／ " + vals.length + " 件");
  console.log("  中のキー: " + Object.entries(keys).map(([k, n]) => k + "(" + n + ")").join(", "));
  const now = Date.now(); let no = 0, due = 0, dueGraceOk = 0;
  for (const v of vals) { if (!v || v.followback_status !== "no") continue; no++;
    if (v.scheduled_unfollow_at && new Date(v.scheduled_unfollow_at).getTime() < now) due++; }
  console.log("  status=no " + no + " 件 ／ うち外す予定日を過ぎた " + due + " 件");
' "$D/reply-followers.json" 2>&1
echo '```'
echo
echo "**外していない。フォローしていない。設定を変えていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -aq '## ③' "$OUT"; then echo "follow-balance.js を書き出した / $(basename "$OUT")"; else echo "**書き出せていない** / $(basename "$OUT")"; fi
