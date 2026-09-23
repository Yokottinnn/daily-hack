# Mac の node まわりの棚卸し（t175・**$0**）

生成: **2026-09-23T20:58:30+0900**

**測るだけ。直さない。** t173 / t174 が 2 回 続けて「無い」で止まったため、
**推測で 3 回目を撃たない**（最上位ルール 15）。

## ① node / npm

| | 場所 | 版 |
| --- | --- | --- |
| node（PATH） | `/opt/homebrew/bin/node` | v26.0.0 |
| node（Homebrew） | `/opt/homebrew/bin/node` | v26.0.0 |
| npm（PATH） | `/opt/homebrew/bin/npm` | 11.12.1 |
| npm（node の隣） | `/opt/homebrew/bin/npm` | 11.12.1 |
| npm（Homebrew） | `/opt/homebrew/bin/npm` | 11.12.1 |

**この周回の `PATH`**（launchd 由来かどうかがここで分かる）

```
/opt/homebrew/bin
/usr/bin
/bin
/usr/sbin
/sbin
```

## ② `playwright-core` の在りか

**X のループは Playwright で動いている**ので、どこかには在るはず。

```
/Users/ny/.openclaw/workspace/node_modules/playwright-core
/Users/ny/.openclaw/workspace/node_modules/playwright-core
/Users/ny/openclaw/node_modules/playwright-core
```

## ③ `@anthropic-ai/sdk` の在りか

```
/Users/ny/projects/anta-baka-x/blog/node_modules/@anthropic-ai/sdk
```

## ④ ブログの `node_modules`

- `/Users/ny/projects/anta-baka-x/blog/node_modules` は **在る**（直下 **426 項目**）
- `astro` は **在る**
- 書き込み **できる**

## ⑤ npm は動くか（**何も入れない**）

```
blog@0.0.1 /Users/ny/projects/anta-baka-x/blog
+-- @anthropic-ai/sdk@0.128.0
+-- @astrojs/check@0.9.9
+-- @astrojs/mdx@5.0.4
+-- @astrojs/rss@4.0.18
+-- @astrojs/sitemap@3.7.2
+-- @emnapi/runtime@1.10.0 extraneous
+-- @tailwindcss/vite@4.3.0
+-- astro@6.3.1
+-- fast-xml-parser@5.8.0
+-- husky@9.1.7
+-- lint-staged@17.0.4
```

---

**読み方**

- **npm が PATH に無く、node の隣にも無い**なら、launchd の PATH を疑う
- **`playwright-core` が別の場所に在る**なら、入れ直さずに `NODE_PATH` で通す
- **`node_modules` に書き込めない**なら、入れる話ではなく権限の話

**次に何を直すかは、この結果を見てから決める。**
