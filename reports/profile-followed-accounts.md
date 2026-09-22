# 最近フォローした相手の素性（2026-09-22 23:42 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-22 23:42:40 JST**

> 「サービスや店舗の公式アカウントをフォローしている。フォロバされるはずない」
> と指摘された（2026-09-22）。**入口に公式を弾く条件が 1 つも無い。**
>
> **「公式」の字面だけで弾くと個人まで巻き込む**（ポイ活の人が
> 「公式LINEはこちら」と書いているだけで落ちる）。**実データで信号を選ぶ。**

**ハンドルは頭 2 文字だけにしてある。** 出力は公開リポジトリに載るため。

## 1. フォローの記録はどこか

```
  在る  /Users/ny/.openclaw/workspace/data/followed.json 55191 bytes
  無い  /Users/ny/.openclaw/workspace/data/follow-log.json
  無い  /Users/ny/.openclaw/workspace/data/follow-history.json
  無い  /Users/ny/.openclaw/workspace/data/competitor-followed.json
  無い  /Users/ny/.openclaw/workspace/data/hashtag-followed.json

  --- data/ で follow を含むもの ---
    badge-followback-state.json
    follow-watchdog-state.json
    followed.json
    follower-daily-report-state.json
    follower-history.json
    follower-snapshots
    follower-target-config.json
    follower-target-config.json.bak
    following-snapshots
    refollow-blacklist.json
    refollow-may18-done.flag
    reply-followers.json
    reply-followers.json.bak-20260913-194151
    reply-followers.json.bak-20260913-194413
    reply-followers.json.bak-20260915-020121
    unfollow-cleanup-state.json
    unfollow-whitelist.json
    unfollow_batch.json
```

## 2. 記録に何が入っているか（**形を決め打ちしない**）

```json
  ===== followed.json : 183 件 =====
  最後の 1 件のキー: handle, followed_at, source, verified
```

**`followers_at_follow` が入っているはず**（`x122` でソースに在るのを見た）。
bio や名前まで残っていれば、DOM を見に行かずに済む。

## 3. 直近 30 件を、記録から並べる

```
  いつ                 ﾌｫﾛﾜｰ数  返った  相手        由来
  ------------------------------------------------------------------
  2026-08-22T15:50:27         -     -    ko…         followed
  2026-08-22T15:50:36         -     -    po…         followed
  2026-08-24T15:50:28         -     -    Ma…         followed
  2026-08-26T15:50:26         -     -    Al…         followed
  2026-08-27T15:50:35         -     -    ok…         followed
  2026-08-28T15:50:28         -     -    NV…         followed
  2026-08-28T15:50:42         -     -    xu…         followed
  2026-08-29T15:50:39         -     -    oy…         followed
  2026-09-05T15:50:27         -     -    ya…         followed
  2026-09-05T15:50:40         -     -    mo…         followed
  2026-09-05T15:50:51         -     -    um…         followed
  2026-09-05T15:51:04         -     -    kr…         followed
  2026-09-05T15:51:17         -     -    ka…         followed
  2026-09-06T15:50:26         -     -    ao…         followed
  2026-09-06T15:50:36         -     -    jt…         followed
  2026-09-06T15:50:45         -     -    li…         followed
  2026-09-07T15:50:28         -     -    Ta…         followed
  2026-09-07T15:50:43         -     -    na…         followed
  2026-09-08T15:50:29         -     -    ay…         followed
  2026-09-08T15:50:46         -     -    9E…         followed
  2026-09-13T15:50:29         -     -    Lo…         followed
  2026-09-15T15:50:43         -     -    lo…         followed
  2026-09-18T15:51:01         -     -    na…         followed
  2026-09-19T16:17:01         -     -    co…         followed
  2026-09-19T16:17:28         -     -    ce…         followed
  2026-09-20T15:50:35         -     -    sh…         followed
  2026-09-20T15:50:49         -     -    LE…         followed
  2026-09-21T15:50:32         -     -    gy…         followed
  2026-09-21T15:50:46         -     -    Ra…         followed
  2026-09-21T15:51:20         -     -    ry…         followed

  直近 30 件 のうちフォロワー数が記録されているもの: 0 件
```

## 4. 実際のプロフィールを見る（**最大 12 件・公式かどうかの信号**）

**記録に bio や名前が無いので、実物を見る。** 5 分 に収めるため 12 件まで。

```json
  rc=0 （**rc は証拠にならない。中身を見る**）
[
 {
  "handle":"ry…(14)",
  "name": "りょうた@コーストFIRE達成🎉",
  "bio": "35歳で夫婦FIRE目指してます🔥｜ 25歳大手金融勤務×公務員夫婦👫｜FP2級/簿記3級/宅建/ITパス保有｜ 現在資産2500万円（投資歴7年🔰）｜世帯年収1400万円｜マイホーム購入・区分3室所有（ワンルーム）🏢｜月23万円入金・生活費合計15万円の家計術と株式投資・不動産投資について発信中です✨",
  "badge": "blue",
  "following": "1,017 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"Ra…(13)",
  "name": "リコ📱楽天モバイル従業員紹介キャンペーン",
  "bio": "現役楽天社員による楽天モバイル紹介です♩楽天モバイル紹介実績多数🌟",
  "badge": "blue",
  "following": "5,618 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"gy…(8)",
  "name": "Gyock",
  "bio": "私はこれよりブログを始めようとしてる、ぎょくまつです。",
  "badge": "blue",
  "following": "596 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"LE…(10)",
  "name": "【公式】LEGEND100",
  "bio": "LEGEND100公式アカウントです✨",
  "badge": "blue",
  "following": "2,465 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"sh…(14)",
  "name": "しらたまちゃん",
  "bio": "🤍白猫しらたま × 🖤ハチワレ月見 ふたりのゆる〜い毎日🐾だいたい寝てる。たまに事件。猫好きさんフォローしてね🐈♡ nekochan公式ライバー🙌",
  "badge": "blue",
  "following": "1,608 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"ce…(9)",
  "name": "フラッグハルミ",
  "bio": null,
  "badge": "blue",
  "following": "1,319 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"co…(10)",
  "name": "connect24h",
  "bio": "セキュリティ × AI駆動開発の交差点を深掘り | 元Microsoft MVP(2003-2013) / CSIRT視点でShadow AI・AIエージェント脅威・物理AIを考察 | 重要インフラ系CSIRTマネージャ|セキュリティキャンプミニ広島お世話人の一人|情報処理安全確保支援士 法定講師",
  "badge": "blue",
  "following": "3,975 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"na…(8)",
  "name": "なほぞの＠マネー系ライターになりたい",
  "bio": "「この働き方、一生続ける？」元医療従事者→不動産経営→Webライターへ挑戦中✍️｜FP2級｜自由な働き方・節約・投資を発信｜温泉♨️猫🐱ちいかわ好き(^^)",
  "badge": "blue",
  "following": "24 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"lo…(13)",
  "name": "ᒪIՏᗩ",
  "bio": "♡なんでもつぶやきます🫶 ♡くだらないことが言いたくなる衝動に駆られます🥹 ♡動物大好きです🐰🐶🐱🐻‍❄️🐼 ♡野球大好き F党です⚾️ #友達1万人できるかなチャレンジ",
  "badge": "blue",
  "following": "2,277 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"Lo…(9)",
  "name": "タカシ君｜ ❤️‍🔥田草川さんファン過ぎアカウント❤️‍🔥 通信費をマイナスに変える闇の魔法使い",
  "bio": "わたくし、孝行息子タカシたん｜通信費を下げて家族に還元｜家族全員でMNP→通信費実質0円を達成｜大好きな姉にiPhone16プレゼント、大大大好きな家族に圧力IH炊飯ジャー炎舞炊き(5．5合炊き) e angle select ブラック NW-NH10E4-BAプレゼント",
  "badge": "blue",
  "following": "7,158 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"9E…(15)",
  "name": "ハバネロ",
  "bio": "資産1000万やっと到達！ 失敗の数は覚えてません。 日本株・決算を勉強中📚 長期投資＋配当好き。 含み損は幻🙄 たまに幻じゃなくなる。",
  "badge": "blue",
  "following": "615 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 },
 {
  "handle":"ay…(12)",
  "name": "あやの｜元外資系金融",
  "bio": "元外資系金融→大手企業で経営企画 相場を当てるより、続けられる投資設計。 NISA・インデックス投資をわかりやすく発信🌷 詳しい解説はYouTubeで↓ https:// youtube.com/@ay…?s i=dC_1VlXwcnzYMZ0P …",
  "badge": "blue",
  "following": "1,141 フォロー中",
  "followers": null,
  "hasProfessional": false,
  "category": null
 }
]

```

## 5. どの信号で弾くかを決める材料

| 信号 | 公式だけを分けられるか |
| --- | --- |
| **`badge: gold`**（認証済み組織） | **いちばん強い。** 個人は金バッジを持てない |
| `hasProfessional` / `category` | 「ビジネス」「小売」等。個人事業主も付けられるので単独では弱い |
| `following` が極端に少ない | 公式は誰もフォローしない。**数字の取り方が表記依存**（1.2万 等） |
| 名前に 株式会社 / (株) / Inc / Corp | 強いが、取りこぼす（カタカナ社名など） |
| bio に 公式 / オフィシャル | **単独で使わない。** 個人が「公式LINE」と書く |

**組み合わせを決めるのは次のタスク。** ここでは材料を出すだけ。

**`返った` の列と突き合わせる。** 公式に分類したものが本当に返っていなければ、
その信号は正しい。返っているものが混ざっていれば、弾きすぎ。

## 6. 費用

**記録を読んで、プロフィールを 12 件 開くだけ。LLM を呼ばない。**
**フォローの判定自体も DOM だけなので、条件を足しても課金は増えない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
