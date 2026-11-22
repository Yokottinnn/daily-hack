# follow-balance.js に「外されたら外し返す」「期日超えを外す」を足す（2026-10-04 12:33 JST・$0）

**このレポートが作られた時刻: 2026-10-04 12:33:02 JST**

```
  控え: follow-balance.js.bak-x227-20261004-123302
  当たった数（1 なら当たり）: 並べ替え 1 ／ 理由 1 ／ 覚える 1 ／ 書き戻し 1
  node --check rc=0 
  置いた。603 行 ／ x227 の印 17 個
```

## 足したところ

```
394:  // x227: 外された人（前回はフォロワー・今回いない）と、フォロバ判定で外す予定日を過ぎた人を、片思いの先頭に並べる（2026-10-04 に指示）
395-  const FPREV = path.join(WS, "data", "follow-balance-followers-prev.json");
396-  // **フォロワーを読み切れたときだけ比べる。** 読み切れていないと、相互を「外された」と取り違える
397-  const fComplete = !!(hdr && Number.isFinite(hdr.followers) && followers.size >= hdr.followers);
435:    cuts.push({ h, why: x227Why(h), rank: 1 });   // x227: 理由を「外された」「予定日を過ぎた」と分ける
568:        x227Unf.push({ h, why: c.why });   // x227
579:  // x227: 外した人を reply-followers.json にも書く（フォロバ判定の側が「外す予定」を持ち続けないように）
```

- **ジョブは走らせていない。** 次の定時（11:45 / 18:45）から効く。1 回目は「前回の記録が無い」ので、外された人の判定は 2 回目から
- 戻すときは `follow-balance.js.bak-x227-20261004-123302` を follow-balance.js に戻す

**外していない。フォローしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
