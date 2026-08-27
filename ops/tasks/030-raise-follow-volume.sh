#!/bin/bash
# **フォロー量を上げる。ただし段階的に、実測を残しながら。**
#
# ## なぜ
#
#   211 人 / 目標 300 人 / 残り 34 日 → 必要 +2.62 人/日
#   実測 +1.25 人/日 → このままだと 9/30 に約 254 人（46 人 不足）
#
# フォロー系は **LLM を使わないので API 費用は $0 のまま。**
# 増やしても Anthropic への課金は増えない。
#
# ## ただし別のリスクがある
#
# **X のスパム判定。** 無差別に大量フォローすると制限や凍結を招く。
# 金銭コストがゼロでも、アカウントを失えば全部止まる。
#
# だから **一気に上げない。** competitor の cap を 5 → 10（2 倍）に留める。
# 効果と副作用を見てから次を判断する。
#
# ## フォロー比の歯止め
#
# フォローを増やすとフォロー数がフォロワー数を上回りやすくなり、
# それ自体がスパム信号になる。**現在の比率を先に測り、
# 危険域（2.0 倍超）なら cap を上げずに報告だけする。**
#
# ## 触り方
#
# plist の EnvironmentVariables だけを書き換える。
# **plutil -extract は使わない**（-o 無しはファイルを壊す）。
# 読むのは -convert json -o - と -p だけ。
# 触る前に退避し、書き換え後に Label が読めなければ元へ戻す。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/raise-follow.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

{
echo "# フォロー量の引き上げ（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> フォロー系は LLM 不使用のため **API 費用は \$0 のまま。**"
echo "> 増やしても Anthropic への課金は増えない。**気にするのは X のスパム判定。**"

echo
echo "## 1. 先に歯止めを確認する（フォロー比）"
echo
RATIO_OK=1
"$NODE_BIN" -e "
const fs=require('fs'),path=require('path');
const W='$W';
function j(p){try{return JSON.parse(fs.readFileSync(path.join(W,p),'utf8'))}catch(e){return null}}
// フォロワー数
let followers=null;
try{
  const t=fs.readFileSync(path.join(W,'logs/follower-snapshot.log'),'utf8');
  const ms=[...t.matchAll(/\"count_today\":(\d+)/g)];
  if(ms.length) followers=+ms[ms.length-1][1];
}catch(e){}
// フォロー数
let following=null;
const f=j('data/followed.json');
if(f){const a=Array.isArray(f)?f:(f.followed||Object.values(f)[0]||[]);if(Array.isArray(a))following=a.length;}
console.log('- フォロワー: '+(followers??'不明'));
console.log('- フォロー（followed.json）: '+(following??'不明'));
if(followers&&following){
  const r=following/followers;
  console.log('- 比率: '+r.toFixed(2)+' 倍');
  console.log(r>2.0 ? '- **危険域（2.0 倍超）。cap を上げない。**' : '- 安全域。cap を上げてよい。');
  process.exit(r>2.0?1:0);
}
console.log('- 比率が出せない。**安全側に倒して cap を上げない。**');
process.exit(1);
" 2>&1 || RATIO_OK=0

echo
echo "## 2. 現在の設定と実績"
echo
for name in competitor-follower-follow hashtag-follow badge-followback; do
  P="$LA/ai.openclaw.$name.plist"
  L="$W/logs/$name.log"
  echo "### $name"
  if [ -f "$P" ]; then
    echo "- 環境変数:"
    plutil -p "$P" 2>/dev/null | awk '/EnvironmentVariables/,/^  \}/' | mask | sed 's/^/      /' | head -8
    echo "- 1 日の発火回数: $(plutil -p "$P" 2>/dev/null | grep -c '\"Hour\"' || echo 0) 回"
  fi
  if [ -f "$L" ]; then
    echo "- 直近 3 日の行数:"
    i=0; while [ "$i" -lt 3 ]; do
      d="$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "$i days ago" '+%Y-%m-%d')"
      printf '      %s  %s 行\n' "$d" "$(grep -c "$d" "$L" 2>/dev/null || echo 0)"
      i=$((i+1)); done
    echo "- 直近 3 行:"
    tail -3 "$L" 2>/dev/null | mask | cut -c1-140 | sed 's/^/      /'
  fi
  echo
done

echo
echo "## 3. 引き上げ"
echo
if [ "$RATIO_OK" != "1" ]; then
  echo "**歯止めに引っかかったので cap を上げない。** 上の比率を見て人が判断する。"
else
  LBL=ai.openclaw.competitor-follower-follow
  P="$LA/$LBL.plist"
  if [ ! -f "$P" ]; then
    echo "- $LBL の plist が無いので中止"
  else
    cp "$P" "$P.pre030.$STAMP"
    echo "- 退避: $(basename "$P").pre030.$STAMP"
    /usr/bin/python3 - "$P" <<'PY' 2>&1 | sed 's/^/- /'
import json, plistlib, subprocess, sys
p = sys.argv[1]
raw = subprocess.run(["plutil", "-convert", "json", "-o", "-", p],
                     capture_output=True, text=True).stdout
d = json.loads(raw)
env = d.get("EnvironmentVariables") or {}
old = env.get("COMPETITOR_FOLLOW_DAILY_CAP")
if old is None:
    print("cap の環境変数が無いので触らない"); sys.exit(1)
try:
    n = int(str(old))
except ValueError:
    print(f"cap が数値でない（{old}）ので触らない"); sys.exit(1)
if n >= 10:
    print(f"cap は既に {n}。これ以上は今回上げない"); sys.exit(1)
env["COMPETITOR_FOLLOW_DAILY_CAP"] = "10"
d["EnvironmentVariables"] = {str(k): str(v) for k, v in env.items()}
with open(p, "wb") as f:
    plistlib.dump(d, f)
print(f"cap を {n} → 10 に上げた（発火 2 回/日 なので 1 日あたり最大 {10*2} 件）")
PY
    if plutil -p "$P" 2>/dev/null | grep -q '"Label"'; then
      launchctl bootout "gui/$UID_N/$LBL" >/dev/null 2>&1 || true
      launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
      if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$LBL"; then
        echo "- **再ロード成功**"
      else
        echo "- **再ロード失敗。退避から戻す**"
        cp "$P.pre030.$STAMP" "$P"
        launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
      fi
    else
      echo "- **書き換え後の plist が壊れた。退避から戻す**"
      cp "$P.pre030.$STAMP" "$P"
    fi
  fi
fi

echo
echo "## 4. 日月の休止は切り替えられるか（今回は触らない）"
echo
echo "competitor-follower-follow は日月を skip している。週 2 日 休むと機会が 28% 減る。"
echo "**環境変数で切り替えられるかだけ調べる。** スクリプトは書き換えない。"
S="$W/scripts/competitor-follower-follow.js"
if [ -f "$S" ]; then
  grep -nE 'Sun|Mon|skip.*day|day.*skip|getDay' "$S" 2>/dev/null | mask | cut -c1-140 | head -8 | sed 's/^/    /'
  echo "    参照している環境変数: $(grep -oE 'process\.env\.[A-Z_]+' "$S" 2>/dev/null | sort -u | tr '\n' ' ')"
fi

echo
echo "## 5. 変更後の確認"
echo
P="$LA/ai.openclaw.competitor-follower-follow.plist"
echo "- 現在の cap: $(plutil -p "$P" 2>/dev/null | grep -A1 'COMPETITOR_FOLLOW_DAILY_CAP' | grep -oE '\"[0-9]+\"' | tr -d '\"' | head -1)"
echo "- 稼働: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -qx ai.openclaw.competitor-follower-follow && echo 稼働 || echo '**未ロード**')"
echo
echo "次の発火（11:30 / 18:30 JST）のログで、実際に何件フォローしたかを確認すること。"
} > "$OUT" 2>&1

cap="$(plutil -p "$LA/ai.openclaw.competitor-follower-follow.plist" 2>/dev/null \
  | grep -A1 'COMPETITOR_FOLLOW_DAILY_CAP' | grep -oE '"[0-9]+"' | tr -d '"' | head -1)"
echo "competitor の cap=${cap:-不明} / $(basename "$OUT")"
