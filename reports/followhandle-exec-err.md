# `follow-handle.js` が落ちている 28 件

**このレポートが作られた時刻: 2026-09-13 21:54:40 JST**

> 弾かれた理由の 2 番目が「判定」ではなく **「落ちた」**。
> `28 exec err: Command failed`
>
> **落ちた分はフォローもしなければ理由も残らない。** 丸ごと機会を損している。

**測るだけ。直さない。**

## 1. exec err の全文（**切れていない記録を探す**）

```
  --- 切れている記録（呼び出し側は slice(0,150)） ---
    hashtag-follow.log                   28 件
    competitor-follower-follow.log        5 件
    comment-orchestrator.log            0
0 件

  --- 直近 8 件（切れたまま） ---
    [2026-08-07T08:03:35.857Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js cuterunchan
    [2026-08-07T11:03:04.761Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js momoyama_univ
    [2026-08-07T11:03:35.047Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js cuterunchan
    [2026-05-30T02:37:58.482Z]   @<伏せ>: ❌ exec err
    [2026-06-09T09:32:05.903Z]   @<伏せ>: ❌ exec err
    [2026-06-09T09:33:28.304Z]   @<伏せ>: ❌ exec err
    [2026-09-07T15:00:01.424Z]   @<伏せ>: ❌ exec err
      @<伏せ>: ❌ exec err

  --- .err / .out に全文が残っていないか ---
    comment-warmup-err.log               151429 bytes / 09-13 21:10
      2071:  error: 'Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/post-comment.js "44Gh44KH44GG44Gp5LuK5Yid5aSP44Gu5pmC5pyf44Gg44GX44CB44G144KL44GV44Go57SN56iO44Gn5pes44Gu5p6c54
      2093:  error: 'Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/post-comment.js "44Gh44KH44GG44Gp5LuK5Yid5aSP44Gu5pmC5pyf44Gg44GX44CB44G144KL44GV44Go57SN56iO44Gn5pes44Gu5p6c54
      2115:  error: 'Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/post-comment.js "44Gh44KH44GG44Gp5LuK5Yid5aSP44Gu5pmC5pyf44Gg44GX44CB44G144KL44GV44Go57SN56iO44Gn5pes44Gu5p6c54
      2211:  error: 'Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/post-comment.js "44GC44KJ44CB44GS44KT44Gh44KD44KT44Gu6YCA6Zmi44GK44KB44Gn44Go44GG44Gt44CC5Yy755mC6LK744Gj44Gm5p
      2234:  error: 'Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/post-comment.js "44GC44KJ44CB44GS44KT44Gh44KD44KT44Gu6YCA6Zmi44GK44KB44Gn44Go44GG44Gt44CC5Yy755mC6LK744Gj44Gm5p
      2257:  error: 'Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/post-comment.js "44GC44KJ44CB44GS44KT44Gh44KD44KT44Gu6YCA6Zmi44GK44KB44Gn44Go44GG44Gt44CC5Yy755mC6LK744Gj44Gm5p

```

## 2. いつ起きているか（**偏りを見る**）

```
  --- 日ごと ---
       1 2026-05-30
       2 2026-06-09
       8 2026-08-04
       8 2026-08-05
       8 2026-08-06
       4 2026-08-07
       1 2026-09-07

  --- 時刻ごと（UTC の時） ---
       8 T11:
       8 T08:
       6 T04:
       6 T01:
       2 T09:
       1 T15:
       1 T02:

  --- ジョブごと ---
    hashtag-follow.log                   28 件 / 全 ❌  271 件
    competitor-follower-follow.log        5 件 / 全 ❌ 1707 件
```

**時刻に偏っていれば Chrome か CDP の状態が疑わしい。**
**ばらけていれば個別の相手（削除・鍵・ブロック）が疑わしい。**

## 3. `follow-handle.js` の落ちうる箇所

```
  220 行 / 最終更新 2026-09-05 18:53

  --- 例外を投げる／握りつぶす箇所 ---
    20:  catch { return new Set(); }
    57:  process.exit(1);
    94:    return { ok: false, reason: `random-looking handle (likely throwaway/spam): ${handle}`, phase };
    134:  await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
    135:  await page.waitForTimeout(2000);
    179:  const browser = _w.browser;
    203:    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
    205:    await page.waitForTimeout(1500);
    212:  } catch (e) {
    216:    await browser.close();

  --- 待ち時間の設定 ---
    134:  await page.goto(`https://x.com/${handle}`, { waitUntil: "domcontentloaded", timeout: 20000 });
    135:  await page.waitForTimeout(2000);
    203:    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });
    205:    await page.waitForTimeout(1500);
```

## 4. 呼び出し側の `execSync` の条件

```
  ══ hashtag-follow.js
    18:const { execSync } = require("child_process");
    22:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
    97:    detectOut = execSync(`/usr/local/bin/node ${TREND_DETECT}`, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024, timeout: 420000 });
    145:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2 * 1024 * 1024 });

  ══ competitor-follower-follow.js
    13:const { execSync } = require("child_process");
    17:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
    79:    await page.goto(`https://x.com/${competitor}/followers`, { waitUntil: "domcontentloaded", timeout: 30000 });
    143:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`, { encoding: "utf8", timeout: 60000, maxBuffer: 2*1024*1024 });

  ══ comment-orchestrator.sh
    35:# 進捗行やエラー行 (例: "hashtag 還元 failed: timeout 12000ms") を出すと SyntaxError で
    78:      const can = JSON.parse(cs.execSync('/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/comment-state.js can-comment ' + item.author).toString());

```

**`timeout: 60000` を超えると `Command failed` になる。**
プロフィールの描画が遅いだけなら、**待ち方を変えれば拾える。**

## 5. 費用

**ログとソースを読むだけ。LLM を呼ばない。ブラウザも触らない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**直す場合も $0**（フォローは DOM 操作で LLM を呼ばない）。
返信ループの実績は 1 回 $0.003 ／ 1 日 $0.027 ／ 1 か月 約 $0.81
（x68 適用後の上限は 1 日 $0.048 ／ 1 か月 $1.44）。
