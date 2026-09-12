# モデルに「弾かれる条件」を教える

**このレポートが作られた時刻: 2026-09-13 02:34:20 JST**

> **弾く条件を全部 知っているのに、モデルには 1 つも伝えていなかった。**
> プロンプトへ渡すのは直近 **8 件の全文**、ゲートが見るのは **20 件**。
> 9〜20 件前に使った書き出しは、モデルから見えないので避けようがない。

## 0. 前提

```
  3 ループ    : **8 / 8 本**
  CDP         : 健全
  login ロック: 無い
  修理(x43)   : 入っている
  本日の返信  : **0 件** / 累計 857 件
```

## 1. 禁止リストをプロンプトに入れる（**根本原因**）

```
  --- 当てる前 ---
    142:  const userMsg = String(cfg.user_template || '{TARGET}')
  パッチの node --check: OK
    書き換えた。userMsg 行=142 / DRY_RUN 行=146
  対象の node --check: OK
  --- 当てた後 ---
    142:  let userMsg = String(cfg.user_template || '{TARGET}')
    158:  // BANNED_LIST (2026-09-13): **弾く条件をモデルにも教える。**
    181:    const badHead = [...new Set(prev2.concat(runR2).map((x) => x.slice(0, oc2)).filter(Boolean))].slice(0,
    198:    const okE = (BR.allowed_emoji || []).filter((e) => !badE.includes(e));
    202:    if (badHead.length) parts.push(BAN_B + badHead.map((o) => KO + o + KC).join(TEN));
```

## 2. 広告を入口で落とす（LLM を呼ぶ前に）

ログに残っていた**生成後**の skip ＝ **LLM 代を払ってから捨てていた。**

```
  --- 当てる前 ---
    campaign_words 14 件 / domains 11 件
    opening_phrases 11 件 / allowed_emoji 14 件
    campaign_words: 14 → 27 件
    domains       : 11 → 15 件
  --- 当てた後 ---
    campaign_words 27 件 / domains 15 件
    opening_phrases 11 件 / allowed_emoji 14 件
```

## 3. 目標 16 件に届くまで繰り返す（最大 8 回）

1 回あたり 最大 4 件・約 $0.012。**最大 8 回で $0.096。**
目標に届けば途中で止まる。候補が尽きても止まる。

```
  開始時: 本日 0 件 / 累計 857 件 / 目標 16 件

  --- 1 回目 ---
      [2026-09-13T02:37:22] picked 1 / max 4 (from 1 candidates)
      [2026-09-13T02:37:24] gen failed (#1): {"ok":false,"error":"生成側が skip: 金銭の要求・乞食行為。返信対象として不適切","skip":true,"reason":"生成側が skip: 金銭の要求・乞食行為。返信対象として不適切"}
      [2026-09-13T02:37:24] === orchestrator done: 1 drafts, 0 reply-connected follows today ===
      → 本日 0 件 / 累計 857 件
  --- 2 回目 ---
      → 本日 0 件 / 累計 857 件
  --- 3 回目 ---
      → 本日 0 件 / 累計 857 件
  --- 4 回目 ---
      → 本日 0 件 / 累計 857 件
  --- 5 回目 ---
      → 本日 0 件 / 累計 857 件
  --- 6 回目 ---
      → 本日 0 件 / 累計 857 件
  --- 7 回目 ---
      → 本日 0 件 / 累計 857 件
  --- 8 回目 ---
      → 本日 0 件 / 累計 857 件

  叩いた回数: 8 回（概算 $0.096 まで）
  本日: 0 件 → **0 件**
  累計: 857 件 → **857 件**
  **今回 出た数: 0 件**
```

### まだ 0 件。**弾かれた理由をそのまま出す**

```
  [2026-09-09T16:03:12] gen failed (#1): {"ok":false,"error":"噛み合い検査で弾いた: 相手の語をなぞっただけで、こちらから足した情報がゼロ / 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","skip":true,"reason":"噛み合い検査で�
  [2026-09-09T16:03:14] gen failed (#2): {"ok":false,"error":"生成側が skip: 相手が具体的な案件名・条件を示していないため、実質的な返信が不可能。また、案件紹介の要求は紹介コード・URL誘導につながりやすく、ガイドライン上リスク",
  [2026-09-09T16:03:16] gen failed (#3): {"ok":false,"error":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","skip":true,"reason":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じ�
  [2026-09-09T16:03:16] gen failed (#4): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / r10.to","skip":true,"reason":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / r10.to"}
  [2026-09-09T16:03:16] === orchestrator done: 4 drafts, 6 reply-connected follows today ===
  [2026-09-09T19:03:07] picked 4 / max 4 (from 10 candidates)
  [2026-09-09T19:03:08] gen failed (#1): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 詳細はこちら","skip":true,"reason":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 詳細はこちら"}
  [2026-09-09T19:03:53] gen failed (#4): {"ok":false,"error":"生成側が skip: 紹介コード・招待コード・登録誘導の投稿。返信すべきでない","skip":true,"reason":"生成側が skip: 紹介コード・招待コード・登録誘導の投稿。返信すべきでない"}
  [2026-09-09T19:03:53] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
  [2026-09-09T22:03:08] picked 4 / max 4 (from 15 candidates)
  [2026-09-09T22:03:10] gen failed (#1): {"ok":false,"error":"生成側が skip: 楽天公式のキャンペーン告知投稿。返信すべき個人の体験・質問・情報がなく、無理に返信すると宣伝への乗っかりになる。また URL 短縮で詳細が不明なため、具体
  [2026-09-09T22:03:12] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 相手の投稿と共有する内容語が 0 個（1 個必要）＝読んでいない返信 / 書き出しの「あら、」が直近 20 件に 3 件＝同じ入り方の繰り返し","skip":true,"reason":"�
  [2026-09-09T22:03:15] gen failed (#3): {"ok":false,"error":"生成側が skip: 店舗の販売促進投稿。相手の具体的な状況・選択・困りごとがなく、返信する実質的な内容がない。商品への感想も数字も固有情報もないため、どの投稿にも貼れ�
  [2026-09-09T22:03:38] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
```

## 4. フォロー／アンフォローの実数

### 4-A. 一次情報（状態ファイル）

```
  reply-followers.json        331 件 / 最終更新 2026-09-13 02:44
  followed.json               173 件 / 最終更新 2026-09-13 00:51

    attachments
    auto-images
    auto-reply-fail-streak.json
    automation-window.json
    badge-followback-state.json
    blog-covers
    blog-eyecatch-cache
    blog-rss-state.json
    bookmark-learnings.json
    bookmark-state.json
    canary-state.json
    celebration
    character-library
    chrome-pid.json
    claude-cost-latest.csv
    comment-state.json
    comment-templates.json
    comment-templates.json.bak.20260513-100323
    comment-templates.json.bak.20260515-watashi-migration
    comment-templates.json.pre034.20260827-154041
    cookie-backups
    cost-2026-07.csv
    cost-log.jsonl
    dm-state.json
    engagement_log.json
```

### 4-B. 一次情報**ではない**（ログの行数。二重計上する）

```
  competitor-follower-follow   本日    0 行 / 最終更新 09-09 18:47
  hashtag-follow               本日    0 行 / 最終更新 09-09 17:04
  badge-followback             本日    0 行 / 最終更新 09-13 00:51
  reply-followback-check       本日    0 行 / 最終更新 09-13 01:15
  reply-followers-cleanup      本日    0 行 / 最終更新 09-13 02:44
```
