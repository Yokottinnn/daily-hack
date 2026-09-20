# `check-follower-v2.js` の呼び方を確かめる

**このレポートが作られた時刻: 2026-09-20 17:11:02 JST**

> 種の候補 58 件 のうち **54 件 がフォロワー数未取得**で、このままでは選べない。
> x101 で `check-follower-v2.js` が**単独で呼べる形**だと分かった。
>
> **だが呼び方を知らない。** いきなり 54 件 回すと 5 分 を超えて
> **heartbeat ごと止める**（2026-09-13 に x50 で 49 分 止めた前例）。

**先に 3 件 で測る。54 件 は回さない。**

## 1. 呼び方（**ソースから読む。推測しない**）

```javascript
  18 行 / 2026-08-09 17:52

  --- 先頭 30 行（用途と使い方が書いてあることが多い）---
     1| #!/usr/bin/env node
     2| const { chromium } = require("playwright-core");
     3| const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
     4| (async () => {
     5|   const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
     6|   const p = await b.contexts()[0].newPage();
     7|   await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 30000 });
     8|   await p.waitForTimeout(6000);
     9|   const r = await p.evaluate(() => {
    10|     const text = document.body.innerText;
    11|     const m1 = text.match(/([\d,]+)\s*フォロワー/);
    12|     const m2 = text.match(/([\d,]+)\s*フォロー中/);
    13|     return { followers: m1 ? m1[1] : null, following: m2 ? m2[1] : null, has_text_snippet: text.slice(0, 300) };
    14|   });
    15|   console.log(JSON.stringify(r));
    16|   await p.close();
    17|   await b.close();
    18| })().catch(e => { console.error(JSON.stringify({ error: e.message })); process.exit(1); });

  --- 引数の取り方 ---
  3:const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";

  --- 何を出すか（console.log / 書き出し先）---
  15:  console.log(JSON.stringify(r));
```

## 2. **3 件 だけ**試す（**時間を測る**）

```
  **引数を取らない作りに見える。** 上の「引数の取り方」を見て、次のタスクで合わせる。
  ここでは走らせない（何をするか分からないものを当て推量で叩かない）。
```

**1 件あたりの秒数が分かれば、次は何件 ずつ回せるかが決まる。**
5 分 = 300 秒 が上限なので、**余裕を見て 1 回 あたり 240 秒 ぶん**にする。

## 3. 次に回す件数の目安

```
    1 件 3 秒 なら  → 1 回 80 件  → **54 件 は 1 回 で終わる**
    1 件 5 秒 なら  → 1 回 48 件  → 2 回 に分ける
    1 件 10 秒 なら → 1 回 24 件  → 3 回 に分ける

    **上限に頼らない。** OPS_TASK_TIMEOUT(900秒) は暴走を止める安全弁であって
    設計の目標ではない（最上位ルール 15）。
```

## 4. 費用

**プロフィールを DOM で読むだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**54 件 を回すのも $0。** 返信ループは `MAX_PICKS` を 6 にしたため
**約 $0.95/月（推定）**。実測は次の 24 時間 の `cost_24h_usd` で確かめる。
