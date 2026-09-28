#!/bin/bash
# **フォロワーより フォローが少ない状態を、機械で保たせる。費用 $0。**
#
# ## 指示（2026-09-28）
#
#   > いまひたすらアンフォロをしたので、これくらいの比率を保てるように心がけてください。
#   > **フォロー数よりフォロワー数が多い方が圧倒的に魅力なアカウントに見える**ということを
#   > 大前提にフォローとアンフォローのアクションをしてください
#
# **いまの実数（9/28 23:29 にヘッダーから実測）**
#
#   フォロー中 **173** / フォロワー **296** → 比率 **0.584**
#
# ## いまの作りでは保てない
#
# `follow-balance.js` の上限は **比率を一切 見ていない。**
#
#   quota = min(MAXN, max(MINN, 今日フォローした数))     ← MINN=MAXN=20 なので **常に 20**
#
# **フォロワーが減っても、フォロー中が既に少なくても、毎回 20 件 外しにいく。**
# 逆に、フォロー側が 1 日 120 件 撃てる設定（competitor 30 / hashtag 90）なので、
# **そちらが動き出すと 40 件/日 の上限では追いつかない。**
#
# ## 直す: 比率の帯で上限を決める
#
#   上限比率 `FOLLOW_RATIO_CEIL`  = **0.65**   → 296 × 0.65 = **192 件 まで**
#   下限比率 `FOLLOW_RATIO_FLOOR` = **0.45**   → 296 × 0.45 = **133 件 を下回らない**
#
# | いまの状態 | 今回 外す数 |
# | --- | --- |
# | 上限を超えている | **超過分 ＋ 今日フォローした数**（絶対上限 MAXN で頭打ち） |
# | 帯の中（いまここ） | **今日フォローした数だけ**＝増えた分を戻して維持する |
# | 下限を下回っている | **0 件。外さない** |
#
# **いまは 173 ≤ 192 なので「帯の中」。** 今日フォローした数（2 件）だけ外す。
# **ひたすら外す動きは、ここで自動的に止まる。**
#
# ## 数は走査ではなくヘッダーから取る
#
# **走査は「おすすめユーザー」が混ざって 17〜21 件 多く出る**（9/28 実測: 走査 190 / 実数 173）。
# **比率の判定に走査値を使うと、実際より多いと思い込んで外しすぎる。**
# X のプロフィールが表示している数だけを使う。**読めなければ比率を見ない**（fail-open）。
#
# ## やらないこと
#
# - **猶予（7 日）・ホワイトリスト・相互の「反応をくれた人」の守りは触らない**
# - **plist も触らない**（`MIN_UNFOLLOW` / `MAX_UNFOLLOW` は絶対上限として残す）
# - **フォロー側のスクリプトは触らない**（別の話。次の一手で出す）
# - **LLM を呼ばない**
#
# ## 費用（最上位ルール 2-B）
#
#   1 回あたり   **$0**
#   1 日あたり   **$0**（11:45 / 18:45 の 2 回）
#   1 か月あたり **$0**
#
# **DOM を読んで押すだけ。判定が増えても増額にならない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
TARGET="$S/follow-balance.js"
LF="$D/follow-balance-lists.json"
STAMP="$(date '+%Y%m%d-%H%M%S')"
# **拡張子は `.js` のまま保つ**（`.new` を付けると Mac の node --check が弾く・最上位ルール 14）
TMPJS="$S/.follow-balance-ratio-$STAMP.js"
PATCHER="$S/.follow-balance-ratio-patch-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/keep-follower-ratio.md"
RUNLOG="$W/.x193-run.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    # **`kill -TERM -$pid` は使わない**（呼び出し側のグループごと落ちる・最上位ルール 14）
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

# ---- 差し込む本体（アンカーを literal で置換する。正規表現を使わない）----
cat > "$PATCHER" <<'PATCHEOF'
const fs = require("fs");
// **ファイルとして実行する**ので argv[1] はこのスクリプト自身のパス。
// `node -e` のときと 1 つ ずれる（最上位ルール 13 と同じ根の間違い）
const src = process.argv[2];
const dst = process.argv[3];
let t = fs.readFileSync(src, "utf8");

if (t.indexOf("FOLLOW_RATIO_CEIL") !== -1) {
  process.stdout.write("ALREADY\n");
  process.exit(0);
}

const anchor =
  '  const quota = Math.min(MAXN, Math.max(MINN, followedToday));\n' +
  '  log("今日フォローした数: " + followedToday + " 件 → **今回の上限 " + quota + " 件**（下限 " + MINN + " / 絶対上限 " + MAXN + "）");\n';

if (t.indexOf(anchor) === -1) {
  process.stdout.write("ANCHOR_NOT_FOUND\n");
  process.exit(2);
}
if (t.split(anchor).length !== 2) {
  process.stdout.write("ANCHOR_NOT_UNIQUE\n");
  process.exit(2);
}

const patch = [
'  // **フォロワーより フォローが少ない状態を保つ**（2026-09-28 に利用者が指示）。',
'  //   「フォロー数よりフォロワー数が多い方が圧倒的に魅力なアカウントに見える」',
'  //',
'  // **走査の数は使わない。** おすすめユーザーが混ざって 17〜21 件 多く出る',
'  // （9/28 実測: 走査 190 / ヘッダーの実数 173）。多いと思い込んで外しすぎる。',
'  // **X が表示しているヘッダーの数だけを使い、読めなければ比率を見ない**（fail-open）。',
'  const CEIL_RATIO = Number(process.env.FOLLOW_RATIO_CEIL || 0.65);',
'  const FLOOR_RATIO = Number(process.env.FOLLOW_RATIO_FLOOR || 0.45);',
'  let hdr = null;',
'  try {',
'    await page.goto("https://x.com/" + me, { waitUntil: "domcontentloaded", timeout: 30000 });',
'    await page.waitForTimeout(4500);',
'    hdr = await page.evaluate(() => {',
'      const pick = (sel) => {',
'        const a = document.querySelector(sel);',
'        return a ? ((a.querySelector("span span") || a).textContent || "").trim() : null;',
'      };',
'      const toN = (x) => {',
'        if (!x) return null;',
'        const s = String(x).replace(/,/g, "");',
'        if (/万/.test(s)) return Math.round(parseFloat(s) * 10000);',
'        if (/[kK]/.test(s)) return Math.round(parseFloat(s) * 1000);',
'        const n = parseInt(s, 10);',
'        return Number.isFinite(n) ? n : null;',
'      };',
'      return {',
'        following: toN(pick(\'a[href$="/following"]\')),',
'        followers: toN(pick(\'a[href$="/verified_followers"]\') || pick(\'a[href$="/followers"]\')),',
'      };',
'    });',
'  } catch (e) { hdr = null; }',
'',
'  let quota = Math.min(MAXN, Math.max(MINN, followedToday));',
'  let ratioNote = "ヘッダーが読めないので比率を見ない";',
'  if (hdr && Number.isFinite(hdr.following) && Number.isFinite(hdr.followers) && hdr.followers > 0) {',
'    const ceilN = Math.floor(hdr.followers * CEIL_RATIO);',
'    const floorN = Math.floor(hdr.followers * FLOOR_RATIO);',
'    const over = hdr.following - ceilN;',
'    log("実数（ヘッダー）: フォロー中 " + hdr.following + " / フォロワー " + hdr.followers +',
'        " → 比率 " + (hdr.following / hdr.followers).toFixed(3) +',
'        "（帯 " + floorN + "〜" + ceilN + " 件 / " + FLOOR_RATIO + "〜" + CEIL_RATIO + "）");',
'    if (over > 0) {',
'      quota = Math.min(MAXN, over + followedToday);',
'      ratioNote = "**上限 " + ceilN + " 件 を " + over + " 件 超えている → 超過分＋今日の増分**";',
'    } else if (hdr.following <= floorN) {',
'      quota = 0;',
'      ratioNote = "**下限 " + floorN + " 件 以下。外しすぎなので今回は外さない**";',
'    } else {',
'      quota = Math.min(MAXN, followedToday);',
'      ratioNote = "**帯の中。今日 増えた分だけ外して維持する**";',
'    }',
'  } else {',
'    log("**ヘッダーの実数が読めなかった。比率の判定をしない**（従来どおりの上限で動く）");',
'  }',
'  log("今日フォローした数: " + followedToday + " 件 → **今回の上限 " + quota + " 件**（" +',
'      ratioNote + " / 絶対上限 " + MAXN + "）");',
'  if (quota <= 0) {',
'    log("**外す必要が無い。ここで終わる。**");',
'    try { await page.close(); } catch (e) {}',
'    process.exit(0);',
'  }',
''].join("\n");

t = t.split(anchor).join(patch);
fs.writeFileSync(dst, t);
process.stdout.write("PATCHED\n");
PATCHEOF

{
echo "# フォロワー > フォロー を機械で保たせる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **指示**: フォロー数よりフォロワー数が多い方が圧倒的に魅力なアカウントに見える。"
echo "> その比率（いま **173 / 296 = 0.584**）を保つ。"
echo "> **LLM を呼ばない（\$0／回・\$0／日・\$0／月）。判定が増えても増額にならない。**"

echo
echo "## 1. 直す前"
echo
echo '```'
if [ ! -f "$TARGET" ]; then
  echo "  **follow-balance.js が無い: $TARGET**"
  echo '```'
  rm -f "$PATCHER"
  echo
  echo "**当て推量で作らない。\`x183\` を読み直すこと。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
printf '  %s 行 / 更新 %s\n' "$(wc -l < "$TARGET" | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$TARGET" 2>/dev/null)"
printf '  いまの上限の決め方: quota = min(MAXN, max(MINN, 今日のフォロー数))  ← 比率を見ていない\n'
printf '  比率の判定が入っている箇所: %s（0 なら未導入）\n' "$(cnt 'FOLLOW_RATIO_CEIL' "$TARGET")"
echo '```'

echo
echo "## 2. 差し込む"
echo
echo "**アンカーは literal で照合する**（正規表現を使わない）。二重に当たらないよう、"
echo "既に入っていれば何もしない。**アンカーが無い／一意でなければ、書かずに止まる。**"
echo
echo '```'
R="$(node "$PATCHER" "$TARGET" "$TMPJS" 2>&1)"; PRC=$?
printf '  %s (rc=%s)\n' "$(printf '%s' "$R" | head -2 | tr '\n' ' ')" "$PRC"
case "$R" in
  ALREADY*)
    echo "  → **もう入っている。書き換えない。**"
    rm -f "$PATCHER" "$TMPJS"
    ;;
  PATCHED*)
    echo
    echo "  --- 構文検査（**タスクが実際に置く名前で打つ**）---"
    CK="$(node --check "$TMPJS" 2>&1)"; CRC=$?
    printf '    node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -2 | cut -c1-140)"
    if [ "$CRC" -ne 0 ]; then
      echo "    → **構文が通らない。置かない。**"
      rm -f "$PATCHER" "$TMPJS"
      echo '```'
      echo
      echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
      exit 1
    fi
    cp "$TARGET" "$TARGET.bak-$STAMP"
    mv "$TMPJS" "$TARGET"
    rm -f "$PATCHER"
    printf '    置いた。%s 行（控え: follow-balance.js.bak-%s）\n' "$(wc -l < "$TARGET" | tr -d ' ')" "$STAMP"
    ;;
  *)
    echo "  → **アンカーが見つからないか一意でない。1 文字も書いていない。**"
    echo
    echo "  --- いまの quota の行 ---"
    grep -an 'const quota' "$TARGET" 2>/dev/null | head -3 | cut -c1-200 | sed 's/^/    /'
    rm -f "$PATCHER" "$TMPJS"
    ;;
esac
echo
printf '  比率の判定が入っている箇所: %s（1 以上が正）\n' "$(cnt 'FOLLOW_RATIO_CEIL' "$TARGET")"
printf '  守りは残っているか: 猶予 %s / ホワイトリスト %s / 片思いの緩め %s\n' \
  "$(cnt 'GRACE_DAYS' "$TARGET")" "$(cnt 'ホワイトリスト' "$TARGET")" "$(cnt 'ONEWAY_IGNORE_ENGAGED' "$TARGET")"
echo '```'

echo
echo "## 3. 判定だけ見る（**DRY・1 件も外さない**）"
echo
echo "一覧はキャッシュを使う（\`MODE=decide\`）。**見たいのは上限の決まり方**なので、"
echo "プロフィールを開く数は 3 件 に絞る。"
echo
echo '```'
T0="$(date +%s)"
MODE=decide DRY_RUN=1 CACHE_MAX_H=24 MAX_PROFILE_READS=3 DECIDE_BUDGET_S=20 \
  MIN_UNFOLLOW=20 MAX_UNFOLLOW=20 \
  run_limited 210 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **210 秒 で打ち切った**' || echo '← 自分で終わった' )"
echo
echo "  --- 比率の判定（**ここが見たいところ**）---"
grep -a -hE '実数（ヘッダー）|今回の上限|外す必要が無い|ヘッダーの実数が読めなかった' "$RUNLOG" 2>/dev/null \
  | tr -d '\000' | tail -6 | cut -c1-240 | clean | sed 's/^/    /'
echo
echo "  --- 出力 全部（**絞り込まない**）---"
cat "$RUNLOG" 2>/dev/null | tr -d '\000' | tail -30 | cut -c1-240 | clean | sed 's/^/    /'
echo '```'
rm -f "$RUNLOG"

echo
echo "## 4. 一覧のキャッシュ（参考）"
echo
echo '```'
if [ -f "$LF" ]; then
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("  読めない"); process.exit(0); }
    const f = (j.following || []).length, g = (j.followers || []).length;
    const ageM = (Date.now() - new Date(j.at || 0).getTime()) / 60000;
    console.log("  " + (isFinite(ageM) ? ageM.toFixed(0) : "?") + " 分 前 / 走査 フォロー中 " + f + " / フォロワー " + g);
    console.log("  ※ 走査はおすすめユーザーが混ざる。**比率の判定には使っていない**");
  ' "$LF" 2>&1 | clean
else
  echo "  キャッシュが無い"
fi
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 に出た行 | 意味 |"
echo "| --- | --- |"
echo "| \`帯の中。今日 増えた分だけ外して維持する\` | **狙いどおり。** ひたすら外す動きが止まった |"
echo "| \`上限 N 件 を M 件 超えている\` | フォローが増えすぎ。**超過分を戻しにいく** |"
echo "| \`下限 N 件 以下。外さない\` | **外しすぎ。** 保護が効いた |"
echo "| \`ヘッダーの実数が読めなかった\` | 比率を見ずに従来どおり動く（fail-open）|"
echo
echo "**\`MIN_UNFOLLOW\` / \`MAX_UNFOLLOW\` は絶対上限として残っている。**"
echo "比率の判定はその内側で効く。**plist は触っていない。**"
echo
echo "**1 件も外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$PATCHER" "$TMPJS" "$RUNLOG"

if grep -aq '比率の判定' "$OUT" 2>/dev/null; then
  echo "比率で上限を決めるようにした / $(basename "$OUT")"
else
  echo "**入っていない。レポートを確認すること** / $(basename "$OUT")"
fi
