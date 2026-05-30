#!/usr/bin/env python3
"""
記事DB ↔ Google Sheets 同期スクリプト。

- 初回: Google Drive 上に「Daily Hack 記事DB」スプレッドシートを作成し、
        Jordan (n-yokota@fieldbeside.com) を Writer として共有。シートIDを tmp/article-db.json に保存。
- 2回目以降: 既存シートに以下3タブを再生成 + 上書き
    1) 公開済記事  : src/content/posts/*.md の frontmatter から
    2) GSC上位クエリ : Search Console から過去30日の上位クエリ
    3) 記事候補     : tmp/article-candidates.json があれば反映、なければ既定の初期候補を生成

認証: gcloud user → gsc-bot SA impersonation（鍵不要）。
"""
import json, os, re, subprocess, sys, urllib.parse, urllib.request, datetime, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
POSTS_DIR = ROOT / "src/content/posts"
TMP_DIR = ROOT / "tmp"
TMP_DIR.mkdir(exist_ok=True)
DB_META = TMP_DIR / "article-db.json"
CANDIDATES_JSON = TMP_DIR / "article-candidates.json"

SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
JORDAN_EMAIL = "n-yokota@fieldbeside.com"
SITE = "https://daily-hack.fieldbeside.com/"
SHEET_TITLE = "Daily Hack 記事DB"

def imp_token(scopes):
    r = subprocess.run(
        ["gcloud", "auth", "print-access-token",
         f"--impersonate-service-account={SA}",
         f"--scopes={','.join(scopes)}"],
        capture_output=True, text=True, check=True)
    return r.stdout.strip()

def http(method, url, token, body=None, content_type="application/json"):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": content_type})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            txt = r.read()
            return r.status, json.loads(txt) if txt else {}
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"{}")
        except Exception: return e.code, {"raw": str(e)}

# ---------- frontmatter parse ----------
def parse_fm(text):
    m = re.match(r"^---\n([\s\S]*?)\n---\n([\s\S]*)$", text)
    if not m: return {}, text
    yaml, body = m.group(1), m.group(2)
    data = {}
    for line in yaml.split("\n"):
        ma = re.match(r"^([a-zA-Z_][\w-]*):\s*(.*)$", line)
        if not ma: continue
        k, v = ma.group(1), ma.group(2).strip()
        if v.startswith("[") and v.endswith("]"):
            v = [s.strip().strip('"').strip("'") for s in v[1:-1].split(",") if s.strip()]
        elif v.startswith('"') and v.endswith('"'):
            v = v[1:-1]
        elif v == "true": v = True
        elif v == "false": v = False
        data[k] = v
    return data, body

def collect_posts():
    posts = []
    for p in sorted(POSTS_DIR.glob("*.md")):
        data, body = parse_fm(p.read_text(encoding="utf-8"))
        slug = p.stem
        posts.append({
            "slug": slug,
            "title": data.get("title", ""),
            "publishDate": str(data.get("publishDate", "")),
            "category": ", ".join(data.get("category", []) if isinstance(data.get("category"), list) else [data.get("category", "")]) ,
            "tags": ", ".join(data.get("tags", []) if isinstance(data.get("tags"), list) else []),
            "isPR": "Y" if data.get("isPR") else "",
            "draft": "Y" if data.get("draft") else "",
            "featured": "Y" if data.get("featured") else "",
            "eyecatchUrl": data.get("eyecatchUrl", ""),
            "wordCount": len(body),
            "url": f"{SITE.rstrip('/')}/posts/{slug}/",
        })
    return posts

# ---------- GSC data ----------
def fetch_gsc_top_queries(token, days=30, row_limit=50):
    end = datetime.date.today()
    start = end - datetime.timedelta(days=days)
    code, res = http("POST",
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{urllib.parse.quote(SITE,safe='')}/searchAnalytics/query",
        token, body={"startDate": str(start), "endDate": str(end),
                     "dimensions": ["query"], "rowLimit": row_limit, "type": "web"})
    rows = (res or {}).get("rows", [])
    return [{"query": r["keys"][0], "clicks": int(r["clicks"]),
             "impressions": int(r["impressions"]),
             "ctr": round(r["ctr"]*100, 2), "position": round(r["position"], 1)} for r in rows]

def fetch_gsc_page_stats(token, days=30, row_limit=200):
    end = datetime.date.today()
    start = end - datetime.timedelta(days=days)
    code, res = http("POST",
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{urllib.parse.quote(SITE,safe='')}/searchAnalytics/query",
        token, body={"startDate": str(start), "endDate": str(end),
                     "dimensions": ["page"], "rowLimit": row_limit, "type": "web"})
    rows = (res or {}).get("rows", [])
    return {r["keys"][0]: {"clicks": int(r["clicks"]),
            "impressions": int(r["impressions"]),
            "ctr": round(r["ctr"]*100, 2),
            "position": round(r["position"], 1)} for r in rows}

# ---------- default candidates (記事候補ライブラリ) ----------
# 戦略: @ryuji_affiliate (2026-05-23) — 金融/保険/転職/脱毛/FX の高単価案件(5,000〜50,000円)を最優先
# est_reward は A8 ASP 経由の概算報酬レンジ（取れた時の天井寄り）
DEFAULT_CANDIDATES = [
    # ===== 🟥 最優先: 高単価 金融（カードローン/FX/暗号資産/住宅ローン/保険） =====
    {"title": "カードローン 即日融資 7社比較 2026 — 金利・限度額・在籍確認ナシ",
     "category": "comparisons,howto", "source": "高単価金融", "priority": "high",
     "monetization": "カードローン申込", "est_reward": "10,000-25,000円/件",
     "notes": "申込単価が最も高い。三井住友/プロミス/アコム/SMBCモビット/レイク/オリックス/楽天銀行"},
    {"title": "FX口座 おすすめ8社比較 2026 — 初心者向けスプレッド・キャッシュバック比較",
     "category": "comparisons,howto", "source": "高単価金融", "priority": "high",
     "monetization": "FX口座開設", "est_reward": "15,000-30,000円/件",
     "notes": "DMM FX/外為どっとコム/みんなのFX/GMOクリック/楽天/松井/SBI/マネックス"},
    {"title": "DMM FX 口座開設キャンペーン徹底解説 2026 — 最大30万円キャッシュバック達成手順",
     "category": "campaigns,howto", "source": "高単価金融/単発", "priority": "high",
     "monetization": "FX口座開設", "est_reward": "15,000-30,000円/件"},
    {"title": "暗号資産取引所 おすすめ5社比較 2026 — 手数料・スプレッド・取り扱い銘柄",
     "category": "comparisons", "source": "高単価金融", "priority": "high",
     "monetization": "暗号資産口座開設", "est_reward": "10,000-30,000円/件",
     "notes": "Coincheck/bitFlyer/GMOコイン/DMM Bitcoin/SBI VC"},
    {"title": "住宅ローン 借り換え 最新比較 2026 — 変動・固定・ネット銀行で月いくら下がる",
     "category": "comparisons,howto", "source": "高単価金融", "priority": "high",
     "monetization": "住宅ローン相談", "est_reward": "10,000-50,000円/件",
     "notes": "auじぶん銀行/住信SBI/ソニー銀行/りそな/イオン銀行"},

    # ===== 🟧 高優先: 保険 =====
    {"title": "自動車保険 一括見積もり 8社比較 2026 — 年間5万円差つく選び方",
     "category": "comparisons,howto", "source": "高単価保険", "priority": "high",
     "monetization": "保険見積もり依頼", "est_reward": "3,000-10,000円/件"},
    {"title": "医療保険 おすすめ7選 2026 — 入院日額・先進医療・がん特約で選ぶ",
     "category": "comparisons", "source": "高単価保険", "priority": "high",
     "monetization": "保険資料請求/相談", "est_reward": "5,000-15,000円/件"},
    {"title": "がん保険 比較 2026 — 一時金型 vs 治療費連動型 どっち選ぶ",
     "category": "comparisons", "source": "高単価保険", "priority": "high",
     "monetization": "保険資料請求", "est_reward": "5,000-15,000円/件"},
    {"title": "学資保険 vs 新NISA 子どもの教育費 月3万でどこまで貯まるか",
     "category": "comparisons,howto", "source": "高単価保険+NISA", "priority": "high",
     "monetization": "保険+証券口座", "est_reward": "5,000-20,000円/件"},
    {"title": "ペット保険 おすすめ5社比較 2026 — 補償範囲・更新拒否・口コミ",
     "category": "comparisons", "source": "高単価保険", "priority": "med",
     "monetization": "ペット保険申込", "est_reward": "3,000-8,000円/件"},

    # ===== 🟧 高優先: 転職 =====
    {"title": "30代向け転職エージェント TOP5 比較 2026 — リクルート/doda/ビズリーチ徹底解説",
     "category": "comparisons,howto", "source": "高単価転職", "priority": "high",
     "monetization": "転職サイト登録", "est_reward": "3,000-10,000円/件"},
    {"title": "エンジニア転職 おすすめサービス10選 2026 — レバテック・Findy・Forkwell ほか",
     "category": "comparisons", "source": "高単価転職", "priority": "high",
     "monetization": "転職登録", "est_reward": "5,000-15,000円/件"},
    {"title": "ハイクラス転職 ビズリーチ vs リクルートダイレクトスカウト vs JACリクルートメント",
     "category": "comparisons", "source": "高単価転職", "priority": "med",
     "monetization": "ハイクラス転職", "est_reward": "8,000-20,000円/件"},
    {"title": "リモートワーク特化型 転職サービス 2026年最新版 — リモートOK率90%超え",
     "category": "comparisons", "source": "高単価転職+トレンド", "priority": "med",
     "monetization": "転職登録", "est_reward": "3,000-10,000円/件"},

    # ===== 🟧 高優先: 脱毛 =====
    {"title": "メンズ脱毛 おすすめ5社比較 2026 — 医療 vs サロン コスパ最強はどこ",
     "category": "comparisons,howto", "source": "高単価脱毛", "priority": "high",
     "monetization": "脱毛無料カウンセリング", "est_reward": "5,000-15,000円/件"},
    {"title": "医療脱毛 全身5回コース料金比較 2026 — リゼ・湘南・アリシア・エミナル",
     "category": "comparisons", "source": "高単価脱毛", "priority": "high",
     "monetization": "脱毛カウンセリング", "est_reward": "5,000-15,000円/件"},
    {"title": "VIO脱毛 男女別おすすめクリニック5選 2026 — 料金・通いやすさ・痛みレベル",
     "category": "comparisons", "source": "高単価脱毛", "priority": "med",
     "monetization": "脱毛申込", "est_reward": "5,000-12,000円/件"},

    # ===== 🟨 中: NISA・投資 系（GSCの「クレカ」隣接で需要強い）=====
    {"title": "新NISA成長投資枠 おすすめ高配当ETF 5選 2026年版",
     "category": "comparisons,howto", "source": "growth_compass", "priority": "high",
     "monetization": "証券口座開設", "est_reward": "3,000-10,000円/件"},
    {"title": "新NISA つみたて投資枠 全インデックス比較 信託報酬ランキング 2026",
     "category": "comparisons", "source": "growth_compass", "priority": "high",
     "monetization": "証券口座開設", "est_reward": "3,000-10,000円/件"},
    {"title": "iDeCo はSBI・楽天・マネックスどれ？ 2026最新版徹底比較",
     "category": "comparisons", "source": "gap", "priority": "high",
     "monetization": "iDeCo口座開設", "est_reward": "5,000-10,000円/件"},

    # ===== 🟨 中: キャッシュレス・QR決済 系 =====
    {"title": "吉野家・すき家・松屋・なか卯 牛丼チェーン4社の最強コード決済比較 2026年版",
     "category": "comparisons,howto", "source": "trend/松屋60周年", "priority": "high",
     "monetization": "クレカ/QR決済アフィ", "est_reward": "1,000-5,000円/件",
     "notes": "牛丼系で松屋以外もキャンペーン頻発、横断比較で検索ボリューム大"},
    {"title": "ファミマ・ローソン・セブン コンビニ3社の決済キャンペーン徹底比較 2026",
     "category": "comparisons,howto", "source": "GSC隣接", "priority": "high",
     "monetization": "QR決済アフィ"},
    {"title": "PayPay vs 楽天ペイ vs d払い vs au PAY 2026年最新 完全比較",
     "category": "comparisons", "source": "GSC隣接/松屋記事の親", "priority": "high",
     "monetization": "QR/クレカアフィ"},

    # NISA・投資 系（GSCの「クレカ」隣接で需要強い）
    {"title": "新NISA成長投資枠 おすすめ高配当ETF 5選 2026年版",
     "category": "comparisons,howto", "source": "growth_compass", "priority": "high"},
    {"title": "新NISA つみたて投資枠 全インデックス比較 信託報酬ランキング 2026",
     "category": "comparisons", "source": "growth_compass", "priority": "high"},
    {"title": "投資信託 5年リターンで選ぶ オルカン vs S&P500 vs FANG+",
     "category": "comparisons", "source": "trend", "priority": "med"},
    {"title": "iDeCo はSBI・楽天・マネックスどれ？ 2026最新版徹底比較",
     "category": "comparisons", "source": "gap", "priority": "high"},

    # ふるさと納税 系 — シーズン前先取り
    {"title": "ふるさと納税 2026年 還元率ランキング 鉄板返礼品20選",
     "category": "roundups,howto", "source": "seasonal", "priority": "high"},
    {"title": "【ふるさと納税】寄付額別 おすすめ返礼品 1万円/3万円/5万円コース",
     "category": "roundups", "source": "GSC", "priority": "med"},
    {"title": "ふるさと納税 ポイント還元廃止後の最適サイト比較 2026",
     "category": "comparisons", "source": "policy_change", "priority": "high",
     "notes": "memory: project_furusato_pointback_ban、必須対応"},

    # 旅行 系（夏休み手前）
    {"title": "夏休み2026 国内コスパ旅TOP10 — ファミリー向け予算別",
     "category": "roundups,howto", "source": "seasonal", "priority": "high"},
    {"title": "夏ボーナス20万円の使い方 — 投資・旅行・固定費削減の最適配分",
     "category": "howto,comparisons", "source": "seasonal", "priority": "high"},
    {"title": "Go To Travel 後継 全国旅行支援は2026年どうなる？最新まとめ",
     "category": "roundups", "source": "trend", "priority": "med"},

    # クレカ追加（GSC top queries から）
    {"title": "ヨドバシゴールドポイントカード・プラス 入会キャンペーン徹底解説 2026",
     "category": "campaigns,howto", "source": "GSC query", "priority": "high",
     "notes": "GSC top query: 'ヨドバシ カード 入会キャンペーン'"},
    {"title": "リクルートカード 学生申込のメリット・審査・即時発行可否",
     "category": "howto", "source": "GSC query", "priority": "med",
     "notes": "GSC top query: 'リクルートカード 学生'"},
    {"title": "Amazon支払い d払い vs dカード どっちが得？比較と使い分け",
     "category": "comparisons,howto", "source": "GSC query", "priority": "high",
     "notes": "GSC top query: 'amazon d払い dカード どっちが得'"},
    {"title": "還元率最強クレカ 2026年最新版 — シーン別ベスト1選",
     "category": "comparisons,roundups", "source": "GSC query", "priority": "high",
     "notes": "GSC top query: 'クレジットカード 還元率 最強'"},

    # 湾岸ライフ追加
    {"title": "晴海・勝どき・月島・豊洲 ランチコスパ最強10選 2026",
     "category": "wangan-life,roundups", "source": "internal/wangan拡張", "priority": "med"},
    {"title": "HARUMI FLAG 住んでわかった本音レポ 良かった点・想定外3カ月",
     "category": "wangan-life", "source": "narrative", "priority": "med"},
    {"title": "湾岸ライフ 引越し業者比較 — 中央区・江東区エリア最強5社",
     "category": "wangan-life,comparisons", "source": "gap", "priority": "med"},

    # 通信・固定費追加
    {"title": "格安SIM 通信品質比較 2026 — IIJmio/mineo/povo/ahamo/楽天モバイル 実測",
     "category": "comparisons", "source": "gap", "priority": "high"},
    {"title": "電気代節約 6月の効くアクション5つ — エアコン使用前にやる初期設定",
     "category": "howto", "source": "seasonal", "priority": "med"},

    # ライフハック・節約
    {"title": "サブスク棚卸し2026 — 月3万円浮かす診断チェックリスト",
     "category": "howto,roundups", "source": "trend", "priority": "high"},
    {"title": "Amazon Prime Day 2026 完全攻略 事前準備 + 当日チェックリスト",
     "category": "campaigns,howto", "source": "seasonal", "priority": "high"},
    {"title": "楽天お買い物マラソン 完全攻略 — SPU + ふるさと納税で還元最大化",
     "category": "howto", "source": "evergreen", "priority": "high"},

    # 仕事・副業（ハイブリッド）
    {"title": "Claude/ChatGPT で副業ライティング 月5万を作る現実的手順 2026",
     "category": "howto", "source": "trend", "priority": "med"},
]

def build_default_candidates():
    base = []
    for i, c in enumerate(DEFAULT_CANDIDATES, 1):
        c.setdefault("notes", "")
        c.setdefault("status", "idea")
        c.setdefault("est_publish", "")
        base.append({**c, "id": f"C{i:03d}"})
    return base

# ---------- Sheets API helpers ----------
def create_or_get_sheet(sheets_tok, drive_tok):
    if DB_META.exists():
        meta = json.loads(DB_META.read_text())
        sid = meta.get("sheet_id")
        if sid:
            code, res = http("GET", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}", sheets_tok)
            if code == 200:
                print(f"  既存シート利用: {sid}")
                return sid, meta.get("url")
    # 新規作成
    code, res = http("POST", "https://sheets.googleapis.com/v4/spreadsheets", sheets_tok,
        body={"properties": {"title": SHEET_TITLE}})
    if code != 200:
        print("  シート作成失敗", code, res); sys.exit(2)
    sid = res["spreadsheetId"]
    url = res["spreadsheetUrl"]
    print(f"  新規シート作成: {sid}\n  URL: {url}")
    # Jordan を Writer として共有
    code, res = http("POST",
        f"https://www.googleapis.com/drive/v3/files/{sid}/permissions?sendNotificationEmail=true",
        drive_tok, body={"type": "user", "role": "writer", "emailAddress": JORDAN_EMAIL})
    print(f"  共有 status={code}")
    DB_META.write_text(json.dumps({"sheet_id": sid, "url": url}, ensure_ascii=False, indent=2))
    return sid, url

def replace_sheet_tab(sheets_tok, sid, tab_title, headers, rows):
    """指定タブを (なければ作成して) クリアし、ヘッダー＋データで上書き。"""
    # 既存メタ取得
    code, meta = http("GET", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}", sheets_tok)
    existing = {s["properties"]["title"]: s["properties"]["sheetId"] for s in meta.get("sheets", [])}
    requests = []
    if tab_title not in existing:
        requests.append({"addSheet": {"properties": {"title": tab_title}}})
    if requests:
        http("POST", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}:batchUpdate", sheets_tok,
            body={"requests": requests})
    # クリア
    http("POST",
        f"https://sheets.googleapis.com/v4/spreadsheets/{sid}/values/{urllib.parse.quote(tab_title)}:clear",
        sheets_tok, body={})
    # 書込み
    values = [headers] + [[str(r.get(h, "")) for h in headers] for r in rows]
    http("PUT",
        f"https://sheets.googleapis.com/v4/spreadsheets/{sid}/values/{urllib.parse.quote(tab_title)}!A1?valueInputOption=RAW",
        sheets_tok, body={"values": values})
    # ヘッダー固定 + 太字
    code, meta = http("GET", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}", sheets_tok)
    sheet_id = next(s["properties"]["sheetId"] for s in meta["sheets"] if s["properties"]["title"] == tab_title)
    http("POST", f"https://sheets.googleapis.com/v4/spreadsheets/{sid}:batchUpdate", sheets_tok,
        body={"requests": [
            {"updateSheetProperties": {"properties": {"sheetId": sheet_id, "gridProperties": {"frozenRowCount": 1}}, "fields": "gridProperties.frozenRowCount"}},
            {"repeatCell": {"range": {"sheetId": sheet_id, "startRowIndex": 0, "endRowIndex": 1},
                "cell": {"userEnteredFormat": {"textFormat": {"bold": True}, "backgroundColor": {"red": 0.92, "green": 0.92, "blue": 0.96}}},
                "fields": "userEnteredFormat(textFormat,backgroundColor)"}},
            {"autoResizeDimensions": {"dimensions": {"sheetId": sheet_id, "dimension": "COLUMNS",
                "startIndex": 0, "endIndex": len(headers)}}}
        ]})

def main():
    sheets_tok = imp_token(["https://www.googleapis.com/auth/spreadsheets",
                            "https://www.googleapis.com/auth/drive"])
    drive_tok = sheets_tok  # 同じscopes
    gsc_tok = imp_token(["https://www.googleapis.com/auth/webmasters"])

    print("=== 1. Sheet 確認/作成 ===")
    sid, url = create_or_get_sheet(sheets_tok, drive_tok)

    print("\n=== 2. 公開済記事 タブ ===")
    posts = collect_posts()
    stats = fetch_gsc_page_stats(gsc_tok, days=30)
    for p in posts:
        s = stats.get(p["url"], {})
        p["clicks_30d"] = s.get("clicks", 0)
        p["impressions_30d"] = s.get("impressions", 0)
        p["ctr_30d"] = s.get("ctr", 0)
        p["position_30d"] = s.get("position", "")
    posts.sort(key=lambda p: (-(p["impressions_30d"] or 0), -(p["clicks_30d"] or 0)))
    headers = ["slug", "title", "publishDate", "category", "tags", "isPR", "featured",
               "clicks_30d", "impressions_30d", "ctr_30d", "position_30d", "wordCount", "url"]
    replace_sheet_tab(sheets_tok, sid, "公開済記事", headers, posts)
    print(f"  公開済記事 = {len(posts)} 件")

    print("\n=== 3. GSC上位クエリ タブ ===")
    queries = fetch_gsc_top_queries(gsc_tok, days=30, row_limit=50)
    headers2 = ["query", "clicks", "impressions", "ctr", "position"]
    replace_sheet_tab(sheets_tok, sid, "GSC上位クエリ", headers2, queries)
    print(f"  クエリ = {len(queries)} 件")

    print("\n=== 4. 記事候補 タブ ===")
    if CANDIDATES_JSON.exists():
        cands = json.loads(CANDIDATES_JSON.read_text())
        print("  → tmp/article-candidates.json を反映")
    else:
        cands = build_default_candidates()
        CANDIDATES_JSON.write_text(json.dumps(cands, ensure_ascii=False, indent=2))
        print(f"  → 初期 {len(cands)} 候補を生成、tmp/article-candidates.json に保存")
    headers3 = ["id", "title", "category", "source", "priority", "est_reward", "status",
                "est_publish", "monetization", "notes"]
    replace_sheet_tab(sheets_tok, sid, "記事候補", headers3, cands)
    print(f"  候補 = {len(cands)} 件")

    print(f"\n=== ✅ DONE ===\n  Sheet: {url}\n  共有: {JORDAN_EMAIL} (Writer)")

if __name__ == "__main__":
    main()
