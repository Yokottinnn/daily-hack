#!/bin/bash
# **商品紹介記事 10 本に使うブランドのロゴ候補を、公式サイトから取る（t298）。** 取るだけ・判断しない・LLM 不使用・**$0**。
# クラウドから接続を断られた（502/403/reset）ものだけ。採否はクラウド側で目で見て決める（blog-article スキル）。
# 出力: reports/affiliate-logos/<key>-<n>-<kind>.<ext> と _found.json（公開ブランチ。ロゴと公式 URL のみ）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; DIR="$RDIR/affiliate-logos"; OUT="$RDIR/t298-affiliate-logos.md"; mkdir -p "$DIR"
PY=""; for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do command -v "$c" >/dev/null 2>&1 && PY="$c" && break; done
cat > "$DIR/sites.json" <<'JSON'
{"cloud-wifi":"https://cloud-wifi.jp/","neo-charge-wifi":"https://neo-charge-wifi.jp/","recharge-wifi":"https://recharge-wifi.jp/","dti":"https://dti.ne.jp/","otegaru-hikari":"https://otegaru-hikari.jp/","gmo-tokutoku":"https://gmobb.jp/","brandear":"https://brandear.jp/","brandoff":"https://www.brandoff.co.jp/","mobazou":"https://mobazou.com/","kakuyasu-koukuken-mall":"https://www.air-mall.jp/","j-trip":"https://www.jtrip.co.jp/","big-holiday":"https://www.bigholiday.co.jp/","aeon-compass":"https://www.aeoncompass.com/","yumeyado":"https://www.yumeyado.jp/","resort-glamping":"https://www.resort-glamping.com/","denki-choice":"https://denki-choice.com/","gas-choice":"https://gas-choice.com/","gasya-no-mado":"https://gasyanomado.jp/","haruene":"https://haruene.jp/","arcana":"https://arcana-energy.jp/","elpio":"https://www.elpio.co.jp/","so-net":"https://www.so-net.ne.jp/access/hikari/","biglobe-hikari":"https://join.biglobe.ne.jp/ftth/hikari/","biglobe-wimax":"https://join.biglobe.ne.jp/mobile/wimax/","softbank-air":"https://www.softbank.jp/internet/air/","docomo-hikari":"https://www.docomo.ne.jp/hikari/","au-hikari":"https://www.au.com/internet/","softbank-hikari":"https://www.softbank.jp/internet/hikari/","flets":"https://flets.com/","navitime-travel":"https://travel.navitime.com/","earthcar":"https://www.earthcar.jp/","aeon-rentacar":"https://www.aeonrentacar.jp/"}
JSON
cd "$DIR" && "$PY" - sites.json <<'PYEOF' > "$OUT" 2>&1
import re,sys,json,urllib.request,urllib.parse,html,os
UA={'User-Agent':'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 Chrome/126 Safari/537.36'}
def get(u,t=20):
    r=urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=t); return r.read(), r.geturl(), r.headers.get('content-type','')
sites=json.load(open(sys.argv[1]))
out={}
for key,url in sites.items():
    try:
        b,fin,ct=get(url); h=b.decode('utf-8','ignore')
    except Exception as e:
        print(key,'ERR',e); continue
    cands=[]
    for m in re.finditer(r'<img\b[^>]*>',h,re.I):
        tag=m.group(0)
        if re.search(r'logo',tag,re.I):
            src=re.search(r'\b(?:src|data-src)="([^"]+)"',tag)
            if src: cands.append(('img',src.group(1)))
    for m in re.finditer(r'<link\b[^>]*rel="(apple-touch-icon[^"]*)"[^>]*>',h,re.I):
        s=re.search(r'href="([^"]+)"',m.group(0)); 
        if s: cands.append(('touch',s.group(1)))
    og=re.search(r'<meta[^>]*property="og:image"[^>]*content="([^"]+)"',h,re.I)
    if og: cands.append(('og',og.group(1)))
    got=[]
    for kind,src in cands[:6]:
        u=urllib.parse.urljoin(fin,html.unescape(src))
        try:
            d,_,ct=get(u)
        except Exception as e: continue
        ext='svg' if (b'<svg' in d[:500] or 'svg' in ct) else ('png' if d[:4]==b'\x89PNG' else ('jpg' if d[:2]==b'\xff\xd8' else ('webp' if d[8:12]==b'WEBP' else 'bin')))
        fn=f'{key}-{len(got)}-{kind}.{ext}'; open(fn,'wb').write(d); got.append({'file':fn,'url':u,'kind':kind})
        if len(got)>=3: break
    out[key]={'page':fin,'files':got}; print(key,len(got),[g['kind'] for g in got])
json.dump(out,open('_found.json','w'),ensure_ascii=False,indent=1)
PYEOF
echo "rc=$?" >> "$OUT"; ls "$DIR" | wc -l >> "$OUT"; cat "$OUT" | head -60
