# ALT の 2 枚目以降を直す（2026-11-05 21:32:35 JST・$0・投稿していない）

## ①〜③ 直す
```
対象の候補: 1 本 → post-via-playwright.js 
置き換えた（1 か所）
構文 OK・入れ替えた（退避 post-via-playwright.js.bak-x425）
112:          // そのときは押して編集画面を開き「次の画像」で i 枚目まで送る（2026-11-05 x425: 「次へ」は編集画面ではいつも押せず、2 枚目以降で必�
126:            const nx = page.locator('[role="dialog"]:has([data-testid="endEditingButton"]) [aria-label="次の画像"]:not([aria-disabled="true"])').last();
```

## ④ 確かめる（画像 2 枚・ALT 2 本・投稿しない）
```json
{
 "log": [
  "1枚目: 編集画面の位置 at=0（合っている）",
  "1枚目: 269 字 入れた（一致）",
  "2枚目: 編集画面の位置 at=1（合っている）",
  "2枚目: 503 字 入れた（一致）",
  "閉じる: 「破棄」を押した"
 ],
 "selector": "[role=\"dialog\"]:has([data-testid=\"endEditingButton\"]) [aria-label=\"次の画像\"]:not([aria-disabled=\"true\"])",
 "alt_badges": 2,
 "wrapper_text": [
  "2件の画像の説明"
 ],
 "result": "2 / 2 枚に ALT が入った"
}
```

画面: x425-final.png 

**投稿ボタンは触っていない。下書きは破棄した。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
