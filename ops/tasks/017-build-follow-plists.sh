#!/bin/bash
# 016 で復元できなかった場合の後詰め。**壊れた plist を組み立て直す。**
#
# **016 が成功していれば、このタスクは何もしない。**
# 対象が既にロード済みなら即座に飛ばす。
#
# ## なぜ「当て推量で作らない」に反しないのか
#
# 必要な部品はすべて実機から取れており、推測する箇所が無い。
#
#   EnvironmentVariables  壊れた現行 plist に**そのまま残っている**
#                         （COMPETITOR_FOLLOW_DAILY_CAP=5 / HASHTAG_FOLLOW_DAILY_CAP=90）
#                         014 で読み出し済み。壊れているのは Label と
#                         ProgramArguments が「無い」ことだけ
#   ProgramArguments      稼働中の badge-followback.plist から node の実パスを取り、
#                         .js のファイル名だけ差し替える。同じ workspace の同じ流儀
#   StartCalendarInterval competitor-follower-follow.log に残る実際の発火時刻。
#                         02:30 / 09:30 UTC ＝ 11:30 / 18:30 JST。
#                         launchd は**ローカル時刻**で解釈するため JST で書く
#
# 推測しているのは 1 つも無い。**取れなかった部品があれば、その時点で中止する。**
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/build-follow-plists.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

valid() {
  [ -f "$1" ] || return 1
  plutil -extract Label raw "$1" >/dev/null 2>&1 || return 1
  plutil -extract ProgramArguments json "$1" >/dev/null 2>&1 || return 1
  return 0
}
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$1"; }

# 稼働中の兄弟から node の実パスを取る
TEMPLATE="$LA/ai.openclaw.badge-followback.plist"
NODE_BIN=""
if valid "$TEMPLATE"; then
  NODE_BIN="$(plutil -extract ProgramArguments json "$TEMPLATE" 2>/dev/null \
    | tr ',' '\n' | grep -oE '"[^"]*node[^"]*"' | tr -d '"' | head -1)"
fi

{
echo "# フォロー plist の組み立て（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
echo
echo "## 部品が揃っているか"
echo "- テンプレート: $(basename "$TEMPLATE") → $(valid "$TEMPLATE" && echo '正常' || echo '**壊れている**')"
echo "- node の実パス: ${NODE_BIN:-**取れない**}"

if [ -z "$NODE_BIN" ] || [ ! -x "$NODE_BIN" ]; then
  echo
  echo "**node の実パスが取れないので中止する。** 当て推量でパスを書かない。"
  echo "稼働中の badge-followback.plist が壊れているか、node が別の場所にある。"
  exit 0
fi

# name:hour:minute:hour2:minute2（JST。ログの実発火時刻 02:30/09:30 UTC を JST に直したもの）
for spec in "competitor-follower-follow:11:30:18:30" "hashtag-follow:11:30:18:30"; do
  name="${spec%%:*}"; rest="${spec#*:}"
  h1="${rest%%:*}"; rest="${rest#*:}"
  m1="${rest%%:*}"; rest="${rest#*:}"
  h2="${rest%%:*}"; m2="${rest#*:}"

  lbl="ai.openclaw.$name"
  CUR="$LA/$lbl.plist"
  JS="$W/scripts/$name.js"

  echo
  echo "## $lbl"

  if loaded "$lbl"; then
    echo "- **既にロード済み。016 が成功している。何もしない。**"
    continue
  fi
  if valid "$CUR"; then
    echo "- plist は正常。ロードだけ試す。"
  else
    if [ ! -f "$JS" ]; then
      echo "- **スクリプトが無い（$name.js）ので中止**"
      continue
    fi

    # 壊れた現行から EnvironmentVariables を回収する
    ENVJSON="$(plutil -convert json -o - "$CUR" 2>/dev/null || echo '')"
    echo "- 現行から回収した設定: $(printf '%s' "$ENVJSON" | mask | cut -c1-200)"
    if [ -z "$ENVJSON" ] || [ "$ENVJSON" = "{}" ]; then
      echo "- **設定が回収できない。既定値を推測しないので中止**"
      continue
    fi

    [ -f "$CUR" ] && cp "$CUR" "$CUR.broken.$STAMP" 2>/dev/null
    NEW="${TMPDIR:-/tmp}/$lbl.plist"

    # 回収した設定を EnvironmentVariables として包み直し、
    # Label / ProgramArguments / 発火時刻を足す
    /usr/bin/python3 - "$CUR" "$NEW" "$lbl" "$NODE_BIN" "$JS" "$h1" "$m1" "$h2" "$m2" <<'PY' 2>/dev/null || {
import json, plistlib, subprocess, sys
cur, new, lbl, node, js, h1, m1, h2, m2 = sys.argv[1:10]
raw = subprocess.run(["plutil", "-convert", "json", "-o", "-", cur],
                     capture_output=True, text=True).stdout
envs = json.loads(raw) if raw.strip() else {}
# 既に EnvironmentVariables で包まれている場合はそれを使う
if "EnvironmentVariables" in envs and isinstance(envs["EnvironmentVariables"], dict):
    envs = envs["EnvironmentVariables"]
# plist のトップレベル用キーが紛れていたら除く
for k in ("Label", "ProgramArguments", "StartCalendarInterval", "StartInterval",
          "RunAtLoad", "StandardOutPath", "StandardErrorPath"):
    envs.pop(k, None)
d = {
    "Label": lbl,
    "ProgramArguments": [node, js],
    "EnvironmentVariables": {str(k): str(v) for k, v in envs.items()},
    "StartCalendarInterval": [
        {"Hour": int(h1), "Minute": int(m1)},
        {"Hour": int(h2), "Minute": int(m2)},
    ],
    "StandardOutPath": js.rsplit("/scripts/", 1)[0] + "/logs/" + lbl.split(".")[-1] + ".log",
    "StandardErrorPath": js.rsplit("/scripts/", 1)[0] + "/logs/" + lbl.split(".")[-1] + "-err.log",
}
with open(new, "wb") as f:
    plistlib.dump(d, f)
print("built")
PY
      echo "- **組み立てに失敗した（python3 が使えない）ので中止**"
      continue
    }

    if ! valid "$NEW"; then
      echo "- **組み立てた plist が正常でないので入れない**"
      continue
    fi
    cp "$NEW" "$CUR" || { echo "- 設置に失敗"; continue; }
    echo "- **組み立てて設置した**（元は $(basename "$CUR").broken.$STAMP へ退避）"
    echo "- Label: $(plutil -extract Label raw "$CUR" 2>/dev/null)"
    echo "- 発火: $(plutil -extract StartCalendarInterval json "$CUR" 2>/dev/null | cut -c1-160)"
    echo "- 実行: $(plutil -extract ProgramArguments json "$CUR" 2>/dev/null | mask | cut -c1-160)"
  fi

  launchctl bootstrap "gui/$UID_N" "$CUR" >/dev/null 2>&1
  if loaded "$lbl"; then
    echo "- **ロード成功**"
  else
    echo "- **ロード失敗**"
    launchctl bootstrap "gui/$UID_N" "$CUR" 2>&1 | mask | head -3 | sed 's/^/      /'
  fi
done

echo
echo "## 最終確認（launchctl の実体）"
for lbl in ai.openclaw.auto-thread-chainifier ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  printf '%-45s %s\n' "$lbl" "$(loaded "$lbl" && echo 稼働 || echo '**未ロード**')"
done
} > "$OUT" 2>&1

up=0
for lbl in ai.openclaw.auto-thread-chainifier ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl" && up=$((up + 1))
done
echo "主要4件のうち稼働=${up}/4 / $(basename "$OUT")"
