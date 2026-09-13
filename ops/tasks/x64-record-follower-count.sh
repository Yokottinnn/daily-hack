#!/bin/bash
# **フォローした瞬間にフォロワー数を記録する。費用 $0（LLM 不使用）。**
#
# ## x63 で答えが出ている（2026-09-13 19:54 実測）
#
# `follow-handle.js` は **成功時に `profile` を返している。**
#
#   // follow-handle.js:208
#   console.log(JSON.stringify({ ok: true, status: "followed", profile }));
#   // profile = { bio, follower_count, following_count, last_post_age_days }
#
# 呼び出し側は `r` を受け取っていながら、**3 つしか書いていない。**
#
#   rf[h] = {
#     followed_at: new Date().toISOString(),
#     followback_status: "pending",
#     source: `competitor-follower:${competitor}`,
#   };
#
# **数字は手元に在るのに捨てている。** 足せば帯ごとの返し率が出せる。
#
# ## 足すもの（**3 つだけ**）
#
#   followers_at_follow   フォローした時点の相手のフォロワー数
#   following_at_follow   同・フォロー数（比率を後から出せる）
#   phase_at_follow       follow-handle が判定した Phase（1/2/3）
#
# **既存のキーは 1 つも触らない。** 足すだけ。
#
# ## なぜ帯が要るのか
#
# 上限 50000 は **2026-05-25 に決めたまま検証されていない。**
# 388 件 の大型アカウントがこれで弾かれているが、
# **その帯が本当に返してくれないのかを裏付けるデータが無い。**
#
# ## やらないこと
#
# **しきい値を変えない。上限を触らない。フォローしない。LLM を呼ばない（$0）。**
# **`timeout` を使わない**（ルール 14）。一時ファイルは `.js` のまま。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/record-follower-count.md"
NODE_BIN="/usr/local/bin/node"
PATCH="$S/.x64-record-follower-count.js"   # **拡張子は .js のまま**（ルール 14）
STAMP="$(date '+%Y%m%d-%H%M%S')"
trap 'rm -f "$PATCH" "$S"/*.x64-new.js' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

cat > "$PATCH" <<'JSEOF'
const fs = require("fs");

// **「followback_status: "pending"," の行の直後」に 3 行 入れる。**
// 行頭の空白は元の行から写す（インデントを壊さない）
const MARK = /^([ \t]*)followback_status: *"pending",[ \t]*$/m;

const out = [];
for (const p of process.argv.slice(2)) {
  const name = p.split("/").pop();
  if (!fs.existsSync(p)) { out.push([name, "無い", 0]); continue; }
  const src = fs.readFileSync(p, "utf8");

  if (src.includes("followers_at_follow")) { out.push([name, "既に入っている", 0]); continue; }

  const hits = src.match(new RegExp(MARK.source, "gm")) || [];
  if (hits.length !== 1) { out.push([name, `目印が ${hits.length} 箇所（1 でないので当てない）`, 0]); continue; }

  const patched = src.replace(MARK, (line, indent) =>
    line + "\n" +
    indent + "followers_at_follow: (r.profile && typeof r.profile.follower_count === \"number\") ? r.profile.follower_count : null,\n" +
    indent + "following_at_follow: (r.profile && typeof r.profile.following_count === \"number\") ? r.profile.following_count : null,\n" +
    indent + "phase_at_follow: (typeof r.phase === \"number\") ? r.phase : null,"
  );

  fs.writeFileSync(p + ".x64-new.js", patched);   // **拡張子を .js に保つ**
  out.push([name, "当てた（検査待ち）", 1]);
}
for (const [n, s] of out) console.log("  " + n.padEnd(32) + " : " + s);
JSEOF

{
echo "# フォローした瞬間にフォロワー数を記録する"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x63 の実測: \`follow-handle.js\` は成功時に \`profile\` を返している。"
echo "> \`profile = { bio, follower_count, following_count, last_post_age_days }\`"
echo ">"
echo "> **数字は手元に在るのに、呼び出し側が捨てていた。**"
echo
echo "**しきい値は触らない。足すだけ。**"

# ═══════════ 0. 当てる前 ═══════════
echo
echo "## 0. 当てる前"
echo
echo '```'
for f in competitor-follower-follow.js hashtag-follow.js; do
  P="$S/$f"
  if [ ! -f "$P" ]; then echo "  $f: **無い**"; continue; fi
  printf '  %-32s %4s 行 / %s\n' "$f" "$(wc -l < "$P" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  grep -c 'followers_at_follow' "$P" 2>/dev/null | sed 's/^/    既に入っている箇所: /'
done
echo '```'

# ═══════════ 1. 当てる ═══════════
echo
echo "## 1. 足す 3 つ"
echo
echo "| キー | 中身 |"
echo "| --- | --- |"
echo "| \`followers_at_follow\` | フォローした時点の相手のフォロワー数 |"
echo "| \`following_at_follow\` | 同・フォロー数（比率を後から出せる） |"
echo "| \`phase_at_follow\` | \`follow-handle\` が判定した Phase（1/2/3） |"
echo
echo '```'
if ! "$NODE_BIN" --check "$PATCH" 2>/dev/null; then
  echo "  **パッチが構文エラー。当てない。**"
  "$NODE_BIN" --check "$PATCH" 2>&1 | head -5 | sed 's/^/    /'
else
  "$NODE_BIN" "$PATCH" "$S/competitor-follower-follow.js" "$S/hashtag-follow.js" 2>&1 | clean

  echo
  echo "  --- 検査して置き換える（**構文が通ったものだけ**） ---"
  for f in competitor-follower-follow.js hashtag-follow.js; do
    P="$S/$f"; N="$P.x64-new.js"
    [ -f "$N" ] || continue
    if "$NODE_BIN" --check "$N" 2>/dev/null; then
      cp "$P" "$P.bak-$STAMP"
      mv "$N" "$P"
      echo "    $f: **置き換えた**（退避 $f.bak-$STAMP）"
    else
      echo "    $f: **構文エラー。置き換えない**"
      "$NODE_BIN" --check "$N" 2>&1 | head -4 | sed 's/^/      /'
      rm -f "$N"
    fi
  done
fi
echo '```'

# ═══════════ 2. 当てた後（実物を見る） ═══════════
echo
echo "## 2. 当てた後（**実物**）"
echo
echo '```javascript'
for f in competitor-follower-follow.js hashtag-follow.js; do
  P="$S/$f"; [ -f "$P" ] || continue
  echo "// ══ $f"
  N="$(grep -n 'followback_status' "$P" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -n "$N" ]; then
    awk -v s="$((N - 3))" -v e="$((N + 6))" 'NR>=s && NR<=e {printf("%4d| %s\n", NR, $0)}' "$P" \
      | cut -c1-180 | clean
  else
    echo "    （目印が見つからない）"
  fi
  echo
done
echo '```'
echo
echo "**\`phase_at_follow\` は \`null\` になる見込み。** 成功時の戻り値は"
echo "\`{ ok: true, status: \"followed\", profile }\` で **phase を含まない**（x63 実測・208 行目）。"
echo "**Phase は \`followers_at_follow\` から後で引ける**（100 未満 = 1 / 300 未満 = 2 / それ以上 = 3）ので、"
echo "**ここでは follow-handle 側を触らない。** 触る必要が出たら別タスクにする。"

# ═══════════ 3. いつ数字が溜まるか ═══════════
echo
echo "## 3. いつ使えるようになるか"
echo
echo "**過去のフォローには遡って入らない。** 次にフォローした分から溜まる。"
echo
echo '```'
echo "  --- 直近 7 日 のフォロー実績（reply-followers.json の followed_at） ---"
RF="$W/data/reply-followers.json"
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows=Array.isArray(j)?j:Object.entries(j).map(([k,v])=>(v&&typeof v==="object"?{handle:k,...v}:{handle:k}));
const d={};
for(const r of rows){const t=(r.followed_at||"").slice(0,10); if(t) d[t]=(d[t]||0)+1;}
const ks=Object.keys(d).sort().slice(-7);
for(const k of ks) console.log("    "+k+"  "+String(d[k]).padStart(3)+" 件");
const sum=ks.reduce((a,k)=>a+d[k],0);
console.log("");
console.log("    直近 7 日 の合計: "+sum+" 件（1 日 平均 "+(sum/7).toFixed(1)+" 件）");
console.log("    → 帯ごとに比べられる量（各帯 20 件 以上）になるのは、この速度なら数週間 先。");
' "$RF" 2>&1 | clean
else
  echo "  **$RF が無い。**"
fi
echo '```'
echo
echo "**上限 50000 の妥当性は、すぐには判定できない。**"
echo "数字が溜まるまでは**しきい値を触らない。** 触ると、何が効いたか分からなくなる。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**JSON に 3 つ キーを足すだけ。LLM を呼ばない。フォロー数も増やさない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "参考（**推定**・前提: Haiku 4.5・生成 64 回/日）: 定時の返信ループは"
echo "1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8。"
echo "**今日の実測の通過率は 56%**（picked 16 / enqueue 9）。"
} > "$OUT" 2>&1

echo "フォロワー数を記録する / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
