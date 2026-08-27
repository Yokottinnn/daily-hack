#!/bin/bash
# **返信を 2 倍にする（8 → 16 件/日）。**
#
# Jordan の指示: 「返信も2倍にして」
#
# ## 変更
#
#   MAX_PICKS_PER_FIRE  2 → 4
#   発火 4 回/日（12/16/19/22 JST）なので 4 × 4 = **16 件/日**
#
# ## 費用（増加後を先に出す）
#
#   実測単価 $0.00417/件（Haiku 4.5・comment-warmup の実測）
#
#   現在  8 件/日  → $0.033/日  月 $1.00
#   変更後 16 件/日 → $0.067/日  **月 $2.00**（+$1.00）
#
# ## 過去の事故を踏まえる
#
# 2026-08-15 に実機が MAX_PICKS_PER_FIRE=8（32 件/日）で動いていて
# 想定の 4 倍になっており、Jordan 判断で 2 に戻した経緯がある。
# **今回の 4 は当時の 8 の半分。** それでも上げすぎないよう、
# **8 以上には絶対にしない**ガードを入れる。
#
# ## NG 判定が先に入っていること
#
# 返信を増やすと売春系に当たる機会も増える。#233/#234 で
# comment-orchestrator.sh に NG 判定を組み込んである。
# **組み込まれていなければ、返信を増やさない。**
#
# ## 触り方
#
# plist の EnvironmentVariables だけ。**plutil -extract は使わない。**
# 退避 → 書き換え → Label 確認 → 再ロード確認。どこで失敗しても元へ戻す。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LBL=ai.openclaw.comment-warmup
P="$LA/$LBL.plist"
OUT="${OPS_REPORT_DIR:-/tmp}/double-replies.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# 返信を 2 倍にする（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "実測単価 \$0.00417/件（Haiku 4.5）"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| 現在 8 件/日 | \$0.00417 | \$0.033 | **\$1.00** |"
echo "| 変更後 16 件/日 | \$0.00417 | \$0.067 | **\$2.00** |"

echo
echo "## 1. 前提: NG 判定が組み込まれているか"
echo
S="$W/scripts/comment-orchestrator.sh"
if grep -q 'ng-filter-candidates' "$S" 2>/dev/null; then
  echo "- **組み込み済み。** 返信を増やしても売春系には打たない。"
  NG_OK=1
else
  echo "- **未組み込み。返信を増やさない。**"
  echo "  先に 028 を通すこと。増やせば当たる機会も増える。"
  NG_OK=0
fi

echo
echo "## 2. 現在の設定"
echo
if [ ! -f "$P" ]; then
  echo "- **plist が無いので中止**"
  NG_OK=0
else
  echo "- 環境変数:"
  plutil -p "$P" 2>/dev/null | awk '/EnvironmentVariables/,/^  \}/' | mask | sed 's/^/      /' | head -10
  echo "- 1 日の発火回数: $(plutil -p "$P" 2>/dev/null | grep -c '"Hour"' || echo 0) 回"
fi

echo
echo "## 3. 引き上げ"
echo
if [ "$NG_OK" != "1" ]; then
  echo "**前提を満たさないので触らない。**"
else
  cp "$P" "$P.pre031.$STAMP"
  echo "- 退避: $(basename "$P").pre031.$STAMP"
  /usr/bin/python3 - "$P" <<'PY' 2>&1 | sed 's/^/- /'
import json, plistlib, subprocess, sys
p = sys.argv[1]
raw = subprocess.run(["plutil", "-convert", "json", "-o", "-", p],
                     capture_output=True, text=True).stdout
d = json.loads(raw)
env = d.get("EnvironmentVariables") or {}
old = env.get("MAX_PICKS_PER_FIRE")
if old is None:
    print("MAX_PICKS_PER_FIRE が無いので触らない"); sys.exit(1)
try:
    n = int(str(old))
except ValueError:
    print(f"数値でない（{old}）ので触らない"); sys.exit(1)

# 2026-08-15 に 8（32 件/日）で事故になっている。**8 以上には絶対にしない**
NEW = 4
if n >= NEW:
    print(f"既に {n}。これ以上は上げない"); sys.exit(1)
if NEW >= 8:
    print("8 以上にはしない（2026-08-15 の事故の値）"); sys.exit(1)

fires = len(d.get("StartCalendarInterval") or [])
env["MAX_PICKS_PER_FIRE"] = str(NEW)
d["EnvironmentVariables"] = {str(k): str(v) for k, v in env.items()}
with open(p, "wb") as f:
    plistlib.dump(d, f)
print(f"MAX_PICKS_PER_FIRE を {n} → {NEW} に上げた")
print(f"発火 {fires} 回/日 なので 1 日あたり {NEW*fires} 件（月額 ${NEW*fires*0.00417*30:.2f}）")
PY
  if plutil -p "$P" 2>/dev/null | grep -q '"Label"'; then
    launchctl bootout "gui/$UID_N/$LBL" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
    if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$LBL"; then
      echo "- **再ロード成功**"
    else
      echo "- **再ロード失敗。退避から戻す**"
      cp "$P.pre031.$STAMP" "$P"
      launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
    fi
  else
    echo "- **書き換え後の plist が壊れた。退避から戻す**"
    cp "$P.pre031.$STAMP" "$P"
  fi
fi

echo
echo "## 4. 変更後の確認"
echo
cur="$(plutil -p "$P" 2>/dev/null | grep -A1 'MAX_PICKS_PER_FIRE' | grep -oE '"[0-9]+"' | tr -d '"' | head -1)"
fires="$(plutil -p "$P" 2>/dev/null | grep -c '"Hour"' || echo 0)"
echo "- MAX_PICKS_PER_FIRE: ${cur:-読めない}"
echo "- 発火回数: ${fires} 回/日"
[ -n "$cur" ] && echo "- 1 日あたり: $((cur * fires)) 件"
echo "- 稼働: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$LBL" && echo 稼働 || echo '**未ロード**')"

echo
echo "## 5. 次の発火で見ること"
echo
echo "- 実際に 4 件 pick しているか（\`picked N / max\` の行）"
echo "- ng-filter が何件弾いたか"
echo
echo "直近のログ:"
grep -E 'picked|ng-filter' "$W/logs/comment-warmup.log" 2>/dev/null | tail -6 | mask | cut -c1-140 | sed 's/^/    /'
} > "$OUT" 2>&1

cur="$(plutil -p "$P" 2>/dev/null | grep -A1 'MAX_PICKS_PER_FIRE' | grep -oE '"[0-9]+"' | tr -d '"' | head -1)"
echo "MAX_PICKS_PER_FIRE=${cur:-不明} / $(basename "$OUT")"
