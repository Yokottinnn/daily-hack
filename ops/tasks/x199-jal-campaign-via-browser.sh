#!/bin/bash
# **JAL のキャンペーン条件を、ブラウザで開いて取る。読むだけ。費用 $0。**
#
# ## なぜ curl ではなくブラウザか
#
# `x198` で `curl` は **HTTP 403** だった（472 bytes のエラーページ）。
# JAL 側が UA だけでは通さない。**実際の Chrome で開けば読める見込み。**
#
# クラウドからは `www.jal.co.jp` が egress で塞がれているので、ここでしか取れない。
#
# ## なぜ要るか
#
# 利用者の依頼は「**JAL の歩いてマイルキャンペーンでマイルをもらえることの紹介**」。
# だが**キャンペーンの数字がどこにも裏取りできていない。**
#
#   記事 `walk-poikatsu-2026.md`  → 月550円・初月無料だけ。**キャンペーンの記載なし**
#   JAL 公式                      → **403 で読めなかった**
#   参考にした第三者の投稿          → 「2倍キャンペーン」とあるが**一次情報ではない**
#
# **数字を書けないまま出すと「お得」が伝わらない。** だから取りに行く。
#
# ## 取り方
#
#   ① JAL Wellness & Travel のトップを開く
#   ② **そのページに在るキャンペーンへのリンクを全部 拾う**（当て推量でURLを組まない）
#   ③ 拾ったものを上から 3 本 まで開いて、**本文をそのまま出す**
#
# **②が肝。** 検索で出た URL だけを叩くと、終わったキャンペーンを掴むか 404 になる。
# **公式が「いま出している」リンクから辿る。**
#
# ## やらないこと
#
# **投稿しない。何も書き換えない。ログインが要るページには入らない。**
# **LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
# **拡張子は `.js` のまま保つ**（最上位ルール 14）
RUNNER="$S/.x199-jal-$STAMP.js"
RAW="$W/.x199-out-$STAMP.json"
OUT="${OPS_REPORT_DIR:-/tmp}/jal-campaign.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

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

cat > "$RUNNER" <<'JSEOF'
// x199: JAL のキャンペーン条件をブラウザで読む。$0（LLM 不使用）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const TOP = "https://www.jal.co.jp/jp/ja/jmb/wellness/";
const MAX_PAGES = 3;
const BUDGET_MS = 220 * 1000;
const t0 = Date.now();

const textOf = (p) => p.evaluate(() => {
  const b = document.body;
  if (!b) return null;
  return b.innerText.replace(/\n{3,}/g, "\n\n").slice(0, 4000);
});

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const p = await ctx.newPage();
  const out = { top: {}, pages: [] };

  // ① トップを開く
  try {
    const r = await p.goto(TOP, { waitUntil: "domcontentloaded", timeout: 45000 });
    await p.waitForTimeout(4000);
    out.top.status = r ? r.status() : null;
    out.top.url = p.url();
    out.top.text = await textOf(p);
    // ② **ページに在るキャンペーンのリンクを拾う。** URL を自分で組まない
    out.top.links = await p.evaluate(() => {
      const seen = new Set(); const acc = [];
      for (const a of document.querySelectorAll("a[href]")) {
        const h = a.href || "";
        if (!/jal\.co\.jp/.test(h)) continue;
        if (!/campaign|キャンペーン/i.test(h + " " + (a.textContent || ""))) continue;
        if (seen.has(h)) continue;
        seen.add(h);
        acc.push({ href: h, text: (a.textContent || "").trim().replace(/\s+/g, " ").slice(0, 80) });
        if (acc.length >= 20) break;
      }
      return acc;
    });
  } catch (e) { out.top.error = String(e && e.message).slice(0, 180); }

  // ③ 上から順に開いて本文を出す
  const links = (out.top.links || []).slice(0, MAX_PAGES);
  for (const l of links) {
    if (Date.now() - t0 > BUDGET_MS) { out.pages.push({ href: l.href, error: "持ち時間を使い切った" }); continue; }
    const row = { href: l.href, label: l.text };
    try {
      const r = await p.goto(l.href, { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(3500);
      row.status = r ? r.status() : null;
      row.text = await textOf(p);
    } catch (e) { row.error = String(e && e.message).slice(0, 180); }
    out.pages.push(row);
  }

  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(out, null, 1));
  // **connectOverCDP は node を終わらせない。** b.close() は利用者の Chrome に触るので使わない
  process.exit(0);
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) }));
  process.exit(0);
});
JSEOF

{
echo "# JAL のキャンペーン条件をブラウザで取る（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x198\` の \`curl\` は **HTTP 403** だった。**実際の Chrome で開く。**"
echo "> **URL を自分で組まない。** 公式がいま出しているリンクから辿る。"
echo "> **投稿しない。何も書き換えない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 1. 構文検査"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -2 | cut -c1-140)"
if [ "$CRC" -ne 0 ]; then
  echo "  → **構文が通らない。走らせない。**"
  echo '```'; rm -f "$RUNNER"
  echo; echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'

echo
echo "## 2. 読む"
echo
echo '```'
T0="$(date +%s)"
run_limited 280 "$RAW" node "$RUNNER"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **280 秒 で打ち切った**' || echo '← 自分で終わった' )"
echo '```'
rm -f "$RUNNER"
echo
if [ -s "$RAW" ]; then
  node -e '
    const fs = require("fs");
    // **`node -e` では argv[1] が第 1 引数**（ファイル実行と 1 つ ずれる）
    let j;
    try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) {
      console.log("```"); console.log("  **JSON として読めない。生の出力:**");
      console.log(String(fs.readFileSync(process.argv[1], "utf8")).slice(0, 700)); console.log("```");
      process.exit(0);
    }
    if (j.fatal) { console.log("```"); console.log("  **止まった: " + j.fatal + "**"); console.log("```"); process.exit(0); }

    const t = j.top || {};
    console.log("### トップ（" + (t.url || "?") + "）");
    console.log("");
    console.log("```");
    console.log("  HTTP " + (t.status ?? "?") + (t.error ? " / エラー: " + t.error : ""));
    console.log("```");
    if (t.status === 403) {
      console.log("");
      console.log("**ブラウザでも 403。** JAL 側が自動操作を弾いている。**数字は書けない。**");
    }
    if (t.text) {
      console.log("");
      console.log("**トップの本文（先頭 1,400 字）**");
      console.log("");
      console.log("```text");
      console.log(t.text.slice(0, 1400));
      console.log("```");
    }
    console.log("");
    console.log("### 拾えたキャンペーンのリンク");
    console.log("");
    console.log("```text");
    const ls = t.links || [];
    if (!ls.length) console.log("  （1 本も無い。トップが読めていないか、構造が違う）");
    for (const l of ls) console.log("  " + (l.text || "(無題)") + "\n    " + l.href);
    console.log("```");

    for (const pg of (j.pages || [])) {
      console.log("");
      console.log("### " + (pg.label || "(無題)"));
      console.log("");
      console.log("```");
      console.log("  " + pg.href);
      console.log("  HTTP " + (pg.status ?? "?") + (pg.error ? " / エラー: " + pg.error : ""));
      console.log("```");
      if (!pg.text) continue;
      console.log("");
      console.log("**本文（先頭 2,200 字）**");
      console.log("");
      console.log("```text");
      console.log(pg.text.slice(0, 2200));
      console.log("```");
      console.log("");
      console.log("**数字が書かれた行だけ**");
      console.log("");
      console.log("```text");
      const seen = new Set();
      for (const l of pg.text.split("\n").map((s) => s.trim()).filter(Boolean)) {
        if (!/(マイル|期間|2026年|2027年|プロモーションコード|抽選|搭乗|月額|無料|対象)/.test(l)) continue;
        if (l.length < 4 || l.length > 200 || seen.has(l)) continue;
        seen.add(l);
        console.log("  " + l);
        if (seen.size >= 30) break;
      }
      console.log("```");
    }
  ' "$RAW" 2>&1 | clean
else
  echo '```'
  echo "  **出力が空。CDP か Chrome を確かめる**"
  echo '```'
fi
rm -f "$RAW"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 次 |"
echo "| --- | --- |"
echo "| 本文が出た | **期間・条件・マイル数をそのまま使う。** 要約しない |"
echo "| **403 のまま** | **数字は書かない。** 記事の「月550円・初月無料」だけで組む |"
echo "| リンクが 0 本 | トップの構造が違う。**本文をそのまま読んで手で URL を拾う** |"
echo "| \`ログイン\` が出る | 会員向けページ。**入らない**。公開情報だけで書く |"
echo
echo "**条件は要約せず、公式の表記のまま使う**（\`x-post-copy\` スキル §4）。"
echo "**期限は日付で書く。「あと◯日」は使わない。**"
echo
echo "**投稿していない。何も書き換えていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAW"

if grep -aq 'キャンペーンのリンク' "$OUT" 2>/dev/null; then
  echo "JAL のキャンペーンをブラウザで読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
