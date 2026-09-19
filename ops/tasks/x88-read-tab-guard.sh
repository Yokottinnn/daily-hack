#!/bin/bash
# **`tab-guard.js` の全文を読む。直さない。費用 $0。**
#
# ## なぜ（x87 で犯人は確定した）
#
#   tab-guard.js:69
#   for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do
#     case "$p" in *tab-guard*) continue;; esac
#     launchctl unload "$p" 2>/dev/null
#   done
#
# **`ai.openclaw.*` を tab-guard 以外すべて外す。**
# 発火条件のひとつが「Chrome プロセスが消滅」で、**再起動すれば必ず成立する。**
#
# ## 直す方針（利用者が選んだ）
#
# > **起動直後は停めない。**
# > 「Chrome が消えた」を「**一度 生きていたのに消えた**」に限る。
# > 起動直後（そもそも一度も見ていない）は誤発火として扱わない。
# > 本来 守りたい「自動化が Jordan の Chrome を殺した」ケースは引き続き止める。
#
# ## だから先に全文を読む
#
# **138 行 しかない。** 状態をどこに持っているか（`prev` の実体）、
# 「消滅」をどう判定しているか、**どの変数を見れば「一度 生きていた」が言えるか**を
# 実物で確かめてから patch を書く。**推測でセレクタや条件を書き換えない**（ルール 15）。
#
# ## やらないこと
#
# **書き換えない。外さない。載せ直さない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/read-tab-guard.md"
TG="$S/tab-guard.js"

hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`tab-guard.js\` の全文"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x87 で犯人は確定した。**tab-guard が \`ai.openclaw.*\` を全部 外している。**"
echo "> 発火条件のひとつが「Chrome プロセスが消滅」で、**再起動すれば必ず成立する。**"
echo ">"
echo "> 方針: **起動直後は停めない。**「一度 生きていたのに消えた」に限る。"
echo
echo "**読むだけ。書き換えない。**"

# ═══════════ 1. 全文 ═══════════
echo
echo "## 1. 全文（**138 行**）"
echo
echo '```'
if [ ! -f "$TG" ]; then
  echo "  **$TG が無い。**"
  ls -1 "$S" 2>/dev/null | grep -i tab | sed 's/^/    候補: /'
else
  echo "  $(wc -l < "$TG" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$TG" 2>/dev/null)"
fi
echo '```'
if [ -f "$TG" ]; then
  echo
  echo '```javascript'
  awk '{printf("%4d| %s\n", NR, $0)}' "$TG" | cut -c1-200 | clean
  echo '```'
fi

# ═══════════ 2. 状態ファイル ═══════════
echo
echo "## 2. 状態をどこに持っているか"
echo
echo '```'
if [ -f "$TG" ]; then
  echo "  --- 読み書きしているファイル ---"
  grep -noE '[A-Za-z0-9_./-]+\.(json|txt|state)' "$TG" 2>/dev/null | awk -F: '{print $2}' | sort -u | sed 's/^/    /'
  echo
fi
echo "  --- data/ にある tab-guard 関連 ---"
for f in "$D"/tab-guard* "$D"/*tabguard* /tmp/tab-guard*; do
  [ -e "$f" ] || continue
  printf '    %-52s %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  head -c 300 "$f" 2>/dev/null | sed 's/^/      /' | clean
  echo
done
echo '```'

# ═══════════ 3. plist（どう起動されるか） ═══════════
echo
echo "## 3. plist（**10 秒 ごとに再起動している件**）"
echo
echo '```'
P="$HOME/Library/LaunchAgents/ai.openclaw.tab-guard.plist"
if [ -f "$P" ]; then
  echo "  更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  for k in KeepAlive RunAtLoad StartInterval ThrottleInterval; do
    V="$(/usr/libexec/PlistBuddy -c "Print :$k" "$P" 2>/dev/null || echo '(無し)')"
    printf '    %-20s %s\n' "$k" "$V"
  done
  echo
  echo "  --- ProgramArguments ---"
  /usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null | head -8 | sed 's/^/    /'
else
  echo "  **$P が無い。**"
fi
echo
echo "  --- いまの状態 ---"
launchctl list 2>/dev/null | awk '$3=="ai.openclaw.tab-guard" {print "    PID=" $1 "  最後の終了コード=" $2}'
echo '```'
echo
echo "**\`KeepAlive\` が true なら、落ちるたびに launchd が上げ直す。**"
echo "10 秒 ごとの再起動は \`ThrottleInterval\`（既定 10 秒）と一致する。"
echo "つまり**毎回 落ちていて、launchd が 10 秒 おきに上げ直している。**"

# ═══════════ 4. 落ちている理由 ═══════════
echo
echo "## 4. 落ちている理由（**エラーログ**）"
echo
echo '```'
for f in tab-guard-err.log tab-guard.err; do
  PP="$L/$f"; [ -f "$PP" ] || continue
  echo "  ══ $f（$(wc -c < "$PP" | tr -d ' ') bytes / $(stat -f '%Sm' -t '%m-%d %H:%M' "$PP" 2>/dev/null)）"
  tail -20 "$PP" 2>/dev/null | cut -c1-190 | sed 's/^/    /' | clean
  echo
done
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**読むだけ。LLM を呼ばない。外しも載せもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**直す場合も \$0**（判定条件を変えるだけ。LLM を呼ばない）。"
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44。"
} > "$OUT" 2>&1

echo "tab-guard の全文 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
