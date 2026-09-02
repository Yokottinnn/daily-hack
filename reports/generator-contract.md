# 生成器の契約を読む（2026-09-02 14:20:41 JST）

> 「テンプレをやめて全文生成」に替える前に、**実物を読む。**
> 推測で書くと外す（2026-08-30 に 3 回）。

## 0. ファイルの所在

- `asuka-fill.js`: **ある**（169 行 / 9654 B）
- `comment-orchestrator.sh`: **ある**（173 行 / 8693 B）
- `comment-templates.json`: **ある**（211 行 / 7585 B）

### workspace/scripts にある返信まわりのファイル
```
asuka-fill.js
asuka-fill.js.bak.20260515-v2
asuka-fill.js.bak.20260720-layer1
asuka-gen.js
asuka-gen.js.bak.20260527-dm
asuka-gen.js.bak.20260613-hook-sentence
asuka-gen.js.bak.20260704-ufffd
asuka-gen.js.bak.20260712-comment-variety-off
auto-reply.js
auto-reply.js.bak.20260720-layer3
auto-reply.js.bak.20260725-notify-batch2
auto-reply.js.bak.20260726-silence-enforce
comment-orchestrator.sh
comment-orchestrator.sh.bak.20260510-180212
comment-orchestrator.sh.bak.20260511-172448
comment-orchestrator.sh.bak.20260513-followE
comment-orchestrator.sh.bak.20260518-auto-reply
comment-orchestrator.sh.bak.20260606-eplan-revive
comment-orchestrator.sh.bak.20260705-approval-required
comment-orchestrator.sh.bak.20260705-user-clarify
```

## 1. `asuka-fill.js` の入出力

### 引数・標準入力の受け方
```javascript
10:const fs = require("fs");
11:const ant = require("./anthropic-client.js");
25:  return JSON.parse(fs.readFileSync(TEMPLATES_PATH, "utf8"));
130:      parsed = m ? JSON.parse(m[0]) : null;
159:  for await (const chunk of process.stdin) stdinData += chunk;
160:  const input = JSON.parse(stdinData);
```

### 出力の形
```javascript
103:  //   従来は 37 テンプレを JSON.stringify(templates, null, 2) で毎回そのまま送っていた。
162:    console.log(JSON.stringify({ ok: false, error: `asuka-fill.js only supports kind=comment, got: ${input.kind}` }));
166:  console.log(JSON.stringify(result));
169:main().catch(e => { console.log(JSON.stringify({ ok: false, error: e.message })); process.exit(1); });
```

## 2. **相手の投稿は手元にあるか**（いちばん重要）

```javascript
7: * Input (stdin): JSON {trend: {text, author?, tweet_url?, ...}, kind: "comment"}
29:キャラクター: **ハッカー子** (毒舌×ドヤ顔のツンデレ系、完全オリジナルキャラ) として X bazz post に返信する。
42:1. 与えられた viral post を読む
65:- **驚き型(T08a-d)は本当に新発見/インパクトある時のみ**、雑なpostには T22簡潔同意 や T01共感 を優先
70:- post の内容を踏まえて placeholder を埋める
126:    const text = ant.textOf(resp).trim();
129:      const m = text.match(/\{[\s\S]*\}/);
138:    // 2026-07-20 Layer 1: reject unfilled placeholders (e.g. {action} remains → bad tweet like "とは、やるじゃない")
```

**上に「相手の投稿の本文」を受け取っている行があるか**を見ること。
無ければ、全文生成より先に**取得から直す**。

## 3. SYSTEM プロンプト（全文）

> テンプレ 37 件をどう渡しているかが、そのまま**削れる入力トークン**になる。

```
あなたは「あんたバカぁ？まだ損してるの？速報💸」(@<伏せ>) の返信生成エンジン。
キャラクター: **ハッカー子** (毒舌×ドヤ顔のツンデレ系、完全オリジナルキャラ) として X bazz post に返信する。

【🚨 IP セーフティ - 絶対遵守】
- 「アスカ」「エヴァ」「綾波」 等、既存作品キャラへの参照は **一切禁止** (C&D リスク回避)
- ハッカー子は完全オリジナル、独自世界観のキャラ

【🔒 一人称ルール - 絶対遵守】
- 一人称は **「アタシ」** 固定
- 「私」「あたし」「わたし」「俺」「僕」 等の他の一人称は **一切禁止**
- テンプレ本体に「アタシ」が含まれていれば変えない
- placeholder で一人称が必要なら「アタシ」を使う

タスク:
1. 与えられた viral post を読む
2. テンプレ集から1つを選ぶ
3. {placeholder} 部分のみ埋めて返信文を生成 (テンプレ本体は絶対に変更禁止)

【🆕 新アルゴ対応 (2026-05-17 Phoenix Transformer)】
- 会話を誘発する reply が最強 (Replies > 引用RT > RT > いいね、likeの27-75倍重み)
- 相手の話を引き出す「○○ってどう?」「みんなは?」 等の質問返しを優先
- 個人体験 + 具体数字 を入れて「人間味」 (AIっぽいスロップ NG)
- 「すごい」「最高」 等の薄い同調は避ける、必ず1要素以上の具体的価値を

【🔒 厳格ルール - 違反は禁止】
- テンプレートの **{} 以外の部分は1文字も変更しない** (語尾・絵文字・句読点も含めて)
- 末尾に **追加の文を勝手に足さない** (「〜なさいよ」「〜じゃない？」 等の追記禁止)
- {placeholder} の中身だけ生成、それ以外は template そのまま貼り付け
- 例: テンプレが "{X}って効くわよね😊" なら、出力も必ず "...って効くわよね😊" で終わる (絵文字含めて変更禁止)

【選択ルール】
- **基本は「感想ベース」**: 自分の意見/驚き/共感を素直に述べる
- **優先カテゴリ (37型から選ぶ、2026-05-20 単調化対策込み)**:
  * **🌟 最優先 (実証 high-engagement)**: リスペクト系 family (T16/T16b/T16c/T16d/T16e ランダム — 必ず variant を散らす) / 肯定(T30) / 簡潔同意(T22) / 経験談(T19)
  * **優先**: 共感型(T01) / 驚き細分(T08a-d) / 相槌(T10) / 質問(T04) / 数字具体(T07) / 補完(T21) / 振り返り(T26) / 提案(T29)
  * **避ける (実証 low-engagement)**: 共有(T18) — アタシの周り系は弱い
- **絶対に避ける (X側で違反判定リスク)**: T12 ボケ型 / T13 突っ込み型 / T14 煽り型
- **驚き型(T08a-d)は本当に新発見/インパクトある時のみ**、雑なpostには T22簡潔同意 や T01共感 を優先
- **🚨 単調化防止 (2026-05-20 強化)**:
  - 直近選択履歴 に注意、**T16 family (T16/T16b/T16c/T16d/T16e) は family 単位で連続2回まで、3回目は別 family を必ず選ぶ** (同 mood の連続防止)
  - opener「あら、」始まりは直近 2 ターンで既出なら避ける (T01 と T16 が両方「あら、」、両方連続使うと出だしが完全に同じになる)
  - 「認めるわ💪」 closer ばかり連続させない、T16b/c/d/e の異なる closer を活用
- post の内容を踏まえて placeholder を埋める

【穴埋め時の追加ルール】
- placeholder 内に「あんたバカ」「やらないあんた」 等の煽り語を入れない
- 命令形 (「〜しなさい」) を新規追加しない (template が元々持っている場合のみ可)
- {method} のような placeholder には**動詞句ではなく名詞句**を入れる (例: "SPU活用" ✅, "SPUを使いこなす" ❌)

出力フォーマット (JSON のみ、説明文不要):
{
  "chosen_template_id": "TXX",
  "filled_placeholders": {"{X}": "中身", "{Y}": "中身"},
  "reply": "テンプレ本体に穴埋めしたもの",
  "reasoning": "1行"
}
```

## 4. モデルと max_tokens（コスト見積もりの前提）

```javascript
13:const MODEL = "claude-haiku-4-5";
120:      model: MODEL,
123:      max_tokens: 500,
124:      temperature: 0.7,
```

## 5. テンプレの渡し方（**削れる量**）

- `comment-templates.json`: 7585 B
- 概算トークン（日本語は 1 文字 ≒ 1 トークンとして）: **約 7585 tok**
```javascript
5: * Haiku 4.5 を使って comment-templates.json から型を選び {placeholder} を穴埋め
14:const TEMPLATES_PATH = "/Users/ny/.openclaw/workspace/data/comment-templates.json";
86:  const templates = loadTemplates();
103:  //   従来は 37 テンプレを JSON.stringify(templates, null, 2) で毎回そのまま送っていた。
109:  const usable = templates.filter(t => !recentFamilySet.has(family(t.id)));
111:  const offered = usable.length >= 5 ? usable : templates;
```

## 6. `comment-orchestrator.sh` の呼び出し口

```bash
3:# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
38:CANDIDATES=$(echo "$DETECT_OUT" | /usr/local/bin/node -e "
46:CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
47:N=$(echo "$CANDIDATES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).length)})")
54:echo "$CANDIDATES" | /usr/local/bin/node -e "
80:# 2026-05-13: 直近5件の chosen_template_id を queue から抽出して asuka-fill に渡す (単調化防止)
111:  GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS="$RECENT_IDS" /usr/local/bin/node scripts/asuka-fill.js 2>&1)
113:  GEN_OUT=$(printf %s "$GEN_OUT" | /usr/local/bin/node scripts/tone-gate.cjs 2>>"$LOG")
119:  TEXT=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).text)})")
127:  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
128:  log "enqueue: $ENQ_RES"
```

### enqueue に渡している中身
```bash
1-#!/bin/bash
2-# comment-orchestrator.sh (v3 2026-05-13: reply連動 follow E案追加)
3:# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
4-set -e
5-
6-WS=/Users/ny/.openclaw/workspace
7-SCRIPTS=$WS/scripts
8-LOG=$WS/logs/comment-orchestrator.log
9-MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
10-REPLY_FOLLOW_DAILY_CAP=${REPLY_FOLLOW_DAILY_CAP:-10}
11-
--
124-
125-  ID="comment-$(date +%Y%m%d-%H%M)-$i"
126-  ENQUEUE_PAYLOAD=$(/usr/local/bin/node -e "console.log(JSON.stringify({id:'$ID', kind:'comment', text:$(echo "$TEXT" | /usr/local/bin/node -e "let d='';process.stdin
127:  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
128:  log "enqueue: $ENQ_RES"
129-  /usr/local/bin/node $SCRIPTS/auto-reply.js "$ID"
130-
131-  # 2026-05-13: reply連動 follow (E案: 48h判定 + 7-14日ランダムunfollow)
132-  if [ "$REPLY_FOLLOW_COUNT" -lt "$REPLY_FOLLOW_DAILY_CAP" ]; then
133-    # Skip if already in reply-followers.json (cooldown過去にfollow済み)
134-    ALREADY=$(/usr/local/bin/node -e "
135-    const fs = require('fs');
136-    const p = '$WS/data/reply-followers.json';
```

## 7. 判断

**結論は書かない。** 上を読んで次を決める。

- 相手の投稿が生成時に**手元にある** → 全文生成に替えられる。記録もすぐ入る
- **手元に無い** → 先に取得を直す。全文生成はその後
- テンプレの渡し方が分かれば、**削れる入力トークン＝下がる月額**が確定する
