# chaosmap の素材はどこに在るか（t190・**$0**）

生成: **2026-09-26T19:10:55+0900**

**測るだけ。直さない。** t188 が `sns-templates` 無しで止まったため、
**推測で次を撃たない**（最上位ルール 15）。

## ① `~/projects` の中身

```
anta-baka-x
bubblesnow-migration
```

```
CLAUDE.md
SHARED
blog
design-mockup
docs
skills
```

## ② フォント（`rocknroll` / `zen-maru`）

```
```

## ③ マスコット（`expr-*.png`）

- ブログのリポジトリ: `/Users/ny/projects/anta-baka-x/blog/public/images/`

```
expr-01-wave.png
expr-01-wave.png.bak.20260612-pre-transparent
expr-02-pout.png
expr-02-pout.png.bak.20260612-pre-transparent
expr-03-bashful.png
expr-04-cheer.png
expr-04-cheer.png.bak.20260612-pre-transparent
expr-05-smug.png
expr-05-smug.png.bak.20260612-pre-transparent
expr-06-shock.png
expr-06-shock.png.bak.20260612-pre-transparent
expr-07-gasp.png
```

- `assets-transparent` という名前のディレクトリ:

```
```

## ④ `sns-templates` という名前

```
```

## ⑤ 直近に作られた図が在るか（**過去に動いた証拠**）

```
-rw-r--r--   1 ny  staff  3027279 Aug  7 21:39:23 2026 chaosmap-matrix.png
-rw-r--r--   1 ny  staff  1110245 Aug  7 21:39:23 2026 chaosmap.png
-rw-r--r--   1 ny  staff   163682 Aug  7 21:39:23 2026 eyecatch.jpg
```

---

経過 **17 秒**。

**読み方**

- ②でフォントが見つかれば、**`SNS_DIR` ではなく個別のパスを渡せば動く**
- ③でマスコットがリポジトリに在れば、**`sns-templates` は要らない**
- ②③とも無ければ、**素材ごと消えている。** 図は作り直せないので、
  そう報告して別の手（記事側で図を差し替える等）を考える
