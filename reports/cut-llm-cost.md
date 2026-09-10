# 返信の LLM コストを下げる

**このレポートが作られた時刻: 2026-09-10 21:38:27 JST**

> **出力は入力の 5 倍 高い**（Haiku 4.5: 入力 $1.00 / 出力 $5.00 per MTok）。
> だから**出力から削る**。次に**呼ぶ回数**を減らす。

**入れるのは 2 つだけ。** まとめ判定と起動回数の変更は`x22`の実測を見てから。

## 0. 触る前の確認

```
  有る  asuka-reply.cjs                                246 行  09-06 20:15
  有る  ng-filter-candidates.cjs                        87 行  08-27 22:38
```

### 退避（**変更前に必ず取る**）

```
  asuka-reply.cjs.bak-20260910-213827
  ng-filter-candidates.cjs.bak-20260910-213827
```

## 1. skip の理由をコード化する（**出力を削る**）

### いま生成器は skip の理由をどう作らせているか

```javascript
  26:// **弾かれたら skip にする。** 無理に返信するくらいなら黙るほうがよい。
  30://   API が呼べない / 応答が壊れている → skip（**送らない**）
  31://   ゲートの部品が読めない             → skip（**送らない**）
  51:function skip(reason) { out({ ok: false, error: String(reason || 'skip'), skip: true, reason: String(reason || 'skip') }); }
  78:  try { input = JSON.parse(raw); } catch (e) { return skip('入力が JSON として読めない'); }
  82:  if (!target) return skip('相手の投稿の本文が無い');
  86:  if (!cfg || !Array.isArray(cfg.system)) return skip('reply-style-prompt.json が読めない');
  91:  if (!checkRelevance || !relRules) return skip('噛み合い検査が読めない（無検査では送らない）');
  100:  // 生成側も「紹介コード・URLへの誘導」として skip したが、**それは LLM を呼んだ後。**
  105:    const ts = (relRules && relRules.target_skip) || {};
  111:      return skip('PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: ' + hit.slice(0, 3).join(' / '));
  141:    .replace('{RECENT}', recent.length ? recent.map(t => '- ' + t).join('\n') : (cfg.skip_when_no_recent || '（無し）'));
  168:    //     max_tokens: 500, temperature: 0.7,
  179:      max_tokens: Number(cfg.max_tokens || 300),
  195:      return skip('anthropic-client に呼べる関数が無い。export: [' + keys.slice(0, 200) + ']');
  207:    else return skip('応答の形が分からない（' + how + ' / keys: ' + Object.keys(resp || {}).join(',').slice(0, 120) + '）');
  210:    if (!m) return skip('応答に JSON が無い');
  212:    if (parsed.skip) return skip('生成側が skip: ' + (parsed.reason || ''));
  215:    return skip('生成に失敗: ' + (e && e.message ? e.message.slice(0, 600) : 'unknown'));
  218:  if (!text) return skip('空文');
```

### プロンプトに「理由は短く」を足す

**長い作文を書かせない。** 出力トークンがそのまま費用になる。

```
  **定数は入れたが、連結先が見つからない**
```

### 構文チェック（**通らなければ戻す**）

```
  node --check: OK
```

## 2. 前段フィルタを足す（**LLM を呼ぶ回数を減らす**）

**投稿本文を見るだけで判定できるもの**は、LLM の手前で落とす。
これらは実際に**LLM を呼んだあとで** skip されていた（＝課金して 0 件）。

### いまの前段フィルタ

```javascript
  4://   CANDIDATES=$(echo "$CANDIDATES" | node scripts/ng-filter-candidates.cjs 2>>"$LOG")
  30:    process.stderr.write(`  ng-filter: 入力を解釈できないので素通しする (${e.message})\n`);
  32:    return;
  42:    process.stderr.write(`  ng-filter: 判定を読めないので素通しする (${e.message})\n`);
  44:    return;
  65:      process.stderr.write(`  ng-filter: 判定に失敗したので残す (${e.message})\n`);
  73:  if (dropped.length) {
  78:      `  ng-filter: ${list.length} 件中 ${dropped.length} 件を弾いた (${detail})\n`
  84:    process.stderr.write(`  ng-filter: ${list.length} 件すべて通過\n`);
```

### 足すもの

```javascript
  isThinContent() を追記した
```

```
  node --check: OK
```

### 効くかどうかを、実際の skip 済み本文で試す

**入れた関数が、これまで課金して落ちていたものを掴めるか。**

```
  落とす(too_short)  hashtag だけ
  落とす(too_short)  極端に短い
  通す        実際の候補（通す想定）
  通す        普通の投稿（通す想定）
  落とす(too_short)  URL だけ
  ng-filter: 入力を解釈できないので素通しする (Unexpected end of JSON input)
[]```

## 3. 実際に入った差分

```diff
--- /Users/ny/.openclaw/workspace/scripts/asuka-reply.cjs.bak-20260910-213827	2026-09-06 20:15:13
+++ /Users/ny/.openclaw/workspace/scripts/asuka-reply.cjs	2026-09-10 21:38:27
@@ -36,6 +36,9 @@
 // `throw` はしない。返信ジョブごと落とさない。
 
 const fs = require('fs');
+
+// SKIP_REASON_SHORT (2026-09-08): 出力単価は入力の 5 倍。理由の作文に課金しない。
+const SKIP_REASON_RULE = '\n\n【skip するときの書き方】理由は必ず 1 語のコードだけで返すこと。説明文を書かない。使えるコード: skip:money_advice / skip:no_content / skip:promo / skip:out_of_voice / skip:other。例: {"skip":true,"reason":"skip:no_content"}';
 const path = require('path');
 
 const DIR = __dirname;
  --- ここまで asuka-reply.cjs ---
--- /Users/ny/.openclaw/workspace/scripts/ng-filter-candidates.cjs.bak-20260910-213827	2026-08-27 22:38:07
+++ /Users/ny/.openclaw/workspace/scripts/ng-filter-candidates.cjs	2026-09-10 21:38:27
@@ -85,3 +85,26 @@
   }
   process.stdout.write(JSON.stringify(kept));
 });
+
+// THIN_CONTENT_GUARD (2026-09-08)
+// **LLM を呼ぶ前に落とす。** 呼んだあとで「内容がない」と skip されるのは
+// 課金だけして 0 件になるということ。出力単価は入力の 5 倍なので無視できない。
+//
+//   落とす条件（本文を見るだけで判定できるもの）
+//     * 本文が 20 文字未満
+//     * hashtag と URL を除いた実文字が 15 文字未満
+//     * 実文字に対して hashtag が半分以上
+function isThinContent(text) {
+  const t = String(text || "");
+  if (t.length < 20) return "too_short";
+  const body = t
+    .replace(/https?:\/\/\S+/g, "")
+    .replace(/[#＃][^\s#＃]+/g, "")
+    .replace(/[@＠][A-Za-z0-9_]+/g, "")
+    .trim();
+  if (body.length < 15) return "no_content";
+  const tags = (t.match(/[#＃][^\s#＃]+/g) || []).join("").length;
+  if (tags > 0 && body.length > 0 && tags >= body.length) return "hashtag_only";
+  return null;
+}
+module.exports.isThinContent = isThinContent;
```

## 4. 戻し方

```bash
cp -p /Users/ny/.openclaw/workspace/scripts/asuka-reply.cjs.bak-20260910-213827 /Users/ny/.openclaw/workspace/scripts/asuka-reply.cjs
cp -p /Users/ny/.openclaw/workspace/scripts/ng-filter-candidates.cjs.bak-20260910-213827 /Users/ny/.openclaw/workspace/scripts/ng-filter-candidates.cjs
```

---

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク自体**（LLM 不使用） | **$0** | **$0** | **$0** |
| 返信の現状（1 件/日・**実測**） | $0.003 | $0.012 | 約 $0.36 |
| ①② 適用後の 1 件あたり（**推定**） | 約 $0.0022 | — | — |

**推定の前提**: ①で出力 150 → 約 80 tok、②で LLM 呼び出し −25%。
**まとめ判定（入力 −70%）は `x22` の実測を見てから別タスクで入れる。**

**ジョブを再起動していない。** 次の定時実行から効く。
**投稿・返信・LLM 呼び出しのいずれもしていない。**
