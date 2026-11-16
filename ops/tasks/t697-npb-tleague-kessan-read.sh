#!/bin/bash
# **プロ野球の球団と Tリーグの決算公告（官報）の一覧を読む（t697）。** 読むだけ・LLM 不使用・$0／回。
# 2026-11-15 利用者がダイアログで「野球・卓球の比較ももっと掘って」を選んだ。Jリーグ記事の入場料収入の比較に使う。
# catr.jp は官報の決算公告を会社ごとに転記しているサイト（ログイン不要の公開ページ）。クラウドからは 403 で開けない。
# 本文から必要な行（会社名・決算期・売上高・純利益・官報の日付）だけを抜き出して出す。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t697-npb-tleague-kessan.md"
mkdir -p "$RDIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36"
TMP="$(mktemp -d)"

{
  echo "# プロ野球・Tリーグの決算公告（t697・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

fetch() { # $1=URL $2=保存名
  local code
  code="$(curl -sSL --max-time 25 -A "$UA" -o "$TMP/$2" -w '%{http_code}' "$1" 2>/dev/null)"
  echo "- \`$1\` → HTTP **$code**・$(wc -c < "$TMP/$2" 2>/dev/null | tr -d ' ') bytes" >> "$OUT"
}

fetch "https://catr.jp/categories/1" list1.html
fetch "https://catr.jp/categories/1?page=2" list2.html
fetch "https://catr.jp/companies/5e667/157317" tleague.html

# 一覧から各社のページを拾う（球団に関係する会社だけ・最大 30 社）
cat "$TMP"/list1.html "$TMP"/list2.html 2>/dev/null | grep -o 'href="/companies/[^"]*"' | sed 's/href="//;s/"$//' | sort -u | head -30 > "$TMP/links.txt"
n=$(wc -l < "$TMP/links.txt" | tr -d ' ')
echo "" >> "$OUT"; echo "一覧から拾った会社のページ: **$n** 件" >> "$OUT"; echo "" >> "$OUT"

i=0
while IFS= read -r p || [ -n "$p" ]; do
  i=$((i+1))
  fetch "https://catr.jp$p" "c$i.html"
done < "$TMP/links.txt"

# 本文を文字だけにして、要る行だけ出す
node - "$TMP" "$n" >> "$OUT" <<'JS'
const fs=require('fs');const dir=process.argv[2];const n=+process.argv[3];
const txt=f=>{try{return fs.readFileSync(f,'utf8').replace(/<script[\s\S]*?<\/script>/g,'').replace(/<style[\s\S]*?<\/style>/g,'').replace(/<br\s*\/?>/g,'\n').replace(/<\/(tr|p|div|li|h\d|th|td)>/g,'\n').replace(/<[^>]+>/g,' ').replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').replace(/[ \t]+/g,' ').split('\n').map(s=>s.trim()).filter(Boolean)}catch(e){return []}};
const KEEP=/(株式会社|社団法人|決算|官報|売上|営業収益|当期純|純利益|純損失|利益剰余金|総資産|第\d+期|年\d+月期|掲載)/;
const files=['list1.html','tleague.html'].concat(Array.from({length:n},(_,i)=>`c${i+1}.html`));
for(const f of files){
  const L=txt(`${dir}/${f}`); if(!L.length) continue;
  const title=(fs.readFileSync(`${dir}/${f}`,'utf8').match(/<title>([^<]*)<\/title>/)||[])[1]||f;
  console.log(`\n## ${title.trim()}\n\n\`\`\`text`);
  console.log(L.filter(s=>KEEP.test(s)&&s.length<200).slice(0,60).join('\n'));
  console.log('```');
}
JS
rm -rf "$TMP"
cat "$OUT"
