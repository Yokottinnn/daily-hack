#!/usr/bin/env python3
"""
fix-md-bold.py — 日本語で太字にならない ** を <strong> に置き換えて直す。

## 問題

日本語だと **強調。**次の文 のように書いた時、閉じ側 ** の直前が句読点だと
CommonMark の right-flanking delimiter 条件を満たさず、太字にならずに ** が
そのまま表示される。開き側の直後が約物（**「扇」**）でも同様に left-flanking
にならない。ビルドは通るし見た目も崩れないので気づきにくい。

## なぜ「約物を外に出す」のではなく <strong> なのか

最初は **無料。**18:30 → **無料**。18:30 のように約物を外へ出す方式を書いたが、
**くじ（抽選）**で のように内容の末尾が閉じ括弧の場合、外に出すと
**くじ（抽選**）で となって括弧の対応が壊れる。
<strong> には flanking 規則が無いため、どの形でも意味を変えずに直せる。

## 判定

CommonMark の delimiter run 規則をそのまま実装し、
「開き側が left-flanking でない」または「閉じ側が right-flanking でない」ペアだけを
<strong> に変換する。正常な **強調** には一切触らない。

Usage:
  python3.11 scripts/fix-md-bold.py --dry-run   # 差分を確認
  python3.11 scripts/fix-md-bold.py             # 書き換え
  npm run build && python3.11 scripts/check-md-bold.py
"""
import re, sys, glob, pathlib, unicodedata

DRY = "--dry-run" in sys.argv


def is_ws(c):
    return c == "" or c.isspace()


def is_punct(c):
    if c == "":
        return False
    return unicodedata.category(c)[0] in ("P", "S")


def left_flanking(before, after):
    """開き記号になれるか（CommonMark: left-flanking delimiter run）"""
    if is_ws(after):
        return False
    if is_punct(after) and not (is_ws(before) or is_punct(before)):
        return False
    return True


def right_flanking(before, after):
    """閉じ記号になれるか（CommonMark: right-flanking delimiter run）"""
    if is_ws(before):
        return False
    if is_punct(before) and not (is_ws(after) or is_punct(after)):
        return False
    return True


# コードブロック・インラインコード・HTML属性の中は触らない
# ⚠️ <[^>]+> を re.S で使うと、本文中の "<<" のような裸の < が次行以降の > まで
#    貪欲でない形でも行をまたいでマッチし、本文をタグとして退避してしまう。
#    実際に mortgage-refinance-breakeven-2026.md を破壊した。タグは行内に限定する。
SKIP_RE = re.compile(r"(```.*?```|`[^`\n]*`|<[a-zA-Z/!][^>\n]*>)", re.S)


def fix_text(src):
    """壊れている **…** だけを <strong>…</strong> に変換する。"""
    # 触ってはいけない領域をプレースホルダに退避
    guards = []

    def stash(m):
        guards.append(m.group(0))
        return f"\x00{len(guards)-1}\x00"

    work = SKIP_RE.sub(stash, src)

    n = 0

    def repl(m):
        nonlocal n
        s, e = m.span()
        content = m.group(1)
        open_before = work[s - 1] if s > 0 else ""
        open_after = content[0] if content else ""
        close_before = content[-1] if content else ""
        close_after = work[e] if e < len(work) else ""
        ok = left_flanking(open_before, open_after) and right_flanking(close_before, close_after)
        if ok:
            return m.group(0)          # 正常なので触らない
        n += 1
        return f"<strong>{content}</strong>"

    work = re.sub(r"\*\*([^*\n]+?)\*\*", repl, work)

    out = re.sub(r"\x00(\d+)\x00", lambda m: guards[int(m.group(1))], work)
    return out, n


def main():
    files = sorted(glob.glob("src/content/posts/*.md"))
    total, changed = 0, []
    for f in files:
        p = pathlib.Path(f)
        before = p.read_text(encoding="utf-8")
        after, n = fix_text(before)
        if n == 0:
            continue
        total += n
        changed.append((p.stem, n))
        if DRY:
            print(f"\n[{p.stem}] {n}箇所")
            for bl, al in zip(before.split("\n"), after.split("\n")):
                if bl != al:
                    print(f"  - {bl.strip()[:120]}")
                    print(f"  + {al.strip()[:120]}")
        else:
            p.write_text(after, encoding="utf-8")

    if not changed:
        print("修正対象なし")
        return 0
    print(f"\n{'(dry-run) ' if DRY else ''}{len(changed)} 記事 / 計 {total} 箇所")
    for slug, n in sorted(changed, key=lambda x: -x[1])[:10]:
        print(f"  {n:>3}箇所  {slug}")
    if not DRY:
        print("\nnpm run build のあと check-md-bold.py で 0 件を確認すること。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
