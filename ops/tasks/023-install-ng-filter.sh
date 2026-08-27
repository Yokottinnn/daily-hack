#!/bin/bash
# **返信 NG 判定を Mac に配る。** 種類で弾く仕組み。
#
# Jordan の指示は「売春系のアカウントに返信するな。本当に NG」。
# 個別ブロックだとイタチごっこになるので、**種類（特徴）で弾く。**
#
# ## 配るもの
#
#   data/reply-ng-rules.json   判定ルール（語・ドメイン・絵文字・構造）
#   scripts/reply-ng-check.cjs 判定モジュール
#
# ## 判定の考え方
#
#   hard    1 語で NG。売春固有の語だけ。**除外語があっても効く**
#   link    外部の出会い系・LINE 誘導リンク
#   構造    作成 30 日未満 / フォロー比 10 倍超
#   除外    ポイ活・節約・家計などを含む相手は、以降の判定を効かせない
#   soft    2 語以上で NG（一般語と紛れやすいもの）
#   emoji   3 つ以上で NG
#
# **誤って弾くより、誤って返信する方が高くつく。** 迷ったら弾く設計。
# クラウド側で 11 ケース検証済み（ポイ活が パパ活 に誤爆しないことを含む）。
#
# **このタスクは配置と自己テストだけ。既存スクリプトへの組み込みはしない。**
# どこに差し込むかは 022 の調査結果を見てから決める。推測で JS を書き換えない。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/ng-filter.md"

{
echo "# 返信 NG 判定の配置（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"

echo
echo "## 1. 配置"
ok=1
for pair in "ops/data/reply-ng-rules.json:$W/data/reply-ng-rules.json" \
            "ops/lib/reply-ng-check.cjs:$W/scripts/reply-ng-check.cjs"; do
  src="${pair%%:*}"; dst="${pair#*:}"
  if git -C "$REPO" show "origin/main:$src" > "$dst.tmp" 2>/dev/null && [ -s "$dst.tmp" ]; then
    mv "$dst.tmp" "$dst"
    echo "- $(basename "$dst"): 配置した（$(wc -c < "$dst" | tr -d ' ') B）"
  else
    rm -f "$dst.tmp"
    echo "- $(basename "$dst"): **取り出せない（origin/main に $src が無い）**"
    ok=0
  fi
done

if [ "$ok" != "1" ]; then
  echo
  echo "**配置に失敗したのでテストしない。**"
  exit 1
fi

echo
echo "## 2. 実機での自己テスト"
echo
echo '```'
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
"$NODE_BIN" -e "
const {isNg}=require('$W/scripts/reply-ng-check.cjs');
const R=require('$W/data/reply-ng-rules.json');
const cases=[
 ['売春の勧誘', {bio:'20代 パパ活してます 条件のいい方DMで'}, true],
 ['ポイ活の人（誤爆NG）', {bio:'ポイ活と節約が趣味 DM開放 詳細はプロフ'}, false],
 ['LINE誘導', {bio:'仲良くしてね', text:'https://lin.ee/x'}, true],
 ['絵文字3つ', {bio:'よろしく💋💦🍑'}, true],
 ['soft 2語', {bio:'DM開放 会いたい'}, true],
 ['soft だが節約垢', {bio:'DM開放 会いたい 節約情報'}, false],
 ['普通の節約垢', {bio:'家計簿 楽天経済圏', text:'ふるさと納税'}, false],
 ['新規垢', {bio:'こんにちは', createdAt:new Date(Date.now()-5*86400000).toISOString()}, true],
 ['無差別フォロー', {bio:'こんにちは', following:5000, followers:100}, true],
 ['援交（節約語があっても弾く）', {bio:'節約垢です 援助希望'}, true],
];
let bad=0;
for(const [n,t,want] of cases){
  const v=isNg(t,R); const good=v.ng===want; if(!good)bad++;
  console.log((good?'OK   ':'外れ ')+n+' → ng='+v.ng+' ('+v.reason+')');
}
console.log('');
console.log(bad===0 ? '全'+cases.length+'ケース 期待どおり' : bad+' 件 外れた');
" 2>&1 | head -20
echo '```'

echo
echo "## 3. ルールの規模"
"$NODE_BIN" -e "
const R=require('$W/data/reply-ng-rules.json');
console.log('- hard（1語でNG）: '+R.hard_ng_words.words.length+' 語');
console.log('- soft（'+R.soft_ng_words.threshold+'語以上でNG）: '+R.soft_ng_words.words.length+' 語');
console.log('- NGドメイン: '+R.ng_link_domains.domains.length+' 件');
console.log('- 絵文字（'+R.ng_emoji.threshold+'個以上でNG）: '+R.ng_emoji.emoji.length+' 件');
console.log('- 除外語（誤爆防止）: '+R.never_ng_words.words.length+' 語');
console.log('- 作成 '+R.structural_ng.min_account_age_days+' 日未満は返信しない');
console.log('- フォロー比 '+R.structural_ng.max_following_to_follower_ratio+' 倍超は返信しない');
" 2>&1

echo
echo "## 4. 組み込み先（まだ差し込まない）"
echo
echo "022 の調査結果を見てから決める。**推測で JS を書き換えない。**"
echo
echo "返信を打つジョブの停止状態:"
for lbl in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher \
           ai.openclaw.auto-thread-chainifier; do
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl"; then
    printf '  %-42s %s\n' "$lbl" "**まだ稼働（止まっていない）**"
  else
    printf '  %-42s %s\n' "$lbl" "停止"
  fi
done
} > "$OUT" 2>&1

echo "NG判定を配置 / $(grep -c 'OK   ' "$OUT" 2>/dev/null) ケース合格 / $(basename "$OUT")"
