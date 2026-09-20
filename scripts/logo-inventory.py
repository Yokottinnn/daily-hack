#!/usr/bin/env python3
"""記事ごとに「ブランドが何社 並んでいるか」を数える。

最上位ルール 17 をどの記事まで適用するかの判断材料。
**リンクの本数ではなくドメイン数**を見る。リンクが 175 本 あっても
飛び先が 1 社なら、それはブランドの並びではない。

    python3 scripts/logo-inventory.py          # 一覧を出す
    python3 scripts/logo-inventory.py --md     # docs/logo-inventory.md の表を出す
"""
import collections
import pathlib
import re
import sys

# 自サイト・SNS・百科事典・プレスリリースは「ブランド」として数えない
SKIP = re.compile(r"daily-hack|twitter\.com|x\.com|wikipedia|wikimedia|youtube|prtimes|note\.com")
LINK = re.compile(r'<a href="(https?://[^"]+)"[^>]*>([^<]{2,30})</a>')


def scan(root=pathlib.Path("src/content/posts")):
    for f in sorted(root.glob("*.md")):
        hosts = collections.Counter()
        for url, _text in LINK.findall(f.read_text(encoding="utf-8")):
            if SKIP.search(url):
                continue
            hosts[re.sub(r"^www\.", "", url.split("/")[2])] += 1
        yield {
            "slug": f.stem,
            "has_logos": pathlib.Path(f"public/images/{f.stem}/logos").is_dir(),
            "links": sum(hosts.values()),
            "domains": len(hosts),
            "top": hosts.most_common(1),
        }


def main():
    rows = sorted(scan(), key=lambda r: (-r["domains"], -r["links"]))
    md = "--md" in sys.argv
    if md:
        print("| 記事 | ブランドのリンク | ドメイン数 | いちばん多い先 |")
        print("| --- | --- | --- | --- |")
    for r in rows:
        top = f"{r['top'][0][0]}:{r['top'][0][1]}" if r["top"] else "-"
        if md:
            print(f"| `{r['slug']}` | {r['links']} | **{r['domains']}** | {top} |")
        else:
            print(f"{'済' if r['has_logos'] else '未'}\t{r['links']}\t{r['domains']}\t{r['slug']}\t{top}")


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:   # `| head` で閉じられても騒がない
        pass
