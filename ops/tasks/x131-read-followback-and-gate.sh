#!/bin/bash
# **フォロー返しの実装と、判定の本体（FOLLOW_HANDLE）を読む。測るだけ。費用 $0。**
#
# ## x129 で診断が変わった
#
# `followed.json` の `source` はこうだった。
#
#   badge-followback       54 件（**直近 30 日 は 28 件。動いているのはこれだけ**）
#   cron-poikatsu-follow  129 件（直近 30 日 は **0 件**。止まっている）
#
# **`competitor-follower-follow` と `hashtag-follow` は `followed.json` に書いていない**
# （`reply-followers.json` のほう）。
#
# つまり `x128` で見た **的外れ 6 件 は、狙ってフォローした相手ではなく、
# 「向こうからフォローされたので返した」相手**だった。
#
#   【公式】LEGEND100                ← 先方が先にフォローしてきた
#   リコ📱楽天モバイル従業員紹介キャンペーン  ← 同上
#
# ## フィルタの本体も別の場所だった
#
#   execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`)
#   log(`  @${h}: ${r.ok ? "✅" : "❌ " + (r.reason || ...)}`)
#
# **2 つのスクリプトは判定を丸投げしているだけ。**
# `off-niche bio` / `low-density bio` / `random-looking handle` /
# `follower count out of range` は **`FOLLOW_HANDLE` に書かれている。**
#
# ## だから 2 つ読む
#
#   ① **`badge-followback`** — 的外れ 6 件 の出どころ。**ここが本丸**
#   ② **`FOLLOW_HANDLE`** — 判定の本体。競合・ハッシュタグの両方が通る共通の口
#
# **パスは決め打ちしない。** `FOLLOW_HANDLE` の定義行から実体を解決する。
# `x129` で「2 つのファイルに在るはず」と決め打ちして空振りした。
#
# ## やらないこと
#
# **フォローしない。外さない。1 行も書き換えない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-and-gate.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UID_N="$(id -u)"

secrets() {
  sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' \
         -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g' -e 's#(botToken[^A-Za-z0-9]{1,4})[A-Za-z0-9-]+#\1<MASKED>#g'
}
maskh() { "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(s.replace(/@([A-Za-z0-9_]{3,15})/g,(m,h)=>"@"+h.slice(0,2)+"…"));
});' 2>/dev/null || cat; }

{
echo "# フォロー返しと判定本体（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x129\` で診断が変わった。**的外れ 6 件 は「狙った相手」ではなく**"
echo "> **「向こうからフォローされたので返した相手」**だった（\`badge-followback\`）。"
echo ">"
echo "> フィルタの本体も別の場所で、2 つのスクリプトは \`FOLLOW_HANDLE\` に丸投げしていた。"
echo "> **パスは決め打ちしない。** 定義行から実体を解決する。"

echo
echo "## 1. \`FOLLOW_HANDLE\` の実体はどこか"
echo
echo '```'
GATE=""
for f in "$S/competitor-follower-follow.js" "$S/hashtag-follow.js"; do
  [ -f "$f" ] || continue
  echo "  ===== $(basename "$f") の定義行 ====="
  grep -n 'FOLLOW_HANDLE' "$f" 2>/dev/null | grep -E 'const|=' | head -3 | cut -c1-180 | sed 's/^/    /'
done
# 定義から実パスを取り出す
GATE="$("$NODE_BIN" -e '
const fs=require("fs");
for(const f of process.argv.slice(1)){
  if(!fs.existsSync(f)) continue;
  const m=fs.readFileSync(f,"utf8").match(/FOLLOW_HANDLE\s*=\s*([^;\n]+)/);
  if(!m) continue;
  // テンプレート・連結を素朴に解決する。**当てずっぽうで組み立てない**
  let e=m[1].trim().replace(/`/g,"").replace(/\$\{[^}]*SCRIPTS?[^}]*\}/g, process.env.HOME+"/.openclaw/workspace/scripts");
  const q=e.match(/["'"'"']([^"'"'"']+)["'"'"']/);
  let p=q?q[1]:e;
  if(!p.startsWith("/")) p=process.env.HOME+"/.openclaw/workspace/scripts/"+p.replace(/^\.\//,"");
  if(fs.existsSync(p)){ console.log(p); process.exit(0); }
}
' "$S/competitor-follower-follow.js" "$S/hashtag-follow.js" 2>/dev/null)"
echo
if [ -n "$GATE" ] && [ -f "$GATE" ]; then
  echo "  解決できた: $GATE（$(wc -l < "$GATE" | tr -d ' ') 行）"
else
  echo "  **定義から解決できなかった。** scripts/ で follow を含むものを挙げる:"
  ls -1 "$S" 2>/dev/null | grep -iE '^follow|follow.*\.js$' | grep -v '\.bak' | sed 's/^/    /' || echo "    （無し）"
fi
echo '```'

echo
echo "## 2. 判定の本体（**理由を返している箇所の全文**）"
echo
echo "\`x128\` のログに出ていた文言で引く。**これが実際に弾いている条件。**"
echo
echo '```javascript'
if [ -n "$GATE" ] && [ -f "$GATE" ]; then
  grep -n -B5 -A5 -E 'off-niche|low-density|random-looking|out of range|inactive|reason' "$GATE" 2>/dev/null \
    | head -170 | cut -c1-190 | sed 's/^/  /' | maskh | secrets
else
  echo "  **実体が分からないので出せない**"
fi
echo '```'
echo
echo "**\`name\`（表示名）を一度も見ていなければ、そこが穴。**"
echo
echo '```'
if [ -n "$GATE" ] && [ -f "$GATE" ]; then
  echo "  --- 表示名を触っている行 ---"
  grep -n -E 'displayName|\.name\b|UserName|screen_?name' "$GATE" 2>/dev/null | head -14 | cut -c1-180 | sed 's/^/    /' | maskh
  echo
  echo "  --- bio を触っている行 ---"
  grep -n -E 'bio|description|UserDescription' "$GATE" 2>/dev/null | head -14 | cut -c1-180 | sed 's/^/    /' | maskh
fi
echo '```'

echo
echo "## 3. フォロー返しの実装（**的外れ 6 件 の出どころ**）"
echo
echo '```javascript'
BF=""
for c in "$S/badge-followback.js" "$S/badge-follow-back.js" "$S/followback.js"; do
  [ -f "$c" ] && BF="$c" && break
done
if [ -n "$BF" ]; then
  echo "  // $BF（$(wc -l < "$BF" | tr -d ' ') 行）"
  echo "  // --- 相手を選ぶ／弾く箇所 ---"
  grep -n -B4 -A6 -E 'filter|skip|reason|follow\(|FOLLOW_HANDLE|cap|CAP' "$BF" 2>/dev/null \
    | head -150 | cut -c1-190 | sed 's/^/  /' | maskh | secrets
else
  echo "  **badge-followback の実体が見つからない。** 候補:"
  ls -1 "$S" 2>/dev/null | grep -iE 'badge|followback' | grep -v '\.bak' | sed 's/^/    /' || echo "    （無し）"
fi
echo '```'
echo
echo "**フォロー返しが \`FOLLOW_HANDLE\` を通しているかどうかが分かれ目。**"
echo "通していれば **1 か所 直すだけで両方 効く。** 通していなければ 2 か所 要る。"

echo
echo "## 4. 載っているか"
echo
echo '```'
for L in ai.openclaw.badge-followback ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  printf '  %-42s ' "$L"
  if launchctl print "gui/$UID_N/$L" 2>&1 | grep -q 'Could not find service'; then
    echo "**載っていない**"
  else
    launchctl print "gui/$UID_N/$L" 2>/dev/null \
      | awk -F'= ' '/^[[:space:]]*runs = /{r=$2} /last exit code = /{e=$2} END{print "runs="r" exit="e}'
  fi
done
echo '```'
echo
echo "**\`cron-poikatsu-follow\` は 30 日間 0 件。** 止まっているなら、そこは直さなくてよい。"

echo
echo "## 5. 直し方（**このタスクでは直さない**）"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| フォロー返しが \`FOLLOW_HANDLE\` を通す | **判定本体に名前の条件を足すだけ。** 1 か所 |"
echo "| 通さない | **フォロー返し側にも足す。** 2 か所。片方だけだと漏れる |"
echo "| 判定本体が \`name\` を見ていない | \`name\` を取る所から足す |"
echo
echo "**足す条件（案）。bio には適用しない**"
echo
echo '```'
echo "  弾く    : 名前に 【公式】 / 公式アカウント / キャンペーン / 紹介コード / アフィリ"
echo "  弾く    : 名前に 株式会社 / (株) / Inc. / Corp."
echo "  弾かない: bio の「公式」（「公式LINE」「公式ライバー」の個人で誤爆する）"
echo '```'
echo
echo "**フォロー返しを弾くのは、能動フォローを弾くより慎重に。**"
echo "向こうは既にこちらをフォローしている。**返さないと外される**ことがある。"

echo
echo "## 6. 費用"
echo
echo "**ソースと launchctl を読むだけ。LLM を呼ばない。**"
echo "**フォローの判定も DOM だけなので、条件を足しても課金は増えない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "フォロー返しと判定本体を読んだ / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
