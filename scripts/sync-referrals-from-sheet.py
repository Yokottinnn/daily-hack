#!/usr/bin/env python3
"""紹介リンク台帳タブ → src/data/referrals.ts へ同期。
紹介コード or 招待リンクが「ある」サービスのみ code/affiliateUrl/url/isActive を更新。
認証: SAキー（gsc-bot）。"""
import json, subprocess, urllib.request, urllib.parse, re, pathlib
SA="gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SID="1cCqUpQoD0oNYkT8xmZvDKu9JlCL5pfdNkLkcraWS5nY"
TAB="紹介リンク台帳"
TS=pathlib.Path(__file__).resolve().parent.parent/"src/data/referrals.ts"
def tok(sc): return subprocess.run(["gcloud","auth","print-access-token",f"--account={SA}",f"--scopes={','.join(sc)}"],capture_output=True,text=True,check=True).stdout.strip()
t=tok(["https://www.googleapis.com/auth/spreadsheets"])
u=f"https://sheets.googleapis.com/v4/spreadsheets/{SID}/values/{urllib.parse.quote(TAB)}"
v=json.load(urllib.request.urlopen(urllib.request.Request(u,headers={"Authorization":f"Bearer {t}"}),timeout=40)).get("values",[])
def clean(x):
    x=(x or "").strip()
    return "" if x in ("","なし","-","N/A") else x
updates={}
for row in v[1:]:
    row=row+['']*13
    cat,name,id_,lp,inv,code,lid,pw,r1,r2,cond,active,memo=row[:13]
    id_=clean(id_);
    if not id_: continue
    lp=clean(lp); inv=clean(inv); code=clean(code)
    if code or inv:  # 紹介コード or 招待リンクがあるものだけ有効化
        updates[id_]={"lp":lp,"inv":inv,"code":code}
print("有効化対象:", list(updates.keys()))

src=TS.read_text()
def esc(s): return s.replace("'","\\'")
def patch_entry(block):
    m=re.search(r"id:\s*'([^']+)'", block)
    if not m: return block
    eid=m.group(1)
    if eid not in updates: return block
    up=updates[eid]
    b=block
    # url(LP)
    if up["lp"]:
        if re.search(r"url:\s*'[^']*'", b): b=re.sub(r"url:\s*'[^']*'", f"url: '{esc(up['lp'])}'", b, count=1)
    # code
    if up["code"]:
        if re.search(r"code:\s*'[^']*'", b): b=re.sub(r"code:\s*'[^']*'", f"code: '{esc(up['code'])}'", b, count=1)
        else: b=b.replace(f"id: '{eid}'", f"id: '{eid}',\n    code: '{esc(up['code'])}'",1)
    # affiliateUrl(招待リンク)
    if up["inv"]:
        if re.search(r"affiliateUrl:\s*'[^']*'", b): b=re.sub(r"affiliateUrl:\s*'[^']*'", f"affiliateUrl: '{esc(up['inv'])}'", b, count=1)
        else: b=b.replace(f"id: '{eid}'", f"id: '{eid}',\n    affiliateUrl: '{esc(up['inv'])}'",1)
    # isActive:true
    if re.search(r"isActive:\s*(true|false)", b): b=re.sub(r"isActive:\s*(true|false)", "isActive: true", b, count=1)
    return b
# エントリ単位（ネスト無し）で置換
out=re.sub(r"\{[^{}]*?serviceName[^{}]*?\}", lambda mm: patch_entry(mm.group(0)), src, flags=re.S)
TS.write_text(out)
print("referrals.ts updated:", len(updates), "entries activated")
