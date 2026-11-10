# 返信の見張りを 7 日に広げる（2026-11-11 00:51:45 JST・$0）
```
OK
  入れた（前のものは .bak.20261111-005145）
109:  const cutoff7 = Date.now() - 7 * 24 * 3600 * 1000;
113:    e.posted_at && new Date(e.posted_at).getTime() > (String(e.id || "").startsWith("comment-") ? cutoff : cutoff7)
--- 7 日で見ることになる投稿の数（今の時点）
  合計 19 本（うち自分から出した投稿 3 本）
```
