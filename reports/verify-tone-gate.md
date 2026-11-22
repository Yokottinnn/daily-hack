# 出口の検査は効いているか（2026-08-29 14:54 JST）

> **差し込んだ＝効いている、ではない。** 発火後のログで確かめる。

## 1. 組み込みの状態

- 出口（tone-gate）: **組み込み済み**
- 入口（ng-filter）: **組み込み済み**
- scripts/tone-gate.cjs: 有り（4611 B）
- scripts/reply-tone-check.cjs: 有り（3220 B）
- data/reply-tone-rules.json: 有り（3572 B）
- テンプレート数: [eval]:2
tryconst t=JSON.parse(require('fs').readFileSync('/Users/ny/.openclaw/workspace/data/comment-templates.json'catch(e){console.log('読めない')}
         ^
Expected ';', '}' or <eof>

SyntaxError: Unexpected identifier 't'
    at makeContextifyScript (node:internal/vm:194:14)
    at compileScript (node:internal/process/execution:420:10)
    at evalTypeScript (node:internal/process/execution:292:22)
    at node:internal/main/eval_string:71:3

Node.js v26.0.0 - テンプレート数: [eval]:2
try'utf8'));
   ^^^^^^
Expected '{', got 'string literal'

SyntaxError: Unexpected string
    at makeContextifyScript (node:internal/vm:194:14)
    at compileScript (node:internal/process/execution:420:10)
    at evalTypeScript (node:internal/process/execution:292:22)
    at node:internal/main/eval_string:71:3

Node.js v26.0.0

## 2. 発火後のログに出ているか

- ログ最終更新: 08-29 12:04
- tone-gate の行: **0 行**

**まだ 1 度も通っていない。** 差し込み後の発火が来ていないか、差し込みが効いていない。

直近の発火（=== で始まる行）:
    5918:[2026-08-28T19:00:05] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    5932:[2026-08-28T19:04:05] === orchestrator done: 2 drafts, 2 reply-connected follows today ===
    5933:[2026-08-28T22:00:05] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    5947:[2026-08-28T22:04:15] === orchestrator done: 2 drafts, 2 reply-connected follows today ===
    5948:[2026-08-29T12:00:05] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    5962:[2026-08-29T12:04:20] === orchestrator done: 2 drafts, 1 reply-connected follows today ===

## 3. 較正 — 過去の投稿を通したらどうなるか

**弾きすぎると返信が 0 件になり、緩すぎると意味がない。**
1 日 8 件のうち 1〜2 件 落ちるくらいが妥当という見立て。実測を出す。

- 検査した件数: 200 件（post_queue の直近 comment）
- **送らない（block）: 19 件（9.5%）**
- 送るが記録（warn）: 61 件（30.5%）
- 通過: 120 件（60.0%）

- 1 日 8 件に換算すると block は約 0.8 件/日

理由別の内訳:
      warn:command           57
      block:insult           12
      warn:assertion         11
      block:illegal_topic    6
      block:referral         5
      warn:repeat            2
      block:minor_safety     1

## 4. block に当たった過去の投稿（**X 上に残っている可能性がある**）

消す判断のために id を出す。**本文は X 上で公開済みなので伏せない。**

---
  理由: referral=紹介コード
  投稿: 2080957311158464779  2026-07-25T10:05:02.336Z
  本文: ちょっと待って、紹介コード入力で8,000円割引って具体的にどうやるの？教えなさいよ😤 
---
  理由: referral=紹介コード
  投稿: 2081365705552003516  2026-07-26T13:07:11.133Z
  本文: ちょっと待って、紹介コード入力のタイミングって具体的にどうやるの？教えなさいよ😤 
---
  理由: referral=クーポンコード
  投稿: 2083177122584265174  2026-07-31T13:05:06.551Z
  本文: iHerbのクーポンコード活用して海外サプリ10%OFF購入とは、やるじゃない。アタシも見直したわ✨ 
---
  理由: insult=適当なこと言ってない illegal_topic=即金
  投稿: 2085713690838643069  2026-08-07T13:04:31.973Z
  本文: ちょっと、登録するだけで必ず1400円即金って本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 
---
  理由: referral=招待コード
  投稿: 2088522321971818895  2026-08-15T07:05:01.409Z
  本文: ポイ活アプリでチャレンジするの？いいわね！招待コード活用して初期ブーストで頑張りなさいよ💪 
---
  理由: insult=適当なこと言ってない
  投稿: 2088522722905338353  2026-08-15T07:06:37.034Z
  本文: ちょっと、新規ダウンロードで即1400円分ポイント獲得って本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 
---
  理由: insult=適当なこと言ってない illegal_topic=即金
  投稿: 2088884362960122326  2026-08-16T07:03:38.727Z
  本文: ちょっと、詐欺なし案件で即金って本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 
---
  理由: illegal_topic=即金
  投稿: 2088974888061329532  2026-08-16T13:03:21.593Z
  本文: 即金案件を探すの？いいわね！焦らず信頼できるやつ見極めてで頑張りなさいよ💪 
---
  理由: insult=適当なこと言ってない
  投稿: 2089609069535674520  2026-08-18T07:03:22.219Z
  本文: ちょっと、PayPalで送金したら資産が増えるって本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 
---
  理由: insult=本気で言ってる
  投稿: 2089609154038272269  2026-08-18T07:03:42.350Z
  本文: あら？JKに金くれって言ったら貰えるとか本気で言ってる？まだそんなこと信じてんの？💢 
---
  理由: insult=適当なこと言ってない
  投稿: 2089971535234887901  2026-08-19T07:03:40.781Z
  本文: ちょっと、5分で必ず報酬が貰えるって本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 
---
  理由: insult=本気で言ってる
  投稿: 2090273452649570694  2026-08-20T03:03:23.552Z
  本文: あら？メッセージと写真でお金くれる人がいるって本気で言ってる？まだそんなこと信じてんの？💢 
---
  理由: insult=適当なこと言ってない illegal_topic=即金
  投稿: 2090424531831959781  2026-08-20T13:03:43.687Z
  本文: ちょっと、振込即金でPayPay受け取りって本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 
---
  理由: insult=適当なこと言ってない
  投稿: 2091058636303012163  2026-08-22T07:03:25.890Z
  本文: ちょっと、分割返済で利息相談可能な個人融資って本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 
---
  理由: insult=適当なこと言ってない
  投稿: 2091783408137712040  2026-08-24T07:03:24.953Z
  本文: ちょっと、Wi-Fi切ってからのリンク起動で8250円って本当なの？ソースはどこよ？適当なこと言ってないでしょうね🤨 

## 5. 判断

- block が **0 件** → 緩すぎる。ルールを足す
- block が **1 日 3 件以上** → 厳しすぎる。返信量が落ちる。warn へ移す
- block が **1 日 0.5〜2 件** → 妥当。このまま様子を見る

**上限と実績を混同しない。** 上は換算値であって、実機の発火実績ではない。
