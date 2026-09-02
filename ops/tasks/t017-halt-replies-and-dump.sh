#!/bin/bash
# **返信を止めて、指摘された実物を持ち帰る。**
#
# 2026-09-02、Jordan から指摘。
#
#   https://x.com/heng_ji31590/status/2094773161623728197
#   「この返信がけっこうトンチンカンなことを言っている」
#   「これじゃあまるでAIが自動で返信していますというのがバレバレ」
#   「以降絶対にやめてほしくて、対応策を考えて実装してみて」
#
# ## まず止める
#
# **直している最中も 8 件/日 出続ける。** 直すより先に止める。
# `ai.openclaw.comment-warmup` を unload する。**フォロー 2 件は止めない**
# （文面を出さないので今回の指摘とは無関係）。
#
# 止めるのは可逆で、費用も減る方向にしか動かない。
#
# ## そのうえで実物を読む
#
# `x-reply-style` スキル §1 ④ に「文脈がずれる」が既に記録されているが、
# **今回の実物をまだ読んでいない。** 推測で直すと外す（2026-08-30 に 3 回やった）。
#
#   1. 指摘されたツイート本体（id 2094773161623728197）
#   2. **何に対する返信だったか**（相手の投稿）
#   3. 直近の返信 15 件（**1 件だけ見ても「バレバレ」の理由は分からない。
#      並べて初めて型が見える**）
#   4. 使われたテンプレート id の分布
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0、むしろ減る）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/halt-replies-and-dump.md"
QJSON="$W/data/post_queue.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LBL="ai.openclaw.comment-warmup"
UID_N="$(id -u)"
TID="2094773161623728197"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$1" || true; }

{
echo "# 返信を止めて、指摘された実物を読む（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> 「トンチンカン」「AI が自動で返信しているのがバレバレ」との指摘。"
echo "> **直している最中も出続けるので、先に止める。**"

echo
echo "## 1. 返信を止める"
echo
echo "- 止める前: \`$LBL\` ロード=**$(loaded "$LBL")** 件"
launchctl bootout "gui/$UID_N/$LBL" >/dev/null 2>&1 || true
sleep 2
AFTER="$(loaded "$LBL")"
echo "- 止めた後: ロード=**${AFTER}** 件"
if [ "${AFTER:-1}" = "0" ]; then
  echo "- ✅ **返信は止まった。** 文面を直すまで出ない"
else
  echo "- 🚨 **止まっていない。** 手で \`launchctl bootout gui/\$(id -u)/$LBL\` を叩くこと"
fi
echo
echo "> **フォローの 2 件は止めていない。** 文面を出さないので今回の指摘とは無関係。"
echo "> 止めたぶん費用は **\$0.033/日 → \$0** に下がる（増える方向には動かない）。"

echo
echo "## 2. 指摘されたツイート（id \`$TID\`）"
echo
"$NODE_BIN" -e '
const fs=require("fs");
const [q,tid]=process.argv.slice(1);
try{
  const d=JSON.parse(fs.readFileSync(q,"utf8"));
  const e=(d.queue||[]).find(x=>String(x.x_tweet_id||"")===tid);
  if(!e){ console.log("- **キューに見つからない。** id 違いか、別経路で出たもの"); process.exit(0); }
  const show={};
  for(const k of Object.keys(e)){
    if(/token|secret|key|cookie/i.test(k)) continue;
    show[k]=e[k];
  }
  console.log("```json");
  console.log(JSON.stringify(show,null,2).slice(0,2600));
  console.log("```");
}catch(err){ console.log("- 読めない: "+err.message); }
' "$QJSON" "$TID" 2>&1 | hide | mask

echo
echo "## 3. 直近の返信 15 件（**並べて型を見る**）"
echo
echo "> **1 件だけ見ても「バレバレ」の理由は分からない。**"
echo "> 出だし・語尾・テンプレの偏りは、並べて初めて見える。"
echo
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const es=(d.queue||[])
    .filter(x=>String(x.kind||"")==="comment" && x.x_tweet_id)
    .slice(-15);
  if(!es.length){ console.log("- comment のエントリが見つからない"); process.exit(0); }
  for(const e of es){
    const t=String(e.text||"").replace(/\n/g," ");
    const src=String(e.target_text||e.source_text||e.context||"").replace(/\n/g," ").slice(0,90);
    console.log("---");
    console.log("- **相手**: " + (src||"（相手の投稿が記録されていない）"));
    console.log("- **返信**: " + t);
    console.log("- template: `" + (e.template_id||e.templateId||"?") + "` / posted: " + (e.posted_at||"?"));
  }
}catch(err){ console.log("- 読めない: "+err.message); }
' "$QJSON" 2>&1 | hide | mask

echo
echo "## 4. テンプレートの偏り（直近 60 件）"
echo
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const es=(d.queue||[]).filter(x=>String(x.kind||"")==="comment").slice(-60);
  const by={}, head={};
  for(const e of es){
    const k=String(e.template_id||e.templateId||"?"); by[k]=(by[k]||0)+1;
    const h=String(e.text||"").slice(0,8); if(h) head[h]=(head[h]||0)+1;
  }
  console.log("| template | 件数 |"); console.log("| --- | --- |");
  Object.entries(by).sort((a,b)=>b[1]-a[1]).slice(0,12)
    .forEach(([k,v])=>console.log(`| \`${k}\` | ${v} |`));
  console.log("");
  console.log("**出だし 8 文字の重複**（同じ書き出しが並ぶと機械に見える）");
  console.log("");
  console.log("| 出だし | 件数 |"); console.log("| --- | --- |");
  Object.entries(head).sort((a,b)=>b[1]-a[1]).slice(0,10)
    .forEach(([k,v])=>console.log(`| \`${k}\` | ${v} |`));
}catch(err){ console.log("- 読めない: "+err.message); }
' "$QJSON" 2>&1 | hide | mask

echo
echo "## 5. 相手の投稿を記録しているか（**直しの前提**）"
echo
echo "「返信が相手の投稿に噛み合っているか」を機械で判定するには、"
echo "**相手の投稿の本文がキューに残っている必要がある。** 残っていなければ、"
echo "まず記録するところから直す。"
echo
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const es=(d.queue||[]).filter(x=>String(x.kind||"")==="comment").slice(-40);
  const keys={};
  for(const e of es) for(const k of Object.keys(e)) keys[k]=(keys[k]||0)+1;
  console.log("直近 40 件の comment エントリが持つフィールド:");
  console.log("```");
  console.log(Object.keys(keys).sort().join(", "));
  console.log("```");
  const cand=["target_text","source_text","context","tweet_text","original_text","parent_text"];
  const has=cand.filter(k=>keys[k]);
  console.log("");
  console.log(has.length
    ? "- ✅ 相手の投稿らしきフィールド: **" + has.join(" / ") + "**"
    : "- ⚠️ **相手の投稿の本文が残っていない。** 噛み合いの判定には記録の追加が要る");
}catch(err){ console.log("- 読めない: "+err.message); }
' "$QJSON" 2>&1 | mask
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '✅ \*\*返信は止まった' "$OUT" 2>/dev/null; then
  echo "**返信を止めた。実物を持ち帰った** / $(basename "$OUT")"
else
  echo "🚨 **返信が止まっていない。手で止めること** / $(basename "$OUT")"
fi
