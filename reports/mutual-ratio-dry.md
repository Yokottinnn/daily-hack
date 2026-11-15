# 相互フォローの整理に「釣り合い」を足して DRY で数える（2026-10-12 22:47:23 JST・$0・1 件も外していない）

## ① パッチ
```json
{"ok":true,"note":"書いた・node --check 通過"}
```

## ② DRY（MUTUAL_RATIO_CUT=0.8・候補 15 件で打ち切り）

**230 秒で打ち切った（途中まで）**
```
相互フォロー: 198 件
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x283-mutual-ratio-dry.sh: line 98: 27653 Terminated: 15          ( cd "$W" && env DRY_RUN=1 MUTUAL_RATIO_CUT=0.8 MAX_UNFOLLOW=15 GRACE_DAYS=1 OPS_WS="$W" CDP_URL="${CDP_URL:-http://127.0.0.1:18810}" /usr/local/bin/node "$S/mutual-prune.js" > "$L" 2>&1 )
```

理由の内訳（✂ のみ）:
```
残した理由（上位）:
```

## ③ follow-balance.js の比率まわり
```javascript
139:      // 診断は正しかった（ヘッダーの実数 239 に対し、この走査は 271〜275 を返す）。
181:  await page.waitForTimeout(4700 + Math.floor(Math.random() * 1500));   // x219: 続けて開きすぎると X が空のページを返す（2.2 秒 → 4.7〜6.2 秒）
295:  // （9/28 実測: 走査 190 / ヘッダーの実数 173）。多いと思い込んで外しすぎる。
296:  // **X が表示しているヘッダーの数だけを使い、読めなければ比率を見ない**（fail-open）。
297:  const CEIL_RATIO = Number(process.env.FOLLOW_RATIO_CEIL || 0.65);
298:  const FLOOR_RATIO = Number(process.env.FOLLOW_RATIO_FLOOR || 0.45);
299:  // **目標。ここへ寄せる**（2026-09-28 に指示を受けた時点の比率）。
302:  // **いま何件 居るかはヘッダーで分かる。目標より多い分だけ外す。**
303:  const TARGET_RATIO = Number(process.env.FOLLOW_RATIO_TARGET || 0.58);
329:  let ratioNote = "ヘッダーが読めないので比率を見ない";
331:    const ceilN = Math.floor(hdr.followers * CEIL_RATIO);
332:    const floorN = Math.floor(hdr.followers * FLOOR_RATIO);
333:    const over = hdr.following - ceilN;
334:    log("実数（ヘッダー）: フォロー中 " + hdr.following + " / フォロワー " + hdr.followers +
336:        "（目標 " + Math.floor(hdr.followers * TARGET_RATIO) + " 件 / 警戒 " + ceilN +
337:        " 件 / 下限 " + floorN + " 件）");
338:    const targetN = Math.floor(hdr.followers * TARGET_RATIO);
339:    if (hdr.following <= floorN) {
341:      ratioNote = "**下限 " + floorN + " 件 以下。外しすぎなので今回は外さない**";
343:      // **目標より多い分だけ外す。** 今日の増分は数えない（記録に依存しない）
344:      quota = Math.min(MAXN, Math.max(0, hdr.following - targetN));
346:        ratioNote = "**目標 " + targetN + " 件 以内。外さない**";
348:        ratioNote = "**警戒線 " + ceilN + " 件 を超えている。目標 " + targetN +
349:          " 件 まで戻す（あと " + (hdr.following - targetN) + " 件 / 今回 " + quota + " 件）**";
351:        ratioNote = "**目標 " + targetN + " 件 へ寄せる（あと " + (hdr.following - targetN) +
356:    log("**ヘッダーの実数が読めなかった。比率の判定をしない**（従来どおりの上限で動く）");
359:      ratioNote + " / 絶対上限 " + MAXN + "）");
380:    if (d !== null && d < GRACE_DAYS) return "フォローしてまだ " + Math.floor(d) + " 日（猶予 " + GRACE_DAYS + " 日）";
456:      const idle = p.lastPost ? Math.floor((now - new Date(p.lastPost).getTime()) / 86400000) : null;
575:      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
```

**1 件も外していない。plist も触っていない（定時の本番は従来どおり）。LLM を呼んでいない（$0／回・$0／日・$0／月）。** 戻すときは mutual-prune.js.bak-x283。
