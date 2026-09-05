# X 投稿キューの契約（`auto-x-publisher.js` / `queue-manager.js`）

**投稿タスクを書く前にここを読む。** 推測で積むと、エラーも出さずに
「候補なし」で黙って終わる。**それを 2026-08-30 に 3 回やって 2 時間 20 分 失った**
（経緯は [`x-post-latency-postmortem.md`](x-post-latency-postmortem.md)）。

実体は Mac の `~/.openclaw/workspace/scripts/`。**クラウドからは読めないので、
ここに写しを固定する。** 値はすべて実機の出力・実物のソースから取ったもので、推測ではない。

最終更新: 2026-08-30
出典: `t002`/`t004` のレポート（`post-sauna.md` / `post-sauna-v3.md`）の実出力、
および **PR #298**（別セッションが Mac 上の `auto-x-publisher.js` / `run-publish.sh` /
`post-via-playwright.js` / `queue-manager.js` を直接読んで調べたもの）。

## 1. いちばん間違えるところ

> **`blog-promo` は kind の名前ではない。「モード」の名前である。**

```javascript
// auto-x-publisher.js
  6: *   kind = blog-promo (== thread + blog-promo- prefix)
 42: if (!["blog-promo", "trend_post", "trend_qt"].includes(KIND)) {
 43:   console.error("usage: node auto-x-publisher.js <blog-promo|trend_post|trend_qt>");
136:        e.kind === "thread" &&
137:        (e.id || "").startsWith("blog-promo-") &&
```

| | コマンドライン引数 | キューに積む `kind` |
| --- | --- | --- |
| ブログ告知 | `blog-promo` | **`thread`** |

**そして `id` は `blog-promo-` で始めなければ候補にならない。**

積む形を間違えると、publisher はエラーではなくこれを返す。**成功に見えるので気づきにくい。**

```json
{"ok":true,"action":"skip","reason":"no candidate","kind":"blog-promo"}
```

## 2. 確定している契約

| 項目 | 値 | 根拠 |
| --- | --- | --- |
| モード引数 | `blog-promo` / `trend_post` / `trend_qt` | `auto-x-publisher.js:42` |
| ブログ告知の `kind` | **`"thread"`** | 同 `:136` |
| ブログ告知の `id` | **`blog-promo-` 接頭辞が必須** | 同 `:137`、`:6` |
| enqueue の必須フィールド | `id`, `kind`, `text` | `queue-manager.js:145` |
| 承認不要な kind | `["comment", "reply"]` | 同 `:108`（`NO_APPROVAL`） |
| enqueue 直後の status | `pending` | `t004` 実測 |
| 同日ガード | その日すでに `posted` な `thread` があれば skip | `auto-x-publisher.js:131-132` |

### 積み方の例

```bash
# ✅ 正しい形（**単発の投稿**。スレッドは 4 章の thread_chain を使う）
node -e '
const [id,text,csv]=process.argv.slice(1);   # ← slice(1)。slice(2) ではない
console.log(JSON.stringify({
  id, kind:"thread", text,                    # ← kind は thread
  image_path: csv                             # ← images ではない。カンマ区切り
}));
' "blog-promo-$(date +%Y%m%d)-<slug>" "$TEXT" "$IMGDIR/1.jpg,$IMGDIR/2.jpg" \
  | node scripts/queue-manager.js enqueue
```

**そのうえで、自動投稿に拾わせるなら 3 章の 5 条件を全部満たす必要がある。**
満たさなければ `auto-x-publisher.js blog-promo` は `no candidate` を返して黙って終わる。
**明示的に出したいなら `run-publish.sh <id>` を直接叩くほうが確実**（4 章）。

> **`node -e 'code' A B C` は `process.argv = [execPath, A, B, C]`。**
> スクリプトのパスが入らないので **`slice(1)`** が正しい。
> `slice(2)` にすると先頭の引数が落ちる（`t002` で `id` に本文が入った）。

## 3. `auto-x-publisher.js` の候補条件は **5 つすべての AND**

出典: **PR #298**（別セッションが Mac の実物を読んで調べたもの）。
クラウドからは実体を読めないため、**ここが現状もっとも確度の高い記録**である。

| 条件 | 要求 | `t004` の実際 |
| --- | --- | --- |
| `status` | `awaiting_approval` | `pending` |
| `kind` | `"thread"` | `"blog-promo"` |
| `id` の接頭辞 | `"blog-promo-"` | `"sauna-x-"` |
| `auto_publish` | `true` | フィールドなし |
| `scheduled_at` | now 以前 | フィールドなし |

**`t004` は 5 つ全部を外していた。** だから `no candidate` だった。

### 画像は `image_path`。**カンマ区切りで最大 4 枚**

`run-publish.sh` が読むのは **`image_path`** で、`post-via-playwright.js:31` が
`split(",")` している。**`images` ではない。**
`t004` は publisher のソースに `images` という文字列が含まれるかだけを見て選んでいた。
**全文検索で決めてはいけない。**

### `queue-manager.js` に **`approve` は無い**

実在する case は次の 9 つだけ。

```
next-pending / show / list-awaiting / list-by-status /
mark-drafted / mark-skipped / mark-posted / enqueue / mark-dm-sent
```

`t004` / `t006` が呼ぼうとした `approve` は**存在しないコマンド**だった。

## 4. スレッドは `run-publish.sh` の `thread_chain` で出す

**`auto-x-publisher.js` を 2 回叩いてスレッドにすることはできない。**
同じ日に blog-promo の thread が投稿済みだと
`skip: "blog-promo already posted today"` を返すため、
**[2/2] は構造的に出せない**（`t005` はこれで詰んでいた）。

正しいのは `run-publish.sh <id>`。**`thread_chain[]` を解釈して、
1 本目を本投稿、2 本目以降を直前への reply として順に出す。**
[1/2] と [2/2] を **1 エントリ・1 回の呼び出し**で出せる。

```json
{
  "id": "blog-promo-20260830-<slug>", "kind": "thread",
  "text": "<1本目>", "image_path": "a.jpg,b.jpg,c.jpg,d.jpg",
  "thread_chain": [
    { "text": "<1本目>", "role": "hook", "image_path": "a.jpg,b.jpg,c.jpg,d.jpg" },
    { "text": "<2本目>", "role": "cta",  "url": "<記事URL>" }
  ]
}
```

### 積む前に **X の重み**を数える（280。**全角は 2**）

**2026-09-05 に、これだけが原因で 40 分 失った。** 本文の重みが **293** で
上限 **280** を 13 超えており、**投稿ボタンが有効にならず中止**されていた。
Chrome も CDP も画像も正常で、そちらばかり疑っていた。

```javascript
// post-via-playwright.js:125
out({ ok:false, step, error: "X refused to enable the post button — nothing was posted" })
```

**日本語は 1 文字が 2。** 161 文字の和文はそれだけで 322 になりうる。
「文字数」で数えると通ると思ってしまう。**必ず重みで数える。**

```bash
node -e 'const w=s=>{let n=0;for(const c of s)n+=c.codePointAt(0)<0x80?1:2;return n};
         console.log(w(require("fs").readFileSync(0,"utf8")))' <<< "$TEXT"
```

**積む前に数え、280 を超えていたら積まない。** 積んでから気づくと、
`run-publish.sh` は `{"ok":false,"step":"thread-main-exec","error":"Command failed: ..."}`
としか返さず、**理由が分からない**（次項）。

### `run-publish.sh` は子プロセスの stdout を捨てる

`post-via-playwright.js` は失敗時も **stdout に JSON で理由を書く**が、
`run-publish.sh` は `execSync` の `error.message`（＝`Command failed: <コマンド>`）
しか出さないため、**その JSON は捨てられる。**

だから「なぜ落ちたか」を知りたければ、**渡している引数を復元して自分で数える**か、
**`post-via-playwright.js` を直接叩いて stdout を読む**しかない。
ただし直接叩くと**成功したときに [1/2] だけ出て片肺になる**ので、
**先に重みと画像枚数を検算するほうが速く、安全。**

### 出す前に Chrome を確かめる

`run-publish.sh` は冒頭で `ensure-chrome.sh` を呼ぶが、
**cookie がディスクに永続化できておらず、再起動＝即ログアウト**である。
ログアウト状態で `thread_chain` を走らせると **[1/2] だけ出て [2/2] が落ちる。**
**CDP が健全でなければ出さない。**

#### CDP の口は **18810**。`9222` ではない

| 項目 | 値 | 根拠 |
| --- | --- | --- |
| CDP のポート | **18810** | `ensure-chrome.sh:PORT=18810` |
| CDP の URL | `http://127.0.0.1:18810` | `post-via-playwright.js:10` の `CDP_URL` 既定値 |
| 健全性の判定 | `scripts/cdp-health.js` | `ensure-chrome.sh:cdp_healthy()` |
| プロファイル | `~/.openclaw/browser/cft-profile` | `ensure-chrome.sh:USER_DATA` |

**2026-09-05 に `9222` を決め打ちして「CDP NG」と誤判定し、健全な Chrome を前に
投稿を止めた。** 契約書にポートを書いていなかったので、ここに書く。

**ポートが LISTEN しているだけでは健全ではない。** `ensure-chrome.sh` の但し書き:

> ハングした Chrome も ポートを開いたまま `/json/version` に 200 を返し
> ws ハンドシェイクも通るため、従来の lsof チェックはハングを "生存" と
> 誤判定し続けた（CDP timeout ログ **18,087 件**）

だから **`cdp-health.js` を使う。** `curl /json/version` で足りると思ってはいけない。

### 失敗したら、エラーの全文を残す

**マスクや `cut` で証拠を消さないこと。** 2026-09-05 に実際にこうなった。

```
{"ok":false,"step":"thread-main-exec","error":"Command failed: ... "<MASKED>
```

`[A-Za-z0-9/_+=-]{22,}` のような**無差別なマスクはエラー本文ごと潰す。**
`cut -c1-170` も同じ。潰すのは**秘密だけ**にする。

```bash
# 秘密だけを潰す（エラー本文は残る）
sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
       -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
       -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
       -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
```

CLAUDE.md ルール 4 の「**何が失敗したかの実際の出力**を出す。
『うまくいきませんでした』では足りない」は、**自分のマスクにも向けられている。**

## 5. 書く前のチェックリスト


- [ ] **本文の重みを数えたか**（**280。全角は 2。** 和文は文字数の 2 倍になる）
- [ ] `kind` は `"thread"` か（`"blog-promo"` にしていないか）
- [ ] `id` は `blog-promo-` で始まっているか
- [ ] `node -e` の argv は `slice(1)` か
- [ ] 画像は **`image_path` にカンマ区切り**で入れたか（`images` ではない）
- [ ] **スレッドなら `thread_chain[]` を作り、`run-publish.sh <id>` で出す**か
      （`auto-x-publisher.js` を 2 回叩いても [2/2] は出ない）
- [ ] `queue-manager.js approve` を呼んでいないか（**存在しない**）
- [ ] 出す前に **CDP の健全性**を確かめているか（ログアウト中は [1/2] だけ出る）
- [ ] 投稿前後に件数を数え、2 件以上なら止める仕掛けが入っているか
- [ ] **人が手で投稿した可能性を考えたか**
      （キューの件数ガードは **X 上の手動投稿を検知できない**。
      2026-08-30 に利用者が手で投稿し、タスクを main から消して止めた）

## 6. 関連

- `ops/tasks` の実行モデル: [`ops-task-runner.md`](ops-task-runner.md)
- 遅延の経緯と対策: [`x-post-latency-postmortem.md`](x-post-latency-postmortem.md)
- 画像の作り方: `.claude/skills/x-post-images/SKILL.md`
