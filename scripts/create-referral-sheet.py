#!/usr/bin/env python3
"""紹介リンク台帳 スプレッドシートを作成し、サービス行を seed して Jordan に共有。
認証: SAキー（gsc-bot、activate-service-account済み・gcloud auth login不要）。
Jordan が 紹介URL/コード/ログイン情報 を直接埋め込む台帳。"""
import json, subprocess, urllib.request, urllib.error, pathlib

SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
JORDAN = "n-yokota@fieldbeside.com"
ROOT = pathlib.Path(__file__).resolve().parent.parent
SEED = json.load(open("/tmp/referral-seed.json"))

def tok(scopes):
    r = subprocess.run(["gcloud","auth","print-access-token",f"--account={SA}",f"--scopes={','.join(scopes)}"],
                       capture_output=True, text=True, check=True)
    return r.stdout.strip()

def http(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            x=r.read(); return r.status, (json.loads(x) if x else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")

t = tok(["https://www.googleapis.com/auth/spreadsheets","https://www.googleapis.com/auth/drive"])

# 1) 作成
st, sp = http("POST","https://sheets.googleapis.com/v4/spreadsheets", t,
  {"properties":{"title":"Daily Hack 紹介リンク台帳"},"sheets":[{"properties":{"title":"紹介リンク"}}]})
sid = sp.get("spreadsheetId"); url = sp.get("spreadsheetUrl")
assert sid, sp
print("created", sid)

# 2) ヘッダ + seed 行
headers = ["カテゴリ","サービス名","id(referrals.ts)","紹介URL(招待リンク)","紹介コード","ログインID","パスワード","報酬:紹介者","報酬:被紹介者","条件","有効(Y/N)","備考"]
rows=[headers]
for r in SEED:
    if not r.get("name"): continue
    rows.append([r["cat"], r["name"], r["id"], r.get("url",""), r.get("code",""), "", "", r.get("reward",""), "", "", "N", "← 紹介URL/コード/ログインを記入してください"])
http("PUT", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}/values/%E7%B4%B9%E4%BB%8B%E3%83%AA%E3%83%B3%E3%82%AF!A1?valueInputOption=RAW", t, {"values":rows})

# 3) 書式（ヘッダ太字・freeze・列幅）
meta_st, meta = http("GET", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}?fields=sheets.properties", t)
gid = meta["sheets"][0]["properties"]["sheetId"]
http("POST", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}:batchUpdate", t, {"requests":[
  {"updateSheetProperties":{"properties":{"sheetId":gid,"gridProperties":{"frozenRowCount":1}},"fields":"gridProperties.frozenRowCount"}},
  {"repeatCell":{"range":{"sheetId":gid,"startRowIndex":0,"endRowIndex":1},"cell":{"userEnteredFormat":{"textFormat":{"bold":True},"backgroundColor":{"red":0.84,"green":0.24,"blue":0.46},"horizontalAlignment":"CENTER"}},"fields":"userEnteredFormat(textFormat,backgroundColor,horizontalAlignment)"}},
  {"repeatCell":{"range":{"sheetId":gid,"startRowIndex":0,"endRowIndex":1},"cell":{"userEnteredFormat":{"textFormat":{"foregroundColor":{"red":1,"green":1,"blue":1},"bold":True}}},"fields":"userEnteredFormat.textFormat"}},
  {"autoResizeDimensions":{"dimensions":{"sheetId":gid,"dimension":"COLUMNS","startIndex":0,"endIndex":12}}},
]})

# 4) Jordan に編集者共有
ps, pr = http("POST", f"https://www.googleapis.com/drive/v3/files/{sid}/permissions?sendNotificationEmail=false", t,
  {"role":"writer","type":"user","emailAddress":JORDAN})
print("share status", ps)

# 5) 記録
meta_path = ROOT/"tmp"/"referral-sheet.json"
meta_path.write_text(json.dumps({"sheet_id":sid,"url":url}, ensure_ascii=False, indent=2))
print("URL:", url)
