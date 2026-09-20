#!/usr/bin/env python3
"""`- **ラベル**: 値` の箇条書きを、仕様表（cmp-table spec-table）に直す。

「1 セクション 1 ビジュアル」を満たすための道具。**中身は足さない。**
並べ替えもせず、ラベルと値をそのまま 2 列に移すだけ。

**`**…**` は HTML ブロックの中では効かない**ので `<strong>` に直す
（blog-article スキル §3）。

    python3 scripts/bullets-to-spec-table.py <slug> [<slug> ...]

4 行 以上 続く塊だけを表にする。2〜3 行の箇条書きは、表にすると逆に読みにくい。
"""
import re, sys, pathlib
BOLD = re.compile(r"\*\*(.+?)\*\*")
def to_html(s):
    return BOLD.sub(r"<strong>\1</strong>", s.strip())

def convert(path, min_rows=4):
    p = pathlib.Path(path)
    lines = p.read_text(encoding="utf-8").split("\n")
    out, i, n = [], 0, 0
    while i < len(lines):
        if re.match(r"^- \*\*[^*]+\*\*[:：]", lines[i]):
            j, rows = i, []
            while j < len(lines) and re.match(r"^- \*\*[^*]+\*\*[:：]", lines[j]):
                m = re.match(r"^- \*\*([^*]+)\*\*[:：]\s*(.*)$", lines[j])
                rows.append((m.group(1).strip(), m.group(2)))
                j += 1
            if len(rows) >= min_rows:
                out += ['<div class="cmp-table-wrap">', '  <table class="cmp-table spec-table">', "    <tbody>"]
                out += [f"      <tr><th>{to_html(k)}</th><td>{to_html(v)}</td></tr>" for k, v in rows]
                out += ["    </tbody>", "  </table>", "</div>"]
                n += 1; i = j; continue
        out.append(lines[i]); i += 1
    p.write_text("\n".join(out), encoding="utf-8")
    return n
for a in sys.argv[1:]:
    print(a, convert(f"src/content/posts/{a}.md"))
