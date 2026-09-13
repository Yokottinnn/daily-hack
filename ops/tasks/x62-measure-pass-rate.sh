#!/bin/bash
# **通過率の実績を測る ＋ フォロワー数を書く場所を特定する。測るだけ。費用 $0。**
#
# ## なぜ測るのか
#
# 「通過率 25%」は **x43（COSMETIC_REPAIR）と x44（BANNED_LIST）を当てる前の数字。**
# 当てた後の実績を見ないまま次の手を打つと、**効いたのか効いていないのかが分からない。**
#
# 直す場所を決めるために、次の 3 つを実物から出す。
#
#   1. 生成 → 通過 の実測（**修理を当てた前後で分ける**）
#   2. いま何で落ちているのか（**却下理由の内訳**）
#   3. 修理が実際に何回 効いたのか（COSMETIC_REPAIR の発火回数）
#
# ## もう一つ: フォロワー数を **書く** 場所
#
# フォロー系ジョブは**拒否するときにフォロワー数を読んでいる**（`out of range (67000`）。
# **通すときに同じ数字を書いていない**ので、帯ごとのフォロー返し率が出せない。
#
# **どの行で読んでいて、どの行で state に書いているのか**を実物で特定する。
# 直すのは次のタスク（ルール 15・測るものと直すものを同じタスクに入れない）。
#
# ## やらないこと
#
# **投稿しない。フォローしない。設定を書き換えない。LLM を呼ばない（$0）。**
# **`timeout` を使わない**（macOS に無い・ルール 14）。ブラウザを触らない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/measure-pass-rate.md"
NODE_BIN="/usr/local/bin/node"
CW="$L/comment-warmup.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 通過率の実績 ＋ フォロワー数を書く場所"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 「通過率 25%」は **x43 / x44 を当てる前の数字。**"
echo "> 当てた後を見ないまま次の手を打つと、効いたかどうかが分からない。"
echo
echo "**測るだけ。直さない。**"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提（ログの実物）"
echo
echo '```'
if [ ! -d "$L" ]; then
  echo "  **$L が無い。**"
else
  echo "  --- logs/ の返信まわり（サイズ / 最終更新） ---"
  for f in comment-warmup.log comment-orchestrator.log asuka-reply.log \
           post-comment.log trend-detect.log reply-gate.log; do
    P="$L/$f"; [ -f "$P" ] || continue
    printf '    %-28s %8s bytes  %s\n' "$f" "$(wc -c < "$P" | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)"
  done
  echo
  echo "  --- logs/ で直近に更新されたもの 上位 12 ---"
  ls -1t "$L" 2>/dev/null | head -12 | sed 's/^/    /'
fi
echo '```'

# ═══════════ 1. 生成 → 通過 の実測 ═══════════
echo
echo "## 1. 生成 → 通過（**実測**）"
echo
echo "**まずログの書式を実物で見る。** 集計はその形に合わせる。"
echo
echo '```'
if [ ! -f "$CW" ]; then
  echo "  **$CW が無い。**"
  ls -1 "$L" 2>/dev/null | grep -iE 'warmup|comment|reply' | sed 's/^/    候補: /'
else
  echo "  --- 直近 40 行（書式を見るため生で出す） ---"
  tail -40 "$CW" 2>/dev/null | cut -c1-200 | sed 's/^/    /' | clean
fi
echo '```'
echo
echo '```'
if [ -f "$CW" ]; then
  echo "  --- 日ごと（候補数 / picked / enqueue） ---"
  awk '
    # **`{4}` を使わない。** macOS の awk は繰り返し回数を解さないことがある（ルール 14）
    match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { d = substr($0, RSTART, RLENGTH) }
    d == "" { next }
    match($0, /from [0-9]+ candidates/) {
      s = substr($0, RSTART + 5, RLENGTH - 16); cand[d] += s + 0; fires[d]++
    }
    match($0, /picked [0-9]+/)   { p = substr($0, RSTART + 7, RLENGTH - 7); pick[d] += p + 0 }
    /enqueue|enqueued/           { enq[d]++ }
    /投稿|posted|post-comment/   { post[d]++ }
    { seen[d] = 1 }
    END {
      n = 0
      for (k in seen) { ks[n++] = k }
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (ks[i] > ks[j]) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
      st = (n > 10 ? n - 10 : 0)
      printf("    %-12s %6s %6s %6s %6s %6s\n", "日付", "発火", "候補", "picked", "enq", "post")
      for (i = st; i < n; i++) {
        k = ks[i]
        printf("    %-12s %6d %6d %6d %6d %6d\n", k, fires[k], cand[k], pick[k], enq[k], post[k])
      }
    }
  ' "$CW" 2>/dev/null | clean
fi
echo '```'
echo
echo '**`picked` が分母、`enq` が分子。** ここが通過率の実測になる。'
echo '**どちらかが 0 のままなら、その日はそもそも生成まで届いていない。**'

# ═══════════ 2. 却下理由の内訳 ═══════════
echo
echo "## 2. いま何で落ちているのか（**却下理由の内訳**）"
echo
echo '```'
if [ -f "$CW" ]; then
  echo "  --- 既知の理由（x43 が修理対象にした 3 つ） ---"
  for pat in '末尾の絵文字' '書き出しの' 'テンプレに無い絵文字'; do
    c="$(grep -c "$pat" "$CW" 2>/dev/null || echo 0)"
    printf '    %-24s %5s 回\n' "$pat" "$c"
  done
  echo
  echo "  --- 却下・見送りを含む行の語（上位 20） ---"
  grep -hoE '(却下|reject[a-z]*|skip[a-z]*|見送[りる]|NG|blocked|gate)[^ ,、。]{0,20}' "$CW" 2>/dev/null \
    | sort | uniq -c | sort -rn | head -20 | sed 's/^/    /' | clean
  echo
  echo "  --- 却下らしき行の実物 直近 15 本 ---"
  grep -E '却下|reject|見送|NG|gate' "$CW" 2>/dev/null | tail -15 | cut -c1-200 | sed 's/^/    /' | clean
fi
echo '```'

# ═══════════ 3. 修理が効いた回数 ═══════════
echo
echo "## 3. 修理（COSMETIC_REPAIR）と禁止リスト（BANNED_LIST）は効いているか"
echo
echo '```'
AR="${W}/lib/asuka-reply.cjs"
[ -f "$AR" ] || AR="$S/asuka-reply.cjs"
if [ ! -f "$AR" ]; then
  echo "  **asuka-reply.cjs が見つからない。**"
  find "$W" -name 'asuka-reply*' -maxdepth 3 2>/dev/null | head -5 | sed 's/^/    候補: /'
else
  echo "  $AR"
  echo "    $(wc -l < "$AR" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$AR" 2>/dev/null)"
  echo
  echo "  --- 当たっているか（印を探す） ---"
  for m in COSMETIC_REPAIR BANNED_LIST; do
    if grep -q "$m" "$AR" 2>/dev/null; then
      echo "    $m: **在る**（$(grep -c "$m" "$AR") 箇所）"
    else
      echo "    $m: **無い（当たっていない）**"
    fi
  done
  echo
  echo "  --- ログ側の発火回数 ---"
  for m in COSMETIC_REPAIR repair 修理 banned 禁止; do
    c="$(grep -rc "$m" "$CW" 2>/dev/null | head -1 || echo 0)"
    printf '    %-18s %5s 回\n' "$m" "${c:-0}"
  done
fi
echo '```'
echo
echo "**印が無ければ、通過率は測るまでもなく当てる前のまま。**"
echo "その場合は当て直しが先で、しきい値には触らない。"

# ═══════════ 4. フォロワー数を読む場所 / 書く場所 ═══════════
echo
echo "## 4. フォロワー数 — **読んでいる場所**と**書いていない場所**"
echo
echo '```'
for f in competitor-follower-follow.js hashtag-follow.js follow-back.js; do
  P="$S/$f"; [ -f "$P" ] || continue
  echo "  ══ $f（$(wc -l < "$P" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)）"
  echo
  echo "    --- フォロワー数を読んでいる行 ---"
  grep -nE 'followers?[_A-Za-z]*|フォロワー|out of range|MIN_FOLLOWERS|MAX_FOLLOWERS|[0-9]+-[0-9]{4,}' "$P" 2>/dev/null \
    | head -14 | cut -c1-200 | sed 's/^/      /' | clean
  echo
  echo "    --- 通したときに state へ書いている行 ---"
  grep -nE 'writeFileSync|followed_at|JSON.stringify|\[handle\] *=|push\(' "$P" 2>/dev/null \
    | head -12 | cut -c1-200 | sed 's/^/      /' | clean
  echo
done
echo "  --- しきい値の実物（3 種類 在るのが分かっている） ---"
grep -rnE 'need [0-9]+-[0-9]+|MIN_FOLLOWERS|MAX_FOLLOWERS|followerRange|FOLLOWER_RANGE' "$S" 2>/dev/null \
  | head -14 | cut -c1-200 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 5. 状態ファイルの現状 ═══════════
echo
echo "## 5. 状態ファイルに今 入っているもの"
echo
echo '```'
for f in reply-followers.json follow-state.json followed.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  echo "  ══ $f（$(wc -c < "$P" | tr -d ' ') bytes / $(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)）"
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows = Array.isArray(j) ? j : (j.entries || j.items || Object.entries(j).map(([k,v])=>({handle:k,...(v&&typeof v==="object"?v:{v})})));
console.log("    件数: " + rows.length);
const keys = {};
for (const r of rows.slice(0, 500)) for (const k of Object.keys(r||{})) keys[k]=(keys[k]||0)+1;
console.log("    フィールド: " + JSON.stringify(keys));
console.log("    先頭 1 件: " + JSON.stringify(rows[0]));
' "$P" 2>&1 | head -8 | clean
  echo
done
echo '```'
echo
echo '**`followers` に相当するキーが無ければ、帯ごとの返し率は出せない。**'
echo 'x61 が足す `still_following` / `follows_back` と合わせて、**通すときに数字を書く**のが次の一手。'

# ═══════════ 6. 費用 ═══════════
echo
echo "## 6. 費用"
echo
echo "**読むだけ。LLM を呼ばない。ブラウザを触らない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "参考（**推定**・前提: Haiku 4.5・通過率 25%・生成 64 回/日）"
echo "定時の返信ループ 1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8。"
echo "**通過率が上がれば 1 件あたりの単価は下がる**（捨てる生成が減るため）。"
} > "$OUT" 2>&1

echo "通過率の実績とフォロワー数の書き場所 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
