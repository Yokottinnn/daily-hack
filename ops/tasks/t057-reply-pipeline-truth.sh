#!/bin/bash
# **返信の配管を、実物で 1 回で全部 読む。費用 $0。**
#
# ## なぜ「読む」から始めるか
#
# 返信は `comment-warmup` が未ロードで止まっている。だが**戻すだけでは直らない。**
# 9/2 に「テンプレの当てはめ」から「全文生成」へ替える作業を途中でやめており、
# **どこまで配線されたかを私は知らない。**
#
# 知らないまま `launchctl load` すると、**古い経路で返信が出る。**
# それは 2026-09-02 に『トンチンカン』『AI が自動で返信しているのがバレバレ』と
# 言われた状態に戻すということ。**戻すより悪い。**
#
# ## 出すもの（すべて $0・LLM を呼ばない）
#
#   1. **`comment-orchestrator.sh` の全文**（どの生成器を叩いているか）
#   2. **新しい部品が入っているか**（`asuka-reply.cjs` / `reply-relevance-check.cjs` /
#      `tone-gate.cjs` / `ng-filter-candidates.cjs` / `reply-style-prompt.json`）
#   3. **`comment-warmup` の plist**（間隔・環境変数・1 回あたりの件数）
#   4. **`auto-reply.js` の投稿口**（承認が要るのか、即 出るのか）
#   5. 返信系ログの最終更新と末尾
#   6. キューの `comment` / `reply` の状態内訳
#
# ## やらないこと
#
# **返信しない。投稿しない。ジョブを触らない（load も unload もしない）。**
# **書き換えない。LLM を呼ばない。**
#
# **ハンドルは伏せる。秘密だけマスクする（無差別マスクは本文ごと潰す）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-pipeline-truth.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LA="$HOME/Library/LaunchAgents"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
         -e 's#(API_KEY[=:"[:space:]]+)[A-Za-z0-9_-]{12,}#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# 返信の配管を実物で読む（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **戻すだけでは直らない。** 9/2 に「テンプレ当てはめ → 全文生成」の"
echo "> 差し替えを途中でやめており、**どこまで配線されたかが分かっていない。**"
echo "> 知らないまま load すると**古い経路で返信が出る。**それは"
echo "> 『トンチンカン』『AI が自動で返信しているのがバレバレ』の状態に戻すということ。"
echo "> **返信しない。投稿しない。ジョブを触らない。LLM も呼ばない。**"

echo
echo "## 1. 新しい部品は入っているか"
echo
echo '```'
for f in asuka-reply.cjs reply-relevance-check.cjs tone-gate.cjs \
         ng-filter-candidates.cjs reply-ng-check.cjs reply-tone-check.cjs \
         asuka-fill.js comment-orchestrator.sh auto-reply.js anthropic-client.js; do
  p="$S/$f"
  if [ -f "$p" ]; then
    printf '  有り  %-30s %6s B  更新 %s\n' "$f" "$(wc -c < "$p" | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$p" 2>/dev/null)"
  else
    printf '  **無し** %-27s\n' "$f"
  fi
done
echo ""
echo "  データ:"
for f in reply-style-prompt.json reply-relevance-rules.json reply-ng-rules.json \
         reply-tone-rules.json comment-templates.json; do
  p="$W/data/$f"
  if [ -f "$p" ]; then
    printf '  有り  %-30s %6s B  更新 %s\n' "$f" "$(wc -c < "$p" | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$p" 2>/dev/null)"
  else
    printf '  **無し** %-27s\n' "$f"
  fi
done
echo '```'
echo
echo "**\`asuka-reply.cjs\` が無ければ、全文生成はまだ Mac に届いていない。**"

echo
echo "## 2. \`comment-orchestrator.sh\` の全文"
echo
echo "**どの生成器を叩いているかがここで決まる。**"
echo
if [ -f "$S/comment-orchestrator.sh" ]; then
  echo '```bash'
  cat -n "$S/comment-orchestrator.sh" 2>/dev/null | clean
  echo '```'
else
  echo "- **無い**（\`$S/comment-orchestrator.sh\`）"
fi

echo
echo "### 生成器の呼び出し箇所だけ抜き出す"
echo
echo '```'
grep -nE 'asuka-fill|asuka-reply|asuka-gen|tone-gate|ng-filter|relevance|GEN_OK|generator' \
  "$S/comment-orchestrator.sh" 2>/dev/null | clean
echo '```'

echo
echo "## 3. \`comment-warmup\` の plist"
echo
P="$LA/ai.openclaw.comment-warmup.plist"
if [ -f "$P" ]; then
  echo "- 更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null) / $(wc -c < "$P" | tr -d ' ') B"
  echo "- \`plutil -lint\`: $(plutil -lint "$P" 2>&1 | tail -1)"
  echo
  echo '```xml'
  cat "$P" 2>/dev/null | clean
  echo '```'
else
  echo "- **plist が無い**（\`$P\`）"
fi
echo
echo "- \`launchctl list\`: $(launchctl list 2>/dev/null | grep -F 'comment-warmup' || echo '**未ロード**')"

echo
echo "## 4. \`auto-reply.js\` の投稿口（**承認が要るのか**）"
echo
echo '```'
grep -nE 'awaiting_approval|NO_APPROVAL|status|enqueue|post-comment|approve|DRY_RUN|MAX_|CAP' \
  "$S/auto-reply.js" 2>/dev/null | head -30 | clean
echo '```'

echo
echo "## 5. 返信系ログ"
echo
echo '```'
for n in comment-warmup comment-warmup-err comment-orchestrator \
         incoming-reply-watcher auto-reply; do
  f="$W/logs/$n.log"
  if [ -f "$f" ]; then
    printf '  %-28s %s  (%s 行)\n' "$n" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)" "$(wc -l < "$f" | tr -d ' ')"
  else
    printf '  %-28s （ログ無し）\n' "$n"
  fi
done
echo '```'
echo
for n in comment-warmup comment-orchestrator; do
  f="$W/logs/$n.log"
  [ -f "$f" ] || continue
  echo "### \`$n.log\` の末尾"
  echo
  echo '```'
  tail -20 "$f" 2>/dev/null | clean
  echo '```'
  echo
done

echo
echo "## 6. キューの \`comment\` / \`reply\`"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
if(!fs.existsSync(p)){ console.log("  post_queue.json が無い"); process.exit(0); }
let q; try{ q=JSON.parse(fs.readFileSync(p,"utf8")); }catch(e){ console.log("  読めない"); process.exit(0); }
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply"));
console.log("  comment / reply: "+rows.length+" 件");
const by={}, days={};
for(const e of rows){
  by[e.status||"(なし)"]=(by[e.status||"(なし)"]||0)+1;
  const d=String(e.posted_at||e.created_at||"").slice(0,10);
  if(/^\d{4}-/.test(d)) days[d]=(days[d]||0)+1;
}
Object.entries(by).sort((a,b)=>b[1]-a[1]).forEach(([k,v])=>console.log("    "+String(k).padEnd(20)+v+" 件"));
console.log("  日別（直近 10 日）:");
const ds=Object.entries(days).sort((a,b)=>b[0].localeCompare(a[0])).slice(0,10);
if(!ds.length) console.log("    （日付つきの記録が無い）");
ds.forEach(([k,v])=>console.log("    "+k+"  "+v+" 件"));
const last=rows.filter(e=>e.posted_at).sort((a,b)=>String(b.posted_at).localeCompare(String(a.posted_at)))[0];
console.log("  最後に出た返信: "+(last?last.posted_at:"（無い）"));
' "$W/data/post_queue.json" 2>&1 | clean
echo '```'

echo
echo "---"
echo
echo "**何も触っていない。返信も投稿もしていない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**返信の配管を実物で読んだ（変更なし・\$0）** / $(basename "$OUT")"
