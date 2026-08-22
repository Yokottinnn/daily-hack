#!/bin/bash
# **③ アンフォローを立ち上げ、019 の再生で失われた設定を戻す。**
#
# ## 019 で何が残ったか
#
#   ① auto-thread-chainifier        ロード成功。ただし env にゴミ（Hour=2/Minute=0）、
#                                    発火の片方 00:11 JST が誤り（ログの無関係な時刻を拾った）
#   ② badge-followback              稼働中
#   ④ competitor-follower-follow    ロード成功。ただし **env が空**。
#      hashtag-follow                COMPETITOR_FOLLOW_DAILY_CAP=5 が失われた
#   ③ unfollow 系                   **未ロード**
#
# env が失われたのは、再生時に読んだ plist が**既に二重破壊されていた**ため
# （EnvironmentVariables ではなく ProgramArguments の配列が入っていた）。
#
# ## 正しい値の出どころ
#
#   COMPETITOR_FOLLOW_DAILY_CAP=5   014 が実機から読み出した値。
#                                   competitor-follower-follow.log の `cap=5` とも一致
#   HASHTAG_FOLLOW_DAILY_CAP=90     014 が実機から読み出した値
#   PATH=/usr/local/bin:/usr/bin:/bin  014 が実機から読み出した値
#
# **推測ではなく、壊れる前に自分で読み出して記録した値。**
#
# ## ③ の発火時刻
#
# **ログから読む。読めない場合だけ、名前が示す朝夕を採用し、
# レポートに「ログから読めなかったので既定値を置いた」と明記する。**
# 黙って既定値を置かない。
#
# **plutil -extract は使わない。読むのは -p と -convert -o - だけ。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/finish-loops.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$1"; }

NODE_BIN=""
for l in $(launchctl list 2>/dev/null | awk '{print $3}' | grep '^ai\.openclaw\.'); do
  c="$(launchctl print "gui/$UID_N/$l" 2>/dev/null | awk '/arguments = \{/,/\}/' \
       | grep -oE '/[^ ]*/node' | head -1)"
  [ -n "$c" ] && [ -x "$c" ] && { NODE_BIN="$c"; break; }
done

# 引数: label script env_kv_pairs(空可) time1 time2...  （時刻は JST の HH:MM）
write_plist() {
  lbl="$1"; js="$2"; envkv="$3"; shift 3
  NEW="${TMPDIR:-/tmp}/$lbl.plist"
  /usr/bin/python3 - "$NEW" "$lbl" "$NODE_BIN" "$js" "$envkv" "$@" <<'PY'
import plistlib, sys
new, lbl, node, js, envkv = sys.argv[1:6]
times = sys.argv[6:]
envs = {}
for pair in envkv.split("|"):
    if "=" in pair:
        k, v = pair.split("=", 1)
        if k.strip():
            envs[k.strip()] = v
cal = []
for t in times:
    hh, mm = t.split(":")
    cal.append({"Hour": int(hh), "Minute": int(mm)})
if not cal:
    sys.exit(1)
short = lbl.split(".")[-1]
base = js.rsplit("/scripts/", 1)[0]
d = {"Label": lbl, "ProgramArguments": [node, js],
     "EnvironmentVariables": envs,
     "StartCalendarInterval": cal,
     "StandardOutPath": f"{base}/logs/{short}.log",
     "StandardErrorPath": f"{base}/logs/{short}-err.log"}
with open(new, "wb") as f:
    plistlib.dump(d, f)
PY
  [ -f "$NEW" ] || return 1
  plutil -p "$NEW" 2>/dev/null | grep -q '"Label"' || return 1
  CUR="$LA/$lbl.plist"
  [ -f "$CUR" ] && cp "$CUR" "$CUR.pre020.$STAMP" 2>/dev/null
  cp "$NEW" "$CUR" || return 1
  launchctl bootout "gui/$UID_N/$lbl" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$UID_N" "$CUR" >/dev/null 2>&1
  loaded "$lbl"
}

{
echo "# ループの仕上げ（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
echo
echo "- node: ${NODE_BIN:-**取れない**}"
[ -z "$NODE_BIN" ] && { echo; echo "**node が取れないので全部中止。**"; exit 0; }

echo
echo "## A. 019 で失われた設定を戻す"
echo
echo "> 値の出どころは **014 が壊れる前に実機から読み出した記録**。推測ではない。"

echo
echo "### ai.openclaw.competitor-follower-follow"
if write_plist ai.openclaw.competitor-follower-follow \
   "$W/scripts/competitor-follower-follow.js" \
   "COMPETITOR_FOLLOW_DAILY_CAP=5|PATH=/usr/local/bin:/usr/bin:/bin" \
   "11:30" "18:30"; then
  echo "- **設定を戻してロード成功**（cap=5 / 発火 11:30・18:30 JST）"
else
  echo "- **失敗**"
fi

echo
echo "### ai.openclaw.hashtag-follow"
HT_TIMES="$(grep -ohE 'T[0-9]{2}:[0-9]{2}' "$W/logs/hashtag-follow.log" 2>/dev/null \
  | grep -oE '[0-9]{2}:[0-9]{2}' | sort | uniq -c | sort -rn | head -2 | awk '{print $2}')"
HT_JST=""
for t in $HT_TIMES; do
  h="${t%%:*}"; m="${t##*:}"
  HT_JST="$HT_JST $(printf '%02d:%s' $(( (10#$h + 9) % 24 )) "$m")"
done
echo "- ログの発火時刻（UTC）: ${HT_TIMES:-読めない} → JST:${HT_JST:- なし}"
if [ -n "$HT_JST" ] && write_plist ai.openclaw.hashtag-follow \
   "$W/scripts/hashtag-follow.js" \
   "HASHTAG_FOLLOW_DAILY_CAP=90|PATH=/usr/local/bin:/usr/bin:/bin" \
   $HT_JST; then
  echo "- **設定を戻してロード成功**（cap=90）"
else
  echo "- **失敗（時刻が読めないか bootstrap 失敗）**"
fi

echo
echo "### ai.openclaw.auto-thread-chainifier"
echo "- 019 が env に \`Hour=2 / Minute=0\` というゴミを入れ、発火の片方 00:11 JST も誤りだった"
echo "- ログの 17:00 UTC ＝ **02:00 JST** が本来の発火。これ 1 本にする"
if write_plist ai.openclaw.auto-thread-chainifier \
   "$W/scripts/auto-thread-chainifier.js" \
   "PATH=/usr/local/bin:/usr/bin:/bin" \
   "02:00"; then
  echo "- **env を掃除してロード成功**（発火 02:00 JST）"
else
  echo "- **失敗**"
fi

echo
echo "## B. ③ アンフォローを立ち上げる"
echo
echo "### 候補スクリプト"
for f in auto_detect_and_unfollow_inactive.js revenge-unfollow.js; do
  [ -f "$W/scripts/$f" ] && echo "- $f: あり（$(wc -l < "$W/scripts/$f" | tr -d ' ') 行）" \
                         || echo "- $f: **無い**"
done
echo
echo "### ログから発火時刻を探す"
UF_SRC=""
for cand in unfollow-cleanup unfollow-daily unfollow-evening revenge-unfollow \
            auto_detect_and_unfollow_inactive; do
  L="$W/logs/$cand.log"
  [ -f "$L" ] || { echo "- $cand.log: 無い"; continue; }
  tt="$(grep -ohE 'T[0-9]{2}:[0-9]{2}|[0-9]{2}:[0-9]{2}:[0-9]{2}' "$L" 2>/dev/null \
        | grep -oE '^T?[0-9]{2}:[0-9]{2}' | tr -d 'T' | sort | uniq -c | sort -rn | head -2 | awk '{print $2}')"
  echo "- $cand.log: $(wc -l < "$L" | tr -d ' ') 行 / 時刻=${tt:-読めない}"
  [ -z "$UF_SRC" ] && [ -n "$tt" ] && UF_SRC="$tt"
done

UF_JS=""
[ -f "$W/scripts/auto_detect_and_unfollow_inactive.js" ] && UF_JS="$W/scripts/auto_detect_and_unfollow_inactive.js"
[ -z "$UF_JS" ] && [ -f "$W/scripts/revenge-unfollow.js" ] && UF_JS="$W/scripts/revenge-unfollow.js"

echo
if [ -z "$UF_JS" ]; then
  echo "**アンフォローのスクリプトが 1 つも無いので立ち上げられない。**"
else
  echo "使うスクリプト: $(basename "$UF_JS")"
  if [ -n "$UF_SRC" ]; then
    UF_JST=""
    for t in $UF_SRC; do
      h="${t%%:*}"; m="${t##*:}"
      UF_JST="$UF_JST $(printf '%02d:%s' $(( (10#$h + 9) % 24 )) "$m")"
    done
    echo "発火時刻: ログから読んだ UTC ${UF_SRC} → JST${UF_JST}"
  else
    UF_JST="22:30"
    echo "発火時刻: **ログから読めなかったので 22:30 JST を置いた。**"
    echo "これは実機から読み取った値ではなく、こちらで選んだ既定値。"
    echo "1 日 1 回・深夜帯。Jordan の指定は「24 時間でフォローバックが無ければアンフォロー」なので"
    echo "日次で足りる。**変えたい時刻があれば言ってください。**"
  fi
  lbl="ai.openclaw.$(basename "$UF_JS" .js | tr '_' '-')"
  echo "ラベル: $lbl"
  if write_plist "$lbl" "$UF_JS" "PATH=/usr/local/bin:/usr/bin:/bin" $UF_JST; then
    echo "- **ロード成功**"
  else
    echo "- **ロード失敗**"
    launchctl bootstrap "gui/$UID_N" "$LA/$lbl.plist" 2>&1 | mask | head -3 | sed 's/^/      /'
  fi
fi

echo
echo "## 最終確認（launchctl の実体）"
echo
for lbl in ai.openclaw.auto-thread-chainifier ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  printf '%-48s %s\n' "$lbl" "$(loaded "$lbl" && echo 稼働 || echo '**未ロード**')"
done
launchctl list 2>/dev/null | awk '{print $3}' | grep -E 'unfollow' \
  | while read -r l; do printf '%-48s %s\n' "$l" "稼働"; done
launchctl list 2>/dev/null | awk '{print $3}' | grep -q 'unfollow' \
  || echo "アンフォロー系                                    **未ロード**"

echo
echo "## 設定の確認（plutil -p は読み取り専用）"
for lbl in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow \
           ai.openclaw.auto-thread-chainifier; do
  echo "### $lbl"
  plutil -p "$LA/$lbl.plist" 2>/dev/null | mask | head -22
done
} > "$OUT" 2>&1

up=0
for lbl in ai.openclaw.auto-thread-chainifier ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl" && up=$((up + 1))
done
uf="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -c 'unfollow' || true)"
echo "①②④=${up}/4 稼働 / ③アンフォロー=${uf}件 / $(basename "$OUT")"
