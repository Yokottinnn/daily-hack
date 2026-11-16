#!/bin/bash
# **t697 の続き。球団と Tリーグの決算公告の「表の数字」を出す（t698）。** 読むだけ・LLM 不使用・$0／回。
# t697 は数字だけの行を落としていた。各社ページの「官報決算 決算一覧」〜「最後に取得した資料」の間をそのまま出す。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t698-npb-tleague-nums.md"
mkdir -p "$RDIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36"
TMP="$(mktemp -d)"
{ echo "# 球団・Tリーグの決算公告の数字（t698・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"

curl -sSL --max-time 25 -A "$UA" -o "$TMP/list.html" "https://catr.jp/categories/1"
grep -o 'href="/companies/[^"]*"' "$TMP/list.html" | sed 's/href="//;s/"$//' | sort -u > "$TMP/links.txt"
echo "https://catr.jp/companies/5e667/157317" > "$TMP/extra.txt"
i=0
while IFS= read -r p || [ -n "$p" ]; do
  i=$((i+1)); case "$p" in http*) u="$p";; *) u="https://catr.jp$p";; esac
  curl -sSL --max-time 25 -A "$UA" -o "$TMP/c$i.html" "$u"; echo "$u" > "$TMP/c$i.url"
done < <(cat "$TMP/links.txt" "$TMP/extra.txt")
echo "取得: **$i** ページ" >> "$OUT"

node - "$TMP" "$i" >> "$OUT" <<'JS'
const fs=require('fs');const dir=process.argv[2];const n=+process.argv[3];
const CLUB=/(ホークス|タイガース|ベイスターズ|カープ|ライオンズ|楽天野球団|ファイターズ|マリーンズ|ヤクルト球団|オリックス野球|ドラゴンズ|巨人軍|Tリーグ)/;
for(let i=1;i<=n;i++){
  let h; try{h=fs.readFileSync(`${dir}/c${i}.html`,'utf8')}catch(e){continue}
  const title=((h.match(/<title>([^<]*)<\/title>/)||[])[1]||'').trim();
  const name=title.split('の会社情報')[0];
  if(!CLUB.test(name)||/スポーツ&|エンターテイメント|ハヤテ|新潟/.test(name)) continue;
  const L=h.replace(/<script[\s\S]*?<\/script>/g,'').replace(/<style[\s\S]*?<\/style>/g,'').replace(/<br\s*\/?>/g,'\n').replace(/<\/(tr|p|div|li|h\d|th|td|dt|dd|span)>/g,'\n').replace(/<[^>]+>/g,' ').replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').replace(/[ \t]+/g,' ').split('\n').map(s=>s.trim()).filter(Boolean);
  const a=L.findIndex(s=>s.includes('官報決算 決算一覧')||s==='官報決算'); const b=L.findIndex((s,k)=>k>a&&s.includes('最後に取得した資料'));
  const url=fs.readFileSync(`${dir}/c${i}.url`,'utf8').trim();
  console.log(`\n## ${name}\n\n${url}\n\n\`\`\`text`);
  console.log((a>=0?L.slice(a,b>a?b:a+80):['（表が見つからない）']).slice(0,80).join('\n'));
  console.log('```');
}
JS
rm -rf "$TMP"; cat "$OUT"
