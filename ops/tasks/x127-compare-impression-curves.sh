#!/bin/bash
# **告知の表示回数を「経過時間ごと」に並べて比べる。測るだけ。費用 $0。**
#
# ## なぜ
#
# 2026-09-21 18:23 に出した格安スーパーの告知が、**4 時間 で 49 件の表示**だった。
# 利用者から「まだ投稿されていない気がする」と言われるほど動いていない。
#
# **だが「49 が少ない」とは、まだ言えない。** 比べる相手が要る。
#
# `com.dailyhack.x-impressions` が 3 時間おきに記録しているので、
# **同じ経過時間（age_h）の過去の告知と並べれば、多いか少ないかが言える。**
#
# ## 疑っていること（**まだ推測。数字で確かめる**）
#
#   ① **削除直後の再投稿**で X 側が配信を絞った
#      → 1 回目（17:00・2101944276943044941）を消して 1 時間半後に同じ内容を出した
#   ② そもそも夕方が弱い時間帯
#   ③ 何も異常でなく、いつもこんなもの
#
# **①②③ のどれかは、過去の曲線と並べないと分からない。**
#
# ## 何を出すか
#
#   * `x-impressions.jsonl` を **age_h ごとに並べた表**（告知別）
#   * **いま生きている 2 本の最新値**（DOM から取り直す）
#   * 出した時刻（JST）を添える。**時間帯の比較に要る**
#
# ## やらないこと
#
# **投稿しない。設定を変えない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LOG="$W/data/x-impressions.jsonl"
QJSON="$W/data/post_queue.json"
OUT="${OPS_REPORT_DIR:-/tmp}/compare-impression-curves.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 表示回数を経過時間ごとに比べる（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 18:23 に出した格安スーパーが **4 時間 で 49 件の表示**。"
echo "> **だが「49 が少ない」とは、まだ言えない。** 同じ経過時間の過去の告知と並べる。"
echo
echo "疑っていること（**まだ推測**）: ① 削除直後の再投稿で配信が絞られた"
echo "／ ② 夕方が弱い ／ ③ いつもこんなもの。**並べないと分からない。**"

echo
echo "## 1. 記録はあるか"
echo
echo '```'
if [ -f "$LOG" ]; then
  echo "  $LOG"
  echo "  行数 : $(wc -l < "$LOG" | tr -d ' ')"
  echo "  mtime: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LOG" 2>/dev/null)"
else
  echo "  **$LOG が無い。** 記録が始まっていない"
fi
echo '```'
echo
echo "**mtime が 3 時間 以上 古ければ、記録ジョブが止まっている。**"
echo "その場合、下の表は途中までしか無い。"

echo
echo "## 2. 経過時間ごとの表示回数（**告知別**）"
echo
echo '```'
if [ ! -f "$LOG" ]; then
  echo "  記録が無いので出せない"
else
"$NODE_BIN" -e '
const fs=require("fs");
const [logp,qp]=process.argv.slice(1);
const rows=[];
// **末尾に改行が無い最後の 1 行も読む**（最上位ルール 14 と同じ根）
for(const line of fs.readFileSync(logp,"utf8").split(/\r?\n/)){
  const t=line.trim(); if(!t.startsWith("{")) continue;
  try{ rows.push(JSON.parse(t)); }catch(e){}
}
if(!rows.length){ console.log("  読める行が 1 つも無い"); process.exit(0); }

// 投稿時刻を JST で添える。**時間帯の比較に要る**
const jst=(iso)=>{ if(!iso) return "  ?  ";
  const d=new Date(Date.parse(iso)+9*3600e3);
  return String(d.getUTCMonth()+1).padStart(2,"0")+"/"+String(d.getUTCDate()).padStart(2,"0")
    +" "+String(d.getUTCHours()).padStart(2,"0")+":"+String(d.getUTCMinutes()).padStart(2,"0"); };

// id ごとにまとめる
const byId=new Map();
for(const r of rows){
  if(!r.id) continue;
  if(!byId.has(r.id)) byId.set(r.id,{id:r.id, posted_at:r.posted_at, pts:[]});
  byId.get(r.id).pts.push({age:r.age_h, v:r.views, l:r.likes, rp:r.reposts});
}

// **経過時間の区切り。** ぴったりは来ないので、近いものを拾う
const BUCKETS=[3,6,12,24,48];
const near=(pts,h)=>{
  let best=null, bd=1e9;
  for(const p of pts){ if(p.age==null) continue;
    const d=Math.abs(p.age-h); if(d<bd && d<=h*0.5+1.5){ bd=d; best=p; } }
  return best;
};

const list=[...byId.values()].sort((a,b)=>String(b.posted_at||"").localeCompare(String(a.posted_at||"")));
console.log("  出した時刻(JST)  " + BUCKETS.map(h=>("~"+h+"h").padStart(8)).join("") + "   id");
console.log("  " + "-".repeat(30+8*BUCKETS.length));
for(const e of list){
  const cells=BUCKETS.map(h=>{ const p=near(e.pts,h); return (p?String(p.v):"-").padStart(8); }).join("");
  console.log("  " + jst(e.posted_at).padEnd(16) + cells + "   " + e.id.replace("blog-promo-",""));
}
console.log("");
console.log("  （\"-\" はその時間帯の記録がまだ無い。3 時間おきなので歯抜けになる）");
console.log("  記録されている告知: " + list.length + " 本 / 総行数 " + rows.length);
' "$LOG" "$QJSON" 2>&1
fi
echo '```'
echo
echo "**横に読む**と 1 本の伸び方、**縦に読む**と同じ経過時間での比較になる。"

echo
echo "## 3. 生きている 2 本のいまの値（**DOM から取り直す**）"
echo
echo "記録は 3 時間おきなので、**いまの値はログに無い**。取りに行く。"
echo
echo '```json'
RUNNER="$S/.x127-now.js"
cat > "$RUNNER" <<'JSEOF'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const H = "heng_ji31590";
const IDS = ["2101965436426564045","2101965516718187002","2101694599215599678","2101694677514846544"];
function parseLabel(s){
  const pick=(re)=>{const m=String(s||"").match(re);return m?Number(m[1].replace(/,/g,"")):null;};
  return { replies:pick(/([\d,]+)\s*件の返信/), reposts:pick(/([\d,]+)\s*件のリポスト/),
           likes:pick(/([\d,]+)\s*件のいいね/), views:pick(/([\d,]+)\s*件の表示/) };
}
(async()=>{
  const b=await chromium.connectOverCDP(CDP,{timeout:60000});
  const p=await b.contexts()[0].newPage();
  const out=[];
  for(const id of IDS){
    try{
      await p.goto("https://x.com/"+H+"/status/"+id,{waitUntil:"domcontentloaded",timeout:40000});
      await p.waitForTimeout(5000);
      const label=await p.evaluate(()=>{
        const a=document.querySelector("article"); if(!a) return null;
        const g=a.querySelector('[role="group"][aria-label]');
        return g?g.getAttribute("aria-label"):null;
      });
      out.push({ id, ...parseLabel(label), raw: label ? String(label).slice(0,90) : null });
    }catch(e){ out.push({ id, error:String(e&&e.message).slice(0,120) }); }
  }
  await p.close(); await b.close();
  console.log(JSON.stringify(out,null,1));
})().catch(e=>{console.log(JSON.stringify({fatal:String(e&&e.message).slice(0,200)}));process.exit(1);});
JSEOF
if "$NODE_BIN" --check "$RUNNER" >/dev/null 2>&1; then
  ( cd "$S" && "$NODE_BIN" "$(basename "$RUNNER")" ) 2>&1 | head -c 2500 | clean
else
  echo "  **構文エラーなので走らせない**"
fi
rm -f "$RUNNER" 2>/dev/null || true
echo
echo '```'
echo
echo "**上 2 本が格安スーパー（18:23）、下 2 本が歩いてポイ活（9/21 00:26）。**"
echo "歩いてポイ活は約 22 時間 前、格安スーパーは約 4 時間 前。**そのまま比べない。**"

echo
echo "## 4. 読み方"
echo
echo "| 出方 | 意味 |"
echo "| --- | --- |"
echo "| 同じ ~3h で過去も 40〜60 | **異常ではない。** いつもこの程度 |"
echo "| 過去は ~3h で数百 | **今回だけ絞られている。** 再投稿が効いた疑いが濃い |"
echo "| 記録が 2〜3 本しか無い | **まだ比べられない。** 数日 溜めてから判断する |"
echo
echo "**「たぶん X に絞られている」とは、数字が揃うまで言わない**（最上位ルール 11）。"
echo
echo "### 時間帯の話は、これだけでは出せない"
echo
echo "出した時刻は **00:26 と 18:23 の 2 点**しか無い。"
echo "**2 点で「夕方が弱い」とは言えない。** 時間帯を言うには、"
echo "同じ内容を違う時刻に出した記録が要る。"

echo
echo "## 5. 費用"
echo
echo "**ログを読んで DOM を 4 回 読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "記録ジョブ \`com.dailyhack.x-impressions\`（3 時間おき）も **\$0**。DOM を読むだけ。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "表示回数の曲線を比べた / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
