#!/bin/bash
# 能動フォローの plist が壊れているので、正常なバックアップから復元してロードする。
#
# ## 014 で分かったこと
#
#   Bootstrap failed: 5: Input/output error
#   Could not find service "ai.openclaw.hashtag-follow" in domain for user gui: 501
#
# plutil -p の中身に **Label も ProgramArguments も無い。**
# 環境変数だけのファイルになっていて、launchd がサービスとして認識できない。
# 013 が「StartInterval も StartCalendarInterval も無し」と言ったのもこれが理由。
#
# 一方、`.bak.20260615-v6-tactic` は v6 tactic 導入時のもので、
# 7/05〜7/07 に実際に動いていた頃の設定のはず。
#
# **現行 plist の更新日は 2026-08-22（今日）。** バックアップは 6/15 のまま。
# 今日 何かが書き換えた可能性があるので、両方を並べて記録に残す。
#
# ## マスクの直し
#
# 014 では 20 字以上の英数字を一律に伏せたため、`COMPETITOR_FOLLOW_DAILY_CAP`
# のような**環境変数名まで潰れて診断できなかった。**
# 秘密は「英字と数字が混ざった長い文字列」なので、そちらだけを伏せる。
# 大文字とアンダースコアだけのキー名は残す。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/repair-follow-plists.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"

# 値だけを伏せる。キー名（大文字と _ のみ）とパスは残す
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

# 正しい launchd plist かどうか
valid() {
  [ -f "$1" ] || return 1
  plutil -extract Label raw "$1" >/dev/null 2>&1 || return 1
  plutil -extract ProgramArguments json "$1" >/dev/null 2>&1 || return 1
  return 0
}

{
echo "# フォロー plist の修復（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"

for name in competitor-follower-follow hashtag-follow; do
  lbl="ai.openclaw.$name"
  CUR="$LA/$lbl.plist"
  echo
  echo "## $lbl"

  echo
  echo "### 現行 .plist"
  if [ -f "$CUR" ]; then
    echo "- 更新: $(date -r "$CUR" '+%Y-%m-%d %H:%M' 2>/dev/null)  サイズ: $(wc -c < "$CUR" | tr -d ' ') B"
    echo "- トップレベルのキー: $(plutil -convert json -o - "$CUR" 2>/dev/null | grep -oE '"[A-Za-z]+":' | tr -d '":' | tr '\n' ' ')"
    echo "- Label: $(plutil -extract Label raw "$CUR" 2>/dev/null || echo '**無し**')"
    echo "- ProgramArguments: $(plutil -extract ProgramArguments json "$CUR" 2>/dev/null | mask | cut -c1-160 || echo '**無し**')"
    valid "$CUR" && echo "- 判定: 正常" || echo "- 判定: **壊れている（launchd が読めない）**"
  else
    echo "- **存在しない**"
  fi

  # 候補のバックアップを新しい順に
  echo
  echo "### バックアップ候補"
  BEST=""
  for B in $(ls -t "$LA/$lbl.plist."* 2>/dev/null); do
    ok="壊れている"
    valid "$B" && { ok="正常"; [ -z "$BEST" ] && BEST="$B"; }
    echo "- $(basename "$B")  更新=$(date -r "$B" '+%Y-%m-%d %H:%M' 2>/dev/null)  → $ok"
  done
  [ -z "$BEST" ] && echo "（正常なバックアップが 1 つも無い）"

  echo
  echo "### 復元"
  if valid "$CUR"; then
    echo "現行が正常なので復元しない。"
  elif [ -n "$BEST" ]; then
    cp "$CUR" "$CUR.broken.$STAMP" 2>/dev/null && echo "- 壊れた現行を $(basename "$CUR").broken.$STAMP へ退避した"
    if cp "$BEST" "$CUR"; then
      echo "- $(basename "$BEST") から復元した"
      echo "- 復元後の Label: $(plutil -extract Label raw "$CUR" 2>/dev/null || echo '読めない')"
      echo "- 復元後の起動設定: StartCalendarInterval=$(plutil -extract StartCalendarInterval json "$CUR" 2>/dev/null | cut -c1-200 || echo '無し') / StartInterval=$(plutil -extract StartInterval raw "$CUR" 2>/dev/null || echo '無し')"
      echo "- ProgramArguments: $(plutil -extract ProgramArguments json "$CUR" 2>/dev/null | mask | cut -c1-200)"
    else
      echo "- **復元に失敗した**"
    fi
  else
    echo "**正常な plist が無いので復元できない。** 当て推量で作らない。"
    echo "元の設定は 7/05〜7/07 に動いていた頃のもので、"
    echo "logs/$name.log に発火時刻（02:30 / 09:30 UTC）と cap が残っている。"
  fi

  echo
  echo "### ロード"
  if ! valid "$CUR"; then
    echo "plist が正常でないので bootstrap しない。"
  elif launchctl list 2>/dev/null | grep -q "$lbl"; then
    echo "既にロード済み。"
  else
    launchctl bootstrap "gui/$UID_N" "$CUR" 2>&1 | mask | head -3
    if launchctl list 2>/dev/null | grep -q "$lbl"; then
      echo "**ロード成功**"
    else
      echo "**ロード失敗**"
    fi
  fi
done

echo
echo "## Chrome CDP（ここが死んでいると、載せても実行 0 件のまま）"
if curl -fsS --noproxy '*' --max-time 5 http://127.0.0.1:18800/json/version 2>/dev/null | head -c 150 | mask; then
  echo
  echo "→ 応答あり"
else
  echo "→ **応答なし。** 別途復旧が必要。"
fi
echo
echo "### chrome-cdp の plist とロード状態"
for B in "$LA"/ai.openclaw.chrome-cdp.plist*; do
  [ -f "$B" ] || continue
  v="壊れている"; valid "$B" && v="正常"
  echo "- $(basename "$B")  更新=$(date -r "$B" '+%Y-%m-%d %H:%M' 2>/dev/null)  → $v"
done
echo "- launchctl: $(launchctl list 2>/dev/null | grep -c 'ai.openclaw.chrome-cdp' || true) 件"

echo
echo "## 最終状態（follow 系）"
launchctl list 2>/dev/null | grep -E 'ai\.openclaw.*follow' | mask || echo "（ai.openclaw の follow 系が 1 つも載っていない）"
} > "$OUT" 2>&1

ok="$(grep -c 'ロード成功' "$OUT" 2>/dev/null || true)"
now="$(launchctl list 2>/dev/null | grep -cE 'ai\.openclaw.*follow' || true)"
echo "ロード成功=${ok}件 / ai.openclaw の follow 系 稼働=${now}件 / $(basename "$OUT")"
