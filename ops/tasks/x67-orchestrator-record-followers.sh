#!/bin/bash
# **返信きっかけのフォローにもフォロワー数を記録する。費用 $0（件数は変わらない）。**
#
# ## なぜ（x63 / x65 の実測）
#
#   comment-orchestrator  135 件 / 返し **21.5%**   ← いちばん良いのに **記録していない**
#   competitor-follower   168 件 / 返し 11.9%       ← x64 で記録済み
#   hashtag-follow         39 件 / 返し 15.4%       ← x64 で記録済み
#
# **いちばん返りのいい供給元だけ、帯ごとの分析ができない状態になっている。**
#
# ## 直すところ（x66 で実物を確認済み）
#
# `comment-orchestrator.sh` の follow 記録は、`follow-handle.js` の出力を
# `FOLLOW_OUT` に持っているのに、**JSON へは 5 つしか書いていない。**
#
#   s['$AUTHOR'] = {
#     followed_at: new Date().toISOString(),
#     followback_status: 'pending',
#     scheduled_unfollow_at: null,
#     source: 'comment-orchestrator',
#     comment_id: '$ID'
#   };
#
# **`FOLLOW_OUT` を環境変数で渡して、`profile.follower_count` を足す。**
#
# ## やること（**2 箇所だけ**）
#
#   1. `/usr/local/bin/node -e "` の前に `FOLLOW_OUT_JSON="$FOLLOW_OUT" ` を足す
#   2. JSON に `followers_at_follow` / `following_at_follow` を足す
#
# **フォローの件数は 1 件も変わらない。返信の本数も変わらない。よって $0。**
#
# ## やらないこと
#
# **上限を触らない。候補の選び方を変えない**（費用が動くので別途 確認を取る）。
# **投稿しない。フォローしない。LLM を呼ばない（$0）。**
# 一時ファイルは `.sh` のまま（ルール 14）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/orchestrator-record-followers.md"
NODE_BIN="/usr/local/bin/node"
ORCH="$S/comment-orchestrator.sh"
PATCH="$S/.x67-patch.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
trap 'rm -f "$PATCH" "$ORCH.x67-new.sh"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[a-z]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

cat > "$PATCH" <<'JSEOF'
const fs = require("fs");
const p = process.argv[2];
const src = fs.readFileSync(p, "utf8");

if (src.includes("followers_at_follow")) {
  console.log("  **既に入っている。当てない。**");
  process.exit(3);
}

// ① FOLLOW_OUT を環境変数で渡す（**この 1 行だけを対象にする**）
const A_OLD = "      if [ \"$FOLLOW_STATUS\" = \"followed\" ]; then\n        /usr/local/bin/node -e \"";
const A_NEW = "      if [ \"$FOLLOW_STATUS\" = \"followed\" ]; then\n        FOLLOW_OUT_JSON=\"$FOLLOW_OUT\" /usr/local/bin/node -e \"";

// ② JSON に 2 つ 足す（**source の行の前に入れる**）
const B_OLD = "          source: 'comment-orchestrator',\n          comment_id: '$ID'";
const B_NEW = [
  "          followers_at_follow: (function () { try { var f = JSON.parse(process.env.FOLLOW_OUT_JSON || '{}'); return (f.profile && typeof f.profile.follower_count === 'number') ? f.profile.follower_count : null; } catch (e) { return null; } })(),",
  "          following_at_follow: (function () { try { var f = JSON.parse(process.env.FOLLOW_OUT_JSON || '{}'); return (f.profile && typeof f.profile.following_count === 'number') ? f.profile.following_count : null; } catch (e) { return null; } })(),",
  "          source: 'comment-orchestrator',",
  "          comment_id: '$ID'",
].join("\n");

const count = (s, sub) => s.split(sub).length - 1;
const nA = count(src, A_OLD), nB = count(src, B_OLD);
console.log("  目印 ①（FOLLOW_OUT の受け渡し）: " + nA + " 箇所");
console.log("  目印 ②（JSON の中身）          : " + nB + " 箇所");

if (nA !== 1 || nB !== 1) {
  console.log("  **1 箇所 でないので当てない。** ファイルが変わっている");
  process.exit(4);
}

const patched = src.replace(A_OLD, A_NEW).replace(B_OLD, B_NEW);
fs.writeFileSync(p + ".x67-new.sh", patched);   // **拡張子は .sh のまま**
console.log("  当てた（検査待ち）");
JSEOF

{
echo "# 返信きっかけのフォローにもフォロワー数を記録する"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`comment-orchestrator\` は **返し率 21.5% でいちばん良いのに、記録していない。**"
echo "> \`FOLLOW_OUT\` に \`profile\` を持っているのに、JSON へ 5 つしか書いていない。"
echo
echo "**フォローの件数も返信の本数も 1 件 も変えない。よって \$0。**"

# ═══════════ 0. 当てる前 ═══════════
echo
echo "## 0. 当てる前"
echo
echo '```'
if [ ! -f "$ORCH" ]; then
  echo "  **$ORCH が無い。**"
else
  printf '  %s 行 / 最終更新 %s\n' "$(wc -l < "$ORCH" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$ORCH" 2>/dev/null)"
  echo "  followers_at_follow を含む箇所: $(grep -c 'followers_at_follow' "$ORCH" 2>/dev/null || echo 0)"
fi
echo '```'

# ═══════════ 1. 当てる ═══════════
echo
echo "## 1. 足す 2 つ"
echo
echo "| キー | 中身 |"
echo "| --- | --- |"
echo "| \`followers_at_follow\` | フォローした時点の相手のフォロワー数 |"
echo "| \`following_at_follow\` | 同・フォロー数 |"
echo
echo "**既存のキーは 1 つも触らない。** \`source\` の行の前に差し込むだけ。"
echo
echo '```'
if [ ! -f "$ORCH" ]; then
  echo "  対象が無い。"
elif ! "$NODE_BIN" --check "$PATCH" 2>/dev/null; then
  echo "  **パッチが構文エラー。当てない。**"
  "$NODE_BIN" --check "$PATCH" 2>&1 | head -5 | sed 's/^/    /'
else
  "$NODE_BIN" "$PATCH" "$ORCH" 2>&1 | clean
  if [ -f "$ORCH.x67-new.sh" ]; then
    echo
    echo "  --- 検査して置き換える ---"
    if bash -n "$ORCH.x67-new.sh" 2>/dev/null; then
      cp "$ORCH" "$ORCH.bak-$STAMP"
      mv "$ORCH.x67-new.sh" "$ORCH"
      chmod +x "$ORCH"
      echo "    **置き換えた**（退避 $(basename "$ORCH").bak-$STAMP）"
    else
      echo "    **bash の構文エラー。置き換えない**"
      bash -n "$ORCH.x67-new.sh" 2>&1 | head -4 | sed 's/^/      /'
      rm -f "$ORCH.x67-new.sh"
    fi
  fi
fi
echo '```'

# ═══════════ 2. 当てた後 ═══════════
echo
echo "## 2. 当てた後（**実物**）"
echo
echo '```bash'
if [ -f "$ORCH" ]; then
  N="$(grep -n "source: 'comment-orchestrator'" "$ORCH" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -n "$N" ]; then
    awk -v s="$((N - 8))" -v e="$((N + 4))" 'NR>=s && NR<=e {printf("%4d| %s\n", NR, $0)}' "$ORCH" \
      | cut -c1-200 | clean
  else
    echo "    （目印が見つからない）"
  fi
fi
echo '```'
echo
echo '```'
echo "  --- 受け渡しの行 ---"
grep -n 'FOLLOW_OUT_JSON' "$ORCH" 2>/dev/null | head -4 | cut -c1-160 | sed 's/^/    /' | clean
echo
echo "  --- bash の構文検査（置き換えた後の実物） ---"
if bash -n "$ORCH" 2>/dev/null; then echo "    OK"; else bash -n "$ORCH" 2>&1 | head -4 | sed 's/^/    /'; fi
echo '```'

# ═══════════ 3. いつ確かめられるか ═══════════
echo
echo "## 3. いつ確かめられるか（**rc=0 は証拠にならない**）"
echo
echo '```'
echo "  次の返信の周回: 22:00 JST（comment-warmup）"
echo "  そこで新しくフォローした相手に followers_at_follow が入る"
echo
echo "  --- いまの状態 ---"
RF="$W/data/reply-followers.json"
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows=Object.entries(j).map(([k,v])=>(v&&typeof v==="object"?{handle:k,...v}:{handle:k}));
const has=rows.filter(r=>r.followers_at_follow!==undefined);
console.log("    全体 "+rows.length+" 件 / followers_at_follow を持つ "+has.length+" 件");
const today=new Date().toISOString().slice(0,10);
console.log("    今日フォローした件数: "+rows.filter(r=>(r.followed_at||"").startsWith(today)).length+" 件");
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**JSON にキーを 2 つ 足すだけ。フォローの件数も返信の本数も変わらない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの**実績**（2026-09-13）: 1 回 \$0.003 ／ 1 日 **\$0.027** ／ 1 か月 **約 \$0.81**。"
echo "**このタスクではこの額は動かない。**"
echo
echo "> 候補を選ぶ前に広告を弾く変更は**別**。生成が 9 件/日 → 16 件/日 になり、"
echo "> 1 日 \$0.048 ／ 1 か月 **\$1.44**（増加 月 +\$0.63）。**確認を取ってから出す。**"
} > "$OUT" 2>&1

echo "orchestrator にフォロワー数を記録 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
