#!/bin/bash
# **返信の中身をチューニングするために、実物と生成の設定を持ち帰る。**
#
# Jordan の指示: 「コメントの返し方なのだけど、ちょっとチューニングしたいかも」
#
# **どう直すかを決める前に、今どう返しているかを見る。**
# 推測で「たぶんこうなっている」と書かない。
#
# ## 持ち帰るもの
#
#   1. 直近 20 件の実際の返信文（**X に公開済みなので中身は出す**）
#   2. どの投稿に対する返信か（相手の投稿の冒頭）
#   3. 生成のシステムプロンプト（口調と方針を決めている本体）
#   4. テンプレートの一覧（families と件数、代表例）
#   5. 選び方のルール（直近の重複回避・cooldown）
#
# **相手のハンドルは出さない。** 誰に返したかは特定できないようにする。
# 返信文そのものは既に X 上で公開されているので伏せない。
# それを見ないとチューニングできない。
#
# **読むだけ。何も書き換えない。**
# **plutil -extract は使わない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-samples.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
# ハンドルだけ伏せる（@ で始まる語）。返信文は伏せない
hide_handle() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask_secret() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{28,}#<MASKED>#g'; }

{
echo "# 返信の実物と生成設定（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **相手のハンドルは伏せる。** 返信文は X 上で公開済みなので出す。"
echo "> それを見ないとチューニングできない。"

echo
echo "## 1. 直近の返信 20 件"
echo
"$NODE_BIN" -e "
const fs=require('fs'),path=require('path');
const W='$W';
function j(p){try{return JSON.parse(fs.readFileSync(path.join(W,p),'utf8'))}catch(e){return null}}
const q=j('data/post_queue.json');
if(!q){console.log('post_queue.json が読めない');process.exit(0)}
const arr=(q.queue||[]).filter(e=>e.id&&String(e.id).startsWith('comment-'));
console.log('post_queue の comment エントリ: '+arr.length+' 件');
console.log('レコードのキー: '+(arr.length?Object.keys(arr[arr.length-1]).join(', '):'なし'));
console.log('');
for(const e of arr.slice(-20)){
  const st=e.status||'(状態なし)';
  const tpl=e.template_id||'-';
  const txt=(e.text||e.body||e.content||'').replace(/\n/g,' ');
  const src=(e.source_text||e.target_text||e.parent_text||'').replace(/\n/g,' ').slice(0,70);
  console.log('---');
  console.log('  状態: '+st+'  テンプレ: '+tpl+'  '+(e.created_at||e.posted_at||''));
  if(src) console.log('  相手の投稿: '+src);
  console.log('  返信: '+txt);
}
" 2>&1 | hide_handle | mask_secret | head -90

echo
echo "## 2. 生成のシステムプロンプト（口調と方針の本体）"
echo
S="$W/scripts/asuka-fill.js"
if [ -f "$S" ]; then
  echo '```javascript'
  awk '/const SYSTEM = `/,/`;/' "$S" 2>/dev/null | hide_handle | mask_secret | head -45
  echo '```'
else
  echo "asuka-fill.js が無い"
fi

echo
echo "## 3. 生成に渡している指示（SYSTEM 以外）"
echo
if [ -f "$S" ]; then
  echo '```javascript'
  grep -nE 'USER|prompt|messages|content:|max_tokens|temperature|model' "$S" 2>/dev/null \
    | hide_handle | mask_secret | cut -c1-160 | head -25
  echo '```'
fi

echo
echo "## 4. テンプレート"
echo
"$NODE_BIN" -e "
const fs=require('fs'),path=require('path');
const W='$W';
try{
  const t=JSON.parse(fs.readFileSync(path.join(W,'data/comment-templates.json'),'utf8'));
  const arr=Array.isArray(t)?t:(t.templates||Object.values(t)[0]||[]);
  console.log('テンプレート数: '+arr.length);
  if(arr.length&&typeof arr[0]==='object') console.log('キー: '+Object.keys(arr[0]).join(', '));
  // family 別の件数
  const by={};
  for(const x of arr){const f=String(x.id||'').replace(/[0-9]+\$/,'').replace(/-.*\$/,'');by[f]=(by[f]||0)+1;}
  console.log('family 別: '+Object.entries(by).map(([k,v])=>k+'='+v).join(' '));
  console.log('');
  console.log('**全件出す。** 直すのはこの中身なので、抜粋では足りない:');
  for(const x of arr){
    console.log('  ['+(x.id||'?')+'] '+String(x.text||x.template||x.body||'').replace(/\n/g,' ').slice(0,140));
  }
}catch(e){console.log('comment-templates.json が読めない: '+e.message)}
" 2>&1 | hide_handle | head -60

echo
echo "## 5. 選び方のルール"
echo
if [ -f "$S" ]; then
  echo '```javascript'
  grep -nE 'recentFamil|RECENT_TEMPLATE_IDS|cooldown|usable|filter\(t =>|weight' "$S" 2>/dev/null \
    | mask_secret | cut -c1-160 | head -15
  echo '```'
fi

echo
echo "## 6. 相手をどう選んでいるか（トレンド検知の条件）"
echo
P="$HOME/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"
if [ -f "$P" ]; then
  echo "plist の環境変数:"
  plutil -p "$P" 2>/dev/null | awk '/EnvironmentVariables/,/^  \}/' | mask_secret | sed 's/^/    /' | head -10
fi
T="$W/scripts/trend-detect.js"
if [ -f "$T" ]; then
  echo
  echo "trend-detect.js の抽出条件:"
  echo '```javascript'
  grep -nE 'MIN_LIKES|MAX_AGE|hashtag|query|search|filter|threshold' "$T" 2>/dev/null \
    | mask_secret | cut -c1-150 | head -18
  echo '```'
fi
echo
echo "## 7. 文面は LLM が作っているのか、テンプレの穴埋めなのか"
echo
echo "**ここが分からないと直し方が変わる。**"
echo "LLM ならプロンプトを直す。テンプレなら 37 件を直す。**推測で決めない。**"
echo
for f in asuka-fill.js asuka-gen.js comment-orchestrator.sh incoming-reply-watcher.js; do
  p="$W/scripts/$f"
  [ -f "$p" ] || { echo "- $f: 無し"; continue; }
  if grep -qE "anthropic-client|require\(.*anthropic|ANTHROPIC_API_KEY|messages\.create" "$p" 2>/dev/null; then
    echo "- $f: **LLM を呼んでいる**"
    grep -nE "anthropic-client|ANTHROPIC_API_KEY|messages\.create|model:" "$p" 2>/dev/null \
      | mask_secret | cut -c1-130 | head -5 | sed 's/^/      /'
  else
    echo "- $f: LLM 呼び出しの痕跡なし（テンプレ側の可能性）"
  fi
done
echo
echo "comment-orchestrator.sh が返信文を作る箇所:"
echo '```bash'
grep -nE 'asuka|fill|draft|generate|queue' "$W/scripts/comment-orchestrator.sh" 2>/dev/null \
  | mask_secret | cut -c1-140 | head -18
echo '```'
} > "$OUT" 2>&1

echo "返信の実物と生成設定を持ち帰った / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
