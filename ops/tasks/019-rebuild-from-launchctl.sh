#!/bin/bash
# **私が壊した plist を、実機に残っている情報だけから再生する。**
#
# ## 前提（018 で確定させた事実）
#
# `plutil -extract` を `-o` 無しで回したため、ai.openclaw の plist が
# EnvironmentVariables の中身だけに潰れた。バックアップも同じ方法で潰した。
#
# ただし **壊れていないものが 3 つ残っている。**
#
#   1. launchd のメモリ  稼働中ジョブの ProgramArguments が launchctl print で読める
#   2. 潰れた plist      EnvironmentVariables は**そのまま残っている**（それだけが残った）
#   3. ログ             実際に発火していた時刻が残っている
#
# この 3 つを合わせれば、推測なしで plist を組み立て直せる。
#
# ## 発火時刻は**ログから読む。決め打ちしない。**
#
# 各ジョブのログに残る時刻の出現頻度を数え、上位 2 つを採用する。
# ログが無い・時刻が読めない場合は **組み立てを中止する**（黙って既定値を置かない）。
#
# ## plutil の使い方
#
# **`-extract` は必ず `-o -` を付ける。** 付けないとファイルを上書きする。
# 読むだけなら `-p` を使う。
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/rebuild.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$1"; }

# 稼働中ジョブの launchctl print から node の実パスを取る
NODE_BIN=""
for lbl in $(launchctl list 2>/dev/null | awk '{print $3}' | grep '^ai\.openclaw\.'); do
  cand="$(launchctl print "gui/$UID_N/$lbl" 2>/dev/null \
    | awk '/arguments = \{/,/\}/' | grep -oE '/[^ ]*/node' | head -1)"
  [ -n "$cand" ] && [ -x "$cand" ] && { NODE_BIN="$cand"; break; }
done

{
echo "# 壊した plist の再生（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
echo
echo "## 部品"
echo "- node の実パス（launchctl print から）: ${NODE_BIN:-**取れない**}"

if [ -z "$NODE_BIN" ]; then
  echo
  echo "**node の実パスが取れないので全部中止する。**"
  echo "稼働中ジョブが 1 つも無いか、launchctl print の形式が想定と違う。"
  echo
  echo "### 参考: 稼働中ジョブの arguments"
  for lbl in $(launchctl list 2>/dev/null | awk '{print $3}' | grep '^ai\.openclaw\.' | head -3); do
    echo "#### $lbl"
    launchctl print "gui/$UID_N/$lbl" 2>/dev/null | awk '/arguments = \{/,/\}/' | mask | head -8
  done
  exit 0
fi

for name in auto-thread-chainifier competitor-follower-follow hashtag-follow; do
  lbl="ai.openclaw.$name"
  CUR="$LA/$lbl.plist"
  JS="$W/scripts/$name.js"

  echo
  echo "## $lbl"

  if loaded "$lbl"; then echo "- 既にロード済み。何もしない。"; continue; fi
  if [ ! -f "$JS" ]; then echo "- **スクリプトが無い（$name.js）ので中止**"; continue; fi

  # 発火時刻をログから読む。ISO の時刻も `[YYYY-MM-DD HH:MM:SS` 形式も拾う
  LOG="$W/logs/$name.log"
  TIMES=""
  if [ -f "$LOG" ]; then
    TIMES="$(grep -ohE 'T[0-9]{2}:[0-9]{2}|[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' "$LOG" 2>/dev/null \
      | grep -oE '[0-9]{2}:[0-9]{2}$' | sort | uniq -c | sort -rn | head -2 | awk '{print $2}')"
  fi
  echo "- ログ: $([ -f "$LOG" ] && echo "$(basename "$LOG") $(wc -l < "$LOG" | tr -d ' ') 行" || echo '**無い**')"
  echo "- ログから読めた発火時刻（多い順 2 つ）: $(printf '%s ' $TIMES)"

  if [ -z "$TIMES" ]; then
    echo "- **時刻が読めないので中止する。** 既定値を黙って置かない。"
    continue
  fi

  # ログの時刻は UTC 表記（ISO）。launchd はローカル（JST）で解釈するので +9 する
  echo "- ログは UTC 表記なので JST に直して plist に書く（launchd はローカル時刻で解釈）"

  # 潰れた plist に残っている環境変数を回収（-o - を付けるので安全）
  ENVJSON="$(plutil -convert json -o - "$CUR" 2>/dev/null || echo '')"
  echo "- 回収した環境変数: $(printf '%s' "$ENVJSON" | mask | cut -c1-200)"

  [ -f "$CUR" ] && cp "$CUR" "$CUR.broken.$STAMP" 2>/dev/null
  NEW="${TMPDIR:-/tmp}/$lbl.plist"

  /usr/bin/python3 - "$NEW" "$lbl" "$NODE_BIN" "$JS" "$ENVJSON" $TIMES <<'PY' 2>&1 | head -5
import json, plistlib, sys
new, lbl, node, js, envjson = sys.argv[1:6]
times = sys.argv[6:]
try:
    envs = json.loads(envjson) if envjson.strip() else {}
except Exception:
    envs = {}
if isinstance(envs, dict) and isinstance(envs.get("EnvironmentVariables"), dict):
    envs = envs["EnvironmentVariables"]
if not isinstance(envs, dict):
    envs = {}
for k in ("Label", "ProgramArguments", "StartCalendarInterval", "StartInterval",
          "RunAtLoad", "StandardOutPath", "StandardErrorPath", "KeepAlive"):
    envs.pop(k, None)

cal = []
for t in times:
    hh, mm = t.split(":")
    cal.append({"Hour": (int(hh) + 9) % 24, "Minute": int(mm)})   # UTC → JST
if not cal:
    print("時刻が無いので中止"); sys.exit(1)

short = lbl.split(".")[-1]
base = js.rsplit("/scripts/", 1)[0]
d = {
    "Label": lbl,
    "ProgramArguments": [node, js],
    "EnvironmentVariables": {str(k): str(v) for k, v in envs.items()},
    "StartCalendarInterval": cal,
    "StandardOutPath": f"{base}/logs/{short}.log",
    "StandardErrorPath": f"{base}/logs/{short}-err.log",
}
with open(new, "wb") as f:
    plistlib.dump(d, f)
print("組み立てた: 発火 " + " / ".join(f"{c['Hour']:02d}:{c['Minute']:02d} JST" for c in cal))
PY

  # 検証は読み取り専用の plutil -p で行う（-extract は使わない）
  if ! plutil -p "$NEW" 2>/dev/null | grep -q '"Label"'; then
    echo "- **組み立てた plist に Label が無い。設置しない。**"
    continue
  fi
  cp "$NEW" "$CUR" || { echo "- 設置に失敗"; continue; }
  echo "- 設置した（元は $(basename "$CUR").broken.$STAMP へ退避）"
  echo '```'
  plutil -p "$CUR" 2>/dev/null | mask | head -20
  echo '```'

  launchctl bootstrap "gui/$UID_N" "$CUR" >/dev/null 2>&1
  if loaded "$lbl"; then
    echo "- **ロード成功**"
  else
    echo "- **ロード失敗**"
    launchctl bootstrap "gui/$UID_N" "$CUR" 2>&1 | mask | head -3 | sed 's/^/      /'
  fi
done

echo
echo "## Chrome CDP"
echo
echo "016 の実測で **18810 が応答**している。Chrome 自体は生きているので、"
echo "chrome-cdp ジョブの再生は急がない（ここでは触らない）。"
echo '```'
curl -fsS --noproxy '*' --max-time 5 http://127.0.0.1:18810/json/version 2>&1 | head -c 150 | mask
echo '```'

echo
echo "## 最終確認（launchctl の実体）"
for lbl in ai.openclaw.auto-thread-chainifier ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  printf '%-45s %s\n' "$lbl" "$(loaded "$lbl" && echo 稼働 || echo '**未ロード**')"
done
} > "$OUT" 2>&1

up=0; down=""
for lbl in ai.openclaw.auto-thread-chainifier ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl"; then
    up=$((up + 1))
  else
    down="$down ${lbl#ai.openclaw.}"
  fi
done
echo "主要4件のうち稼働=${up}/4${down:+ / 未ロード:$down} / $(basename "$OUT")"
