# テンプレ 37 件の実物（2026-09-05 10:44:04 JST・費用 $0）

> 方式は**新しい方（全文生成）のまま**。引き継ぐのは**キャラ設定だけ**。
> これまでのキャラ定義は**私が想像で書いたもの**で、テンプレ由来ではなかった。
> **だから元の声にならなかった。** ここで本物を読む。
> **LLM を 1 回も呼ばない。書き換えない。投稿しない。**

## 0. ファイル

- `asuka-fill.js`: 169 行 / 更新 2026-08-15 16:38

テンプレが外部ファイルにあるかも見る:
```
auto-reply-fail-streak.json
comment-state.json
comment-templates.json
incoming-reply-state.json
quick-reply-targets.json
reply-followers.json
reply-ng-rules.json
reply-tone-rules.json
```

## 1. テンプレ全文（**本命**）

`asuka-fill.js` の中の文字列リテラルを、絵文字や語尾ごと**そのまま**出す。

```javascript
56:- 例: テンプレが "{X}って効くわよね😊" なら、出力も必ず "...って効くわよね😊" で終わる (絵文字含めて変更禁止)
75:- {method} のような placeholder には**動詞句ではなく名詞句**を入れる (例: "SPU活用" ✅, "SPUを使いこなす" ❌)
80:  "filled_placeholders": {"{X}": "中身", "{Y}": "中身"},
81:  "reply": "テンプレ本体に穴埋めしたもの",
82:  "reasoning": "1行"
97:    ? `\n\n## ⚠️ T16 family (リスペクト型) 直近 ${t16Count} 回連続。**今回は T16/T16b/T16c/T16d/T16e 以外を選ぶこと** (単調化防止強制)`
100:    ? `\n\n## 直近選択履歴 (新→旧)\n${recentIds.join(", ")}\n→ 同 family (T16系等) 連続2回まで、3回目は必ず別 family 選ぶこと${t16Note}`
115:  const userMsg = `## viral post (作者: @${trend.author || "unknown"})\n${trend.text}\n\n## 利用可能テンプレ集 (${offered.length}個、形式: id|category|scenario|template、deprioriti
122:      user: userMsg + (attempt > 1 ? `\n\n[再生成 attempt ${attempt}: 前回の出力が ${MAX_WEIGHT} weight超過 or template違反]` : ""),
138:    // 2026-07-20 Layer 1: reject unfilled placeholders (e.g. {action} remains → bad tweet like "とは、やるじゃない")
```

## 2. 型の選び方（どのテンプレが選ばれるか）

```javascript
5: * Haiku 4.5 を使って comment-templates.json から型を選び {placeholder} を穴埋め
7: * Input (stdin): JSON {trend: {text, author?, tweet_url?, ...}, kind: "comment"}
8: * Output (stdout): JSON {ok, text, template_id, weight, attempts}
14:const TEMPLATES_PATH = "/Users/ny/.openclaw/workspace/data/comment-templates.json";
15:const DEPRIORITIZE = ["T12", "T13", "T14"];
18:function weightOf(s) {
25:  return JSON.parse(fs.readFileSync(TEMPLATES_PATH, "utf8"));
61:  * **🌟 最優先 (実証 high-engagement)**: リスペクト系 family (T16/T16b/T16c/T16d/T16e ランダム — 必ず variant を散らす) / 肯定(T30) / 簡潔同意(T22) / 経�
62:  * **優先**: 共感型(T01) / 驚き細分(T08a-d) / 相槌(T10) / 質問(T04) / 数字具体(T07) / 補完(T21) / 振り返り(T26) / 提案(T29)
63:  * **避ける (実証 low-engagement)**: 共有(T18) — アタシの周り系は弱い
64:- **絶対に避ける (X側で違反判定リスク)**: T12 ボケ型 / T13 突っ込み型 / T14 煽り型
65:- **驚き型(T08a-d)は本当に新発見/インパクトある時のみ**、雑なpostには T22簡潔同意 や T01共感 を優先
67:  - 直近選択履歴 に注意、**T16 family (T16/T16b/T16c/T16d/T16e) は family 単位で連続2回まで、3回目は別 family を必ず選ぶ** (同 mood の連続防止)
68:  - opener「あら、」始まりは直近 2 ターンで既出なら避ける (T01 と T16 が両方「あら、」、両方連続使うと出だしが完全に同じになる)
69:  - 「認めるわ💪」 closer ばかり連続させない、T16b/c/d/e の異なる closer を活用
86:  const templates = loadTemplates();
87:  const recentIds = (process.env.RECENT_TEMPLATE_IDS || "").split(",").filter(Boolean);
88:  // 2026-05-20: T16 family を 1 つの class として cooldown 判定強化
90:    const m = id.match(/^(T\d+)/);
92:    return m[1]; // T16, T16b, T16c → "T16"
95:  const t16Count = recentFamilies.filter(f => f === "T16").length;
97:    ? `\n\n## ⚠️ T16 family (リスペクト型) 直近 ${t16Count} 回連続。**今回は T16/T16b/T16c/T16d/T16e 以外を選ぶこと** (単調化防止強制)`
100:    ? `\n\n## 直近選択履歴 (新→旧)\n${recentIds.join(", ")}\n→ 同 family (T16系等) 連続2回まで、3回目は必ず別 family 選ぶこと${t16Note}`
103:  //   従来は 37 テンプレを JSON.stringify(templates, null, 2) で毎回そのまま送っていた。
109:  const usable = templates.filter(t => !recentFamilySet.has(family(t.id)));
111:  const offered = usable.length >= 5 ? usable : templates;
122:      user: userMsg + (attempt > 1 ? `\n\n[再生成 attempt ${attempt}: 前回の出力が ${MAX_WEIGHT} weight超過 or template違反]` : ""),
129:      const m = text.match(/\{[\s\S]*\}/);
150:    const w = weightOf(parsed.reply);
152:    return { ok: true, text: parsed.reply, template_id: parsed.chosen_template_id, weight: w, attempts: attempt };
154:  return { ok: false, error: `failed ${maxAttempts} attempts (weight or format or v3 first-person violation)` };
161:  if (input.kind !== "comment") {
162:    console.log(JSON.stringify({ ok: false, error: `asuka-fill.js only supports kind=comment, got: ${input.kind}` }));
```

## 3. 穴埋めの語彙（`{...}` に入るもの）

```javascript
3: * asuka-fill.js (v3 brand 2026-05-15: ハッカー子 + アタシ 一人称固定)
4: * 注: ファイル名は歴史的に asuka-fill.js だが、内部キャラは v3 ブランド「ハッカー子」に移行済
5: * Haiku 4.5 を使って comment-templates.json から型を選び {placeholder} を穴埋め
39:- placeholder で一人称が必要なら「アタシ」を使う
44:3. {placeholder} 部分のみ埋めて返信文を生成 (テンプレ本体は絶対に変更禁止)
55:- {placeholder} の中身だけ生成、それ以外は template そのまま貼り付け
56:- 例: テンプレが "{X}って効くわよね😊" なら、出力も必ず "...って効くわよね😊" で終わる (絵文字含めて変更禁止)
70:- post の内容を踏まえて placeholder を埋める
73:- placeholder 内に「あんたバカ」「やらないあんた」 等の煽り語を入れない
75:- {method} のような placeholder には**動詞句ではなく名詞句**を入れる (例: "SPU活用" ✅, "SPUを使いこなす" ❌)
80:  "filled_placeholders": {"{X}": "中身", "{Y}": "中身"},
85:async function fill(trend) {
115:  const userMsg = `## viral post (作者: @${trend.author || "unknown"})\n${trend.text}\n\n## 利用可能テンプレ集 (${offered.length}個、形式: id|category|scenario|template、
122:      user: userMsg + (attempt > 1 ? `\n\n[再生成 attempt ${attempt}: 前回の出力が ${MAX_WEIGHT} weight超過 or template違反]` : ""),
138:    // 2026-07-20 Layer 1: reject unfilled placeholders (e.g. {action} remains → bad tweet like "とは、やるじゃない")
140:      continue; // unfilled placeholder detected
142:    // 2026-07-20 Layer 1: reject too-short replies (< 15 chars = likely broken template fill)
146:    // 2026-07-20 Layer 1: reject if starts with particle/verb-tail (「とは」「して」「したら」 = placeholder was empty)
154:  return { ok: false, error: `failed ${maxAttempts} attempts (weight or format or v3 first-person violation)` };
162:    console.log(JSON.stringify({ ok: false, error: `asuka-fill.js only supports kind=comment, got: ${input.kind}` }));
165:  const result = await fill(input.trend);
```

## 4. 実際に X に出た返信（**テンプレが実物でどう見えたか**）

```
 1. 貧乏で育つのって、実は強みになる😉 大事よね 
 2. 上州牛ゲットとは、やるじゃない。アタシも見直したわ✨ 
 3. ちょうど今月末の時期だし、楽天ペイの還元キャンペーン活用始めるのにいいわね📅 
 4. nanacoクレカ + セブン銀行設定やったら年間12000円浮くのよね。アタシもこれは早めにやっといてよかったわ💸 
 5. あら、無理なく続けられる金額で投資するか。それアタシもやってるわよ、いいわよね😊 
 6. ちょっと待って、PayPayくださいって具体的にどうやるの？教えなさいよ😤 
 7. 長期・積立・分散😉 大事よね 
 8. ふーん、楽天ポイントのキャンペーンね。まあ悪くないんじゃない？アタシはもっといい方法知ってるけど😏 
 9. 投資をしないという選択の裏には、インフレによる現金価値の減少があるのよ。つまり、何もしないことも実はリスクを取ってることにな
10. 楽天ポイント山分けキャンペーン参加やったら年間数十万円浮くのよね。アタシもこれは早めにやっといてよかったわ💸 
11. ちょうど今月末の時期だし、ポイ活の確認と新規登録始めるのにいいわね📅 
12. ちょっと待って、高校生が持てるカードの種類って具体的にどうやるの？教えなさいよ😤 
13. 楽天ポイントのクリック案件をコツコツ積み重ねるとは、やるじゃない。アタシも見直したわ✨ 
14. 楽天カード決済も組み合わせるともっといいわよ。試してみなさい💡 
15. えっ年6kg分も!? ふるさと納税でそんなに変わるの？アタシも見直さなきゃ💸 
16. 楽天ポイント還元キャンペーン、同意😉 
17. しょうがないわね…毎月のポイント還元も損したなんて。でも他のポイント還元カードに乗り換えれば取り戻せるわよ 
18. 新NISAで高配当株の基礎できたなら、次は配当利回りと企業成長性のバランス戦略に進むといいわよ。頑張りなさい💪 
19. 楽天ウェブ検索のクリックやったら年間3650円浮くのよね。アタシもこれは早めにやっといてよかったわ💸 
20. ちょっと待って、ログインだけで1ポイント貰えるキャンペーンって具体的にどうやるの？教えなさいよ😤 
21. ビビンバに焼肉のせて、無花果まで丸ごと弁当にするなんて筋金入りじゃない、その意気よ🔥 
22. 楽天ポイントの懸賞キャンペーン、同意😉 
23. SPU活用も組み合わせるともっといいわよ。試してみなさい💡 
24. 楽天ポイント企画に応募するの？いいわね！ラッキーくじも引いて頑張りなさいよ💪 
25. 朝食を納豆お茶漬け+ヨーグルト+ドリンクやったら年間40000円浮くのよね。アタシもこれは早めにやっといてよかったわ💸 
```

## 5. ゲートを挟む場所（**あとで使う。推測で書かないため**）

### `asuka-fill` の呼び出し
```bash
  ── comment-orchestrator.sh:80 ──
});
"
N_PICKED=$(/usr/local/bin/node -e "console.log(require('$PICKS_FILE').length)")
log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
if [ "$N_PICKED" = "0" ]; then
  log "all candidates in cooldown"
  rm -f $PICKS_FILE
  exit 0
fi

# 2026-05-13: 直近5件の chosen_template_id を queue から抽出して asuka-fill に渡す (単調化防止)
RECENT_IDS=$(/usr/local/bin/node -e "
const j = JSON.parse(require('fs').readFileSync('$WS/data/post_queue.json', 'utf8'));
const ids = j.queue.filter(x => x.id && x.id.startsWith('comment-') && x.template_id).slice(-5).map(x => x.template_id).reverse();
console.log(ids.join(','));
")
log "recent template ids (newest first): ${RECENT_IDS:-none}"

# 2026-05-13: reply連動 follow (E案) - 今日のfollow数を取得
TODAY=$(date +%Y-%m-%d)
REPLY_FOLLOW_COUNT=$(/usr/local/bin/node -e "
const fs = require('fs');
const p = '$WS/data/reply-followers.json';
if (!fs.existsSync(p)) { console.log(0); process.exit(0); }
const s = JSON.parse(fs.readFileSync(p, 'utf8'));
let n = 0;
for (const [_, e] of Object.entries(s)) {
  if (e.followed_at && e.followed_at.startsWith('$TODAY')) n++;
}
console.log(n);
")

  ── comment-orchestrator.sh:111 ──
log "today's reply-connected follows: $REPLY_FOLLOW_COUNT / $REPLY_FOLLOW_DAILY_CAP"

for i in $(seq 0 $((N_PICKED - 1))); do
  PICK=$(/usr/local/bin/node -e "console.log(JSON.stringify(require('$PICKS_FILE')[$i]))")
  AUTHOR=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).author)})")
  TARGET_URL=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).tweet_url)})")

  log "--- processing #$((i+1))/$N_PICKED for @$AUTHOR ---"

  GEN_INPUT=$(/usr/local/bin/node -e "console.log(JSON.stringify({trend: $PICK, kind: 'comment'}))")
  GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS="$RECENT_IDS" /usr/local/bin/node scripts/asuka-fill.js 2>&1)
  # 2026-08-28: 紹介コード・URL・見下しなどを送る前に弾く。判定できないときは素通しする
  GEN_OUT=$(printf %s "$GEN_OUT" | /usr/local/bin/node scripts/tone-gate.cjs 2>>"$LOG")
  GEN_OK=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
  if [ "$GEN_OK" != "true" ]; then
    log "gen failed (#$((i+1))): $GEN_OUT"
    continue
  fi
  TEXT=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).text)})")
  TEMPLATE_ID=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).template_id||'unknown')}catch{co
  log "  → chosen template_id: $TEMPLATE_ID"
  RECENT_IDS="$TEMPLATE_ID${RECENT_IDS:+,}$RECENT_IDS"
  RECENT_IDS=$(echo "$RECENT_IDS" | cut -d, -f1-5)

  ID="comment-$(date +%Y%m%d-%H%M)-$i"
  ENQUEUE_PAYLOAD=$(/usr/local/bin/node -e "console.log(JSON.stringify({id:'$ID', kind:'comment', text:$(echo "$TEXT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);proc
  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
  log "enqueue: $ENQ_RES"
  /usr/local/bin/node $SCRIPTS/auto-reply.js "$ID"

  # 2026-05-13: reply連動 follow (E案: 48h判定 + 7-14日ランダムunfollow)

```

### `enqueue` の呼び出し
```bash
  ── comment-orchestrator.sh:3 ──
#!/bin/bash
# comment-orchestrator.sh (v3 2026-05-13: reply連動 follow E案追加)
# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
set -e

WS=/Users/ny/.openclaw/workspace
SCRIPTS=$WS/scripts
LOG=$WS/logs/comment-orchestrator.log
MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
REPLY_FOLLOW_DAILY_CAP=${REPLY_FOLLOW_DAILY_CAP:-10}

ts() { date "+%Y-%m-%dT%H:%M:%S"; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

  ── comment-orchestrator.sh:127 ──
  TEXT=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).text)})")
  TEMPLATE_ID=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).template_id||'unknown')}catch{co
  log "  → chosen template_id: $TEMPLATE_ID"
  RECENT_IDS="$TEMPLATE_ID${RECENT_IDS:+,}$RECENT_IDS"
  RECENT_IDS=$(echo "$RECENT_IDS" | cut -d, -f1-5)

  ID="comment-$(date +%Y%m%d-%H%M)-$i"
  ENQUEUE_PAYLOAD=$(/usr/local/bin/node -e "console.log(JSON.stringify({id:'$ID', kind:'comment', text:$(echo "$TEXT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);proc
  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
  log "enqueue: $ENQ_RES"
  /usr/local/bin/node $SCRIPTS/auto-reply.js "$ID"

  # 2026-05-13: reply連動 follow (E案: 48h判定 + 7-14日ランダムunfollow)
  if [ "$REPLY_FOLLOW_COUNT" -lt "$REPLY_FOLLOW_DAILY_CAP" ]; then
    # Skip if already in reply-followers.json (cooldown過去にfollow済み)
    ALREADY=$(/usr/local/bin/node -e "
    const fs = require('fs');
    const p = '$WS/data/reply-followers.json';
    if (!fs.existsSync(p)) { console.log('no'); process.exit(0); }

  ── comment-orchestrator.sh:128 ──
  TEMPLATE_ID=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).template_id||'unknown')}catch{co
  log "  → chosen template_id: $TEMPLATE_ID"
  RECENT_IDS="$TEMPLATE_ID${RECENT_IDS:+,}$RECENT_IDS"
  RECENT_IDS=$(echo "$RECENT_IDS" | cut -d, -f1-5)

  ID="comment-$(date +%Y%m%d-%H%M)-$i"
  ENQUEUE_PAYLOAD=$(/usr/local/bin/node -e "console.log(JSON.stringify({id:'$ID', kind:'comment', text:$(echo "$TEXT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);proc
  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
  log "enqueue: $ENQ_RES"
  /usr/local/bin/node $SCRIPTS/auto-reply.js "$ID"

  # 2026-05-13: reply連動 follow (E案: 48h判定 + 7-14日ランダムunfollow)
  if [ "$REPLY_FOLLOW_COUNT" -lt "$REPLY_FOLLOW_DAILY_CAP" ]; then
    # Skip if already in reply-followers.json (cooldown過去にfollow済み)
    ALREADY=$(/usr/local/bin/node -e "
    const fs = require('fs');
    const p = '$WS/data/reply-followers.json';
    if (!fs.existsSync(p)) { console.log('no'); process.exit(0); }
    const s = JSON.parse(fs.readFileSync(p, 'utf8'));

```

## 6. 返信ジョブが止まったままであることの確認

```
-	-9	com.apple.followupd
-	0	ai.openclaw.competitor-follower-follow
-	0	ai.openclaw.hashtag-follow
```

---

**何も書き換えていない。LLM も呼んでいない（$0）。**
次は 1 章の実物から声を抜き出して `reply-style-prompt.json` に入れ直す。
