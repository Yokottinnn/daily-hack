#!/bin/bash
# 能動フォローを**確実にロードする**。013 は自分で入れた安全弁に引っかかって
# ロードせずに終わった。46 日止まっているものを、さらに待たせない。
#
# ## 013 の何が過剰だったか
#
# 1. **CDP が落ちていたらロードしない** → 過剰。
#    CDP が無くてもジョブを載せること自体は無害で、ログに ECONNREFUSED を
#    書くだけ。載せておけば CDP が復活した瞬間に動き出す。
#    載せないと、CDP が直っても永久に動かない。
#
# 2. **TOKEN を含む env をすべて LLM 判定にした** → 誤検知。
#    X の API トークンなど LLM と無関係なものまで拾う。
#    本当に見るべきは SDK の import と CLI 起動だけ。
#
# 3. 出力を標準出力に書いたため 300 字で切られ、**どの条件で落ちたのか
#    分からなかった**。全文はレポートファイルに書く。
#
# **残す判定は 1 つだけ: LLM の SDK / CLI を使っていたらロードしない。**
# 費用が出せないものを黙って動かさないための最低線（最上位ルール 2-A / 2-B）。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/restore-follow.md"
mask() { sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g'; }

TARGETS="ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow"

{
echo "# 能動フォローの復旧（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"

echo
echo "## 1. LLM を使っているか（ロードの唯一の条件）"
llm_free=1
for f in competitor-follower-follow.js hashtag-follow.js; do
  S="$W/scripts/$f"
  echo
  echo "### $f"
  if [ ! -f "$S" ]; then echo "- **存在しない**"; llm_free=0; continue; fi
  echo "- 行数: $(wc -l < "$S" | tr -d ' ')"
  sdk="$(grep -nE "require\(['\"]@(anthropic-ai|google)|from ['\"]@(anthropic-ai|google)|require\(['\"]openai|from ['\"]openai" "$S" 2>/dev/null | mask | cut -c1-120)"
  cli="$(grep -nE '(spawn|exec|execSync|execFile)[^;]{0,60}(claude|gemini|anthropic)' "$S" 2>/dev/null | mask | cut -c1-120)"
  echo "- SDK import: ${sdk:-なし}"
  echo "- LLM CLI 起動: ${cli:-なし}"
  echo "- env 全部（キー名のみ）: $(grep -oE 'process\.env\.[A-Z_]+' "$S" 2>/dev/null | sort -u | tr '\n' ' ')"
  [ -n "$sdk" ] && llm_free=0
  [ -n "$cli" ] && llm_free=0
done
echo
if [ "$llm_free" = "1" ]; then
  echo "**判定: LLM 呼び出し無し → 追加の API 費用は 1回 \$0 / 1日 \$0 / 1か月 \$0。ロードしてよい。**"
else
  echo "**判定: LLM を使う。費用が出せないのでロードしない。**"
fi

echo
echo "## 2. plist の中身（013 で StartInterval も Calendar も「無し」と出たので全キーを見る）"
for lbl in $TARGETS; do
  P="$LA/$lbl.plist"
  echo
  echo "### $lbl"
  if [ ! -f "$P" ]; then echo "- **plist が無い**"; continue; fi
  plutil -p "$P" 2>/dev/null | mask | cut -c1-160 | head -40
done

echo
echo "## 3. Chrome CDP の状態（ロードの条件にはしない。事実として記録するだけ）"
if curl -fsS --noproxy '*' --max-time 5 http://127.0.0.1:18800/json/version 2>/dev/null | head -c 200 | mask; then
  echo
  echo "→ **応答あり**"
else
  echo "→ **応答なし。** ジョブは載せる（載せておけば CDP 復活と同時に動く）。"
  echo "   CDP 側の復旧は別途必要。"
fi
echo
echo "### chrome-cdp ジョブのロード状態"
launchctl list 2>/dev/null | grep -i 'chrome' | mask || echo "（chrome 系ジョブは launchctl に無い）"

echo
echo "## 4. ロード"
if [ "$llm_free" != "1" ]; then
  echo "LLM を使うため中止。"
else
  for lbl in $TARGETS; do
    P="$LA/$lbl.plist"
    [ -f "$P" ] || { echo "- $lbl: plist が無いので飛ばす"; continue; }
    if launchctl list 2>/dev/null | grep -q "$lbl"; then
      echo "- $lbl: 既にロード済み"
      continue
    fi
    launchctl bootstrap "gui/$UID_N" "$P" 2>&1 | mask | head -3
    if launchctl list 2>/dev/null | grep -q "$lbl"; then
      echo "- $lbl: **ロード成功**"
    else
      echo "- $lbl: **ロード失敗**"
      launchctl print "gui/$UID_N/$lbl" 2>&1 | head -5 | mask
    fi
  done
fi

echo
echo "## 5. 結果（follow 系すべて）"
launchctl list 2>/dev/null | grep -iE 'follow' | mask || echo "（follow 系ジョブが 1 つも載っていない）"
} > "$OUT" 2>&1

# heartbeat の tasks に載る 300 字には、いちばん効く 1 行だけ出す
echo "$(grep -c 'ロード成功' "$OUT" 2>/dev/null) 件ロード成功 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
launchctl list 2>/dev/null | grep -icE 'follow' | sed 's/^/follow系の稼働数: /'
