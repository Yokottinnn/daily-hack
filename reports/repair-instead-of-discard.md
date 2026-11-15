# 捨てる前に飾りを外して測り直す

**このレポートが作られた時刻: 2026-09-13 02:14:57 JST**

> LLM 呼び出しは**既に終わっている**のに、末尾の絵文字が直近と被っただけで
> **本文ごと捨てていた。** 金は払って、出力は 0。

## 0. ジョブの数え方を直したうえで数える

**ジョブごとに `launchctl list` を呼び直さない。** 1 回のスナップショットを 3 列目の
ラベル完全一致で照合する。この取りこぼしが「4/8」の正体だった。

```
  3 ループ: **8 / 8 本**
  ai.openclaw.* 全体: 9 本
  CDP: 健全
  login ロック: 無い
```

## 1. `asuka-reply.cjs` に修理を入れる

```
  --- 書き換える前（該当箇所） ---
    231:  const rel = checkRelevance({ text, targetText: target, recentReplies: recentForGate, runReplies: runForGate }, relRules);
    232:  if (!rel.ok) return skip('噛み合い検査で弾いた: ' + rel.reasons.join(' / '));
    既に入っている数: 0
  退避: asuka-reply.cjs.bak-20260913-021457
  [eval]:9
  const OLD_SKIP = "if (!rel.ok) return skip(噛み合い検査で弾いた:
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Unterminated string constant
  
  SyntaxError: Invalid or unexpected token
      at makeContextifyScript (node:internal/vm:194:14)
      at compileScript (node:internal/process/execution:388:10)
      at evalTypeScript (node:internal/process/execution:260:22)
      at node:internal/main/eval_string:71:3
  
  Node.js v24.14.0
  node --check: OK
  --- 書き換えた後（**必ず出す**） ---
    232:  if (!rel.ok) return skip('噛み合い検査で弾いた: ' + rel.reasons.join(' / '));
```

## 2. 待たずに走らせて、実投稿を数える

```
  走らせる前の累計: **857 件**

  --- comment-orchestrator を直接 叩く（最大 4 件・約 $0.012） ---
    [2026-09-13T02:14:58] === comment orchestrator start (max_picks=2, reply_follow_cap=10) ===
    [2026-09-13T02:17:59] picked 2 / max 2 (from 2 candidates)
    [2026-09-13T02:17:59] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
    [2026-09-13T02:17:59] today's reply-connected follows: 0 / 10
    [2026-09-13T02:17:59] --- processing #1/2 for @<伏せ> ---
    [2026-09-13T02:18:01] gen failed (#1): {"ok":false,"error":"噛み合い検査で弾いた: 書き出しの「ふーん、」が直近 20 件に 3 件＝同じ入り方の繰り返し / テンプレに無い絵文字「😅」＝声の範囲の外","skip":true,"reason":"噛み合い検査で弾いた: 書き出しの「ふーん、」が直近 20 件に 3 件＝同じ入り方の繰り返し / テンプレに無い絵文字「😅」＝声の範囲の外"}
    [2026-09-13T02:18:01] --- processing #2/2 for @<伏せ> ---
    [2026-09-13T02:18:03] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 書き出しの「ふーん、」が直近 20 件に 3 件＝同じ入り方の繰り返し","skip":true,"reason":"噛み合い検査で弾いた: 書き出しの「ふーん、」が直近 20 件に 3 件＝同じ入り方の繰り返し"}
    [2026-09-13T02:18:03] === orchestrator done: 2 drafts, 0 reply-connected follows today ===

     60 秒後: 累計 857 件
    120 秒後: 累計 857 件

  走らせる前: 857 件 → 後: 857 件
  **今回 出た数: 0 件**
```

### まだ 0 件。**弾かれた理由を全部 出す**

修理が効いたかは、`噛み合い検査で弾いた` の理由を見れば分かる。
**末尾の絵文字・書き出しの相づちが理由なら、修理が当たっていない。**

```
  [2026-09-09T19:03:08] gen failed (#1): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 詳細はこちら","skip":true,"reason":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 詳細はこちら"}
  [2026-09-09T19:03:10] enqueue: {"ok":true,"id":"comment-20260909-1903-1"}
  [2026-09-09T19:03:29] enqueue: {"ok":true,"id":"comment-20260909-1903-2"}
  [2026-09-09T19:03:53] gen failed (#4): {"ok":false,"error":"生成側が skip: 紹介コード・招待コード・登録誘導の投稿。返信すべきでない","skip":true,"reason":"生成側が skip: 紹介コード・招待コード・登録誘導の投稿。返信すべきでない"}
  [2026-09-09T19:03:53] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
  [2026-09-09T22:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-09T22:03:08] picked 4 / max 4 (from 15 candidates)
  [2026-09-09T22:03:10] gen failed (#1): {"ok":false,"error":"生成側が skip: 楽天公式のキャンペーン告知投稿。返信すべき個人の体験・質問・情報がなく、無理に返信すると宣伝への乗っかりになる。また URL 短縮で詳細が不明なため、具体
  [2026-09-09T22:03:12] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 相手の投稿と共有する内容語が 0 個（1 個必要）＝読んでいない返信 / 書き出しの「あら、」が直近 20 件に 3 件＝同じ入り方の繰り返し","skip":true,"reason":"�
  [2026-09-09T22:03:15] gen failed (#3): {"ok":false,"error":"生成側が skip: 店舗の販売促進投稿。相手の具体的な状況・選択・困りごとがなく、返信する実質的な内容がない。商品への感想も数字も固有情報もないため、どの投稿にも貼れ�
  [2026-09-09T22:03:17] enqueue: {"ok":true,"id":"comment-20260909-2203-3"}
  [2026-09-09T22:03:38] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
```
