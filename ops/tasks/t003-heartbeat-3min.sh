#!/bin/bash
# **ハートビートの間隔を 30 分 → 3 分にする。**
#
# ## なぜ要るか
#
# 2026-08-30、承認済みの X 投稿を「あと 26 分待ち」にした。
# クラウドから Mac を動かせる経路は `ops/tasks` だけで、それが 30 分間隔だから。
#
#   ssh                 未インストール。apt も 404 で入らない
#   生 TCP              出口プロキシが塞いでいる（1.1.1.1:22 に出られない）
#   192.168.2.102:22    到達せず。Mac は家庭内 NAT の内側で公開口が無い
#   HTTPS               これだけ通る
#
# **「Mac 側から HTTPS で取りに来る」しか無く、その間隔が待ち時間そのもの。**
# 30 分は長すぎる。**急ぎの用が必ず最大 30 分 遅れる構造**になっている。
#
# ## 3 分にしても負荷は増えない
#
# ハートビートがやるのは launchctl の一覧・ログの mtime・git fetch。
# **LLM は呼ばない。** GitHub API も認証済みで、3 分間隔なら 1 日 480 回。
# 制限（5,000/時）に対して桁が違う。
#
# ## 触り方
#
# plist の `StartInterval` **だけ**を書き換える。
# **`plutil -extract` は使わない**（`-o` 無しはファイルを壊す。8/22 に 56 件壊した）。
# 退避 → 書き換え → Label 確認 → 再ロード。どこで失敗しても元へ戻す。
#
# **ハンドル名は出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LBL=com.dailyhack.ops-heartbeat
P="$LA/$LBL.plist"
OUT="${OPS_REPORT_DIR:-/tmp}/heartbeat-3min.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
WANT=180
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# ハートビートを 3 分間隔にする（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **クラウドから Mac を動かせる経路はこれだけ。** その間隔が待ち時間そのもの。"
echo "> ssh は使えない（未インストール・生 TCP が塞がれている・Mac は NAT の内側）。"

echo
echo "## 1. 現在の設定"
echo
if [ ! -f "$P" ]; then echo "**plist が無い。中止。**"; exit 1; fi
echo '```'
plutil -p "$P" 2>/dev/null | mask | head -20
echo '```'
CUR="$(plutil -p "$P" 2>/dev/null | grep -A0 'StartInterval' | grep -oE '[0-9]+' | head -1)"
echo
echo "- 現在の StartInterval: **${CUR:-読めない}** 秒"
if [ "${CUR:-0}" = "$WANT" ]; then
  echo "- **既に ${WANT} 秒。何もしない。**"; exit 0
fi

echo
echo "## 2. 書き換え"
echo
cp "$P" "$P.pre-3min.$STAMP"
echo "- 退避: $(basename "$P").pre-3min.$STAMP"
/usr/bin/python3 - "$P" "$WANT" <<'PY' 2>&1 | sed 's/^/- /'
import json, plistlib, subprocess, sys
p, want = sys.argv[1], int(sys.argv[2])
raw = subprocess.run(["plutil", "-convert", "json", "-o", "-", p],
                     capture_output=True, text=True).stdout
try:
    d = json.loads(raw)
except Exception as e:
    print(f"plist を JSON にできない（{e}）ので触らない"); sys.exit(1)
if "Label" not in d:
    print("Label が無い。壊れた plist なので触らない"); sys.exit(1)
old = d.get("StartInterval")
# **StartCalendarInterval で動いているなら触らない。** 別の仕組みを壊す
if "StartCalendarInterval" in d:
    print("StartCalendarInterval で動いている。StartInterval に変えない"); sys.exit(1)
if want < 60:
    print("60 秒未満にはしない"); sys.exit(1)
d["StartInterval"] = want
with open(p, "wb") as f:
    plistlib.dump(d, f)
print(f"StartInterval を {old} → {want} 秒にした")
print(f"Label 保持: {d['Label']}")
print(f"ProgramArguments 保持: {d.get('ProgramArguments')}")
PY

if plutil -p "$P" 2>/dev/null | grep -q '"Label"'; then
  launchctl bootout "gui/$UID_N/$LBL" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$LBL"; then
    echo "- **再ロード成功**"
  else
    echo "- **再ロード失敗。退避から戻す**"
    cp "$P.pre-3min.$STAMP" "$P"
    launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
  fi
else
  echo "- **書き換え後の plist が壊れた。退避から戻す**"
  cp "$P.pre-3min.$STAMP" "$P"
  launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
fi

echo
echo "## 3. 確認"
echo
NOW="$(plutil -p "$P" 2>/dev/null | grep -A0 'StartInterval' | grep -oE '[0-9]+' | head -1)"
echo "- StartInterval: **${NOW:-読めない}** 秒"
echo "- 稼働: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$LBL" && echo 稼働 || echo '**未ロード**')"
echo
echo "**これで ops/tasks にコミットしたものは最大 3 分で走る。**"
echo "急ぎの投稿を 30 分 待たせる構造は無くなる。"

echo
echo "## 4. 負荷"
echo
echo "- ハートビートがやるのは launchctl の一覧・ログの mtime・git fetch。**LLM は呼ばない**"
echo "- 3 分間隔なら 1 日 480 回。GitHub API の制限（5,000/時）に対して桁が違う"
echo "- **API 課金はゼロのまま**（\$0/回・\$0/日・\$0/月）"
} > "$OUT" 2>&1

n="$(grep -oE 'StartInterval: \*\*[0-9]+' "$OUT" 2>/dev/null | grep -oE '[0-9]+' | tail -1)"
echo "StartInterval=${n:-?} 秒 / $(basename "$OUT")"
