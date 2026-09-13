#!/bin/bash
# **ハッシュタグ側が 2 件 しか試せない理由を読む。測るだけ。費用 $0。**
#
# ## なぜ（x65 の実測）
#
#   HASHTAG_FOLLOW_DAILY_CAP=90   ← 上限は 90
#   2026-09-13 の結果: **1/2 OK**  ← **2 件 しか試していない**
#
# **上限では止まっていない。候補が来ていない。** 90 に対して 2 件 は 2%。
#
# 競合刈り取りは 30 件 試して 1 件 通過（フィルタが厳しい）。
# ハッシュタグ側は **そもそも 2 件 しか集まっていない**ので、質の前に量の問題。
#
# ## 読むところ（**直さない**）
#
#   1. どのタグを見ているか（設定の実物）
#   2. 1 回の実行で何件 集まっているか（ログの推移）
#   3. どこで減っているか（scrape → フィルタ → picks）
#   4. `trend-detect` と同じタグを見ているのか（重複していないか）
#
# **広げるのは、どこで減っているか分かってから。** 推測でタグを足さない。
#
# ## やらないこと
#
# **タグを足さない。上限を変えない。フォローしない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（ファイルを読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/hashtag-supply.md"
NODE_BIN="/usr/local/bin/node"
HF="$S/hashtag-follow.js"
TD="$S/trend-detect.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# ハッシュタグ側が 2 件 しか試せない理由"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`HASHTAG_FOLLOW_DAILY_CAP=90\` なのに、2026-09-13 の結果は **1/2 OK**。"
echo "> **上限では止まっていない。候補が来ていない。**"
echo
echo "**測るだけ。タグを足さない。**"

# ═══════════ 1. どのタグを見ているか ═══════════
echo
echo "## 1. 見ているタグ（**設定の実物**）"
echo
echo '```'
if [ ! -f "$HF" ]; then
  echo "  **$HF が無い。**"
else
  echo "  $(wc -l < "$HF" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$HF" 2>/dev/null)"
  echo
  echo "  --- タグ・検索語の定義 ---"
  grep -nE 'HASHTAGS|TAGS|hashtag|タグ|search\?q=|/search|query' "$HF" 2>/dev/null \
    | head -16 | cut -c1-200 | sed 's/^/    /' | clean
  echo
  echo "  --- 読み込んでいる設定ファイル ---"
  grep -noE '[A-Za-z0-9_.-]+\.json' "$HF" 2>/dev/null | awk -F: '{print $2}' | sort -u | sed 's/^/    /'
  echo
  echo "  --- 何件 取ろうとしているか（上限・slice・件数） ---"
  grep -nE 'slice\(|MAX|LIMIT|PER_|\.length' "$HF" 2>/dev/null \
    | head -14 | cut -c1-200 | sed 's/^/    /' | clean
fi
echo '```'

# ═══════════ 2. どこで減っているか ═══════════
echo
echo "## 2. どこで減っているか（**ログの推移**）"
echo
echo '```'
HL="$L/hashtag-follow.log"
if [ ! -f "$HL" ]; then
  echo "  **$HL が無い。**"
else
  echo "  $(wc -c < "$HL" | tr -d ' ') bytes / 最終更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$HL" 2>/dev/null)"
  echo
  echo "  --- 直近 30 行（書式を見るため生で出す） ---"
  tail -30 "$HL" 2>/dev/null | cut -c1-190 | sed 's/^/    /' | clean
  echo
  echo "  --- 日ごとの推移（start / 集めた数 / 試した数 / 通った数） ---"
  awk '
    match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { d = substr($0, RSTART, RLENGTH) }
    d == "" { next }
    /hashtag-follow start/ { fires[d]++ }
    /SKIP/                 { skips[d]++ }
    match($0, /=== end: [0-9]+\/[0-9]+ OK ===/) {
      s = substr($0, RSTART + 9, RLENGTH - 16)
      split(s, a, "/"); ok[d] += a[1] + 0; tried[d] += a[2] + 0
    }
    match($0, /[0-9]+ (candidates|targets|authors|posts)/) {
      c = substr($0, RSTART, RLENGTH); split(c, b, " "); got[d] += b[1] + 0
    }
    { seen[d] = 1 }
    END {
      n = 0
      for (k in seen) ks[n++] = k
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (ks[i] > ks[j]) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
      st = (n > 10 ? n - 10 : 0)
      printf("    %-12s %6s %6s %7s %6s %6s\n", "日付", "発火", "SKIP", "集めた", "試した", "通った")
      for (i = st; i < n; i++) {
        k = ks[i]
        printf("    %-12s %6d %6d %7d %6d %6d\n", k, fires[k], skips[k], got[k], tried[k], ok[k])
      }
    }
  ' "$HL" 2>/dev/null | clean
  echo
  echo "  --- 弾かれた理由（上位 12） ---"
  grep -oE '❌ [^(]{1,60}' "$HL" 2>/dev/null | sed 's/❌ //' | sed 's/ *$//' \
    | sort | uniq -c | sort -rn | head -12 | sed 's/^/    /' | clean
fi
echo '```'

# ═══════════ 3. trend-detect と同じタグを見ているか ═══════════
echo
echo "## 3. \`trend-detect\` と重なっていないか"
echo
echo "**同じタグを見ているなら、返信で拾った相手をフォローでも拾っている。**"
echo "その場合は「既にフォロー済み」で落ちるので、**タグを足しても増えない。**"
echo
echo '```'
if [ -f "$TD" ]; then
  echo "  --- trend-detect が見ているタグ ---"
  grep -noE '#[^"'"'"' ,\]]{2,20}' "$TD" 2>/dev/null | awk -F: '{print $2}' | sort -u | head -20 | sed 's/^/    /' | clean
  echo
fi
if [ -f "$HF" ]; then
  echo "  --- hashtag-follow が見ているタグ ---"
  grep -noE '#[^"'"'"' ,\]]{2,20}' "$HF" 2>/dev/null | awk -F: '{print $2}' | sort -u | head -20 | sed 's/^/    /' | clean
fi
echo
echo "  --- 設定ファイル側のタグ ---"
for f in hashtag-targets.json trend-keywords.json reply-relevance-rules.json x-growth.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  echo "    ══ $f（$(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)）"
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const out=[];
const walk=(o,d)=>{ if(d>3||!o) return;
  if(Array.isArray(o)){for(const v of o) if(typeof v==="string"&&v.indexOf("#")===0) out.push(v); else walk(v,d+1); return;}
  if(typeof o==="object") for(const k of Object.keys(o)) walk(o[k],d+1);
};
walk(j,0);
const u=[...new Set(out)];
console.log("      タグらしき値: "+u.length+" 件");
if(u.length) console.log("      "+u.slice(0,18).join(" "));
' "$P" 2>&1 | head -4 | clean
done
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**ファイルとログを読むだけ。LLM を呼ばない。ブラウザも触らない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**タグを足す変更も \$0**（フォローは DOM 操作で LLM を呼ばない）。"
echo "増えるのは Mac の CPU 時間と通信だけ。"
echo "返信ループの実績は 1 回 \$0.003 ／ 1 日 \$0.027 ／ 1 か月 約 \$0.81"
echo "（x68 の適用後は上限 1 日 \$0.048 ／ 1 か月 \$1.44）。"
} > "$OUT" 2>&1

echo "ハッシュタグ側の候補不足 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
