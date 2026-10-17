# フォロー返しした人を別のジョブが外していないか（2026-10-17 13:30:04 JST・$0・押していない）

## ① いまの返し漏れ（ボタンの文字ごと）
```
   3 フォロー
   3 フォローバック
```

## ② ボタンが「フォロー」の人の、全ログでの出現（新しい順に最大 6 行／人）

### 人 1（ボタン「フォロー」）
```
data での出現: follow-balance-followers-prev.json follow-balance-lists.json 
```

### 人 2（ボタン「フォロー」）
```
data での出現: follow-balance-followers-prev.json follow-balance-lists.json 
```

### 人 3（ボタン「フォロー」）
```
data での出現: 
```

## ③ 全体: badge-followback が返した人のうち、あとで外された人（ログのファイル別）
```
返した人: 185 / あとで外す側のログに出た人: 26
  competitor-follower-follow.log: 38 行
  follow-balance.log: 70 行
  mutual-prune.log: 17 行
  reply-followback-check.log: 3 行
  x284-mutual-dry.log: 1 行
```

**押していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
