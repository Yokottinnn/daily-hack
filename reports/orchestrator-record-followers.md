# 返信きっかけのフォローにもフォロワー数を記録する

**このレポートが作られた時刻: 2026-09-13 20:44:46 JST**

> `comment-orchestrator` は **返し率 21.5% でいちばん良いのに、記録していない。**
> `FOLLOW_OUT` に `profile` を持っているのに、JSON へ 5 つしか書いていない。

**フォローの件数も返信の本数も 1 件 も変えない。よって $0。**

## 0. 当てる前

```
  173 行 / 最終更新 2026-09-06 20:52
  followers_at_follow を含む箇所: 0
0
```

## 1. 足す 2 つ

| キー | 中身 |
| --- | --- |
| `followers_at_follow` | フォローした時点の相手のフォロワー数 |
| `following_at_follow` | 同・フォロー数 |

**既存のキーは 1 つも触らない。** `source` の行の前に差し込むだけ。

```
  目印 ①（FOLLOW_OUT の受け渡し）: 1 箇所
  目印 ②（JSON の中身）          : 1 箇所
  当てた（検査待ち）

  --- 検査して置き換える ---
    **置き換えた**（退避 comment-orchestrator.sh.bak-20260913-204446）
```

## 2. 当てた後（**実物**）

```bash
 150|         const p = '$WS/data/reply-followers.json';
 151|         const s = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
 152|         s['$AUTHOR'] = {
 153|           followed_at: new Date().toISOString(),
 154|           followback_status: 'pending',
 155|           scheduled_unfollow_at: null,
 156|           followers_at_follow: (function () { try { var f = JSON.parse(process.env.FOLLOW_OUT_JSON || '{}'); return (f.profile && typeof f.profile.follower_count === 'number') ? f.profile.follow
 157|           following_at_follow: (function () { try { var f = JSON.parse(process.env.FOLLOW_OUT_JSON || '{}'); return (f.profile && typeof f.profile.following_count === 'number') ? f.profile.follo
 158|           source: 'comment-orchestrator',
 159|           comment_id: '$ID'
 160|         };
 161|         const tmp = p + '.tmp';
 162|         fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
```

```
  --- 受け渡しの行 ---
    148:        FOLLOW_OUT_JSON="$FOLLOW_OUT" /usr/local/bin/node -e "
    156:          followers_at_follow: (function () { try { var f = JSON.parse(process.env.FOLLOW_OUT_JSON || '{}'); return (f.profile && typeof f.profile.follower_
    157:          following_at_follow: (function () { try { var f = JSON.parse(process.env.FOLLOW_OUT_JSON || '{}'); return (f.profile && typeof f.profile.following

  --- bash の構文検査（置き換えた後の実物） ---
    OK
```

## 3. いつ確かめられるか（**rc=0 は証拠にならない**）

```
  次の返信の周回: 22:00 JST（comment-warmup）
  そこで新しくフォローした相手に followers_at_follow が入る

  --- いまの状態 ---
    全体 346 件 / followers_at_follow を持つ 0 件
    今日フォローした件数: 9 件
```

## 4. 費用

**JSON にキーを 2 つ 足すだけ。フォローの件数も返信の本数も変わらない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

返信ループの**実績**（2026-09-13）: 1 回 $0.003 ／ 1 日 **$0.027** ／ 1 か月 **約 $0.81**。
**このタスクではこの額は動かない。**

> 候補を選ぶ前に広告を弾く変更は**別**。生成が 9 件/日 → 16 件/日 になり、
> 1 日 $0.048 ／ 1 か月 **$1.44**（増加 月 +$0.63）。**確認を取ってから出す。**
