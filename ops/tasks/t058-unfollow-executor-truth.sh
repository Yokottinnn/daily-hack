#!/bin/bash
# **アンフォローを実際に「外す」のはどれかを特定する。費用 $0。**
#
# ## 何が起きているか（t056 の実測）
#
#   reply-followers.json  総数 303 件
#     no          207 件   ← フォロバ無しと判定済み
#     unfollowed   16 件
#   **アンフォロー予約あり 207 件（うち期限到来 196 件）**
#
# **判定側は動いている**（`reply-followback-check` は本日 13:15 に更新）。
# **外す側が動いていない。** 196 件が期限を過ぎたまま残っている。
#
# 同時にフォローは今日 16 件 増えている。**入れるだけで出さない状態**が続くと
# フォロー／フォロワー比が悪化する。**ここが 3 系統でいちばん悪い。**
#
# ## 分かっていること（t046 / t047）
#
#   * 6 本の plist は **中身が XML ではなく JSON**（`plutil -lint` が
#     `Unexpected character {`・87〜126 B）。だから `Bootstrap failed: 5`
#   * 古いアンフォロー系スクリプトは **CDP 18800** を見ている（正しくは **18810**）
#
# ## まだ分かっていないこと（**これを埋めるのがこのタスク**）
#
#   1. **`scheduled_unfollow_at` を読んで実際に外すのはどのスクリプトか。**
#      `reply-followback-check.js` は**予約するだけ**。実行役は別にいる
#   2. 6 本の plist の**中身の実物**（JSON なら、何を書こうとしたのかが読める）
#   3. **生きている plist の実物**（作り直すときの雛形になる）
#   4. 実行役スクリプトが見ている **CDP のポート**
#
# ## やらないこと
#
# **アンフォローしない。フォローしない。投稿しない。**
# **ジョブを触らない（load も unload もしない）。書き換えない。LLM を呼ばない。**
#
# **ハンドルは伏せる。秘密だけマスクする。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/unfollow-executor-truth.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LA="$HOME/Library/LaunchAgents"
BROKEN="follow-watchdog unfollow-daily unfollow-evening unfollow-cleanup-morning unfollow-cleanup-evening revenge-unfollow"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
         -e 's#(API_KEY[=:"[:space:]]+)[A-Za-z0-9_-]{12,}#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# アンフォローの実行役はどれか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **判定側は動いている。外す側が動いていない。**"
echo "> 予約 207 件のうち **196 件が期限を過ぎたまま残っている。**"
echo "> 同時にフォローは今日 16 件 増えている。**入れるだけで出さない状態。**"
echo "> **何も触らない。読むだけ。**"

echo
echo "## 1. \`scheduled_unfollow_at\` を読むのはどのスクリプトか"
echo
echo "**\`reply-followback-check.js\` は予約するだけ。実行役は別にいる。**"
echo
echo '```'
grep -rln 'scheduled_unfollow_at' "$S" 2>/dev/null | while read -r f; do
  b="$(basename "$f")"
  case "$b" in *.bak.*) continue ;; esac
  printf '  %-42s %6s B  更新 %s\n' "$b" "$(wc -c < "$f" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo '```'
echo
echo "### そのうち「外す」動作を持つもの（\`unfollow\` を呼んでいる）"
echo
echo '```'
grep -rln 'scheduled_unfollow_at' "$S" 2>/dev/null | while read -r f; do
  b="$(basename "$f")"
  case "$b" in *.bak.*) continue ;; esac
  n="$(grep -cE 'unfollowUser|clickUnfollow|do_unfollow|unfollow\(' "$f" 2>/dev/null || echo 0)"
  [ "$n" -gt 0 ] && printf '  %-42s unfollow 呼び出し %s 箇所\n' "$b" "$n"
done
echo '```'

echo
echo "### 実行役の候補を全文で読む"
echo
for f in "$S"/*unfollow*.js "$S"/*unfollow*.cjs; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  case "$b" in *.bak.*) continue ;; esac
  grep -q 'scheduled_unfollow_at' "$f" 2>/dev/null || continue
  echo "#### \`$b\`（$(wc -l < "$f" | tr -d ' ') 行）"
  echo
  echo '```javascript'
  cat -n "$f" 2>/dev/null | head -120 | clean
  echo '```'
  echo
done

echo
echo "## 2. どのスクリプトが どの CDP ポートを見ているか"
echo
echo "**18810 が正しい**（\`ensure-chrome.sh:PORT\`）。**18800 は存在しない。**"
echo
echo '```'
grep -rhoE '127\.0\.0\.1:[0-9]{4,5}|localhost:[0-9]{4,5}|CHROME_CDP_URL[^"]*"[^"]*"' "$S"/*.js "$S"/*.cjs "$S"/*.sh 2>/dev/null \
  | grep -oE '[0-9]{4,5}' | sort | uniq -c | sort -rn | sed 's/^/  /'
echo ""
echo "  ポート別の内訳:"
for port in 18810 18800 9222; do
  echo "    :$port を見ているファイル"
  grep -rl "$port" "$S"/*.js "$S"/*.cjs "$S"/*.sh 2>/dev/null | while read -r f; do
    b="$(basename "$f")"; case "$b" in *.bak.*) continue ;; esac
    echo "      $b"
  done
done
echo '```'

echo
echo "## 3. 壊れている 6 本の plist の中身（**実物**）"
echo
echo "\`plutil -lint\` が \`Unexpected character {\` と言う＝**XML ではなく JSON**。"
echo "何を書こうとしたのかが読めれば、**正しい XML に起こし直せる。**"
echo
for j in $BROKEN; do
  P="$LA/ai.openclaw.$j.plist"
  echo "### \`$j\`"
  echo
  if [ ! -f "$P" ]; then echo "- **ファイルが無い**"; echo; continue; fi
  echo "- $(wc -c < "$P" | tr -d ' ') B / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  echo "- \`plutil -lint\`: $(plutil -lint "$P" 2>&1 | tail -1 | clean)"
  echo
  echo '```'
  cat "$P" 2>/dev/null | head -30 | clean
  echo '```'
  echo
done

echo
echo "## 4. 生きている plist（**作り直しの雛形**）"
echo
echo "同じ系統で**実際にロードできているもの**を雛形にする。当て推量で書かない。"
echo
for j in reply-followback-check auto-detect-and-unfollow-inactive badge-followback; do
  P="$LA/ai.openclaw.$j.plist"
  [ -f "$P" ] || continue
  echo "### \`$j\`（$(wc -c < "$P" | tr -d ' ') B・lint $(plutil -lint "$P" 2>&1 | grep -o 'OK' || echo NG)）"
  echo
  echo '```xml'
  cat "$P" 2>/dev/null | clean
  echo '```'
  echo
done

echo
echo "## 5. 期限が来ている 196 件の内訳（**どれくらい古いか**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
if(!fs.existsSync(p)){ console.log("  reply-followers.json が無い"); process.exit(0); }
let s; try{ s=JSON.parse(fs.readFileSync(p,"utf8")); }catch(e){ console.log("  読めない"); process.exit(0); }
const now=Date.now(); const buckets={};
let due=0, oldest=null;
for(const [h,e] of Object.entries(s)){
  if(!e||!e.scheduled_unfollow_at) continue;
  const t=new Date(e.scheduled_unfollow_at).getTime();
  if(!(t<=now)) continue;
  due++;
  const days=Math.floor((now-t)/86400000);
  const b=days<1?"0日":days<3?"1〜2日":days<7?"3〜6日":days<14?"7〜13日":days<30?"14〜29日":"30日以上";
  buckets[b]=(buckets[b]||0)+1;
  if(oldest===null||t<oldest) oldest=t;
}
console.log("  期限到来: "+due+" 件");
["0日","1〜2日","3〜6日","7〜13日","14〜29日","30日以上"].forEach(k=>{
  if(buckets[k]) console.log("    "+k.padEnd(10)+buckets[k]+" 件 放置");
});
if(oldest) console.log("  いちばん古い期限: "+new Date(oldest).toISOString().slice(0,10));
' "$W/data/reply-followers.json" 2>&1 | clean
echo '```'
echo
echo "**古いものほど、フォロバが無いまま長くフォローし続けている。**"

echo
echo "---"
echo
echo "**何も触っていない。アンフォローもフォローもしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**アンフォローの実行役を特定した（変更なし・\$0）** / $(basename "$OUT")"
