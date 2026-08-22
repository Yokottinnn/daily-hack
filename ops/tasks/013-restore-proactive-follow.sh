#!/bin/bash
# 能動フォロー（v6 tactic）を戻す。ただし**壊れたまま戻さない**。
#
# ## 7/04 に何が起きていたか（012 の結果）
#
#   6/15  後継 v6 tactic を用意（hashtag-follow / competitor-follower-follow）
#   7/04  レガシーのポイ活フォロー一式を legacy-poikatsu-kill として意図的に廃止
#   7/05  後継は正常稼働（cap=5・1日2回・日月休み）
#   7/07  scrape failure: connect ECONNREFUSED 127.0.0.1:18800
#         → **Chrome CDP への接続が死んだ**
#   8/09  *.bak18800 が一括作成＝直そうとした形跡。以後ログが止まり未ロード
#
# **凍結リスクでも誤フォローでもなく、技術的故障だった。** だから戻してよい。
#
# ## 戻す前に必ず確かめること（1 つでも欠けたらロードしない）
#
#   1. Chrome CDP (18800) が応答するか  → 死んでいれば 7/07 を繰り返すだけ
#   2. スクリプトが LLM を呼ばないか    → 呼ぶなら費用が出せないので人が判断する
#                                         （最上位ルール 2-A / 2-B）
#   3. plist が実在するか               → 当て推量で作らない
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
mask() { sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g'; }

echo "## 1. Chrome CDP (18800) の生死"
cdp_ok=0
if curl -fsS --max-time 5 http://127.0.0.1:18800/json/version >/dev/null 2>&1; then
  echo "- 応答あり（接続できる）"
  cdp_ok=1
else
  echo "- **応答なし**。7/07 と同じ ECONNREFUSED になるのでロードしない。"
  echo "  先に chrome-cdp を復旧すること。"
fi

echo
echo "## 2. 各スクリプトが LLM を呼ぶか（費用が出せるか）"
llm_free=1
for f in competitor-follower-follow.js hashtag-follow.js; do
  S="$W/scripts/$f"
  if [ ! -f "$S" ]; then
    echo "- $f: **存在しない**"
    llm_free=0
    continue
  fi
  sdk="$(grep -cE "@anthropic-ai|@google/gen|openai" "$S" 2>/dev/null || true)"
  key="$(grep -oE 'process\.env\.[A-Z_]*(API_KEY|TOKEN)[A-Z_]*' "$S" 2>/dev/null | sort -u | tr '\n' ' ')"
  cli="$(grep -cE '(spawn|exec|execSync)[^)]*(claude|gemini|anthropic)' "$S" 2>/dev/null || true)"
  echo "- $f: SDK=${sdk}箇所 / CLI起動=${cli}箇所 / APIキー参照=[${key:-無し}]"
  if [ "$sdk" != "0" ] || [ "$cli" != "0" ] || [ -n "$key" ]; then
    llm_free=0
  fi
  echo "    上限: $(grep -oE '(cap|CAP|MAX[A-Z_]*)[[:space:]]*[=:][[:space:]]*[0-9]+' "$S" 2>/dev/null | sort -u | tr '\n' ' ' | cut -c1-120)"
done
if [ "$llm_free" = "1" ]; then
  echo "- 判定: **LLM 呼び出し無し ＝ 追加の API 費用は 0**"
else
  echo "- 判定: **LLM を呼ぶ可能性あり。費用が出せないのでロードしない。**"
fi

echo
echo "## 3. plist の実在と発火設定"
have_plist=1
for lbl in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  P="$LA/$lbl.plist"
  if [ -f "$P" ]; then
    echo "- $lbl: あり / StartCalendarInterval=$(plutil -extract StartCalendarInterval json "$P" 2>/dev/null | cut -c1-160 || echo '無し') / StartInterval=$(plutil -extract StartInterval raw "$P" 2>/dev/null || echo '無し')"
  else
    echo "- $lbl: **plist が無い**"
    have_plist=0
  fi
done

echo
echo "## 4. ロード"
if [ "$cdp_ok" != "1" ] || [ "$llm_free" != "1" ] || [ "$have_plist" != "1" ]; then
  echo "**条件を満たさないのでロードしない。** 上の 1〜3 を見て人が判断する。"
  exit 0
fi

for lbl in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  P="$LA/$lbl.plist"
  if launchctl list 2>/dev/null | grep -q "$lbl"; then
    echo "- $lbl: 既にロード済み"
    continue
  fi
  if launchctl bootstrap "gui/$UID_N" "$P" 2>&1 | mask | head -2; then :; fi
  if launchctl list 2>/dev/null | grep -q "$lbl"; then
    echo "- $lbl: **ロード成功**"
  else
    echo "- $lbl: ロード失敗（launchctl list に載らない）"
  fi
done

echo
echo "## 5. ロード後の確認"
launchctl list 2>/dev/null | grep -E 'follow' | mask
