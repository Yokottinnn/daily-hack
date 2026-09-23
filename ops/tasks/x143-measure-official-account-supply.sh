#!/bin/bash
# **フォロー先に「公式アカウント」がどれだけ混ざっているかを測る。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# `follow-handle.js` の絞り（`reports/follow-handle.md` の写し）には、
# **相手が「人」か「会社・店・公式」かを見る判定が 1 つも無い。**
#
#   follower 数の範囲 ／ ratio<0.3 ／ blacklist ／ ランダム handle ／
#   off-niche bio ／ 低密度 bio ／ 30 日 無投稿 ／ phase 別のキーワード
#
# **公式アカウントはフォロバを返さない。** それでいて bio は情報密度が高く、
# 「節約」「お得」「ポイント」が普通に入るので **phase 2 も phase 3 も素通りする。**
#
# ## だが、まだ足さない
#
# **直す前に測る**（最上位ルール 15）。理由は 2 つ。
#
# 1. **実ファイルが写しと違う。** ログの拒否理由は `need 10-50000` だが、
#    9/05 の写しは `10000` 上限だった。**誰かが上限を変えている。**
#    写しを前提にパッチを書くと、当たらないか、別の変更を潰す
# 2. **供給に余裕が無い。** 直近ログは `5/30 OK` と `1/4 OK`。
#    絞りを足せば、その分 フォロー数が落ちる。**落ちる量を知らずに足さない**
#
# ## 何を出すか
#
#   ① `follow-handle.js` の **いまの** sha256・行数・更新時刻（写しとの差）
#   ② **表示名を取っているか**（`getProfileData` の中）。取っていなければ
#      名前フィルタは「取る」ところから作ることになる
#   ③ 実ファイルの `passFilter` 全文（**これが土台。推測しない**）
#   ④ 直近ログの **拒否理由の内訳**（何が何件 弾いているか＝余力）
#   ⑤ **通った handle に「公式らしさ」の語が何件 当たるか**（強い手がかり／弱い手がかり）
#
# ## やらないこと
#
# **フォローしない。1 文字も書き換えない。ジョブも触らない。LLM も呼ばない（$0）。**
#
# 出力は公開リポジトリに載る。**handle は出さない。** 当たった語と件数だけ出す。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
D="$W/data"
FH="$S/follow-handle.js"
OUT="${OPS_REPORT_DIR:-/tmp}/official-account-supply.md"
TMP="$W/.x143-work"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xoxb-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
         -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

# **grep -c は 0 件でも 0 を出して rc=1 を返す。`|| echo 0` を付けない**（最上位ルール 13）
cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

mkdir -p "$TMP"

{
echo "# フォロー先に公式アカウントがどれだけ混ざっているか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** フォローも、書き換えも、ジョブの操作もしていない。"
echo "> **handle は出さない。** 当たった語と件数だけ。"

echo
echo "## 1. \`follow-handle.js\` は写しと違うか"
echo
if [ ! -f "$FH" ]; then
  echo "- **無い: \`$FH\`**"
  echo
  echo "  \`\`\`"
  ls -1 "$S" 2>/dev/null | grep -i follow | sed 's/^/    /'
  echo "  \`\`\`"
else
  echo '```'
  printf '  行数      : %s\n' "$(wc -l < "$FH" | tr -d ' ')"
  printf '  bytes     : %s\n' "$(wc -c < "$FH" | tr -d ' ')"
  # macOS は stat -f（-c は Linux。最上位ルール 14）
  printf '  更新       : %s\n' "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$FH" 2>/dev/null)"
  printf '  sha256    : %s\n' "$(shasum -a 256 "$FH" 2>/dev/null | awk '{print $1}')"
  echo '```'
  echo
  echo "**9/05 の写しは 220 行 / 更新 2026-08-09 17:52。** 違えば、写しを前提にしたパッチは当たらない。"
  echo
  echo "上限の実値（ログの \`need 10-50000\` と合うか）:"
  echo
  echo '```javascript'
  grep -n "follower_count < minFollowers\|minFollowers =\|out of range" "$FH" 2>/dev/null | clean | sed 's/^/  /'
  echo '```'
fi

echo
echo "## 2. 表示名を取っているか（**名前フィルタの前提**）"
echo
echo "名前で弾くには、まず名前を持っていないといけない。"
echo "\`getProfileData\` の \`page.evaluate\` が返しているキーを見る。"
echo
echo '```javascript'
if [ -f "$FH" ]; then
  awk '/async function getProfileData/,/^}/' "$FH" 2>/dev/null | grep -n "querySelector\|return {\|bio\|name\|verif\|UserName\|_count\|canFollow\|alreadyFollowing" | clean | sed 's/^/  /'
fi
echo '```'
echo
nhit="$(grep -c 'UserName\|displayName\|display_name' "$FH" 2>/dev/null | head -1)"
case "$nhit" in ''|*[!0-9]*) nhit=0 ;; esac
if [ "$nhit" -gt 0 ]; then
  echo "- **表示名を取っている（\`UserName\`/\`displayName\` が $nhit 箇所）。** 判定を足すだけで済む"
else
  echo "- **表示名を取っていない。** 名前フィルタは \`[data-testid=\"UserName\"]\` を"
  echo "  \`getProfileData\` に足すところから作ることになる。**bio と handle だけなら いま在る材料で足りる**"
fi

echo
echo "## 3. \`passFilter\` の実物（**土台。ここから書き足す**）"
echo
echo '```javascript'
if [ -f "$FH" ]; then
  awk '/^function passFilter/,/^}/' "$FH" 2>/dev/null | cat -n | clean | sed 's/^/  /'
fi
echo '```'

echo
echo "## 4. 直近ログの拒否理由の内訳（**足す余力があるか**）"
echo
echo "いま何が何件 弾いているか。**\`✅\` の数が、名前フィルタが削る母数。**"
echo
echo '```'
: > "$TMP/reasons.txt"
: > "$TMP/passed.txt"
for f in "$L"/*follow*.log; do
  [ -f "$f" ] || continue
  # 末尾に改行が無い最後の 1 行も読む（最上位ルール 14）
  base="$(basename "$f")"
  ok="$(cnt ': ✅' "$f")"
  ng="$(cnt ': ❌' "$f")"
  printf '  %-34s ✅ %4s 件   ❌ %4s 件   更新 %s\n' "$base" "$ok" "$ng" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  grep ': ❌' "$f" 2>/dev/null >> "$TMP/reasons.txt"
  grep ': ✅' "$f" 2>/dev/null >> "$TMP/passed.txt"
done
echo '```'
echo
echo "拒否理由の内訳（多い順・**数字は伏せて理由だけで束ねる**）:"
echo
echo '```'
if [ -s "$TMP/reasons.txt" ]; then
  # **理由だけ残す。** `: ` の後ろに handle が付く行があるので必ず落とす（公開リポジトリに載る）
  sed -E -e 's/.*: ❌ //' \
         -e 's/\(.*\)//g' \
         -e 's/:.*$//' \
         -e 's/[0-9]+/N/g' \
         -e 's/[[:space:]]+$//' "$TMP/reasons.txt" \
    | sort | uniq -c | sort -rn | head -20 | clean | sed 's/^/  /'
else
  echo "  **拒否の行が 1 件も無い。** ログが空か、書式が違う"
fi
echo '```'

echo
echo "## 5. 通った先に「公式らしさ」がどれだけ在るか"
echo
echo "**\`✅\` になった handle だけ**に語を当てる。**handle は出さない。当たった語と件数だけ。**"
echo
# handle 部分だけ取り出す（@xxx: ✅ の形）
sed -E 's/.*[[:space:]]@?([A-Za-z0-9_]{2,15}): ✅.*/\1/' "$TMP/passed.txt" 2>/dev/null \
  | grep -E '^[A-Za-z0-9_]{2,15}$' | sort -u > "$TMP/handles.txt"
total="$(wc -l < "$TMP/handles.txt" 2>/dev/null | tr -d ' ')"
case "$total" in ''|*[!0-9]*) total=0 ;; esac
echo "**\`✅\` の実数（重複を除いた handle）: $total 件**"
echo
if [ "$total" -eq 0 ]; then
  echo "- **0 件。** ログから handle を取り出せていない。**書式を確かめること**（§4 の ✅ 件数と突き合わせる）"
else
  echo "### 強い手がかり（**当たればほぼ公式・法人**）"
  echo
  echo '```'
  for k in official Official OFFICIAL _jp _JP _pr _PR press Press corp Corp inc Inc _co _CO staff Staff; do
    n="$(grep -c -- "$k" "$TMP/handles.txt" 2>/dev/null | head -1)"
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    [ "$n" -gt 0 ] && printf '  %-12s %3s 件\n' "$k" "$n"
  done
  echo '```'
  echo
  echo "### 弱い手がかり（**個人でも普通に使う。単独では弾けない**）"
  echo
  echo '```'
  for k in info news shop store support team lab365 group; do
    n="$(grep -c -- "$k" "$TMP/handles.txt" 2>/dev/null | head -1)"
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    [ "$n" -gt 0 ] && printf '  %-12s %3s 件\n' "$k" "$n"
  done
  echo '```'
fi

echo
echo "## 6. bio 側に語が在るか（**日本語はこちらが本命**）"
echo
echo "handle は英字しか入らないので、**「【公式】」「株式会社」「編集部」は bio と表示名にしか出ない。**"
echo "フォロー実績に bio が残っているファイルを探して当てる。"
echo
echo '```'
found=0
for f in "$D"/*.json; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    *follow*|*candidate*|*profile*) ;;
    *) continue ;;
  esac
  found=1
  printf '  %-42s %9s bytes  更新 %s\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done
[ "$found" -eq 0 ] && echo "  **該当するファイルが無い。** bio は保存されていない"
echo '```'
echo
if [ "$found" -eq 1 ]; then
  echo "そのファイルの中で、公式らしさの語が何件 当たるか（**中身は出さない**）:"
  echo
  echo '```'
  for k in 公式 株式会社 有限会社 合同会社 広報 編集部 運営 カスタマーサポート 採用 求人 加盟店 店舗; do
    n=0
    for f in "$D"/*.json; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in *follow*|*candidate*|*profile*) ;; *) continue ;; esac
      m="$(grep -c -- "$k" "$f" 2>/dev/null | head -1)"
      case "$m" in ''|*[!0-9]*) m=0 ;; esac
      n=$((n + m))
    done
    [ "$n" -gt 0 ] && printf '  %-22s %4s 行\n' "$k" "$n"
  done
  echo '```'
  echo
  echo "> **「行」であって「アカウント数」ではない。** 1 行に複数 入っていることも、"
  echo "> 同じアカウントが複数 行に出ていることもある。**上限の見積もりとして読む**"
fi

echo
echo "---"
echo
echo "## 読み方（**このタスクでは直さない**）"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| 語の当たりが **多い**（✅ の 1 割 以上） | **名前フィルタを足す価値がある。** §3 の \`passFilter\` に足す |"
echo "| 語の当たりが **ほぼ 0** | **公式は既に別の絞りで落ちている。** 足しても供給が減るだけ。**やめる** |"
echo "| 表示名を取っていない（§2） | \`getProfileData\` に \`UserName\` を足すぶん、パッチが 2 箇所 になる |"
echo "| \`follow-handle.js\` が写しと違う（§1） | **実物の \`passFilter\`（§3）から書く。** 写しは使わない |"
echo "| ✅ が日に数件 しかない | **絞りを足す前に供給を増やす話。** 順番が逆 |"
echo
echo "## 費用"
echo
echo "**ファイルとログを読むだけ。LLM を呼んでいない。**"
echo "**フォロー自体も DOM 操作のみで LLM を呼ばない**ので、絞りを変えても課金は増えない。"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -rf "$TMP"

if grep -q 'passFilter' "$OUT" 2>/dev/null; then
  echo "公式アカウントの混入を測った / $(basename "$OUT")"
else
  echo "**測れていない。レポートを確認すること** / $(basename "$OUT")"
fi
