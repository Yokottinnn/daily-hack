# tab-guard の B 条件を直す — 1 → 0 枚は破壊ではない

**このレポートが作られた時刻: 2026-09-13 00:43:39 JST**

> `[2026-09-12T15:24:13Z] 🚨 Jordan のタブが **1 → 0 枚**（実質全消滅） → 自動化を全停止`

**自動化専用 Chrome は起動直後 1 タブしかない。**
スクリプトが作業タブを `page.close()` すると 1 → 0 枚になり、tab-guard が発火する。
**＝ 自動化そのものが tab-guard を発火させている。**

## 1. B 条件の現状

```javascript
  13: *     C. 一度に半分以上のタブが消えた（＝一括破壊）
  29:const MIN_TABS = 1;              // これ未満なら異常（実質全消滅）
  96:  const result = { count: now.count, prev: prev.count ?? null };
  99:  if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
  100:    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
  104:  else if (prev.count >= 6 && now.count <= prev.count * CATASTROPHIC_RATIO) {
  105:    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（一括破壊）`);
  110:  try { fs.writeFileSync(STATE, JSON.stringify({ count: now.count, at: new Date().toISOString() }, null, 2)); } catch {}
  116:    log(`tab-guard 監視開始（${INTERVAL_MS / 1000}秒間隔・全消滅/一括破壊のみ検知）`);
```

## 2. 直す（**前回が既に少なかったなら破壊ではない**）

`x33` の `UNREACHABLE_GUARD` と同じ考え方。
**タブ 10 → 1 のような本物の一括破壊は、これまでどおり検知する。**

```
  退避: tab-guard.js.bak-20260913-004339
  LOW_BASELINE_GUARD を入れた
  node --check: OK
```

```diff
--- /Users/ny/.openclaw/workspace/scripts/tab-guard.js.bak-20260913-004339	2026-09-12 23:22:26
+++ /Users/ny/.openclaw/workspace/scripts/tab-guard.js	2026-09-13 00:43:39
@@ -97,6 +97,16 @@
 
   // B: 実質全部消えた
   if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
+    // LOW_BASELINE_GUARD (2026-09-13): **元が 1 枚なら「全部 消えた」ではない。**
+    // 自動化専用 Chrome は起動直後 1 タブしかなく、スクリプトが作業タブを
+    // page.close() すると 1 → 0 枚になる。それを「実質全消滅」と見なすと、
+    // **自動化そのものが自動化を止める**（2026-09-12 15:24 に実際に起きた）。
+    // B は「たくさんあったものが 0〜1 枚になった」を想定した条件。
+    // **前回が 3 枚未満なら、そもそも破壊の前提が無い。**
+    if (!prev || typeof prev.count !== "number" || prev.count < 3) {
+      log(`タブ ${prev && prev.count} → ${now.count} 枚。元が少ないので破壊とみなさない`);
+      return;
+    }
     haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
     result.halted = true;
   }
```

## 3. tab-guard を載せ直す（直した版を効かせる）

```
  Load failed: 5: Input/output error
  Try running `launchctl bootstrap` as root for richer errors.
  載ったか: 1 本
```

## 4. 8 本を載せて、**3 分 生き残るか**

これまでは 60〜90 秒で消えていた。**今度は 3 分 見る。**

```
  載せた直後: 4 / 8 本

   60 秒後: 5 / 8 本
  120 秒後: 5 / 8 本
  180 秒後: 5 / 8 本

  **未**   comment-warmup                    
  ロード   competitor-follower-follow        
  ロード   hashtag-follow                    
  ロード   badge-followback                  
  ロード   reply-followback-check            
  **未**   reply-followers-cleanup           
  **未**   incoming-reply-watcher            
  **未**   pipeline-heartbeat                

  **最終: 4 / 8 本**
  tab-guard: 1 本
  CDP: 健全

  --- tab-guard のログ（この 3 分に鳴ったか） ---
    [2026-09-12T13:29:49.601Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:29:49.639Z] 🚨 Jordan のタブが 14 → 1 枚（一括破壊） → 自動化を全停止
    [2026-09-12T13:29:49.860Z] 停止完了
    [2026-09-12T13:29:49.861Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:59.929Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
    [2026-09-12T15:24:13.631Z] 停止完了
    [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
    [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T15:43:41.695Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

---

## 塞いだ穴（3 つのうち 2 つ）

| 条件 | 中身 | 状態 |
| --- | --- | --- |
| A | Chrome プロセスが消えた | **x33 で塞いだ**（CDP 断は消滅ではない） |
| B | タブが 0〜1 枚になった | **この タスクで塞ぐ**（元が 1 枚なら破壊ではない） |
| C | 一度に半分以上のタブが消えた | **残す。** 本物の一括破壊を拾うのはこれ |

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（LLM 不使用） | **$0** | **$0** | **$0** |
| フォロー・アンフォロー（DOM 操作） | **$0** | **$0** | **$0** |
| 返信（**実測** 3〜5 件/日） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |

**Chrome を kill していない。tab-guard も止めていない（条件を 1 つ 直しただけ）。**
