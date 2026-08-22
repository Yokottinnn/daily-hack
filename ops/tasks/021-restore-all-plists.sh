#!/bin/bash
# **稼働中ジョブの plist を launchctl print から忠実に再生する。**
#
# ## なぜ急ぐか
#
# 私が `plutil -extract` を `-o` 無しで回して plist を潰した。
# 稼働中のジョブは launchd がメモリに設定を保持しているだけで、
# **Mac を再起動すると 15 件が全部止まる。**
# メモリ上の設定が唯一の復元元なので、消える前に書き戻す。
#
# ## 018 で分かった重要なこと
#
#   badge-followback  program = /bin/bash   ← **node 直叩きではない**
#   comment-warmup    12/16/19/22 時 × MAX_PICKS_PER_FIRE=2 = 8 件/日
#
# 019/020 で私が組み直した ①③④ は `node` + `.js` の形にした。
# **元と違う可能性がある。** ここでは推測せず、launchctl print の
# program / arguments をそのまま使う。
#
# ## 再生の方針
#
#   Label                  ラベルそのもの
#   ProgramArguments       arguments ブロックをそのまま
#   EnvironmentVariables   environment ブロックから、launchd が注入するものを除いたもの
#   StartCalendarInterval  event triggers の calendarinterval から Hour/Minute
#   StandardOutPath/Err    stdout path / stderr path
#
# **launchd が注入する変数は書き戻さない**（SSH_AUTH_SOCK / XPC_SERVICE_NAME /
# OSLogRateLimit、および launchd 既定の PATH）。書き戻すと環境が固定されて壊れる。
#
# **書き込むのは、いま稼働しているジョブの plist だけ。**
# 未ロードのものはメモリに設定が無く、忠実に再生できないので触らない。
#
# **plutil -extract は使わない。** 検証は -p（読み取り専用）で行う。
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/restore-all.md"
DUMP="${OPS_REPORT_DIR:-/tmp}/launchctl-dump.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

LABELS="$(launchctl list 2>/dev/null | awk '{print $3}' \
  | grep -E '^(ai\.openclaw|com\.dailyhack)\.' | sort)"

# 生の launchctl print を丸ごと残す。**次に何かあったときの原本になる。**
{
echo "# launchctl print の原本（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
echo
echo "> plist を潰したため、**これが唯一の復元元**。再起動すると失われる。"
for lbl in $LABELS; do
  echo
  echo "## $lbl"
  echo '```'
  launchctl print "gui/$UID_N/$lbl" 2>/dev/null | mask
  echo '```'
done
} > "$DUMP" 2>&1

{
echo "# plist の忠実な再生（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
echo
echo "原本は \`launchctl-dump.md\` に丸ごと残した。"
echo

for lbl in $LABELS; do
  CUR="$LA/$lbl.plist"
  TMP="${TMPDIR:-/tmp}/lcp-$lbl.txt"
  launchctl print "gui/$UID_N/$lbl" > "$TMP" 2>/dev/null || { echo "## $lbl"; echo "- print できない"; continue; }

  echo "## $lbl"
  NEW="${TMPDIR:-/tmp}/new-$lbl.plist"
  /usr/bin/python3 - "$TMP" "$NEW" "$lbl" <<'PY' 2>&1 | sed 's/^/- /'
import plistlib, re, sys

src, out, lbl = sys.argv[1:4]
lines = open(src, encoding="utf-8", errors="replace").read().splitlines()

program, args, env, cal = None, [], {}, []
stdout_p = stderr_p = None
# launchd が注入するもの。書き戻すと環境が固定されて壊れる
INJECTED = {"SSH_AUTH_SOCK", "XPC_SERVICE_NAME", "OSLogRateLimit",
            "__CF_USER_TEXT_ENCODING", "HOME", "USER", "LOGNAME", "TMPDIR", "SHELL"}
LAUNCHD_DEFAULT_PATH = "/usr/bin:/bin:/usr/sbin:/sbin"

section, depth_at = None, None
for raw in lines:
    line = raw.rstrip()
    s = line.strip()
    depth = len(raw) - len(raw.lstrip("\t"))

    m = re.match(r'^program\s*=\s*(.+)$', s)
    if m and program is None:
        program = m.group(1).strip()
    m = re.match(r'^stdout path\s*=\s*(.+)$', s)
    if m:
        stdout_p = m.group(1).strip()
    m = re.match(r'^stderr path\s*=\s*(.+)$', s)
    if m:
        stderr_p = m.group(1).strip()

    if re.match(r'^arguments\s*=\s*\{', s):
        section, depth_at = "args", depth
        continue
    if re.match(r'^environment\s*=\s*\{', s):
        section, depth_at = "env", depth
        continue
    if section and s == "}" and depth == depth_at:
        section = None
        continue

    if section == "args" and s and s != "{":
        args.append(s)
    elif section == "env":
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=>\s*(.*)$', s)
        if m:
            k, v = m.group(1), m.group(2).strip()
            if k in INJECTED:
                continue
            if k == "PATH" and v == LAUNCHD_DEFAULT_PATH:
                continue          # launchd 既定なので plist 由来ではない
            env[k] = v

# カレンダー発火。"Minute" => N / "Hour" => N が対で並ぶ
pend = {}
for raw in lines:
    s = raw.strip()
    m = re.match(r'^"(Minute|Hour|Weekday|Day|Month)"\s*=>\s*(\d+)$', s)
    if m:
        pend[m.group(1)] = int(m.group(2))
    elif s == "}" and pend:
        cal.append(dict(pend)); pend = {}
if pend:
    cal.append(dict(pend))
# 同じ内容の重複を落とす
seen, uniq = set(), []
for c in cal:
    k = tuple(sorted(c.items()))
    if k not in seen:
        seen.add(k); uniq.append(c)
cal = uniq

if not args and program:
    args = [program]
if not args:
    print("**arguments が読めないので書かない**"); sys.exit(1)

d = {"Label": lbl, "ProgramArguments": args}
if program and program != args[0]:
    d["Program"] = program
if env:
    d["EnvironmentVariables"] = env
if cal:
    d["StartCalendarInterval"] = cal
if stdout_p:
    d["StandardOutPath"] = stdout_p
if stderr_p:
    d["StandardErrorPath"] = stderr_p

with open(out, "wb") as f:
    plistlib.dump(d, f)

print("実行: " + " ".join(args[:2]))
print("環境変数: " + (", ".join(f"{k}={v}" for k, v in env.items()) if env else "なし"))
print("発火: " + (" / ".join(
    f"{c.get('Hour','*'):0>2}:{c.get('Minute',0):02d}" for c in cal) if cal else "**カレンダー無し（常駐 or 間隔起動）**"))
PY

  if [ ! -f "$NEW" ] || ! plutil -p "$NEW" 2>/dev/null | grep -q '"Label"'; then
    echo "- **組み立てに失敗したので書かない**"
    continue
  fi
  # 既に正常な plist があるなら触らない（Label が読めれば正常とみなす）
  if plutil -p "$CUR" 2>/dev/null | grep -q '"Label"'; then
    echo "- 現行 plist は既に正常。触らない。"
    continue
  fi
  [ -f "$CUR" ] && cp "$CUR" "$CUR.broken.$STAMP" 2>/dev/null
  if cp "$NEW" "$CUR"; then
    echo "- **書き戻した**（元は .broken.$STAMP へ退避）"
  else
    echo "- **書き戻しに失敗**"
  fi
done

echo
echo "## 結果"
echo
ok=0; ng=0
for lbl in $LABELS; do
  if plutil -p "$LA/$lbl.plist" 2>/dev/null | grep -q '"Label"'; then
    ok=$((ok+1)); printf '%-48s %s\n' "$lbl" "plist 正常"
  else
    ng=$((ng+1)); printf '%-48s %s\n' "$lbl" "**plist 壊れたまま**"
  fi
done
echo
echo "正常 $ok 件 / 壊れたまま $ng 件"
echo
echo "> **未ロードのジョブは触っていない。** メモリに設定が無く忠実に再生できないため。"
} > "$OUT" 2>&1

ok=0
for lbl in $LABELS; do
  plutil -p "$LA/$lbl.plist" 2>/dev/null | grep -q '"Label"' && ok=$((ok+1))
done
tot="$(printf '%s\n' "$LABELS" | grep -c . || true)"
echo "稼働中 ${tot} 件のうち plist 正常=${ok}件 / 原本=launchctl-dump.md / $(basename "$OUT")"
