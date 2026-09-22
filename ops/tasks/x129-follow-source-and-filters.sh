#!/bin/bash
# **どのジョブが的外れを連れてきたか ＋ 入口フィルタの実装を出す。測るだけ。費用 $0。**
#
# ## なぜ
#
# `x128` で、直近フォローした 12 件 のうち **6 件 が的外れ**だと分かった。
#
#   【公式】LEGEND100               ← 名前に「【公式】」
#   リコ📱楽天モバイル従業員紹介キャンペーン  ← 紹介キャンペーンの集客垢
#   しらたまちゃん（白猫・ハチワレ）   ← ペット垢。off-niche で弾くはずが通過
#   connect24h（セキュリティ × AI）   ← 完全に畑違い
#   ᒪIՏᗩ（#友達1万人できるかな）      ← 数合わせ垢
#   フラッグハルミ                   ← bio が空。low-density で弾くはずが通過
#
# **効く信号は `bio` ではなく `name` だった。** 既存のフィルタは bio しか見ていない。
#
# ## 直す前に 2 つ確かめる（最上位ルール 15）
#
#   ① **どのジョブが連れてきたか。** `followed.json` に `source` が入っている
#   ② **入口フィルタは実際どう書かれているか。**
#      当て推量でパッチを書かない。`x120` で決め打ちの grep をして誤判定した
#
# ## 次のタスクで直せるだけの材料を出す
#
# 判定している関数の**全文**を出す。行番号つきで。
# これが無いと、次のタスクが「たぶんこの辺」で書き換えることになる。
#
# ## やらないこと
#
# **フォローしない。外さない。1 行も書き換えない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-source-and-filters.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
# **ハンドルは頭 2 文字だけ。** 出力は公開リポジトリに載る
maskh() { "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(s.replace(/@([A-Za-z0-9_]{3,15})/g,(m,h)=>"@"+h.slice(0,2)+"…"));
});' 2>/dev/null || cat; }

{
echo "# 的外れは誰が連れてきたか ＋ フィルタの実装（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x128\` で直近 12 件 のうち **6 件 が的外れ**と分かった。"
echo "> **効く信号は \`bio\` ではなく \`name\`。** 既存のフィルタは bio しか見ていない。"
echo ">"
echo "> **直す前に、どのジョブが連れてきたかと、実装の全文を見る**（最上位ルール 15）。"
echo "> \`x120\` で決め打ちの grep をして「使っていない」と誤判定した。同じことをしない。"

echo
echo "## 1. \`source\` の内訳（**誰が連れてきたか**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
if(!fs.existsSync(p)){ console.log("  followed.json が無い"); process.exit(0); }
let j; try{ j=JSON.parse(fs.readFileSync(p,"utf8")); }
catch(e){ console.log("  JSON が読めない: "+e.message); process.exit(0); }
const rows=Array.isArray(j)?j:(j.followed||Object.values(j));
if(!Array.isArray(rows)){ console.log("  配列が取り出せない"); process.exit(0); }

const at=(r)=>r.followed_at||r.at||"";
const bySrc=new Map(), bySrc30=new Map();
const cut=new Date(Date.now()-30*86400e3).toISOString();
for(const r of rows){
  if(!r||typeof r!=="object") continue;
  const s=r.source||"(無し)";
  bySrc.set(s,(bySrc.get(s)||0)+1);
  if(String(at(r))>=cut) bySrc30.set(s,(bySrc30.get(s)||0)+1);
}
console.log("  全 "+rows.length+" 件");
console.log("");
console.log("  source                              全体   直近30日");
console.log("  "+"-".repeat(56));
const keys=[...new Set([...bySrc.keys(),...bySrc30.keys()])].sort();
for(const k of keys){
  console.log("  "+String(k).padEnd(34)+String(bySrc.get(k)||0).padStart(6)
    +String(bySrc30.get(k)||0).padStart(10));
}
console.log("");
// **x128 で的外れだった 6 件 が、どの source か**
const BAD=["LEGEND","リコ","しらたま","connect24h","ᒪIՏᗩ","フラッグ"];
console.log("  --- 記録が持っているキー（最後の 1 件）---");
const last=rows.filter(r=>r&&typeof r==="object").slice(-1)[0];
console.log("    "+(last?Object.keys(last).join(", "):"(無し)"));
console.log("");
console.log("  --- verified の内訳 ---");
const byV=new Map();
for(const r of rows){ if(!r||typeof r!=="object") continue;
  const v=String(r.verified); byV.set(v,(byV.get(v)||0)+1); }
for(const [k,v] of byV) console.log("    "+k.padEnd(10)+v+" 件");
' "$D/followed.json" 2>&1 | secrets
echo '```'
echo
echo "**\`source\` が 1 種類しか無ければ、直す場所も 1 つ。**"
echo "複数あれば、**全部に同じ条件を入れないと片側から漏れる。**"

echo
echo "## 2. 入口フィルタの実装（**全文。行番号つき**）"
echo
echo "**当て推量でパッチを書かないための材料。** 判定している箇所を丸ごと出す。"
echo
for f in "$S/competitor-follower-follow.js" "$S/hashtag-follow.js"; do
  echo "### $(basename "$f")"
  echo
  if [ ! -f "$f" ]; then echo '```'; echo "  **無い**"; echo '```'; echo; continue; fi
  echo '```javascript'
  echo "  // 総行数: $(wc -l < "$f" | tr -d ' ')"
  echo "  // --- 判定・除外に関わる行（前後 4 行）---"
  grep -n -B4 -A4 -E 'off-niche|low-density|random-looking|out of range|inactive|skip|reject|❌' "$f" 2>/dev/null \
    | head -140 | cut -c1-190 | sed 's/^/  /' | maskh
  echo '```'
  echo
done

echo
echo "## 3. 語彙はどこに書かれているか"
echo
echo "**\`off-niche\` の判定語が外出しなら、JSON を足すだけで済む。**"
echo "ソースに直書きなら、スクリプトを触ることになる。"
echo
echo '```'
for f in "$S/competitor-follower-follow.js" "$S/hashtag-follow.js"; do
  [ -f "$f" ] || continue
  echo "  ===== $(basename "$f") ====="
  grep -n -E 'ダイエット|オタ活|ペット|require\(.*\.json|readFileSync.*json|NICHE|KEYWORD|NG_' "$f" 2>/dev/null \
    | head -20 | cut -c1-180 | sed 's/^/    /'
  echo
done
echo "  --- data/ にそれらしい JSON があるか ---"
ls -1 "$D" 2>/dev/null | grep -iE 'niche|keyword|ng|filter|exclude' | sed 's/^/    /' || echo "    （無し）"
echo '```'

echo
echo "## 4. 名前を見ているか（**ここが本題**）"
echo
echo "\`x128\` の実物では、**的外れの根拠が全部 名前に出ていた。**"
echo
echo '```'
echo "  【公式】LEGEND100"
echo "  リコ📱楽天モバイル従業員紹介キャンペーン"
echo '```'
echo
echo '```javascript'
for f in "$S/competitor-follower-follow.js" "$S/hashtag-follow.js"; do
  [ -f "$f" ] || continue
  echo "  ===== $(basename "$f") ====="
  echo "  // name / displayName / 表示名 を触っている行"
  grep -n -E '\bname\b|displayName|screen_name|profile\.name|UserName' "$f" 2>/dev/null \
    | head -18 | cut -c1-180 | sed 's/^/    /' | maskh
  echo
done
echo '```'
echo
echo "**名前を一度も見ていなければ、そこが穴。** 次のタスクで足す。"

echo
echo "## 5. 次に打つ手（**このタスクでは直さない**）"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| 語彙が外出しの JSON | **JSON に足すだけ。** スクリプトを触らない |"
echo "| 語彙がソースに直書き | 名前の判定ごとスクリプトに足す |"
echo "| \`source\` が複数 | **全部に同じ条件を入れる。** 片側だけだと漏れる |"
echo "| 名前を見ていない | \`name\` の判定を新設する |"
echo
echo "**名前で弾く条件（案）。bio には適用しない**"
echo
echo '```'
echo "  弾く: 名前に 【公式】 / 公式アカウント / キャンペーン / 紹介コード / アフィリ"
echo "  弾く: 名前が 株式会社 / (株) / Inc. / Corp. を含む"
echo "  **弾かない**: bio の「公式」（個人の「公式LINE」「公式ライバー」で誤爆する）"
echo '```'

echo
echo "## 6. 費用"
echo
echo "**JSON とソースを読むだけ。LLM を呼ばない。**"
echo "**フォローの判定も DOM だけなので、条件を足しても課金は増えない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "的外れの出どころとフィルタ実装 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
