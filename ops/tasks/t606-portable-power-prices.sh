#!/bin/bash
# **ポータブル電源の記事の 3 店ボタン: must・exclude で別商品を拾っていないかを読む（t606・blog3・読むだけ・$0）。**
# 2026-11-13 利用者がダイアログで「作戦室の構想から比較記事を書く」を選んだ（構想 portable-power-lfp-blackfriday）。楽天・Yahoo! の検索結果の上位 30 件を、
# 「当たり（must を全部含み exclude を含まない）」と「外したもの」に分けて商品名・店・価格を書き出す。鍵は Keychain から渡すだけで出さない。
# あわせて t352 と同じく全シリーズの価格を取り、当たりがあれば reports/board/shop-prices.json に置く（apply-prices.mjs で反映する）。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t606-shop-candidates-trend3.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
WORK="${TMPDIR:-/tmp}/t606"; rm -rf "$WORK"; mkdir -p "$WORK/shop-data" "$RDIR/board"
{ echo "# ポータブル電源の 3 店ボタンの候補（t606・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
git -C "$REPO" show origin/main:scripts/shop/fetch-prices.mjs > "$WORK/fetch.mjs"
for f in $(git -C "$REPO" ls-tree --name-only origin/main src/data/shop/); do git -C "$REPO" show "origin/main:$f" > "$WORK/shop-data/$(basename "$f")"; done
cat > "$WORK/cand.mjs" <<'JS'
import fs from 'node:fs';
const { RAKUTEN_APP_ID='', RAKUTEN_ACCESS_KEY='', YAHOO_APP_ID='' } = process.env;
const DEF = ['中古','ジャンク','訳あり','レンタル','交換用','専用ケース','カバーのみ','変換ケーブル','変換アダプター','交換バッテリー'];
const norm = (s) => String(s||'').normalize('NFKC').toLowerCase().replace(/\s+/g,'');
const why = (name, must=[], ex=[]) => { const n=norm(name); const miss=must.filter(m=>!n.includes(norm(m))); const bad=[...DEF,...ex].filter(x=>n.includes(norm(x))); return miss.length?'must 欠け: '+miss.join('/'):bad.length?'exclude: '+bad.join('/'):''; };
const sleep = (ms) => new Promise(r=>setTimeout(r,ms));
const hide = (s) => String(s).replace(/[A-Za-z0-9_-]{24,}/g,'［伏せた］');
async function get(u){ for(let i=0;i<3;i++){ const r=await fetch(u,{headers:{'User-Agent':'daily-hack-shop/1.0'}}); if(r.status===429){await sleep(3000*(i+1));continue;} const t=await r.text(); if(!r.ok) throw new Error('HTTP '+r.status+' '+hide(t.slice(0,120))); return JSON.parse(t);} throw new Error('429'); }
async function rk(q){ const p=new URLSearchParams({applicationId:RAKUTEN_APP_ID,accessKey:RAKUTEN_ACCESS_KEY,keyword:q.keyword,hits:'30',availability:'1',formatVersion:'2',format:'json'});
  const j=await get('https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260701?'+p); return (j.Items||j.items||[]).map(x=>x.Item||x).map(x=>({name:x.itemName,shop:x.shopName,price:x.itemPrice,url:x.itemUrl})); }
async function yh(q){ const p=new URLSearchParams({appid:YAHOO_APP_ID,query:q.keyword,results:'30',in_stock:'true'});
  const j=await get('https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch?'+p); return (j.hits||[]).map(x=>({name:x.name,shop:(x.seller||{}).name,price:x.price,url:x.url})); }
const dir=process.argv[2];
for (const s of ['portable-power']) {
  const d=JSON.parse(fs.readFileSync(`${dir}/${s}.json`,'utf8'));
  console.log(`\n## ${s}\n`);
  for (const it of d.items) {
    for (const [st,fn] of [['rakuten',rk],['yahoo',yh]]) {
      const q=it[st]; if(!q) continue;
      console.log(`### ${it.name} — ${st}（「${q.keyword}」・must ${JSON.stringify(q.must||[])}・exclude ${JSON.stringify(q.exclude||[])}${q.itemUrl?'・itemUrl 固定 '+q.itemUrl:''}）\n`);
      try { const rows=await fn(q); const ok=rows.filter(r=>!why(r.name,q.must,q.exclude)).sort((a,b)=>a.price-b.price); const ng=rows.filter(r=>why(r.name,q.must,q.exclude));
        console.log(`- 検索 ${rows.length} 件・当たり ${ok.length} 件・外した ${ng.length} 件`);
        ok.slice(0,12).forEach(r=>console.log(`  - ✅ ${r.price}円｜${r.shop}｜${r.name.slice(0,110)}｜${r.url}`));
        ng.slice(0,8).forEach(r=>console.log(`  - ✖ ${r.price}円｜${r.shop}｜${r.name.slice(0,80)}（${why(r.name,q.must,q.exclude)}）`));
      } catch(e){ console.log('- エラー: '+hide(e.message)); }
      console.log(''); await sleep(1100);
    }
    console.log(`- Amazon: 検索「${it.amazon?.keyword}」${it.amazon?.asin?'・ASIN '+it.amazon.asin:'・ASIN なし（検索結果へ飛ぶ）'}\n`);
  }
}
JS
( export RAKUTEN_APP_ID="$(security find-generic-password -s dailyhack-rakuten-ws -a applicationId -w 2>/dev/null)"
  export RAKUTEN_ACCESS_KEY="$(security find-generic-password -s dailyhack-rakuten-ws -a accessKey -w 2>/dev/null)"
  export YAHOO_APP_ID="$(security find-generic-password -s dailyhack-yahoo-shopping -a clientId -w 2>/dev/null)"
  "$NODE_BIN" "$WORK/cand.mjs" "$WORK/shop-data"
  echo ""; echo "## 全シリーズの価格（t352 と同じ）"; echo ""
  "$NODE_BIN" "$WORK/fetch.mjs" --dir "$WORK/shop-data" --out "$WORK/shop-prices.json" ) >> "$OUT" 2>&1
"$NODE_BIN" -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); let n=0;
for(const [s,rows] of Object.entries(j.series||{})) for(const r of Object.values(rows)) for(const v of Object.values(r)) if(v.found) n++;
console.log("- 当たり "+n+" 件"); process.exit(n>0?0:1)' "$WORK/shop-prices.json" >> "$OUT" 2>&1 \
  && { cp "$WORK/shop-prices.json" "$RDIR/board/shop-prices.json"; echo "- reports/board/shop-prices.json に置いた" >> "$OUT"; } \
  || echo "- 当たりが無いので置かない" >> "$OUT"
echo "rc=0 / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 60000 "$OUT"
