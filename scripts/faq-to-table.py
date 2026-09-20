#!/usr/bin/env python3
"""FAQ の「**Q. …**／A. …」を表（cmp-table spec-table）に直す。

「1 セクション 1 ビジュアル」を満たすための道具。**中身は足さない。**
Q と A をそのまま 2 列に移すだけで、順番も文言も変えない。

**`**…**` は HTML ブロックの中では効かない**ので `<strong>` に直す
（blog-article スキル §3）。

    python3 scripts/faq-to-table.py <slug> [<slug> ...]

Q が 3 つ 以上 ある塊だけを表にする。
"""
import pathlib
import re
import sys

BOLD = re.compile(r"\*\*(.+?)\*\*")
Q = re.compile(r"^\*\*Q\.\s*(.+?)\*\*\s*$")
A = re.compile(r"^A\.\s*(.+)$")


def to_html(s):
    return BOLD.sub(r"<strong>\1</strong>", s.strip())


def convert(slug, min_rows=3):
    p = pathlib.Path(f"src/content/posts/{slug}.md")
    lines = p.read_text(encoding="utf-8").split("\n")
    out, i, n = [], 0, 0
    while i < len(lines):
        if Q.match(lines[i]):
            j, rows = i, []
            while j < len(lines):
                mq = Q.match(lines[j])
                if not mq:
                    if lines[j].strip() == "":
                        j += 1
                        continue
                    break
                k = j + 1
                while k < len(lines) and lines[k].strip() == "":
                    k += 1
                ma = A.match(lines[k]) if k < len(lines) else None
                if not ma:
                    break
                rows.append((mq.group(1), ma.group(1)))
                j = k + 1
            if len(rows) >= min_rows:
                out += ['<div class="cmp-table-wrap">',
                        '  <table class="cmp-table spec-table faq-table">', "    <tbody>"]
                out += [f"      <tr><th>{to_html(q)}</th><td>{to_html(a)}</td></tr>"
                        for q, a in rows]
                out += ["    </tbody>", "  </table>", "</div>"]
                n += 1
                i = j
                continue
        out.append(lines[i])
        i += 1
    p.write_text("\n".join(out), encoding="utf-8")
    return n


if __name__ == "__main__":
    for a in sys.argv[1:]:
        print(a, convert(a))
