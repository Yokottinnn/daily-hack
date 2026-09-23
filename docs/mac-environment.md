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

## node / npm と、パッケージの在りか（2026-09-23 に実測・t175）

| | 場所 | 版 |
| --- | --- | --- |
| node | `/opt/homebrew/bin/node` | **v26.0.0** |
| npm | `/opt/homebrew/bin/npm` | **11.12.1** |

**`ops/tasks` から見える `PATH` はこれだけ。** ログイン時のものは乗らない。

```text
/opt/homebrew/bin : /usr/bin : /bin : /usr/sbin : /sbin
```

`/opt/homebrew/bin` が入っているので、**`npm` は素で呼べる。**

### パッケージはリポジトリごとに別。**「無い」の前に場所を探す**

| パッケージ | 在りか |
| --- | --- |
| `@anthropic-ai/sdk` | `~/projects/anta-baka-x/blog/node_modules`（426 項目・**書き込み可**） |
| `playwright-core` | **`~/.openclaw/workspace/node_modules`** と `~/openclaw/node_modules` |

**ブログのリポジトリに `playwright-core` は無い。** X のループが持っている。
**入れ直さずに、そこから読む。**

```js
// **`NODE_PATH` は ESM の import では効かない。** require で場所を指定する
import { createRequire } from 'node:module';
const req = createRequire('/Users/ny/.openclaw/workspace/node_modules/x.js');
const { chromium } = req('playwright-core');
```

### 失敗の理由を握りつぶさない（2026-09-23 に 1 往復 無駄にした）

`npm install ... >/dev/null 2>&1 || true` と書いたため、
**「入れられなかった」としか残らず、原因が分からなかった。**
そのあと推測で「PATH に無いのが有力」と報告したが、**実測したら PATH に在った。**

- **出力は捨てない。** せめて `2>&1 | tail -20`
- **見つからないときは `PATH` ごと出す**
- **2 回 同じところで止まったら、直す前に測る**（最上位ルール 15）

## 追記するとき

**実測してから書く。** 「たぶん入っている」は書かない。
`ops/tasks` の先頭で `command -v` を並べて出力させれば、次のレポートで分かる。
