#!/usr/bin/env python3
"""
fetch-commons-photo.py — Wikimedia Commons から画像を検索・取得し、
ライセンス情報を _manifest.json に記録する。

このリポジトリの写真素材は「Commons の自由ライセンス画像 + 出典明記」で
統一されている（public/images/*/photos/_manifest.json）。手作業で拾うと
ライセンス表記を落としやすいので、取得と台帳記録をセットにする。

Usage:
  # 検索して候補を見る
  python3.11 scripts/fetch-commons-photo.py --search "Toyosu Park" --limit 8

  # 決めたら保存（キー名と保存先ディレクトリを指定）
  python3.11 scripts/fetch-commons-photo.py --file "File:Xxx.jpg" \
      --key toyosu-park --dir public/images/wangan-august-events-2026/photos
"""
import json, sys, os, re, urllib.parse, urllib.request, pathlib, argparse

API = "https://commons.wikimedia.org/w/api.php"
UA = "DailyHackBot/1.0 (https://daily-hack.fieldbeside.com; n-yokota@fieldbeside.com)"

# 再利用しづらいライセンスは弾く
BAD_LIC = re.compile(r"non[- ]?free|fair use|all rights reserved", re.I)


def api(params):
    params = {**params, "format": "json"}
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(params),
                                 headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read())


def meta_of(page):
    ii = (page.get("imageinfo") or [{}])[0]
    ex = ii.get("extmetadata") or {}
    g = lambda k: re.sub(r"<[^>]+>", "", str(ex.get(k, {}).get("value", ""))).strip()
    return dict(title=page.get("title", ""), url=ii.get("url", ""),
                lic=g("LicenseShortName"), artist=g("Artist"),
                w=ii.get("width"), h=ii.get("height"),
                page=ii.get("descriptionurl", ""))


def search(q, limit):
    d = api({"action": "query", "generator": "search", "gsrsearch": f"filetype:bitmap {q}",
             "gsrnamespace": 6, "gsrlimit": limit,
             "prop": "imageinfo", "iiprop": "url|size|extmetadata"})
    pages = (d.get("query") or {}).get("pages") or {}
    out = []
    for p in pages.values():
        m = meta_of(p)
        if not m["url"] or BAD_LIC.search(m["lic"] or ""):
            continue
        if (m["w"] or 0) < 900:      # カード背景に使うので小さすぎるものは除外
            continue
        out.append(m)
    return out


def save(file_title, key, outdir):
    d = api({"action": "query", "titles": file_title,
             "prop": "imageinfo", "iiprop": "url|size|extmetadata"})
    pages = (d.get("query") or {}).get("pages") or {}
    page = next(iter(pages.values()))
    m = meta_of(page)
    if not m["url"]:
        print("画像が見つからない:", file_title, file=sys.stderr)
        return 1
    if BAD_LIC.search(m["lic"] or ""):
        print("再利用不可のライセンス:", m["lic"], file=sys.stderr)
        return 1
    outdir = pathlib.Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    dst = outdir / f"{key}.jpg"
    req = urllib.request.Request(m["url"], headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=90) as r:
        dst.write_bytes(r.read())

    mf = outdir / "_manifest.json"
    data = json.loads(mf.read_text(encoding="utf-8")) if mf.exists() else {}
    data[key] = {"file": m["title"].replace("File:", ""), "lic": m["lic"],
                 "artist": m["artist"], "page": m["page"],
                 "px": f'{m["w"]}x{m["h"]}', "bytes": dst.stat().st_size}
    mf.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"保存 {dst}  [{m['lic']}] {m['artist'][:40]}")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--search"); ap.add_argument("--limit", type=int, default=8)
    ap.add_argument("--file"); ap.add_argument("--key"); ap.add_argument("--dir")
    a = ap.parse_args()
    if a.search:
        for m in search(a.search, a.limit):
            print(f'{m["lic"]:<18} {m["w"]}x{m["h"]:<6} {m["title"]}')
        return 0
    if a.file and a.key and a.dir:
        return save(a.file, a.key, a.dir)
    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
