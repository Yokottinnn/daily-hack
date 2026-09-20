#!/bin/bash
# **t111 で取れなかった 2 ブランドのロゴを、別の入口から取る（t113）。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「ロゴはちゃんとそのサービスのロゴ使って」
#   「ブランド名の左隣にスーパーのロゴ載せて。今後もそれをスキル化したい。」
#   「サービス名の左にロゴを表示して」
#   「ロゴは例えばこれとかつかって https://prtimes.jp/main/html/searchrlp/company_id/70747」
#
# t111 の結果:
#   - トライアル … logo_trial.png が **144x22** で下限（80x40）に届かず落ちた
#   - 業務スーパー … 候補 **0 件**（トップが JS 描画）
#
# **入口を変える。** 会社情報・ブランドサイト・採用サイト・PR TIMES を起点にする。
# 横長ロゴは高さが小さくなりがちなので、**下限を 120x20 に緩める**（高さ 44px で使うため）。
#
# **商標であり自由ライセンスではない。** どのチェーンの節かを示す識別目的で使う。
# 改変しない。取得元を manifest に必ず残す。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t113-super-logos-rest.md"
DIR="$RDIR/super-logos"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, html, io, json, re, sys, time, urllib.error, urllib.parse, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 250.0
# **PR TIMES の企業ページは利用者が名指しした取得元**（まいばすけっと）。
BRANDS = [
    ("trial",  "トライアル（会社情報）",   "https://www.trial-net.co.jp/company/"),
    ("trial",  "トライアル（採用）",       "https://www.trial-net.co.jp/recruit/"),
    ("trial",  "トライアル（IR）",         "https://www.trial-holdings.inc/"),
    ("gyomu",  "業務スーパー（会社情報）", "https://www.kobebussan.co.jp/"),
    ("gyomu",  "業務スーパー（店舗一覧）", "https://www.gyomusuper.jp/shop/list.php?pref_id=13"),
    ("gyomu",  "業務スーパー（FC募集）",   "https://www.gyomusuper.jp/fc/"),
]
EXTRA = []

UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}

def get(u, t=25):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

def getb(u, t=25):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

def candidates(base, h):
    """**ロゴらしい画像を、確度の高い順に並べる。**"""
    out = []
    def add(u):
        if not u:
            return
        u = urllib.parse.urljoin(base, html.unescape(u.strip()))
        if u.startswith("http") and u not in out:
            out.append(u)
    # 1) og:image / apple-touch-icon は 1 枚に決め打ちされているので確度が高い
    for m in re.finditer(r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"', h, re.I):
        add(m.group(1))
    for m in re.finditer(r'<link[^>]+rel="apple-touch-icon[^"]*"[^>]+href="([^"]+)"', h, re.I):
        add(m.group(1))
    # 2) ファイル名・alt・class に logo が入る img
    for m in re.finditer(r'<img[^>]+>', h, re.I):
        tag = m.group(0)
        if not re.search(r'logo', tag, re.I):
            continue
        s = re.search(r'\ssrc="([^"]+)"', tag) or re.search(r'\sdata-src="([^"]+)"', tag)
        if s:
            add(s.group(1))
    # 3) svg の use/href
    for m in re.finditer(r'<link[^>]+rel="icon"[^>]+href="([^"]+)"', h, re.I):
        add(m.group(1))
    return out

L = ["# t111 で取れなかった 2 ブランドのロゴ候補（t113）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**商標であり自由ライセンスではない。** 識別目的の利用を前提に、取得元を必ず残す。",
     "**落ちた理由も 1 件ずつ書く**（t095 が 0 枚で理由が分からなかったため）。", ""]
man = {"_note": "各チェーンの公式サイトから取得したロゴ。**商標であり自由ライセンスではない。**"
                "どのチェーンの節かを示す識別目的で使っている。改変せず、そのまま置くこと。"
                f"取得日 {dt.date.today().isoformat()}（ops/tasks/t113-super-logos-rest.sh）。"}

t0 = time.time()
targets = [(k, n, u) for k, n, u in BRANDS] + [(k, k, u) for k, u in EXTRA]
for key, name, url in targets:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** {name} 以降は次のタスクで。")
        break
    L.append(f"## {name}")
    L.append("")
    L.append(f"起点 `{url}`")
    L.append("")
    try:
        page = get(url)
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:140]}", ""]
        continue
    cands = candidates(url, page)
    L.append(f"候補 **{len(cands)} 件**")
    L.append("")
    saved = 0
    for i, cu in enumerate(cands[:8]):
        if saved >= 3 or time.time() - t0 > BUDGET:
            break
        try:
            blob = getb(cu)
        except Exception as e:
            L.append(f"  - ✗ `{cu[:90]}`: {type(e).__name__}")
            continue
        try:
            im = Image.open(io.BytesIO(blob))
            im.load()
        except Exception as e:
            L.append(f"  - ✗ `{cu[:90]}`: 画像として開けない（{type(e).__name__}）")
            continue
        w, h = im.size
        if w < 120 or h < 20:
            L.append(f"  - ✗ `{cu[:90]}`: {w}x{h}（小さすぎる）")
            continue
        # **透過を保つ。** 見出しの横に置くので、白地で潰さない。
        name_out = f"{key}-{len(man.get(key, []))+1}"
        if im.mode in ("RGBA", "LA", "P") and "transparency" in im.info or im.mode == "RGBA":
            im = im.convert("RGBA")
            path = f"{DIR}/{name_out}.png"
            im.save(path, "PNG", optimize=True)
        else:
            im = im.convert("RGB")
            path = f"{DIR}/{name_out}.png"
            im.save(path, "PNG", optimize=True)
        saved += 1
        L.append(f"  - ✅ `{name_out}.png` ← `{cu[:90]}` / {w}x{h} / {im.mode}")
        man.setdefault(key, []).append({
            "brand": name, "source": cu, "page": url,
            "source_type": "公式サイト（商標）", "file": f"{name_out}.png",
            "width": w, "height": h,
        })
    if saved == 0:
        L.append("  - **1 枚も取れなかった。** JS で差し込んでいるか、CDN が弾いている可能性")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
# **自分で parse して確かめる**（最上位ルール 13）。
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
