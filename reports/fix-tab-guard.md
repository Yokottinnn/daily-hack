# tab-guard の 2 つのバグを直す

**このレポートが作られた時刻: 2026-09-20 02:30:10 JST**

> ① `check()` が値を返さない経路で `r.halted` が TypeError → **10 秒 ごとに再起動**
> ② `reachable` を保存していないため 88 行 のガードが死んでいて、
>    **再起動のたびに `ai.openclaw.*` を全部 外していた**

**判定 B（タブの一括破壊）と C（半分以上 消えた）は触らない。**

## 0. 当てる前

```
  138 行 / 最終更新 2026-09-13 01:41
  BOOT_GRACE の印: 0
0 箇所

  --- いまの状態ファイル ---
    {
      "count": 3,
      "at": "2026-09-19T17:30:03.251Z"
    }
  --- エラーログの大きさ ---
    tab-guard-err.log         2958020 bytes
    tab-guard.log            20710080 bytes
    tab-guard.out            14388301 bytes
```

## 1. 当てる（**3 箇所**）

```
  目印 ①: 1 箇所
  目印 ②: 1 箇所
  目印 ③: 1 箇所
  当てた（検査待ち）

  --- 検査して置き換える ---
    **置き換えた**（退避 tab-guard.js.bak-20260920-023010）
```

## 2. 当てた後（**実物**）

```javascript
  88|     if (prev && prev.reachable === false) {
  89|       log("CDP unreachable が続いている（前回も false）。消滅とみなさず halt しない");
  90|       return;
  91|     }
  92|     // BOOT_GRACE (2026-09-20 x89): **起動直後は停めない。**
  93|     // 再起動すれば Chrome プロセスは必ず消えるため、この条件を毎回 踏んでいた。
  94|     // 2026-09-12 と 2026-09-20 に、これで ai.openclaw.* が全滅した。
  95|     // **「一度 生きていたのに消えた」ときだけ止める。**
  96|     const aliveAt = prev && prev.chrome_alive_at ? Date.parse(prev.chrome_alive_at) : 0;
  97|     const ALIVE_WINDOW_MS = 15 * 60 * 1000;
  98|     if (!aliveAt || Date.now() - aliveAt > ALIVE_WINDOW_MS) {
  99|       log("Chrome を最近 生きている状態で見ていない（起動直後など）。消滅とみなさず halt しない");
 100|       try {
 101|         fs.writeFileSync(STATE, JSON.stringify({
 102|           count: 0,
 103|           reachable: false,
 104|           chrome_alive_at: (prev && prev.chrome_alive_at) || null,
 105|           at: new Date().toISOString(),
 106|         }, null, 2));
 107|       } catch {}
 108|       return;
 109|     }
 110|     haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");

// --- 保存の行 ---
146:      reachable: now.reachable === true,
147-      chrome_alive_at: new Date().toISOString(),
148-      at: new Date().toISOString(),
149-    }, null, 2));
150-  } catch {}
151-  return result;
152-}
153-
154-(async () => {

// --- 呼び出し側 ---
159:      if (r && r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }
```

## 3. 載せ直して、落ちなくなったかを見る

```
  載せ直した。**30 秒 待って、落ちていないかを見る**
  エラーログ:  2958020 →  2958020 bytes（差 0）
  → **30 秒 間 エラーが増えていない。落ちていない。**

  PID=26232  最後の終了コード=0

  --- 状態ファイル（reachable が入ったか） ---
    {
      "count": 3,
      "reachable": true,
      "chrome_alive_at": "2026-09-19T17:30:12.273Z",
      "at": "2026-09-19T17:30:12.273Z"
    }```

## 4. 費用

**判定条件を直すだけ。LLM を呼ばない。ループを載せ直さない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

返信ループの実額は 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 $1.44
（`MAX_PICKS` は 4 のまま）。フォロー・アンフォロー系は $0（DOM 操作のみ）。
