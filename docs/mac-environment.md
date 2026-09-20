# Mac に何が入っているか

> `CLAUDE.md` の最上位ルール 14 が参照している棚卸し。**`ops/tasks` を書く前にここを読む。**
> **推測で書かない。** 載っていないものを使うなら、タスクの先頭で `command -v` を確かめ、
> 無ければ代替に切り替えるか、**理由を書いて止まる。**
>
> ここの内容は**実測**（`ops/tasks/t126-wangan-logos-retry.sh` が 2026-09-20 に
> Mac 上で `command -v` を打った結果）。**推定は 1 つも入っていない。**

## 画像まわり（2026-09-20 実測）

| コマンド | 有無 | 場所 |
| --- | --- | --- |
| `qlmanage` | **在る** | `/usr/bin/qlmanage` |
| `sips` | **在る** | `/usr/bin/sips` |
| `node` | **在る** | `/opt/homebrew/bin/node` |
| `npx` | **在る** | `/opt/homebrew/bin/npx` |
| `rsvg-convert` | **無い** | — |
| `inkscape` | **無い** | — |
| `magick` | **無い** | — |
| `convert`（ImageMagick） | **無い** | — |
| `cairosvg`（Python） | **無い** | — |

### SVG は Mac で変換しない

**変換できるものが実質 無い。** `sips` は SVG を扱えず、`qlmanage` は
QuickLook 頼みでサイズも背景も選べない。**Pillow は SVG を開けない**
（`UnidentifiedImageError`。t123 で 10 件 以上 これで落ちた）。

**SVG はそのまま持ち帰って、クラウド側の Chromium でラスタライズする。**

```bash
# Mac 側（ops/tasks）… 中身が <svg> で始まるなら .svg のまま保存する
# クラウド側 … playwright-core + /opt/pw-browsers/chromium で PNG にする
node scripts/svg-to-png.mjs <file.svg> ...
```

## ネットワーク

- **コモンズが一時的に `URLError` を返すことがある。** 2026-09-20 に、
  3 分 前に成功していたのに 5 件 連続で落ちた。**3 回 まで間を空けて試す。**
- **既定の UA を弾くサイトがある**（`HTTPError`）。ブラウザ相当の UA で再試行する。
- **URL に日本語が入っていると `UnicodeEncodeError` で落ちる。**
  `urllib.parse.quote` でパスを percent-encode してから開く。

## Python

- `python3` は 3.10 以上。`/opt/homebrew/bin/python3.12` / `python3.11` も探して使う。
- **Pillow は在る。** ただし SVG は開けない（上記）。

## 追記するとき

**実測してから書く。** 「たぶん入っている」は書かない。
`ops/tasks` の先頭で `command -v` を並べて出力させれば、次のレポートで分かる。
