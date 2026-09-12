#!/bin/bash
# **末尾の絵文字 1 個で返信を丸ごと捨てるのをやめる。費用 最大 $0.012。**
#
# ## x40 で分かった本当の理由（2026-09-13 01:41）
#
# **ジョブは 8 本 全部 載っていた。** `launchctl list` の全件ダンプがそう出ている。
# 私が報告し続けた「4/8」は、**ジョブごとに `launchctl list` を呼び直す
# 数え方の取りこぼし**だった（`scripts/ops-heartbeat.sh` 側は別途 直した）。
#
# 返信が出ない理由はゲートだった。
#
#   14 candidates → 2 picked → **0 件 通過**
#   #1 生成側が skip: 相手が広告投稿で、返信すべき個人の体験・質問がない
#   #2 噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ
#
# **#2 が問題。** LLM 呼び出しは**既に終わっている**のに、
# 末尾の絵文字が直近と被っただけで**本文ごと捨てている。**
#
#   - 金は払った（生成した）
#   - 出力は 0
#   - 本文自体は噛み合っていた。**顔だけが同じだった**
#
# ## 直し方: 捨てる前に「飾りを外して測り直す」
#
# 弾かれた理由が**見た目の重複だけ**なら、その部分を削って再検査する。
#
#   末尾の絵文字が被った → **絵文字を落とす**
#   書き出しの相づちが被った → **その相づちを落とす**
#
# **LLM を追加で呼ばない。** 既にある文から飾りを外すだけなので **$0**。
#
# ### 緩めないもの
#
# **内容で弾かれたものは今までどおり捨てる。**
#
#   「相手の投稿と共有する内容語が 0 個」← 読んでいない返信。捨てる
#   「同じ書き出し『あら、その値』が直近 20 件に 3 件」← 冒頭 8 字 の一致。
#     どこを削れば直るか決められないので捨てる
#
# 判定は「理由が**全部** 末尾の絵文字／書き出しの相づち であること」。
# 1 つでも内容系が混ざっていれば修理しない。
#
# ## 検証済み（クラウド側でローカル実行）
#
#   "…ならないのよ 😏"        → "…ならないのよ"
#   "やるじゃない 💪💪"        → "やるじゃない"
#   "300円で一食はさすがに強いわよ" → 変化なし（末尾が絵文字でない）
#   "あら、その値段なら悪くないわね" ＋ 理由「書き出しの「あら、」」 → "その値段なら悪くないわね"
#   cosmetic 判定: 絵文字のみ=true ／ 内容語 0 個 混在=false ／ 同じ書き出し(8字)=false
#
# ## やらないこと
#
# **しきい値を緩めない。プロンプトを変えない。Chrome を kill しない。**
# `.bak-<日時>` に退避し、`node --check` が通らなければその場で戻す。
# **書き換えた「後」を必ず grep で出す**（x39 は出さなかったので、
# 当たっていないことに気づくのが 1 往復 遅れた）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/repair-instead-of-discard.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"
UID_NUM="$(id -u)"
GEN="$S/asuka-reply.cjs"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

count_posted() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")
    &&(e.x_tweet_id||e.tweet_id)).length);
}catch(e){ console.log(-1); }
' "$QJSON" 2>/dev/null || echo -1
}

{
echo "# 捨てる前に飾りを外して測り直す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> LLM 呼び出しは**既に終わっている**のに、末尾の絵文字が直近と被っただけで"
echo "> **本文ごと捨てていた。** 金は払って、出力は 0。"

# ═══════════ 0. 全件スナップショットで数える ═══════════
echo
echo "## 0. ジョブの数え方を直したうえで数える"
echo
echo "**ジョブごとに \`launchctl list\` を呼び直さない。** 1 回のスナップショットを 3 列目の"
echo "ラベル完全一致で照合する。この取りこぼしが「4/8」の正体だった。"
echo
echo '```'
SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"
[ -z "$SNAP" ] && { sleep 2; SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"; }
EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
N=0; MISS=""
for j in $EXPECT; do
  if printf '%s\n' "$SNAP" | grep -qxF "ai.openclaw.$j"; then N=$((N+1)); else MISS="$MISS $j"; fi
done
echo "  3 ループ: **${N} / 8 本**${MISS:+ / 欠け:$MISS}"
echo "  ai.openclaw.* 全体: $(printf '%s\n' "$SNAP" | grep -c '^ai\.openclaw\.' || true) 本"
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
[ -f /tmp/x-login-in-progress ] && echo "  login ロック: **在る**" || echo "  login ロック: 無い"
echo '```'

# ═══════════ 1. 生成器を直す ═══════════
echo
echo "## 1. \`asuka-reply.cjs\` に修理を入れる"
echo
echo '```'
if [ ! -f "$GEN" ]; then
  echo "  **$GEN が無い。何もしない。**"
else
  echo "  --- 書き換える前（該当箇所） ---"
  grep -n 'checkRelevance({ text' "$GEN" 2>/dev/null | sed 's/^/    /' | clean
  grep -n '噛み合い検査で弾いた' "$GEN" 2>/dev/null | sed 's/^/    /' | clean
  grep -c 'COSMETIC_REPAIR' "$GEN" 2>/dev/null | sed 's/^/    既に入っている数: /'

  cp "$GEN" "$GEN.bak-$STAMP" && echo "  退避: $(basename "$GEN").bak-$STAMP"

  "$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
let s=fs.readFileSync(p,"utf8");
if(s.includes("COSMETIC_REPAIR")){ console.log("  既に入っている。何もしない。"); process.exit(0); }

// 元の 2 行。**この形でなければ触らない。**
const OLD_DECL = "const rel = checkRelevance({ text, targetText: target, recentReplies: recentForGate, runReplies: runForGate }, relRules);";
const OLD_SKIP = "if (!rel.ok) return skip('噛み合い検査で弾いた: ' + rel.reasons.join(' / '));";
if(!s.includes(OLD_DECL) || !s.includes(OLD_SKIP)){
  console.log("  **想定した 2 行が見つからない。触らない。**");
  console.log("  DECL 一致: "+s.includes(OLD_DECL)+" / SKIP 一致: "+s.includes(OLD_SKIP));
  process.exit(0);
}

const NEW = [
  "let rel = checkRelevance({ text, targetText: target, recentReplies: recentForGate, runReplies: runForGate }, relRules);",
  "",
  "  // COSMETIC_REPAIR (2026-09-13): **見た目の重複だけで捨てない。**",
  "  //",
  "  // LLM 呼び出しは既に終わっている。末尾の絵文字や書き出しの相づちが直近と",
  "  // 被っただけなら、本文は無傷なので**その部分を削って測り直す。**",
  "  // 追加の LLM 呼び出しは無いので $0。",
  "  //",
  "  // **内容で弾かれたものは今までどおり捨てる。**",
  "  //   「共有する内容語が 0 個」  ← 読んでいない返信",
  "  //   「同じ書き出し『…』」      ← 冒頭 8 字 の一致。どこを削れば直るか決められない",
  "  // 理由が**全部**『末尾の絵文字』『書き出しの』のときだけ修理する。",
  "  if (!rel.ok) {",
  "    const rs = rel.reasons || [];",
  "    const cosmetic = rs.length > 0 && rs.every((r) =>",
  "      /^末尾の絵文字「/.test(r) || /^書き出しの「/.test(r));",
  "    if (cosmetic) {",
  "      let fixed = text;",
  "      if (rs.some((r) => /^末尾の絵文字「/.test(r))) {",
  "        fixed = fixed.replace(/[\\s\\u200d\\ufe0f\\p{Extended_Pictographic}]+$/u, '').trim();",
  "      }",
  "      for (const r of rs) {",
  "        const m = /^書き出しの「(.+?)」/.exec(r);",
  "        if (m && fixed.startsWith(m[1])) fixed = fixed.slice(m[1].length).trim();",
  "      }",
  "      const fw = weightOf(fixed);",
  "      if (fixed && fixed !== text && fixed.length >= MIN_CHARS && fw <= MAX_WEIGHT) {",
  "        const re2 = checkRelevance({ text: fixed, targetText: target, recentReplies: recentForGate, runReplies: runForGate }, relRules);",
  "        if (re2.ok) { text = fixed; rel = re2; }",
  "      }",
  "    }",
  "  }"
].join("\n");

s = s.replace(OLD_DECL, NEW);
fs.writeFileSync(p, s);
console.log("  書き換えた。");
' "$GEN" 2>&1 | sed 's/^/  /' | clean

  if "$NODE_BIN" --check "$GEN" 2>/dev/null; then
    echo "  node --check: OK"
    echo "  --- 書き換えた後（**必ず出す**） ---"
    grep -n 'COSMETIC_REPAIR\|let rel = checkRelevance\|噛み合い検査で弾いた' "$GEN" 2>/dev/null \
      | head -6 | cut -c1-140 | sed 's/^/    /' | clean
  else
    echo "  **node --check が通らない。戻す。**"
    cp "$GEN.bak-$STAMP" "$GEN"
    "$NODE_BIN" --check "$GEN" 2>&1 | head -3 | sed 's/^/    /' | clean
  fi
fi
echo '```'

# ═══════════ 2. 走らせて数える ═══════════
echo
echo "## 2. 待たずに走らせて、実投稿を数える"
echo
echo '```'
if ! cdp_ok; then
  echo "  CDP が落ちている。**LLM を 1 回も呼ばずに終わる（\$0）。**"
  echo '```'
  exit 0
fi
if [ -f /tmp/x-login-in-progress ]; then
  echo "  login ロックが在る。**走らせない（\$0）。**"
  echo '```'
  exit 0
fi

BEFORE="$(count_posted)"
echo "  走らせる前の累計: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo "  **キューが読めない。何もしない。**"; echo '```'; exit 1; fi
echo
echo "  --- comment-orchestrator を直接 叩く（最大 4 件・約 \$0.012） ---"
ORCH="$S/comment-orchestrator.sh"
if [ -f "$ORCH" ]; then
  ( cd "$W" && bash "$ORCH" ) 2>&1 | tail -25 | sed 's/^/    /' | clean
else
  echo "    **$ORCH が無い。走らせられない（\$0）。**"
fi
echo
for i in 60 120; do
  sleep 60
  printf '    %3s 秒後: 累計 %s 件\n' "$i" "$(count_posted)"
done
AFTER="$(count_posted)"
DIFF=$(( AFTER - BEFORE ))
echo
echo "  走らせる前: ${BEFORE} 件 → 後: ${AFTER} 件"
echo "  **今回 出た数: ${DIFF} 件**"
echo '```'

if [ "$DIFF" -gt 0 ]; then
  echo
  echo "### 出た返信（**キューの \`x_tweet_id\`＝一次情報**）"
  echo
  echo '```'
  "$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const n=Number(process.argv[2]);
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
rows.slice(-n).forEach(e=>{
  console.log("  "+(e.posted_at||e.created_at));
  console.log("  https://x.com/heng_ji31590/status/"+(e.x_tweet_id||e.tweet_id));
  console.log("  "+String(e.text||"").replace(/\n/g,"\n  "));
  console.log("");
});
' "$QJSON" "$DIFF" 2>&1 | clean
  echo '```'
else
  echo
  echo "### まだ 0 件。**弾かれた理由を全部 出す**"
  echo
  echo "修理が効いたかは、\`噛み合い検査で弾いた\` の理由を見れば分かる。"
  echo "**末尾の絵文字・書き出しの相づちが理由なら、修理が当たっていない。**"
  echo
  echo '```'
  tail -30 "$W/logs/comment-warmup.log" 2>/dev/null | grep -E 'gen failed|picked|orchestrator|enqueue' \
    | tail -20 | cut -c1-300 | sed 's/^/  /' | clean
  echo '```'
fi
} > "$OUT" 2>&1

echo "捨てる前に飾りを外す / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
