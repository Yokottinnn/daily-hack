#!/bin/bash
# **公式・法人アカウントの名前フィルタを入れる。ただし既定は「記録だけ」。費用 $0。**
#
# ## x143 が出したこと
#
#   ✅ の実数 319 件 のうち、公式らしさの語が当たったのは **6 件（1.9%）**
#   bio 側は **「公式」2 行** だけ
#
# **これだけなら足す価値は無い。** だが x143 の §2 が同時にこう出している。
#
#   - **表示名を取っていない。** `[data-testid="UserName"]` を getProfileData に足すところから
#
# **日本語の「【公式】」「株式会社」「編集部」は handle には入らない。表示名にしか出ない。**
# つまり **1.9% は下限で、本命の母数はまだ 1 件も測れていない。**
#
# ## だから「弾かずに記録する」から入る
#
# いきなり弾くと、**根拠が無いまま供給が減る。** 直近ログは `5/30 OK` の水準しかない。
#
#   FOLLOW_NAME_FILTER=log   **既定。記録するだけでフォローは止めない**
#                     =on    実際に弾く（強い手がかりのみ）
#                     =off   何もしない
#
# **環境変数を足さなければ `log`。** plist を触らない限り挙動は変わらず、
# `data/name-filter-dryrun.jsonl` が貯まるだけ。**1 日 待てば実数が出る。**
#
# ## 直す前に確かめること（**当て推量でパッチを当てない**）
#
# x143 で実物を読んである。`follow-handle.js` は **220 行 / sha256 00840ddb…**。
# **それでも sha を証拠にしない**（9/23 以降に誰かが触っているかもしれない）。
# **目印の文字列が在るかで判定し、無ければ 1 文字も書かずに止まる。**
#
# ## 安全側
#
# - **バックアップを取ってから書く。** 投稿ではなくフォロー経路の本体である
# - **`node --check` が通らなければ元に戻す**
# - 一時ファイルに `.new` を付けない。**隠しファイル名で拡張子は `.js` のまま**（最上位ルール 14）
# - `sed -i` を使わない。**node で書いて `mv`**
# - **フォローしない。ジョブも触らない。LLM も呼ばない（$0）**
#
# ## Linux 側で先に回した結果（**Mac で確かめたことにはならない**・最上位ルール 14）
#
# `follow-handle.js` の写しを作ってパッチを通した。
#
#   パッチ適用       OK（4 箇所すべて目印が当たった）
#   node --check    OK
#   **二重適用**       FAIL already patched で止まる（意図どおり）
#   判定 8 ケース     NG 0 件
#   log / on / off   **log は返り値を変えない**（公式でも ok:true）。on だけ弾く
#
# **踏んだ穴**: 判定関数を切り出す正規表現を `^}` で止めると **`officialStrong` で切れて
# `officialWeak` が落ちる**。`ReferenceError` になる。`function officialWeak` まで含めて取る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
FH="$S/follow-handle.js"
TMPJS="$S/.x144-follow-handle.js"
PATCHER="$W/.x144-patch.js"
OUT="${OPS_REPORT_DIR:-/tmp}/name-filter-dryrun.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$FH.bak-$STAMP"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cat > "$PATCHER" <<'PATCHJS'
const fs = require("fs");
const SRC = process.argv[2];
const DST = process.argv[3];
let s = fs.readFileSync(SRC, "utf8");
const notes = [];
const fail = (m) => { console.log("FAIL " + m); process.exit(1); };

if (s.includes("FOLLOW_NAME_FILTER")) fail("already patched (FOLLOW_NAME_FILTER がもう在る)");

// --- 1. 定数と判定関数を BLACKLIST の直後に置く ---
const A1 = "const BLACKLIST = loadBlacklist();";
if (!s.includes(A1)) fail("anchor 1 not found: " + A1);
const BLOCK = `${A1}

// --- 2026-09-25 x144: 公式・法人アカウントの名前フィルタ ---
// FOLLOW_NAME_FILTER=log(既定) 記録するだけでフォローは止めない / on 弾く / off 何もしない
// **日本語の「【公式】」「株式会社」は handle に入らない。表示名にしか出ない。**
const NAME_FILTER_MODE = process.env.FOLLOW_NAME_FILTER || "log";
const NAME_FILTER_LOG = "/Users/ny/.openclaw/workspace/data/name-filter-dryrun.jsonl";

// 強い手がかり: 当たればほぼ公式・法人。on のとき弾くのはこれだけ
const OFFICIAL_NAME_RE = /[【\\[(（]\\s*公式\\s*[】\\])）]|公式(アカウント|ツイッター|ストア|通販|サイト)|株式会社|有限会社|合同会社|[(（]\\s*[株有]\\s*[)）]|Co\\.,?\\s?Ltd|Inc\\.|Corporation|編集部|広報(部|室|担当)|カスタマー(サポート|サービス)|お客様(サポート|センター)|採用(担当|情報)/i;
// 弱い手がかり: 個人でも使う。**記録はするが on でも弾かない**
const OFFICIAL_WEAK_RE = /_(jp|pr|co|inc|corp|press|staff)$/i;

function officialStrong(name, bio, h) {
  let m = (name || "").match(OFFICIAL_NAME_RE); if (m) return "name:" + m[0];
  m = (bio || "").match(OFFICIAL_NAME_RE);      if (m) return "bio:" + m[0];
  m = (h || "").match(/(^|_)official/i);         if (m) return "handle:official";
  return null;
}
function officialWeak(h) {
  const m = (h || "").match(OFFICIAL_WEAK_RE);
  return m ? "handle:" + m[0] : null;
}
`;
s = s.replace(A1, BLOCK);
notes.push("1. 定数と判定関数を入れた");

// --- 2. getProfileData の evaluate で表示名を取る ---
const A2 = 'const bio = document.querySelector(\'[data-testid="UserDescription"]\')?.textContent || "";';
if (!s.includes(A2)) fail("anchor 2 not found (UserDescription の行)");
s = s.replace(A2, A2 + `
    // 2026-09-25 x144: 表示名。**UserName は表示名と @handle が繋がって取れる**が、
    // 「【公式】」の判定にはそれで足りる
    const displayName = document.querySelector('[data-testid="UserName"]')?.textContent || "";`);
notes.push("2. 表示名の取得を足した");

// --- 3. 返り値に display_name を足す ---
const A3 = "    return {\n      bio,\n      follower_count: followerCount,";
if (!s.includes(A3)) fail("anchor 3 not found (return { bio, follower_count ...)");
s = s.replace(A3, "    return {\n      bio,\n      display_name: displayName,\n      follower_count: followerCount,");
notes.push("3. 返り値に display_name を足した");

// --- 4. passFilter の最後（通ると決まる直前）に判定を差す ---
const A4 = "  // Phase 3: just rely on common filters (already passed range + influencer + activity)\n  return { ok: true, phase };";
if (!s.includes(A4)) fail("anchor 4 not found (Phase 3 のコメントと return)");
s = s.replace(A4, `  // 2026-09-25 x144: **ここまで来たもの＝「通るはずだったもの」だけを見る。**
  // log のときは記録するだけで返り値を変えない（供給を 1 件も減らさない）
  if (NAME_FILTER_MODE !== "off") {
    const strong = officialStrong(profile.display_name, bio, handle);
    const weak = strong ? null : officialWeak(handle);
    const hit = strong || weak;
    if (hit) {
      try {
        fs.appendFileSync(NAME_FILTER_LOG, JSON.stringify({
          ts: new Date().toISOString(),
          handle,
          hit,
          strength: strong ? "strong" : "weak",
          name: profile.display_name || "",
          follower_count, following_count: followingCount,
          mode: NAME_FILTER_MODE,
          acted: NAME_FILTER_MODE === "on" && !!strong,
        }) + "\\n");
      } catch (e) { /* 記録に失敗してもフォローは止めない */ }
      if (NAME_FILTER_MODE === "on" && strong) {
        return { ok: false, reason: \`official/corporate account (\${strong})\`, phase };
      }
    }
  }

  // Phase 3: just rely on common filters (already passed range + influencer + activity)
  return { ok: true, phase };`);
notes.push("4. passFilter の末尾に判定を差した");

fs.writeFileSync(DST, s);
console.log("OK " + notes.join(" / "));
PATCHJS

{
echo "# 公式アカウントの名前フィルタを入れる（記録モード）（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **既定は \`log\`。記録するだけでフォローは止めない。** 環境変数を足さない限り挙動は変わらない。"

echo
echo "## 0. 当てる前の状態"
echo
if [ ! -f "$FH" ]; then
  echo "- **無い: \`$FH\`。ここで止まる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'
printf '  行数    : %s\n' "$(wc -l < "$FH" | tr -d ' ')"
printf '  更新     : %s\n' "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$FH" 2>/dev/null)"
printf '  sha256  : %s\n' "$(shasum -a 256 "$FH" 2>/dev/null | awk '{print $1}')"
echo '```'
echo
echo "> x143 の時点は \`220 行 / 00840ddb…\`。**違っても sha では止めない。**"
echo "> **目印の文字列が在るかで判定する**（無ければ 1 文字も書かずに止まる）。"

echo
echo "## 1. バックアップ"
echo
cp -p "$FH" "$BAK" 2>/dev/null
if [ -f "$BAK" ]; then
  echo '```'
  printf '  %s  (%s bytes)\n' "$(basename "$BAK")" "$(wc -c < "$BAK" | tr -d ' ')"
  echo '```'
else
  echo "- **バックアップが取れなかった。ここで止まる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 2. パッチを当てる（**目印が 1 つでも無ければ止まる**）"
echo
echo '```'
PRES="$(node "$PATCHER" "$FH" "$TMPJS" 2>&1)"
PRC=$?
printf '%s\n' "$PRES" | clean | sed 's/^/  /'
printf '  rc=%s\n' "$PRC"
echo '```'
if [ "$PRC" -ne 0 ] || [ ! -f "$TMPJS" ]; then
  echo
  echo "- **当てていない。元のファイルは 1 文字も変わっていない。**"
  rm -f "$TMPJS" "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 3. \`node --check\`（**通らなければ元に戻す**）"
echo
echo '```'
CHK="$(node --check "$TMPJS" 2>&1)"
CRC=$?
printf '  rc=%s\n' "$CRC"
[ -n "$CHK" ] && printf '%s\n' "$CHK" | clean | sed 's/^/  /'
echo '```'
if [ "$CRC" -ne 0 ]; then
  echo
  echo "- **構文が通らない。当てずに終わる。元のファイルはそのまま。**"
  rm -f "$TMPJS" "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

mv "$TMPJS" "$FH"
rm -f "$PATCHER"

echo
echo "## 4. 当てたあと"
echo
echo '```'
printf '  行数    : %s\n' "$(wc -l < "$FH" | tr -d ' ')"
printf '  sha256  : %s\n' "$(shasum -a 256 "$FH" 2>/dev/null | awk '{print $1}')"
printf '  差分    : +%s 行\n' "$(( $(wc -l < "$FH" | tr -d ' ') - $(wc -l < "$BAK" | tr -d ' ') ))"
echo '```'
echo
echo "入った箇所（**行番号だけ。中身は §5 の動作確認で見る**）:"
echo
echo '```'
grep -n "NAME_FILTER_MODE\|OFFICIAL_NAME_RE\|OFFICIAL_WEAK_RE\|display_name\|officialStrong\|officialWeak" "$FH" 2>/dev/null | clean | sed 's/^/  /'
echo '```'

echo
echo "## 5. 動作確認（**rc=0 は証拠にならない**・最上位ルール 13）"
echo
echo "判定関数だけを切り出して、**当たるはずのものと当たらないはずのもの**を通す。"
echo "**X には 1 回も触らない。フォローもしない。**"
echo
echo '```'
node -e '
const fs=require("fs");
const src=fs.readFileSync(process.argv[1],"utf8");
// **`^}` で止めると officialStrong で切れて officialWeak が落ちる**（Linux で踏んだ）
const m=src.match(/const OFFICIAL_NAME_RE[\s\S]*?\nfunction officialWeak[\s\S]*?\n}/);
if(!m){console.log("  判定関数を切り出せない");process.exit(0);}
const fn=new Function("return (function(){"+m[0]+"\nreturn {officialStrong,officialWeak};})()")();
const cases=[
 ["【公式】セブン-イレブン・ジャパン","","seven_eleven_japan","当たる"],
 ["株式会社はっか堂","","hakkado","当たる"],
 ["節約主婦のブログ編集部","","setsuyaku_blog","当たる"],
 ["ポイ活あかり","公式アカウントをフォローしてます","akari_poi","当たる(bio)"],
 ["Daily Hack Official","","dailyhack_official","当たる(handle)"],
 ["ゆうき","節約とポイ活。二児の母","yuki_kakei","当たらない"],
 ["ミニマリストの家計簿","貯金1000万円めざす","minimal_kakei","当たらない"],
 ["たろう","ふるさと納税マニア","taro_jp","弱い(記録のみ)"],
];
let ng=0;
for(const [name,bio,h,want] of cases){
  const s=fn.officialStrong(name,bio,h), w=s?null:fn.officialWeak(h);
  const got=s?("strong "+s):(w?("weak "+w):"(なし)");
  const ok = want.startsWith("当たる")? !!s : (want.startsWith("弱い")? (!s&&!!w) : (!s&&!w));
  if(!ok)ng++;
  console.log("  "+(ok?"OK ":"NG ")+want+" -> "+got);
}
console.log("  ---");
console.log("  NG "+ng+" 件");
' "$FH" 2>&1 | clean
echo '```'

echo
echo "## 6. いまの挙動"
echo
echo "| \`FOLLOW_NAME_FILTER\` | 何が起きるか |"
echo "| --- | --- |"
echo "| **未設定（＝いま）** | \`log\`。**当たったものを \`data/name-filter-dryrun.jsonl\` に書くだけ。フォローは止めない** |"
echo "| \`on\` | 強い手がかりに当たったものを弾く。**弱い手がかり（\`_jp\` 等）は on でも弾かない** |"
echo "| \`off\` | 何もしない（記録もしない） |"
echo
echo "**plist を触っていないので、いまは \`log\` で動く。** 1 日 貯めれば"
echo "**表示名まで含めた実数**が出る。そこを見てから \`on\` にするかを決める。"
echo
echo "戻すとき:"
echo
echo '```bash'
echo "  cp -p \"$BAK\" \"$FH\""
echo '```'
echo
echo "## 7. 費用"
echo
echo "**ファイルを書き換えて構文を検査しただけ。LLM を呼んでいない。**"
echo "**フォロー自体も DOM 操作のみで LLM を呼ばない**ので、この変更で課金は増えない。"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'NG 0 件' "$OUT" 2>/dev/null; then
  echo "名前フィルタを記録モードで入れた（テスト全通過） / $(basename "$OUT")"
else
  echo "**入っていないか、テストに落ちた。レポートを確認すること** / $(basename "$OUT")"
fi
