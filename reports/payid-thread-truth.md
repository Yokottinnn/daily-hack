# PAY ID のスレッドはどこまで出たか（2026-09-27 16:20 JST・$0）

**このレポートが作られた時刻: 2026-09-27 16:20:58 JST**

> **読むだけ。** 投稿も削除もしていない。**消すかどうかは利用者が決める。**

## 1. ログの全体から tweet id / URL を探す

**`x165` は末尾 14 行しか出していない。** 頭から見る。

```
  10 行 / 1406 bytes / 更新 09-27 12:00:30

  --- status URL / 19 桁前後の数字 ---
    "tweet_id":"2104043402358886416
    status/2104043402358886416

  --- 先頭 40 行（何をしてから落ちたか）---
    [run-publish] thread_chain mode
    [post-via-playwright] attached 4/4 image(s)
    [step] connect t=0ms
    [step] navigate-target t=103ms
    [step] find-reply-textarea t=6236ms
    [textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6280ms
    [step] type-text t=6280ms
    [x154] like 付いた
    {"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"QkFTReOBp+S9nOOCieOCjOOBn+OCt+ODp+ODg+ODl+KAlOKAlOOBguOBruWAi+S6uuWVhuW6l+OBv+
    [2026-09-27 12:00:30] done rc=0
```

## 2. キューの行を、キーを選ばず全部 出す

**`x165` は 11 キーだけ出した。** id が別のキーに入っているかもしれない。

```json
  {
    "id": "blog-promo-20260927-payid-a",
    "kind": "thread",
    "status": "awaiting_approval",
    "auto_publish": true,
    "scheduled_at": "2026-09-27T03:00:00.000Z",
    "created_at": "2026-09-26T15:33:20.798Z",
    "text": "PAY ID、招待コード入れるだけで500円分もらえるわよ。\n\n招待コード：YY8RQV\n\n招待コードを入力すると\n《500円分のPAY IDポイント》がもらえます！\n#PR\n\n▽PAY IDアプリはこちら\nhttps://s.payid.…(略)",
    "image_path": "/Users/ny/.openclaw/workspace/data/payid-invite/1-summary.jpg,/Users/ny/.openclaw/workspace/data/payid-invite/2-atobarai…(略)",
    "thread_chain": [
      {
        "text": "PAY ID、招待コード入れるだけで500円分もらえるわよ。\n\n招待コード：YY8RQV\n\n招待コードを入力すると\n《500円分のPAY IDポイント》がもらえます！\n#PR\n\n▽PAY IDアプリはこちら\nhttps://s.payid.…(略)",
        "role": "hook",
        "image_path": "/Users/ny/.openclaw/workspace/data/payid-invite/1-summary.jpg,/Users/ny/.openclaw/workspace/data/payid-invite/2-atobarai…(略)"
      },
      {
        "text": "BASEで作られたショップ——あの個人商店みたいなネットショップが、ぜんぶこのアプリから買えるの。2,000万アカウント突破、App Storeの評価4.65。\n\n食品・調味料・フルーツ・お菓子。お米や野菜を生産者から直接っていう枠もあるわ…(略)",
        "role": "body"
      },
      {
        "text": "極めつけが「PAY ID あと払い」。\n今日買って翌月払い。紙の請求書もなし、コンビニでバーコード見せるだけよ。\n\nつまり、500円もらって、あと払いで買える。\nタダで先に500円ぶん持っときなさい。\n\n招待コード：YY8RQV\nhttps…(略)",
        "role": "cta"
      }
    ],
    "_note": "2026-09-26 に利用者が画像を見たうえで承認（レビューページ 版 28・payid-a）。文面は指示なく変えない"
  }
```

## 3. 自分の TL の最新の投稿を読む（**これが決め手**）

**キューとログで分からないなら、実物を見る。**

```json
  {
    "ok": true,
    "count": 7,
    "rows": [
      {
        "url": null,
        "at": "2026-09-27T01:35:12.000Z",
        "text": "フェアモント東京のクラブラウンジ。朝食はオーダーメニュー＋ビュッフェの組み合わせ。和食が人気で確かに美味しかったけど個人的な推しはリコッ�
      },
      {
        "url": "https://x.com/heng_ji31590/status/2104104877668680175",
        "at": "2026-09-27T07:04:29.000Z",
        "text": "クラブラウンジでリコッタパンケーキ、いいわね。焼きたてふわふわって朝から気分上がるわ。で、隠れメニューのクロワッサンってスタッフに言えば�
      },
      {
        "url": null,
        "at": "2026-09-27T02:26:53.000Z",
        "text": "おはようございます🍦 な、な、ななんと タピオカの日は、本日で最後となります🥲 本日20:30まで販売しております🧋 湘南モールフィルでお待ちして�
      },
      {
        "url": "https://x.com/heng_ji31590/status/2104104794084544828",
        "at": "2026-09-27T07:04:09.000Z",
        "text": "ラスト販売か。タピオカの日って期間限定だったんだ。湘南モールフィルなら立地いいし、20:30までなら仕事帰りでも間に合うわね。で、閉店後はその�
      },
      {
        "url": null,
        "at": "2026-09-26T01:39:57.000Z",
        "text": "特定口座は、、売っても問題ない銘柄を 新NISAは、持ち続けられる銘柄を意識してます＾＾ 野村不動産は、権利日までに単元化を意識してます あくまで
      },
      {
        "url": "https://x.com/heng_ji31590/status/2103663023621837140",
        "at": "2026-09-26T01:48:43.000Z",
        "text": "あ、権利日狙いか。単元化の手法、アタシもやってるけど、その先の配当狙いもあるってわけ？コツコツ派、好きよ"
      },
      {
        "url": null,
        "at": "2026-09-25T16:40:41.000Z",
        "text": "厳しいお言葉！"
      }
    ]
  }
```

**取れなければ「取れない」と書く。** 推測の結論は置かない（最上位ルール 11）。

## 4. 招待コードとリンクが出ているか

**[1/3] に `YY8RQV` と `s.payid.jp/nNE1nwcd` を必ず入れる**という指示だった。
**出ているなら、その 1 本だけでも用は足りている。** 判断材料にする。

```
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x167-payid-thread-truth.sh: command substitution: line 159: syntax error near unexpected token `newline'
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x167-payid-thread-truth.sh: command substitution: line 159: `c="$(grep -c 'YY8RQV' "$F" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*'
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x167-payid-thread-truth.sh: line 159: c: unbound variable
