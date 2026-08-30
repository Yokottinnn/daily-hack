#!/bin/bash
# **フォロー候補の供給が枯れている原因を、コードと実データで突き止める。**
#
# 042 の実測（2026-08-30）
#
#   hashtag-follow:              0/1 → 0/1 → 1/3     ← **cap 90 に対し候補が 1〜3 件**
#   competitor-follower-follow:  0/10 → 1/10 → 0/10  ← 試行は増えたが成功が 0〜1
#   フォロワー実測ペース +0.45 人/日（必要 +2.66）→ 9/30 見込み 約 229 人
#
# **上限をいじっても意味が無いと分かっている。** 供給側を見る。
#
# ## 見るもの（推測で決めない）
#
#   1. 探しに行っているハッシュタグの一覧（HASHTAGS）と、1 タグあたりの取得数
#   2. トレンド検知の足切り条件（MIN_LIKES / MAX_AGE_HOURS / EARLY_EXIT）
#   3. どの段階で減っているか: 取得 → 重複除外 → 足切り → pick
#   4. 競合の巡回先（day-rotation の母数）と 1 回の scrape 件数
#   5. 既フォロー・解除済みの除外がどれだけプールを削っているか
#
# **「取れていない」のか「弾いている」のかを混同しない。** 段階ごとに数を出す。
#
# **読むだけ。何も書き換えない。LLM を呼ばない（費用 $0）。**
# **ハンドルは伏せる。** **plutil -extract は使わない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-supply.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# フォロー候補の供給を太くする（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **cap 90 に対し候補が 1〜3 件。** 上限ではなく供給が詰まっている。"
echo "> 「取れていない」のか「弾いている」のかを段階ごとの数で分ける。"

echo
echo "## 1. 探しに行っているハッシュタグ"
echo
T="$W/scripts/trend-detect.js"
if [ -f "$T" ]; then
  echo '```javascript'
  grep -nE 'HASHTAGS|const TAGS|hashtags\s*=|ACCOUNTS' "$T" 2>/dev/null | mask | cut -c1-190 | head -14
  echo '```'
  echo
  echo "定義の中身（配列の実体）:"
  echo '```javascript'
  awk '/HASHTAGS *=|const TAGS *=/,/\]/' "$T" 2>/dev/null | mask | cut -c1-190 | head -22
  echo '```'
else
  echo "**trend-detect.js が無い。**"
fi

echo
echo "## 2. 足切りの条件"
echo
for f in trend-detect.js hashtag-follow.js follow-handle.js; do
  p="$W/scripts/$f"
  [ -f "$p" ] || { echo "- $f: 無し"; continue; }
  echo "### $f（$(wc -l < "$p" | tr -d ' ') 行）"
  echo '```javascript'
  grep -nE 'MIN_LIKES|MAX_AGE|EARLY_EXIT|PER_ITEM_TIMEOUT|LIMIT|slice\(0|follower.*(range|100|10000)|ratio|density|off-niche|inactive|random-looking' \
    "$p" 2>/dev/null | mask | cut -c1-170 | head -18
  echo '```'
done

echo
echo "## 3. どの段階で減っているか（直近 10 回ぶん）"
echo
echo "**取得 → 重複除外 → 足切り → pick。** どこで落ちているかを並べる。"
echo
L="$W/logs/hashtag-follow.log"
if [ -f "$L" ]; then
  echo "### hashtag-follow"
  echo '```'
  grep -E 'trend candidates|unique new authors|picks:|already follows|=== end' "$L" 2>/dev/null \
    | tail -40 | hide | mask | cut -c1-140
  echo '```'
fi
L2="$W/logs/competitor-follower-follow.log"
if [ -f "$L2" ]; then
  echo
  echo "### competitor-follower-follow"
  echo '```'
  grep -E 'start:|scraped|new targets|=== end' "$L2" 2>/dev/null \
    | tail -30 | hide | mask | cut -c1-140
  echo '```'
fi

echo
echo "## 4. 巡回先の母数"
echo
echo "競合の day-rotation は何件あるか（**ハンドルは出さない。件数だけ**）:"
"$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const W=process.argv[1];
const p=path.join(W,"scripts/competitor-follower-follow.js");
try{
  const s=fs.readFileSync(p,"utf8");
  const m=s.match(/(?:COMPETITORS|TARGETS|ACCOUNTS)\s*=\s*\[([^\]]*)\]/);
  if(m){
    const n=m[1].split(",").filter(x=>x.trim()).length;
    console.log("- 競合の巡回先: **"+n+" 件**");
  } else console.log("- 競合の巡回先: 配列が見つからない");
}catch(e){ console.log("- 読めない: "+e.message); }
// 除外プールの大きさ
try{
  const f=JSON.parse(fs.readFileSync(path.join(W,"data/followed.json"),"utf8"));
  const arr=Array.isArray(f)?f:(f.followed||[]);
  const by={};
  for(const r of arr){const s=(r&&r.status)||"(なし)";by[s]=(by[s]||0)+1;}
  console.log("- followed.json: "+arr.length+" 件 / "+Object.entries(by).map(([k,v])=>k+"="+v).join(" / "));
  console.log("  → **この数だけ候補から除外されている**");
}catch(e){ console.log("- followed.json: 読めない"); }
' "$W" 2>&1 | head -10

echo
echo "## 5. 太くする手の候補（**実行はしない。材料を出すだけ**）"
echo
echo "上の数字を見て、効く順に選ぶこと。"
echo
echo "    A. ハッシュタグを増やす        → 1 タグ 1〜3 件なら、タグ数がそのまま効く"
echo "    B. MIN_LIKES を下げる          → 足切りで落ちているなら効く。落ちていないなら無意味"
echo "    C. MAX_AGE_HOURS を伸ばす      → 18h → 48h で母数が増える"
echo "    D. 競合の巡回先を増やす        → 6 件しか無いなら、ここが一番太い"
echo "    E. 1 タグあたりの取得上限を上げる"
echo
echo "**上限（cap）はもう効かないと分かっている。** A〜E は供給側の手。"
} > "$OUT" 2>&1

echo "供給の詰まりを調べた / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
