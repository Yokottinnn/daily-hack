# post-comment.js: 空白・改行の数の違いでは止めない（2026-10-04 20:09 JST・$0）

```
  控え: post-comment.js.bak-x247-20261004-200941
  当たった数（1 なら当たり）: 1
  node --check rc=0 
  置いた。363 行
```

```javascript
186:      // x247: X の入力欄は空行 1 つにつき改行を 1 つ多く返す（JAL [2/2] で 180 / 182・先頭は一致）。空白・改行は落として比べる
187-      const _x247sq = (v) => _norm(v).replace(/\s+/g, "");
188-      if (_x247sq(_got) !== _x247sq(text)) {
189-        out({
```

- 戻すときは `post-comment.js.bak-x247-20261004-200941` を post-comment.js に戻す

**投稿していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
