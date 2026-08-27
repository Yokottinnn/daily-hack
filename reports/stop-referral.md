# 紹介コードを止める＋危険テンプレを外す（2026-08-28 00:40 JST）

> **凍結すれば 4 ループ全部が止まる。** 金銭コストより先に効く。

## 1. 差し込み位置の調査（次で出口検査を入れるため）

comment-orchestrator.sh の 100〜132 行（生成 → enqueue の間）:
```bash
        1	")
        2	log "today's reply-connected follows: $REPLY_FOLLOW_COUNT / $REPLY_FOLLOW_DAILY_CAP"
        3	
        4	for i in $(seq 0 $((N_PICKED - 1))); do
        5	  PICK=$(/usr/local/bin/node -e "console.log(JSON.stringify(require('$PICKS_FILE')[$i]))")
        6	  AUTHOR=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.par
        7	  TARGET_URL=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON
        8	
        9	  log "--- processing #$((i+1))/$N_PICKED for @$AUTHOR ---"
       10	
       11	  GEN_INPUT=$(/usr/local/bin/node -e "console.log(JSON.stringify({trend: $PICK, kind: 'comment'}))")
       12	  GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS="$RECENT_IDS" /usr/local/bin/node scripts/asuka-fill.js 2>&1)
       13	  GEN_OK=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(J
       14	  if [ "$GEN_OK" != "true" ]; then
       15	    log "gen failed (#$((i+1))): $GEN_OUT"
       16	    continue
       17	  fi
       18	  TEXT=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.pa
       19	  TEMPLATE_ID=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.
       20	  log "  → chosen template_id: $TEMPLATE_ID"
       21	  RECENT_IDS="$TEMPLATE_ID${RECENT_IDS:+,}$RECENT_IDS"
       22	  RECENT_IDS=$(echo "$RECENT_IDS" | cut -d, -f1-5)
       23	
       24	  ID="comment-$(date +%Y%m%d-%H%M)-$i"
       25	  ENQUEUE_PAYLOAD=$(/usr/local/bin/node -e "console.log(JSON.stringify({id:'$ID', kind:'comment', text:$(echo "$TEXT" | /usr/local/bin/node 
       26	  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
       27	  log "enqueue: $ENQ_RES"
       28	  /usr/local/bin/node $SCRIPTS/auto-reply.js "$ID"
       29	
       30	  # 2026-05-13: reply連動 follow (E案: 48h判定 + 7-14日ランダムunfollow)
       31	  if [ "$REPLY_FOLLOW_COUNT" -lt "$REPLY_FOLLOW_DAILY_CAP" ]; then
       32	    # Skip if already in reply-followers.json (cooldown過去にfollow済み)
       33	    ALREADY=$(/usr/local/bin/node -e "
```

SYSTEM プロンプトの末尾（禁止事項を足す場所）:
```javascript
    }
    // 2026-07-20 Layer 1: reject if starts with particle/verb-tail (「とは」「して」「したら」 = placeholder was empty)
    if (/^(とは|して|したら|する|の|は|が|を|に|で|、|。|「)/.test(parsed.reply.trim())) {
      continue;
    }
    const w = weightOf(parsed.reply);
    if (w > MAX_WEIGHT) continue;
    return { ok: true, text: parsed.reply, template_id: parsed.chosen_template_id, weight: w, attempts: attempt };
  }
  return { ok: false, error: `failed ${maxAttempts} attempts (weight or format or v3 first-person violation)` };
}

async function main() {
  let stdinData = "";
  for await (const chunk of process.stdin) stdinData += chunk;
  const input = JSON.parse(stdinData);
  if (input.kind !== "comment") {
    console.log(JSON.stringify({ ok: false, error: `asuka-fill.js only supports kind=comment, got: ${input.kind}` }));
    process.exit(1);
  }
  const result = await fill(input.trend);
  console.log(JSON.stringify(result));
}

main().catch(e => { console.log(JSON.stringify({ ok: false, error: e.message })); process.exit(1); });
```

## 2. 危険なテンプレを外す（T03 / T06）

- 退避: comment-templates.json.pre034.20260827-154041
-   外す [T03] あんたバカぁ？{mistake_pattern}で損するなんて。次は{correct_action}しなさいよ💸
-   外す [T06] あら？{naive_thinking}とか本気で言ってる？まだそんなこと信じてんの？💢
- テンプレート 37 → 35 件（2 件 外した）
- 書き換え後の JSON: **正常**

## 3. 闇バイト・詐欺の語を NG に足す

T09 が実際にこれらに絡んでいた。ng-filter は売春系しか見ていない。

- 退避: reply-ng-rules.json.pre034.20260827-154041
- hard_ng_words 32 → 52 語（20 語 追加）
- 追加した語: 闇バイト / 即金 / 高額バイト / 裏バイト / 叩き / 受け子 / 出し子 / ホワイト案件 / 簡単に稼げる / 日給10万 / 副業紹介します / LINEで詳細 / マイナンバーカード 譲渡 / 口座譲渡 / 名義貸し / 携帯名義 / SIM譲渡 / アカウント売買 / 現金化 / 後払い現金化
- 書き換え後の JSON: **正常**

## 4. 判定が壊れていないか（追加後に確かめる）

```
  ng-filter: 4 件中 2 件を弾いた (hard=2)
    弾いた理由 hard: 即金
    弾いた理由 hard: パパ活
[{"id":1,"text":"今日のポイ活の成果"},{"id":3,"text":"ふるさと納税の返礼品が届いた"}]
残った件数: 読めない
```

**ポイ活とふるさと納税が残り、闇バイトとパパ活が消えていれば正しい。**

## 5. まだ塞げていないもの

- **出口の検査はまだ無い。** 紹介コードを本文から弾く仕組みは入っていない。
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/034-stop-referral-codes.sh: line 161: reply-tone-check.cjs: command not found
  §1 で出した位置に、次の一手で  を差し込む
- T11 の {encouragement_phrase} は生きている。**SYSTEM に禁止文言を足すまで再発しうる**
