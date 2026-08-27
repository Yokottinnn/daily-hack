#!/bin/bash
# **返信に紹介コードが混ざるのを止める。あわせて危険なテンプレを外す。**
#
# 2026-08-25 に実際にこれが X に出ている（reports/reply-samples.md）。
#
#   Yahoo!フリマの1,000円キャンペーンに挑戦するの？いいわね！
#   紹介コード ZOAQ61 入力してPayPayポイントゲットで頑張りなさいよ💪   ← T11
#
# **X のスパムポリシー（紹介／アフィリエイトコードの無差別投稿）に直撃する。**
# 金銭の話ではなく**アカウント凍結の話**。凍結すれば 4 ループ全部が止まる。
#
# 出どころは T11 の {encouragement_phrase}。テンプレ本体は変更禁止なので、
# **壊れるのは常に穴埋め側**であり、SYSTEM プロンプトにこれを禁じる文言が無い。
#
# ## やること（それぞれ独立に失敗しても他を巻き込まない）
#
#   1. **調べる** — 差し込み位置を決めるために orchestrator と SYSTEM の末尾を出す
#   2. **危険なテンプレを外す** — T03 / T06（「あんたバカぁ？」「本気で言ってる？」を
#      他人に向ける型）。SYSTEM の「絶対に避ける」に T12/T13/T14 はあるが
#      **T03 と T06 は入っていない**。選ばれうる状態のまま置いてある
#   3. **闇バイト・詐欺の語を NG に足す** — T09 が実際に闇バイト勧誘に絡んでいた。
#      ng-filter は売春系しか見ていないので通り抜けた
#
# **2 と 3 はデータだけ触る。コードもプロンプトも書き換えない。**
# JSON として壊れたら必ず退避から戻す。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
# **plutil -extract は使わない。** LLM を呼ばない（費用 $0）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/stop-referral.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide_handle() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# 紹介コードを止める＋危険テンプレを外す（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **凍結すれば 4 ループ全部が止まる。** 金銭コストより先に効く。"

echo
echo "## 1. 差し込み位置の調査（次で出口検査を入れるため）"
echo
S="$W/scripts/comment-orchestrator.sh"
if [ -f "$S" ]; then
  echo "comment-orchestrator.sh の 100〜132 行（生成 → enqueue の間）:"
  echo '```bash'
  sed -n '100,132p' "$S" 2>/dev/null | cat -n | sed 's/^/   /' | mask | cut -c1-150
  echo '```'
else
  echo "comment-orchestrator.sh が無い"
fi

A="$W/scripts/asuka-fill.js"
if [ -f "$A" ]; then
  echo
  echo "SYSTEM プロンプトの末尾（禁止事項を足す場所）:"
  echo '```javascript'
  awk '/const SYSTEM = `/,/^`;/' "$A" 2>/dev/null | tail -25 | hide_handle | mask | cut -c1-150
  echo '```'
fi

echo
echo "## 2. 危険なテンプレを外す（T03 / T06）"
echo
T="$W/data/comment-templates.json"
if [ ! -f "$T" ]; then
  echo "**comment-templates.json が無いので触らない。**"
else
  cp "$T" "$T.pre034.$STAMP"
  echo "- 退避: $(basename "$T").pre034.$STAMP"
  "$NODE_BIN" -e "
const fs=require('fs');
const p='$T';
const raw=fs.readFileSync(p,'utf8');
let d;
try{ d=JSON.parse(raw); }catch(e){ console.log('JSON として読めないので触らない: '+e.message); process.exit(1); }
const arr=Array.isArray(d)?d:(d.list||d.templates||null);
if(!Array.isArray(arr)){ console.log('配列が見つからないので触らない'); process.exit(1); }
const before=arr.length;
const DROP=['T03','T06'];
const kept=arr.filter(x=>!DROP.includes(String(x.id)));
const removed=before-kept.length;
if(removed===0){ console.log('T03/T06 は既に無い。何もしない'); process.exit(0); }
if(kept.length<30){ console.log('残りが '+kept.length+' 件と少なすぎる。安全側に倒して触らない'); process.exit(1); }
for(const x of arr) if(DROP.includes(String(x.id)))
  console.log('  外す ['+x.id+'] '+String(x.template||'').slice(0,80));
if(Array.isArray(d)) d=kept; else if(d.list) d.list=kept; else d.templates=kept;
fs.writeFileSync(p, JSON.stringify(d,null,2));
console.log('テンプレート '+before+' → '+kept.length+' 件（'+removed+' 件 外した）');
" 2>&1 | sed 's/^/- /'
  # 書いた結果が JSON として読めなければ必ず戻す
  if ! "$NODE_BIN" -e "JSON.parse(require('fs').readFileSync('$T','utf8'))" 2>/dev/null; then
    cp "$T.pre034.$STAMP" "$T"
    echo "- **書き換え後に JSON が壊れた。退避から戻した。**"
  else
    echo "- 書き換え後の JSON: **正常**"
  fi
fi

echo
echo "## 3. 闇バイト・詐欺の語を NG に足す"
echo
echo "T09 が実際にこれらに絡んでいた。ng-filter は売春系しか見ていない。"
echo
R="$W/data/reply-ng-rules.json"
if [ ! -f "$R" ]; then
  echo "**reply-ng-rules.json が無いので触らない。**（先に 028 を通すこと）"
else
  cp "$R" "$R.pre034.$STAMP"
  echo "- 退避: $(basename "$R").pre034.$STAMP"
  "$NODE_BIN" -e "
const fs=require('fs');
const p='$R';
let d;
try{ d=JSON.parse(fs.readFileSync(p,'utf8')); }catch(e){ console.log('JSON として読めないので触らない'); process.exit(1); }
// 闇バイト・詐欺勧誘。**実際に返信していた投稿の語彙から取る**
const ADD=['闇バイト','即金','高額バイト','裏バイト','叩き','受け子','出し子',
           'ホワイト案件','簡単に稼げる','日給10万','副業紹介します','LINEで詳細',
           'マイナンバーカード 譲渡','口座譲渡','名義貸し','携帯名義','SIM譲渡',
           'アカウント売買','現金化','後払い現金化'];
d.hard_ng_words = d.hard_ng_words || {words:[]};
d.hard_ng_words.words = d.hard_ng_words.words || [];
const before=d.hard_ng_words.words.length;
for(const w of ADD) if(!d.hard_ng_words.words.includes(w)) d.hard_ng_words.words.push(w);
const after=d.hard_ng_words.words.length;
if(after===before){ console.log('全部 既に入っている。何もしない'); process.exit(0); }
fs.writeFileSync(p, JSON.stringify(d,null,2));
console.log('hard_ng_words '+before+' → '+after+' 語（'+(after-before)+' 語 追加）');
console.log('追加した語: '+ADD.filter(w=>true).join(' / '));
" 2>&1 | sed 's/^/- /'
  if ! "$NODE_BIN" -e "JSON.parse(require('fs').readFileSync('$R','utf8'))" 2>/dev/null; then
    cp "$R.pre034.$STAMP" "$R"
    echo "- **書き換え後に JSON が壊れた。退避から戻した。**"
  else
    echo "- 書き換え後の JSON: **正常**"
  fi
fi

echo
echo "## 4. 判定が壊れていないか（追加後に確かめる）"
echo
echo '```'
printf '%s' '[{"id":1,"text":"今日のポイ活の成果"},{"id":2,"text":"即金で稼げる高額バイト DMで"},{"id":3,"text":"ふるさと納税の返礼品が届いた"},{"id":4,"text":"パパ活募集"}]' \
  | "$NODE_BIN" "$W/scripts/ng-filter-candidates.cjs" > "/tmp/ng034.$$" 2>&1
cat "/tmp/ng034.$$" | head -8
echo
echo "残った件数: $("$NODE_BIN" -e 'const fs=require("fs");try{const a=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log(a.length)}catch(e){console.log("読めない")}' "/tmp/ng034.$$" 2>/dev/null)"
rm -f "/tmp/ng034.$$"
echo '```'
echo
echo "**ポイ活とふるさと納税が残り、闇バイトとパパ活が消えていれば正しい。**"

echo
echo "## 5. まだ塞げていないもの"
echo
echo "- **出口の検査はまだ無い。** 紹介コードを本文から弾く仕組みは入っていない。"
echo "  §1 で出した位置に、次の一手で `reply-tone-check.cjs` を差し込む"
echo "- T11 の {encouragement_phrase} は生きている。**SYSTEM に禁止文言を足すまで再発しうる**"
} > "$OUT" 2>&1

echo "紹介コード対策と危険テンプレ除去 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
