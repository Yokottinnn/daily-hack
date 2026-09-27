#!/bin/bash
# **走査の修正が効いたかを、数だけで確かめる。外さない。費用 $0。**
#
# ## なぜ要るか
#
# `x186` は走ったが（rc=0 / 146 秒・**1 件 外した**）、肝心の証拠が消えた。
#
#   --- 取り直した一覧と判定 ---
#     **Binary file /Users/ny/.openclaw/workspace/.x186-run.log matches**
#
# **ログに不正なバイトが混じり、`grep` がバイナリ扱いにして中身を出さなかった。**
# 件数（`grep -c`）は有効なので「1 件 外した」は正しいが、
# **フォロー中の数が減ったかは分からない。**
#
# あわせて **一覧のキャッシュが書かれていなかった**（`[ -f ]` が偽）。
# 理由も同じ抑制で消えている。
#
# ## 直したこと
#
# **`grep` に `-a` を付ける。** テキストとして扱わせる。
# 日本語の表示名や打ち切られたマルチバイトで、ログはバイナリ判定されうる。
#
# ## 何を出すか
#
#   ① `MODE=collect` で**一覧だけ取り直す**（外さない・約 60 秒）
#   ② **フォロー中 / フォロワー / 片思い / 相互**の数
#   ③ **プロフィールのヘッダーが出す実数**（これが答え合わせの基準）
#   ④ キャッシュが書けたか、書けないなら理由
#
# ## 直す前の数（比較のため）
#
#   走査（おすすめが混ざった状態）  フォロー中 271〜275 / フォロワー 311
#   プロフィールのヘッダー          **251**（`x160` の実測）
#   → **約 23 人 多かった**
#
# **今日 17 件 外している**（状態ファイル 0 → 17）ので、
# 混ざりが無くなれば **230 前後**になるはず。**275 のままなら効いていない。**
#
# ## やらないこと
#
# **外さない。plist も触らない。LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
TARGET="$S/follow-balance.js"
LF="$D/follow-balance-lists.json"
ST="$D/follow-balance-state.json"
OUT="${OPS_REPORT_DIR:-/tmp}/scrape-counts.md"
RUNLOG="$W/.x187-run.log"
PROBE="$W/.x187-probe.js"
ME="heng_ji31590"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

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
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

{
echo "# 走査の修正が効いたか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **外さない。** 一覧だけ取り直して数を見る。"
echo "> \`grep\` に **\`-a\`** を付けた（\`x186\` はバイナリ判定で中身が消えた）。"
echo "> **LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 1. これまでに外した数（一次情報）"
echo
echo '```'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  状態ファイルが読めない"); process.exit(0); }
  const k = Object.keys(j || {});
  console.log("  外した記録: " + k.length + " 件");
  const byWhy = {};
  for (const h of k) { const w = String((j[h] || {}).why || "?"); byWhy[w] = (byWhy[w] || 0) + 1; }
  for (const [w, n] of Object.entries(byWhy)) console.log("    " + w + "  " + n + " 件");
' "$ST" 2>&1
echo '```'

echo
echo "## 2. 一覧だけ取り直す（\`MODE=collect\`・外さない）"
echo
echo '```'
rm -f "$LF"
T0="$(date +%s)"
MODE=collect DRY_RUN=1 LIST_BUDGET_S=110 run_limited 300 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **300 秒 で打ち切った**' || echo '← 自分で終わった' )"
echo
echo "  --- 出力（**-a 付きで読む**）---"
grep -a -hE 'フォロー中:|フォロワー:|一覧を書いた|一覧を書けない|打ち切る|ログインが切れている|context が無い|CDP に繋がらない|0 件しか読めない' "$RUNLOG" 2>/dev/null \
  | tail -12 | cut -c1-200 | clean | sed 's/^/    /'
echo
echo "  --- 末尾 12 行（そのまま・-a 付き）---"
tail -12 "$RUNLOG" 2>/dev/null | tr -d '\000' | cut -c1-200 | clean | sed 's/^/    /'
echo '```'

echo
echo "## 3. 数（**ここが答え**）"
echo
echo '```json'
if [ -f "$LF" ]; then
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("  **キャッシュが読めない: " + e.message + "**"); process.exit(0); }
    const f = j.following || [], g = j.followers || [];
    const lower = new Set(g.map((h) => String(h).toLowerCase()));
    const one = f.filter((h) => !lower.has(String(h).toLowerCase()));
    console.log("  at " + j.at);
    console.log("  かかった秒 " + JSON.stringify(j.secs || {}));
    console.log("");
    console.log("  フォロー中 " + f.length + " / フォロワー " + g.length + "（差 " + (g.length - f.length) + "）");
    console.log("  片思い " + one.length + " / 相互 " + (f.length - one.length));
    console.log("");
    console.log("  --- 比較 ---");
    console.log("  直す前の走査（おすすめ混ざり）  フォロー中 271〜275 / フォロワー 311");
    console.log("  プロフィールのヘッダー（実数）  251（x160 の実測）");
    console.log("  今日 外した数                   17 件");
    console.log("");
    if (f.length <= 245) console.log("  → **混ざりは解消した**（230 前後の想定に入っている）");
    else if (f.length >= 265) console.log("  → **まだ混ざっている。** primaryColumn の外に在る");
    else console.log("  → **判断がつかない。** §4 のヘッダーの実数と突き合わせる");
  ' "$LF" 2>&1 | clean
else
  echo "  **キャッシュが書かれていない。** §2 の末尾に理由が出ている"
fi
echo '```'

echo
echo "## 4. プロフィールのヘッダーの実数（**答え合わせの基準**）"
echo
echo "**走査に頼らず、X が表示している数をそのまま読む。**"
echo
# **プローブはワークスペースの中に置く。** $TMPDIR だと playwright-core が解決できない
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const ME = process.env.X_ME || "heng_ji31590";
(async () => {
  let b, p;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 20000 });
    const ctx = b.contexts()[0];
    if (!ctx) { console.log(JSON.stringify({ ok: false, error: "no context" })); return; }
    p = await ctx.newPage();
    await p.goto("https://x.com/" + ME, { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(4500);
    const r = await p.evaluate(() => {
      const pick = (sel) => {
        const a = document.querySelector(sel);
        if (!a) return null;
        return ((a.querySelector("span span") || a).textContent || "").trim();
      };
      const toN = (t) => {
        if (!t) return null;
        const s = String(t).replace(/,/g, "");
        if (/万/.test(s)) return Math.round(parseFloat(s) * 10000);
        if (/k/i.test(s)) return Math.round(parseFloat(s) * 1000);
        const n = parseInt(s, 10);
        return Number.isFinite(n) ? n : null;
      };
      const fg = pick('a[href$="/following"]');
      const fr = pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]');
      return { followingTxt: fg, followersTxt: fr, following: toN(fg), followers: toN(fr) };
    });
    console.log(JSON.stringify({ ok: true, ...r }));
  } catch (e) {
    console.log(JSON.stringify({ ok: false, error: String((e && e.message) || e).slice(0, 160) }));
  } finally {
    try { if (p) await p.close(); } catch {}
    try { if (b) await b.close(); } catch {}
  }
})();
PJS
echo '```json'
X_ME="$ME" node "$PROBE" 2>&1 | tr -d '\000' | cut -c1-200 | clean | sed 's/^/  /'
echo '```'
rm -f "$PROBE" "$RUNLOG"
echo
echo "**ヘッダーの数と §3 の走査が近ければ、混ざりは解消している。**"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 と §4 の関係 | 意味 |"
echo "| --- | --- |"
echo "| **ほぼ一致**（差が 5 以内） | **直った。** 走査が実数を返している |"
echo "| 走査がヘッダーより **20 以上 多い** | **まだ混ざっている。** 除く条件を足す |"
echo "| 走査がヘッダーより**少ない** | **取りこぼしている。** \`LIST_BUDGET_S\` を上げる |"
echo "| §4 が \`ok:false\` | Chrome か CDP。**数は書かない** |"
echo
echo "**外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -aq 'プロフィールのヘッダーの実数' "$OUT" 2>/dev/null; then
  echo "走査の数を確かめた / $(basename "$OUT")"
else
  echo "**確かめられていない。レポートを確認すること** / $(basename "$OUT")"
fi
