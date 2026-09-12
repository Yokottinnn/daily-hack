#!/bin/bash
# **モデルに「使ってはいけない書き出し」を教える ＋ 広告を入口で落とす ＋ 今日の分を埋める。**
# 費用 最大 $0.096（下に内訳）。
#
# ## 根本原因（x41 の実測で見えた）
#
#   132: const recent = recentReplies(QUEUE, RECENT_N || 8)   ← **プロンプトに渡すのは 8 件**
#   135: const recentForGate = recentReplies(QUEUE, 20)        ← **ゲートが見るのは 20 件**
#
# **モデルは 8 件しか見ていないのに、ゲートは 20 件で弾く。**
# 9〜20 件前に使った書き出しはモデルから見えないので、避けようがない。
#
# しかも渡しているのは**返信の全文**であって、「この書き出しは使うな」という
# 指示ではない。ルールはこうなっている。
#
#   max_same_opening_in_recent: 1   ← 冒頭 8 字 が直近 20 件に 1 件でもあれば弾く
#   max_same_opener_in_recent:  3   ← 「ふーん、」等の相づちが 3 件で弾く
#   max_same_final_emoji_in_recent: 3
#   allowed_emoji: 14 種            ← この外を使うと弾く
#
# **弾く条件を全部 知っているのに、モデルには 1 つも伝えていなかった。**
#
# ## 直し方: 禁止リストをプロンプトに入れる
#
# ゲートが見るのと**同じ 20 件**から、次を計算して渡す。
#
#   - 使うと弾かれる相づち（「ふーん、」など）
#   - 使ってはいけない冒頭 8 字（直近 20 件の先頭 8 字 そのもの）
#   - 末尾に使ってはいけない絵文字
#   - **使ってよい絵文字の一覧**（テンプレ外を使わせない）
#
# 増える入力は 200〜300 字 ＝ **1 件あたり $0.0003 未満**（Haiku 4.5 入力 $1.00/MTok）。
# **修理（x43）は対症療法で、これが根本。** 弾かれる前に散らす。
#
# ## 広告を入口で落とす
#
# ログに残っていた**生成後**の skip（＝LLM 代を払ってから捨てた）。
#
#   生成側が skip: 楽天公式のキャンペーン告知投稿
#   生成側が skip: 店舗の販売促進投稿
#   生成側が skip: 紹介コード・招待コード・登録誘導の投稿
#
# `target_skip.campaign_words` に**高精度なものだけ**足す。
# 広く取りすぎると普通の投稿まで落ちるので、**曖昧な語は入れない。**
#
# ## 今日の分を埋める
#
# 1 回の実行では最大 4 件。**目標に届くまで繰り返し叩く。**
#
#   1 回あたり: 最大 4 件 × $0.003 = **$0.012**
#   このタスク: 最大 8 回 = **$0.096**（目標に届けば途中で止まる）
#   毎日 同じことをした場合: $0.096 × 30 = **$2.88/月**
#     ただしこれは**取り戻しのための 1 回きり**で、定時実行の分とは別。
#     定時の推定は 1日 約 $0.19 ／ 1か月 約 $5.8（通過率 25% 前提）。
#
# ## やらないこと
#
# **しきい値を緩めない。1 日の上限を上げない。Chrome を kill しない。**
# 変更は `.bak-<日時>` に退避し、`node --check` / `JSON.parse` が通らなければその場で戻す。
# **書き換えた「後」を必ず出す。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/teach-banned.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$D/post_queue.json"
GEN="$S/asuka-reply.cjs"
RULES="$D/reply-relevance-rules.json"
PROMPT="$D/reply-style-prompt.json"
LOCK=/tmp/x-login-in-progress
STAMP="$(date '+%Y%m%d-%H%M%S')"
TARGET_TODAY="${TARGET_TODAY:-16}"
MAX_FIRES="${MAX_FIRES:-8}"

P1="$(mktemp -t xp1).js"; P2="$(mktemp -t xp2).js"; P3="$(mktemp -t xp3).js"
trap 'rm -f "$P1" "$P2" "$P3"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

count_posted() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{ const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id)).length);
}catch(e){ console.log(-1); }' "$QJSON" 2>/dev/null || echo -1
}
count_today() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{ const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const t=new Date(Date.now()+9*3600*1000).toISOString().slice(0,10);
  console.log((q.queue||[]).filter(e=>{
    if(!e||!(e.x_tweet_id||e.tweet_id)) return false;
    if(e.kind!=="comment"&&e.kind!=="reply") return false;
    const d=new Date(e.posted_at||e.created_at||0);
    return !isNaN(d) && new Date(d.getTime()+9*3600*1000).toISOString().slice(0,10)===t;
  }).length);
}catch(e){ console.log(-1); }' "$QJSON" 2>/dev/null || echo -1
}

# ─── ① 生成器: 禁止リストを組み立ててプロンプトに足す ───
cat > "$P1" <<'JSEOF'
const fs = require('fs');
const p = process.argv[2];
let s = fs.readFileSync(p, 'utf8');
if (s.includes('BANNED_LIST')) { console.log('  既に入っている。何もしない。'); process.exit(0); }

const lines = s.split('\n');
const iUser = lines.findIndex((l) => /^\s*const\s+userMsg\s*=/.test(l));
const iDry = lines.findIndex((l) => /^\s*if\s*\(process\.env\.DRY_RUN\s*===/.test(l));
if (iUser < 0 || iDry < 0 || iDry <= iUser) {
  console.log('  **想定した 2 行が見つからない。触らない。** user=' + iUser + ' dry=' + iDry);
  process.exit(0);
}

lines[iUser] = lines[iUser].replace(/\bconst\s+userMsg\s*=/, 'let userMsg =');

const block = [
  '',
  '  // BANNED_LIST (2026-09-13): **弾く条件をモデルにも教える。**',
  '  //',
  '  // プロンプトへ渡していたのは直近 8 件の「全文」だけで、ゲートは 20 件を見ていた。',
  '  // 9〜20 件前に使った書き出しはモデルから見えず、避けようがなかった。',
  '  // **ゲートと同じ 20 件から禁止リストを作って渡す。**',
  '  //',
  '  // 増える入力は 200〜300 字 ＝ 1 件あたり $0.0003 未満（Haiku 4.5 入力 $1.00/MTok）。',
  '  try {',
  '    const BR = relRules || {};',
  '    const NL = String.fromCharCode(10);',
  '    const win2 = Number.isFinite(BR.recent_window) ? BR.recent_window : 20;',
  '    const prev2 = recentForGate.slice(-win2).map((x) => String(x || []));',
  '    const runR2 = runForGate.map((x) => String(x || []));',
  '',
  '    // 相づち（「ふーん、」など）',
  '    const maxOpRun = Number.isFinite(BR.max_same_opener_in_run) ? BR.max_same_opener_in_run : 1;',
  '    const maxOpOld = Number.isFinite(BR.max_same_opener_in_recent) ? BR.max_same_opener_in_recent : 3;',
  '    const badOpen = (BR.opening_phrases || []).filter((o) =>',
  '      runR2.filter((x) => x.startsWith(o)).length >= maxOpRun ||',
  '      prev2.filter((x) => x.startsWith(o)).length >= maxOpOld);',
  '',
  '    // 冒頭 N 字（max_same_opening_in_recent は 1 なので、直近に有る時点で使えない）',
  '    const oc2 = Number.isFinite(BR.opening_chars) ? BR.opening_chars : 8;',
  '    const badHead = [...new Set(prev2.concat(runR2).map((x) => x.slice(0, oc2)).filter(Boolean))].slice(0, 20);',
  '',
  '    // 末尾の絵文字',
  '    const lastE = (x) => {',
  '      const m = String(x).match(/(?:\\p{Extended_Pictographic}(?:\\ufe0f)?(?:\\u200d\\p{Extended_Pictographic}(?:\\ufe0f)?)*)\\s*$/u);',
  '      return m ? m[0].trim().replace(/\\ufe0f/g, String.fromCharCode()) : String.fromCharCode();',
  '    };',
  '    const maxERun = Number.isFinite(BR.max_same_final_emoji_in_run) ? BR.max_same_final_emoji_in_run : 1;',
  '    const maxEOld = Number.isFinite(BR.max_same_final_emoji_in_recent) ? BR.max_same_final_emoji_in_recent : 3;',
  '    const tally = new Map();',
  '    for (const x of prev2) { const e = lastE(x); if (e) tally.set(e, (tally.get(e) || 0) + 1); }',
  '    const runE = new Map();',
  '    for (const x of runR2) { const e = lastE(x); if (e) runE.set(e, (runE.get(e) || 0) + 1); }',
  '    const badE = [...new Set([',
  '      ...[...tally].filter((kv) => kv[1] >= maxEOld).map((kv) => kv[0]),',
  '      ...[...runE].filter((kv) => kv[1] >= maxERun).map((kv) => kv[0]),',
  '    ])];',
  '    const okE = (BR.allowed_emoji || []).filter((e) => !badE.includes(e));',
  '',
  '    const parts = [];',
  '    if (badOpen.length) parts.push(BAN_A + badOpen.map((o) => KO + o + KC).join(TEN));',
  '    if (badHead.length) parts.push(BAN_B + badHead.map((o) => KO + o + KC).join(TEN));',
  '    if (badE.length) parts.push(BAN_C + badE.join(SP));',
  '    if (okE.length) parts.push(BAN_D + okE.join(SP));',
  '    if (parts.length) userMsg = userMsg + NL + NL + parts.join(NL);',
  '  } catch (e) { /* 禁止リストが作れなくても生成は続ける */ }',
  '',
];

// 文字リテラルを直に書かずに済ませる（クォートの取り違えを避ける）
const consts = [
  '',
  '  // BANNED_LIST の見出し。JSON 側の banned_labels があればそれを使う',
  '  const BL = (relRules && relRules.banned_labels) || {};',
  '  const KO = BL.open_quote || String.fromCharCode(0x300C);',
  '  const KC = BL.close_quote || String.fromCharCode(0x300D);',
  '  const TEN = BL.sep || String.fromCharCode(0x3001);',
  '  const SP = String.fromCharCode(32);',
  '  const BAN_A = BL.a || String.fromCharCode(0x4F7F,0x3046,0x3068,0x5F3E,0x304B,0x308C,0x308B,0x76F8,0x3065,0x3061,0x3002,0x907F,0x3051,0x308B,0x3053,0x3068,0x3A);',
  '  const BAN_B = BL.b || String.fromCharCode(0x4F7F,0x3063,0x3066,0x306F,0x3044,0x3051,0x306A,0x3044,0x66F8,0x304D,0x51FA,0x3057,0x3A);',
  '  const BAN_C = BL.c || String.fromCharCode(0x672B,0x5C3E,0x306B,0x4F7F,0x3048,0x306A,0x3044,0x7D75,0x6587,0x5B57,0x3A);',
  '  const BAN_D = BL.d || String.fromCharCode(0x4F7F,0x3063,0x3066,0x3088,0x3044,0x7D75,0x6587,0x5B57,0x306F,0x3053,0x306E,0x4E2D,0x3060,0x3051,0x3A);',
];

lines.splice(iDry, 0, ...consts, ...block);
fs.writeFileSync(p, lines.join('\n'));
console.log('  書き換えた。userMsg 行=' + (iUser + 1) + ' / DRY_RUN 行=' + (iDry + 1));
JSEOF

# ─── ② ルール: 広告語を入口に足す ───
cat > "$P2" <<'JSEOF'
const fs = require('fs');
const p = process.argv[2];
const r = JSON.parse(fs.readFileSync(p, 'utf8'));
r.target_skip = r.target_skip || {};
const cw = r.target_skip.campaign_words || [];

// **高精度なものだけ。** 曖昧な語（「お得」「セール」など）は普通の投稿まで落とすので入れない。
// 根拠: 2026-09-09〜13 のログで LLM を呼んだ後に skip したもの。
//   生成側が skip: 楽天公式のキャンペーン告知投稿
//   生成側が skip: 店舗の販売促進投稿
//   生成側が skip: 紹介コード・招待コード・登録誘導の投稿
const add = [
  '招待コード', '紹介コード', '招待リンク', '紹介リンク', '友達紹介',
  'キャンペーン実施中', 'キャンペーン開催中', '新規登録で', '初回限定',
  '全員にプレゼント', '応募受付', 'エントリーで', 'ご招待',
];
const before = cw.length;
for (const w of add) if (!cw.includes(w)) cw.push(w);
r.target_skip.campaign_words = cw;

const dm = r.target_skip.domains || [];
const addD = ['lin.ee', 'ck.jp.ap.valuecommerce', 'h.accesstrade', 'app.adjust.com'];
const beforeD = dm.length;
for (const d of addD) if (!dm.includes(d)) dm.push(d);
r.target_skip.domains = dm;

fs.writeFileSync(p, JSON.stringify(r, null, 2));
console.log('  campaign_words: ' + before + ' → ' + cw.length + ' 件');
console.log('  domains       : ' + beforeD + ' → ' + dm.length + ' 件');
JSEOF

# ─── ③ 検証: 書き換えた後の JSON が読めるか ───
cat > "$P3" <<'JSEOF'
const fs = require('fs');
const r = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const ts = r.target_skip || {};
console.log('  campaign_words ' + (ts.campaign_words || []).length + ' 件 / domains ' + (ts.domains || []).length + ' 件');
console.log('  opening_phrases ' + (r.opening_phrases || []).length + ' 件 / allowed_emoji ' + (r.allowed_emoji || []).length + ' 件');
JSEOF

{
echo "# モデルに「弾かれる条件」を教える"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **弾く条件を全部 知っているのに、モデルには 1 つも伝えていなかった。**"
echo "> プロンプトへ渡すのは直近 **8 件の全文**、ゲートが見るのは **20 件**。"
echo "> 9〜20 件前に使った書き出しは、モデルから見えないので避けようがない。"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"
[ -z "$SNAP" ] && { sleep 2; SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"; }
EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
N=0; for j in $EXPECT; do printf '%s\n' "$SNAP" | grep -qxF "ai.openclaw.$j" && N=$((N+1)); done
echo "  3 ループ    : **${N} / 8 本**"
cdp_ok && echo "  CDP         : 健全" || echo "  CDP         : **落ちている**"
[ -f "$LOCK" ] && echo "  login ロック: **在る**" || echo "  login ロック: 無い"
grep -q 'COSMETIC_REPAIR' "$GEN" 2>/dev/null && echo "  修理(x43)   : 入っている" || echo "  修理(x43)   : **入っていない**"
echo "  本日の返信  : **$(count_today) 件** / 累計 $(count_posted) 件"
echo '```'

# ═══════════ 1. 禁止リスト ═══════════
echo
echo "## 1. 禁止リストをプロンプトに入れる（**根本原因**）"
echo
echo '```'
if [ ! -f "$GEN" ]; then echo "  **$GEN が無い。**"; else
  echo "  --- 当てる前 ---"
  grep -nE 'const userMsg =|BANNED_LIST' "$GEN" 2>/dev/null | head -3 | cut -c1-110 | sed 's/^/    /'
  if ! "$NODE_BIN" --check "$P1" 2>/dev/null; then
    echo "  **パッチ自体が構文エラー。当てない。**"
    "$NODE_BIN" --check "$P1" 2>&1 | head -5 | sed 's/^/    /'
  else
    echo "  パッチの node --check: OK"
    cp "$GEN" "$GEN.bak-$STAMP"
    "$NODE_BIN" "$P1" "$GEN" 2>&1 | sed 's/^/  /' | clean
    if "$NODE_BIN" --check "$GEN" 2>/dev/null; then
      echo "  対象の node --check: OK"
      echo "  --- 当てた後 ---"
      grep -nE 'BANNED_LIST \(|let userMsg =|badHead|okE' "$GEN" 2>/dev/null | head -5 | cut -c1-110 | sed 's/^/    /'
    else
      echo "  **構文エラーになった。戻す。**"
      cp "$GEN.bak-$STAMP" "$GEN"
      "$NODE_BIN" --check "$GEN" 2>&1 | head -3 | sed 's/^/    /'
    fi
  fi
fi
echo '```'

# ═══════════ 2. 広告を入口で落とす ═══════════
echo
echo "## 2. 広告を入口で落とす（LLM を呼ぶ前に）"
echo
echo "ログに残っていた**生成後**の skip ＝ **LLM 代を払ってから捨てていた。**"
echo
echo '```'
if [ ! -f "$RULES" ]; then echo "  **$RULES が無い。**"; else
  echo "  --- 当てる前 ---"
  "$NODE_BIN" "$P3" "$RULES" 2>&1 | sed 's/^/  /'
  cp "$RULES" "$RULES.bak-$STAMP"
  "$NODE_BIN" "$P2" "$RULES" 2>&1 | sed 's/^/  /'
  if "$NODE_BIN" "$P3" "$RULES" >/dev/null 2>&1; then
    echo "  --- 当てた後 ---"
    "$NODE_BIN" "$P3" "$RULES" 2>&1 | sed 's/^/  /'
  else
    echo "  **JSON が壊れた。戻す。**"
    cp "$RULES.bak-$STAMP" "$RULES"
  fi
fi
echo '```'

# ═══════════ 3. 今日の分を埋める ═══════════
echo
echo "## 3. 目標 ${TARGET_TODAY} 件に届くまで繰り返す（最大 ${MAX_FIRES} 回）"
echo
echo "1 回あたり 最大 4 件・約 \$0.012。**最大 ${MAX_FIRES} 回で \$$(echo "$MAX_FIRES" | awk '{printf "%.3f", $1*0.012}')。**"
echo "目標に届けば途中で止まる。候補が尽きても止まる。"
echo
echo '```'
if ! grep -q 'BANNED_LIST' "$GEN" 2>/dev/null; then
  echo "  禁止リストが入っていない。**走らせても同じなので終わる（\$0）。**"
  echo '```'
elif ! cdp_ok; then
  echo "  CDP が落ちている。**走らせない（\$0）。**"
  echo '```'
elif [ -f "$LOCK" ]; then
  echo "  login ロックが在る。**走らせない（\$0）。**"
  echo '```'
else
  ORCH="$S/comment-orchestrator.sh"
  if [ ! -f "$ORCH" ]; then echo "  **$ORCH が無い（\$0）。**"; echo '```'; else
    T0="$(count_today)"; A0="$(count_posted)"
    echo "  開始時: 本日 ${T0} 件 / 累計 ${A0} 件 / 目標 ${TARGET_TODAY} 件"
    echo
    FIRED=0
    for k in $(seq 1 "$MAX_FIRES"); do
      NOWT="$(count_today)"
      if [ "$NOWT" -ge "$TARGET_TODAY" ] 2>/dev/null; then
        echo "  目標に到達した（本日 ${NOWT} 件）。止める。"; break
      fi
      FIRED=$((FIRED+1))
      echo "  --- ${k} 回目 ---"
      RES="$( ( cd "$W" && MAX_PICKS_PER_FIRE=4 bash "$ORCH" ) 2>&1 || true )"
      printf '%s\n' "$RES" | grep -aE 'picked|gen failed|enqueue|orchestrator done' \
        | tail -8 | cut -c1-260 | sed 's/^/      /' | clean
      # 候補が 0 なら、これ以上 叩いても同じ
      if printf '%s\n' "$RES" | grep -qa 'from 0 candidates'; then
        echo "      **候補が 0。これ以上 叩いても同じなので止める。**"; break
      fi
      sleep 20
      echo "      → 本日 $(count_today) 件 / 累計 $(count_posted) 件"
    done
    sleep 40
    T1="$(count_today)"; A1="$(count_posted)"
    echo
    echo "  叩いた回数: ${FIRED} 回（概算 \$$(echo "$FIRED" | awk '{printf "%.3f", $1*0.012}') まで）"
    echo "  本日: ${T0} 件 → **${T1} 件**"
    echo "  累計: ${A0} 件 → **${A1} 件**"
    echo "  **今回 出た数: $(( A1 - A0 )) 件**"
    echo '```'

    DIFF=$(( A1 - A0 ))
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
      echo "### まだ 0 件。**弾かれた理由をそのまま出す**"
      echo
      echo '```'
      tail -60 "$W/logs/comment-warmup.log" 2>/dev/null \
        | grep -aE 'gen failed|picked|orchestrator done' | tail -14 \
        | cut -c1-300 | sed 's/^/  /' | clean
      echo '```'
    fi
  fi
fi

# ═══════════ 4. フォロー／アンフォロー ═══════════
echo
echo "## 4. フォロー／アンフォローの実数"
echo
echo "### 4-A. 一次情報（状態ファイル）"
echo
echo '```'
for f in reply-followers.json followed.json follow-state.json unfollowed.json auto-followed.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  CNT="$("$NODE_BIN" -e '
const fs=require("fs");
try{ const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(Array.isArray(d)) console.log(d.length);
  else if(d&&typeof d==="object"){const a=Object.values(d).find(v=>Array.isArray(v));console.log(a?a.length:Object.keys(d).length);}
  else console.log("?");
}catch(e){ console.log("読めない"); }' "$P" 2>/dev/null)"
  printf '  %-24s %6s 件 / 最終更新 %s\n' "$f" "$CNT" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
ls -1 "$D" 2>/dev/null | head -25 | sed 's/^/    /'
echo '```'
echo
echo "### 4-B. 一次情報**ではない**（ログの行数。二重計上する）"
echo
echo '```'
TODAY="$(date '+%Y-%m-%d')"
for L in competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup; do
  F="$W/logs/$L.log"
  if [ ! -f "$F" ]; then printf '  %-28s ログ無し\n' "$L"; continue; fi
  TD=$(grep -cE "^\[$TODAY" "$F" 2>/dev/null || true)
  TD=$(printf '%s' "${TD:-0}" | tr -dc '0-9'); [ -z "$TD" ] && TD=0
  printf '  %-28s 本日 %4s 行 / 最終更新 %s\n' "$L" "$TD" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$F" 2>/dev/null)"
done
echo '```'
} > "$OUT" 2>&1

echo "禁止リストと今日の埋め / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
