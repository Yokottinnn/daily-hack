# PAY ID パターンA を予約する（2026-09-27 00:33 JST・$0）

**このレポートが作られた時刻: 2026-09-27 00:33:20 JST**

## 0. 予約時刻

```
  JST          2026-09-27 12:00
  scheduled_at 2026-09-27T03:00:00.000Z  (UTC)
  いまから      687 分後
```

## 1. 画像を `origin/main` から取り直す

**Mac の作業ツリーは main とは限らない。** 絵を直しても取り直さないと古い絵が出る。

```
  1-summary.jpg        204105 bytes
  2-atobarai.jpg       112730 bytes
  3-shops.jpg          141248 bytes
  4-rating.jpg         127986 bytes
```

## 2. キューに 1 件 積む

契約書 §3 の 5 条件をすべて満たす形にする。

```
  OK 積んだ: blog-promo-20260927-payid-a
    [1/3] 重み 222 / 280
    [2/3] 重み 218 / 280
    [3/3] 重み 227 / 280
  rc=0
```

## 3. その時刻に 1 回だけ走るジョブ

**走ったら自分を外して消える。** 常駐しない＝滞留を拾わない。

```
  bootstrap rc=0  
```

## 4. 載ったことの証拠（**rc ではなく `print` で見る**）

```
  	path = /Users/ny/Library/LaunchAgents/ai.openclaw.publish-payid-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

キューに入ったことの確認:

```
  id の出現: 1
```

---

## 取り消すとき

```bash
  launchctl bootout gui/501/ai.openclaw.publish-payid-oneshot
  rm -f "/Users/ny/Library/LaunchAgents/ai.openclaw.publish-payid-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-payid-oneshot.sh"
  # キューの blog-promo-20260927-payid-a を status=cancelled にする
```

## 費用

**キューを 1 行 足して plist を置くだけ。投稿も DOM 操作のみで LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

> **常駐させない**ので、この先 毎日 かかるものは増えない。
