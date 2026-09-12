#!/bin/bash
# **修理を今度こそ当てる。パッチはヒアドキュメントでファイルに落として実行する。最大 $0.012。**
#
# ## x41 が失敗した理由（2026-09-13 02:14）
#
#   [eval]:9
#     const OLD_SKIP = "if (!rel.ok) return skip(噛み合い検査で弾いた:
#                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#     Unterminated string constant
#
# `node -e '...'` に埋め込んだ `\u0027`（シングルクォート）が途中で失われ、
# **JS が構文エラーで死んだ。** `node --check: OK` は元ファイルが無傷だっただけ。
#
# **対策: パッチをシェルに通さない。**
# `<<'JSEOF'`（引用符つきヒアドキュメント）でファイルに落とす。
# 引用符つきなので**シェルは中身を一切 解釈しない。** クォートもバックスラッシュもそのまま届く。
#
# ついでに**文字列の完全一致をやめる。** 行を正規表現で探して差し込む。
# 空白が 1 つ違うだけで当たらない当て方を続けない。
#
# ## x41 が持ち帰った収穫
#
#   3 ループ: **8 / 8 本**   ← 数え方を直したら 8/8。やはり全部 載っていた
#
#   #1 書き出しの「ふーん、」が直近 20 件に 3 件 / テンプレに無い絵文字「😅」＝声の範囲の外
#   #2 書き出しの「ふーん、」が直近 20 件に 3 件
#
# **2 件とも見た目の理由だけ。** 修理が当たっていれば通っていた。
# 新しい理由「テンプレに無い絵文字」も見えたので、**そこも拾う**（該当の絵文字を外す）。
#
# ## 修理する理由・しない理由
#
#   修理する … 末尾の絵文字「…」 ／ 書き出しの「…」 ／ テンプレに無い絵文字「…」
#   捨てる   … 共有する内容語が 0 個（読んでいない返信）
#              同じ書き出し「…」（冒頭 8 字 の一致。どこを削るか決められない）
#              金額の断定 など内容に関わるもの全部
#
# 理由が**全部**「修理する」側のときだけ直す。1 つでも混ざれば従来どおり捨てる。
# **LLM を追加で呼ばない。** 既にある文から飾りを外すだけなので $0。
#
# ## やらないこと
#
# **しきい値を緩めない。プロンプトを変えない。上限を上げない。Chrome を kill しない。**
# `.bak-<日時>` に退避し、`node --check` が通らなければその場で戻す。
# **書き換えた「後」を必ず grep で出す。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/repair-v2.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"
GEN="$S/asuka-reply.cjs"
LOCK=/tmp/x-login-in-progress
STAMP="$(date '+%Y%m%d-%H%M%S')"
PATCHJS="$(mktemp -t xrepair).js"
trap 'rm -f "$PATCHJS"' EXIT

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

# ─── パッチ本体。**引用符つきヒアドキュメント＝シェルは中身を解釈しない** ───
cat > "$PATCHJS" <<'JSEOF'
const fs = require('fs');
const p = process.argv[2];
let s = fs.readFileSync(p, 'utf8');

if (s.includes('COSMETIC_REPAIR')) { console.log('  既に入っている。何もしない。'); process.exit(0); }

const lines = s.split('\n');

// **完全一致をやめて、行を正規表現で探す。** 空白 1 つで外れる当て方をしない。
const iDecl = lines.findIndex((l) => /^\s*const\s+rel\s*=\s*checkRelevance\(/.test(l));
const iSkip = lines.findIndex((l) => /^\s*if\s*\(!rel\.ok\)\s*return\s+skip\(/.test(l));

if (iDecl < 0 || iSkip < 0 || iSkip <= iDecl) {
  console.log('  **想定した 2 行が見つからない。触らない。**');
  console.log('  decl=' + iDecl + ' skip=' + iSkip);
  process.exit(0);
}

// 1) const rel → let rel（あとで差し替えるため）
lines[iDecl] = lines[iDecl].replace(/\bconst\s+rel\s*=/, 'let rel =');

// 2) skip の直前に修理を差し込む
const block = [
  '',
  '  // COSMETIC_REPAIR (2026-09-13): **見た目の重複だけで捨てない。**',
  '  //',
  '  // LLM 呼び出しは既に終わっている。末尾の絵文字・書き出しの相づち・',
  '  // テンプレ外の絵文字で弾かれただけなら、本文は無傷なので',
  '  // **その飾りを外して測り直す。** 追加の LLM 呼び出しは無いので $0。',
  '  //',
  '  // **内容で弾かれたものは今までどおり捨てる。**',
  '  //   「共有する内容語が 0 個」 ← 読んでいない返信',
  '  //   「同じ書き出し『…』」     ← 冒頭 8 字 の一致。どこを削れば直るか決められない',
  '  if (!rel.ok) {',
  '    const rs = rel.reasons || [];',
  '    const FIXABLE = [/^末尾の絵文字「/, /^書き出しの「/, /^テンプレに無い絵文字「/];',
  '    const cosmetic = rs.length > 0 && rs.every((r) => FIXABLE.some((re) => re.test(r)));',
  '    if (cosmetic) {',
  '      let fixed = text;',
  '      // 末尾の絵文字が被った → 末尾の絵文字を落とす',
  '      if (rs.some((r) => /^末尾の絵文字「/.test(r))) {',
  '        fixed = fixed.replace(/[\\s\\u200d\\ufe0f\\p{Extended_Pictographic}]+$/u, EMPTY);',
  '      }',
  '      // テンプレに無い絵文字 → その絵文字を本文から外す',
  '      for (const r of rs) {',
  '        const m = /^テンプレに無い絵文字「(.+?)」/.exec(r);',
  '        if (!m) continue;',
  '        const bad = m[1].match(/\\p{Extended_Pictographic}(?:\\ufe0f)?(?:\\u200d\\p{Extended_Pictographic}(?:\\ufe0f)?)*/gu) || [];',
  '        for (const b of bad) fixed = fixed.split(b).join(EMPTY);',
  '      }',
  '      // 書き出しの相づちが被った → その相づちを落とす',
  '      for (const r of rs) {',
  '        const m = /^書き出しの「(.+?)」/.exec(r);',
  '        if (m && fixed.startsWith(m[1])) fixed = fixed.slice(m[1].length);',
  '      }',
  '      fixed = fixed.replace(/[ \\u3000]{2,}/g, SPACE).trim();',
  '      const fw = weightOf(fixed);',
  '      if (fixed && fixed !== text && fixed.length >= MIN_CHARS && fw <= MAX_WEIGHT) {',
  '        const re2 = checkRelevance({ text: fixed, targetText: target, recentReplies: recentForGate, runReplies: runForGate }, relRules);',
  '        if (re2.ok) { text = fixed; rel = re2; }',
  '      }',
  '    }',
  '  }',
  '',
];

// `EMPTY` / `SPACE` は**この差し込みの直前で定義する。**
// 空文字リテラルを組み立てで書かずに済ませ、クォートの取り違えを避ける。
const consts = [
  '',
  '  // COSMETIC_REPAIR のための定数（空文字・半角スペース）',
  '  const EMPTY = String.fromCharCode();',
  '  const SPACE = String.fromCharCode(32);',
];

lines.splice(iSkip, 0, ...consts, ...block);
fs.writeFileSync(p, lines.join('\n'));
console.log('  書き換えた。decl 行=' + (iDecl + 1) + ' / skip 行=' + (iSkip + 1));
JSEOF

{
echo "# 修理を今度こそ当てる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x41 は \`node -e\` に埋め込んだシングルクォートが失われて**構文エラーで死んだ。**"
echo "> 今回はパッチを**引用符つきヒアドキュメントでファイルに落として**実行する。"
echo "> シェルは中身を一切 解釈しない。"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"
[ -z "$SNAP" ] && { sleep 2; SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"; }
EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
N=0; MISS=""
for j in $EXPECT; do
  if printf '%s\n' "$SNAP" | grep -qxF "ai.openclaw.$j"; then N=$((N+1)); else MISS="$MISS $j"; fi
done
echo "  3 ループ    : **${N} / 8 本**${MISS:+ / 欠け:$MISS}"
cdp_ok && echo "  CDP         : 健全" || echo "  CDP         : **落ちている**"
[ -f "$LOCK" ] && echo "  login ロック: **在る**" || echo "  login ロック: 無い"
echo '```'

# ═══════════ 1. パッチを当てる ═══════════
echo
echo "## 1. \`asuka-reply.cjs\` に修理を当てる"
echo
echo '```'
if [ ! -f "$GEN" ]; then
  echo "  **$GEN が無い。何もしない。**"
else
  echo "  --- 当てる前 ---"
  grep -nE 'const rel = checkRelevance|if \(!rel\.ok\) return skip|COSMETIC_REPAIR' "$GEN" \
    2>/dev/null | head -4 | cut -c1-130 | sed 's/^/    /' | clean
  echo "  パッチ: $PATCHJS（$(wc -l < "$PATCHJS" | tr -d ' ') 行）"
  if ! "$NODE_BIN" --check "$PATCHJS" 2>/dev/null; then
    echo "  **パッチ自体が構文エラー。当てない。**"
    "$NODE_BIN" --check "$PATCHJS" 2>&1 | head -5 | sed 's/^/    /'
  else
    echo "  パッチの node --check: OK"
    cp "$GEN" "$GEN.bak-$STAMP" && echo "  退避: $(basename "$GEN").bak-$STAMP"
    "$NODE_BIN" "$PATCHJS" "$GEN" 2>&1 | sed 's/^/  /' | clean
    if "$NODE_BIN" --check "$GEN" 2>/dev/null; then
      echo "  対象の node --check: OK"
      echo "  --- 当てた後（**必ず出す**） ---"
      grep -nE 'COSMETIC_REPAIR \(|let rel = checkRelevance|FIXABLE|if \(re2\.ok\)|if \(!rel\.ok\) return skip' \
        "$GEN" 2>/dev/null | head -6 | cut -c1-130 | sed 's/^/    /' | clean
    else
      echo "  **対象が構文エラーになった。戻す。**"
      cp "$GEN.bak-$STAMP" "$GEN"
      "$NODE_BIN" --check "$GEN" 2>&1 | head -3 | sed 's/^/    /' | clean
    fi
  fi
fi
echo '```'

# ═══════════ 2. 走らせて数える ═══════════
echo
echo "## 2. 定時と同じ \`MAX_PICKS_PER_FIRE=4\` で走らせる"
echo
echo "直接 叩くと既定の **2** になる。9/9 の定時実行は **4** だった。"
echo "**1 日あたりの件数は変えない。** 定時と同じ条件で測るために揃えるだけ。"
echo
echo '```'
if ! grep -q 'COSMETIC_REPAIR' "$GEN" 2>/dev/null; then
  echo "  **修理が入っていない。走らせても同じ結果になるので、LLM を呼ばずに終わる（\$0）。**"
  echo '```'
  exit 0
fi
if ! cdp_ok; then echo "  CDP が落ちている。**走らせない（\$0）。**"; echo '```'; exit 0; fi
if [ -f "$LOCK" ]; then echo "  login ロックが在る。**走らせない（\$0）。**"; echo '```'; exit 0; fi

BEFORE="$(count_posted)"
echo "  走らせる前の累計: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo "  **キューが読めない。何もしない。**"; echo '```'; exit 1; fi
ORCH="$S/comment-orchestrator.sh"
if [ ! -f "$ORCH" ]; then echo "  **$ORCH が無い（\$0）。**"; echo '```'; exit 0; fi
echo
echo "  --- 実行（最大 4 件・約 \$0.012） ---"
( cd "$W" && MAX_PICKS_PER_FIRE=4 bash "$ORCH" ) 2>&1 | tail -30 | cut -c1-320 | sed 's/^/    /' | clean
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
  echo "### まだ 0 件。**弾かれた理由をそのまま出す**"
  echo
  echo "修理が効いていれば、\`末尾の絵文字\`・\`書き出しの\`・\`テンプレに無い絵文字\` だけを"
  echo "理由に落ちることは無くなるはず。**それらがまだ単独で出ていれば、修理が動いていない。**"
  echo
  echo '```'
  tail -40 "$W/logs/comment-warmup.log" 2>/dev/null \
    | grep -aE 'gen failed|picked|orchestrator|enqueue' | tail -16 \
    | cut -c1-320 | sed 's/^/  /' | clean
  echo '```'
fi

# ═══════════ 3. フォロー／アンフォローの実数 ═══════════
echo
echo "## 3. フォロー／アンフォローは何件 出ているか"
echo
echo "**返信ばかり見ていて、ここを一度も数えていなかった。**"
echo
echo "### 3-A. 一次情報（状態ファイルの実体）"
echo
echo '```'
for f in reply-followers.json followed.json follow-state.json unfollowed.json \
         auto-followed.json reply-follow-log.json; do
  P="$W/data/$f"
  [ -f "$P" ] || continue
  CNT="$("$NODE_BIN" -e '
const fs=require("fs");
try{ const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(Array.isArray(d)) console.log(d.length);
  else if(d && typeof d==="object"){
    const a=Object.values(d).find(v=>Array.isArray(v));
    console.log(a?a.length:Object.keys(d).length);
  } else console.log("?");
}catch(e){ console.log("読めない"); }' "$P" 2>/dev/null)"
  printf '  %-24s %6s 件 / 最終更新 %s\n' "$f" "$CNT" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
echo "  --- data/ にある状態ファイル ---"
ls -1 "$W/data" 2>/dev/null | head -25 | sed 's/^/    /'
echo '```'
echo
echo "### 3-B. 一次情報**ではない**（ログの行数。二重計上する）"
echo
echo '```'
TODAY="$(date '+%Y-%m-%d')"
for L in competitor-follower-follow hashtag-follow badge-followback \
         reply-followback-check reply-followers-cleanup; do
  F="$W/logs/$L.log"
  if [ ! -f "$F" ]; then printf '  %-28s ログ無し\n' "$L"; continue; fi
  TD=$(grep -cE "^\[$TODAY" "$F" 2>/dev/null || true)
  TD=$(printf '%s' "${TD:-0}" | tr -dc '0-9'); [ -z "$TD" ] && TD=0
  printf '  %-28s 本日 %4s 行 / 最終更新 %s\n' "$L" "$TD" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$F" 2>/dev/null)"
done
echo
echo "  --- 直近の「フォロー／解除」行（各 3 行） ---"
for L in competitor-follower-follow hashtag-follow badge-followback reply-followers-cleanup; do
  F="$W/logs/$L.log"
  [ -f "$F" ] || continue
  echo "  [$L]"
  grep -aE 'follow|unfollow|フォロー|解除|外し' "$F" 2>/dev/null | tail -3 \
    | cut -c1-200 | sed 's/^/    /' | clean
done
echo '```'
} > "$OUT" 2>&1

echo "修理 v2 とフォロー実数 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
