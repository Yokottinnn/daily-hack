#!/bin/bash
# **落ちた PAY ID スレッドの続き（[2/3] [3/3]）を足す。最優先。x168 の作り直し。**
#
# ## 何が起きたか
#
# 9/27 12:00 の `publish-payid-oneshot` は **[1/3] を出したあと [2/3] で落ちた。**
#
#   [post-via-playwright] attached 4/4 image(s)
#   [step] navigate-target / find-reply-textarea / type-text
#   [x154] like 付いた
#   {"ok":false,"step":"thread-reply-1-exec","error":"Command failed: node scripts/post-comment.js \"<base64>\""}
#
# base64 を復号すると `BASEで作られたショップ——あの個人商店みたい…` ＝ **[2/3] の本文**。
# **利用者も X 上で失敗を確認している**（2026-09-27）。
#
# ## 落ちた経路は使わない
#
# **`post-comment.js` が落ちた理由は未特定。** 同じものを呼び直しても同じ所で落ちうる。
# だから**この タスクの中で完結する Playwright の経路で出す。**
# ついでに `post-comment.js` の**本当のエラー文もレポートに出す**（次の手がかり）。
#
# ## 二重投稿を出さないための門（**全部 通らなければ出さない**）
#
#   ① 自分の TL に **[1/3] の実物**が在る（本文の頭 24 字で一致）
#   ② そのスレッドに **[2/3] / [3/3] がまだ無い**（頭 16 字で照合）
#   ③ 文面は **`origin/main` の `posts.json` から読む**（作業ツリーを信じない・`x158` の教訓）
#   ④ 1 本 出すごとに**実物が出たかを確かめる。** 出ていなければそこで止める
#
# **承認済みの文面を 1 文字も変えない**（最上位ルール 18）。
#
# ## 費用
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。** DOM 操作だけ。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
REPO="${OPS_MAIN_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/payid-thread-complete2.md"
PROBE="$W/.x169-probe.js"
COPY="$W/.x169-copy.json"
ME="heng_ji31590"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
# **自分の投稿 URL は伏せない。** 確認してもらう対象そのもの
clean() { hide | sed -E "s#@<伏せ>/status#@$ME/status#g"; }

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
echo "# PAY ID スレッドの続きを足す（作り直し・$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **[1/3] は触らない。** 足すのは [2/3] と [3/3] だけ。"
echo "> **門が 1 つでも通らなければ 1 本も出さない。**"

echo
echo "## 1. 落ちた本当の理由（**次の手がかり**）"
echo
echo "**\`x165\` は末尾 14 行しか出していない。** エラー文を最後まで出す。"
echo
echo '```'
F="$L/publish-payid-oneshot.log"
if [ ! -f "$F" ]; then
  echo "  **ログが無い**"
else
  # 折り返された JSON も拾えるよう、失敗行から後ろを全部 出す
  awk '/thread-reply-1-exec/{f=1} f' "$F" 2>/dev/null | head -40 | cut -c1-400 | clean | sed 's/^/  /'
  echo
  echo "  --- 守り（x150）が働いた形跡 ---"
  for k in wrong-page no-focus text-mismatch; do
    c="$(grep -c "$k" "$F" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0;; esac
    printf '  %-16s %s 件\n' "$k" "$c"
  done
fi
echo '```'

echo
echo "## 2. 文面を \`origin/main\` から読む（**作業ツリーを信じない**）"
echo
echo '```'
if node -e '
  const { execFileSync } = require("child_process");
  const fs = require("fs");
  const [repo, out] = process.argv.slice(1);
  const raw = execFileSync("git", ["-C", repo, "show", "origin/main:scripts/image-review/posts.json"],
                           { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  const j = JSON.parse(raw);
  const a = j["payid-a"];
  if (!Array.isArray(a) || a.length !== 3) throw new Error("payid-a が 3 本ではない: " + (a ? a.length : "無い"));
  const w = (s) => { let n = 0; for (const c of s) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
  a.forEach((t, i) => {
    if (w(t) > 280) throw new Error("[" + (i + 1) + "/3] の重みが 280 を超える: " + w(t));
    console.log("  [" + (i + 1) + "/3] 重み " + w(t) + " / 頭: " + t.slice(0, 26).replace(/\n/g, "⏎"));
  });
  fs.writeFileSync(out, JSON.stringify(a));
' "$REPO" "$COPY" 2>&1 | sed 's/^/  /'; then
  :
else
  echo
  echo "  **文面が読めない。1 本も出さずに終わる。**"
  echo '```'
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'
[ -s "$COPY" ] || { echo; echo "- **文面ファイルが空。止まる。**"; echo; echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"; exit 1; }

echo
echo "## 3. [1/3] を探して、足りない分だけ出す"
echo
cat > "$PROBE" <<'PJS'
const fs = require("fs");
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const ME = process.env.X_ME || "heng_ji31590";
const TEXTS = JSON.parse(fs.readFileSync(process.env.X169_COPY, "utf8"));
const log = (...a) => console.error("[x169]", ...a);
const norm = (s) => String(s || "").replace(/\s+/g, "").replace(/[…‥]/g, "");
const head = (s, n) => norm(s).slice(0, n);

(async () => {
  const result = { ok: false, found_root: null, posted: [], skipped: [], error: null };
  let b, p;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 20000 });
    const ctx = b.contexts()[0];
    if (!ctx) throw new Error("no context");
    p = await ctx.newPage();

    // --- 門① [1/3] を自分の TL から探す ------------------------------------
    // **`x168` はここで失敗した。** `/with_replies` をスクロールせずに読んだので
    // 直近 7 件（返信ばかり）しか見えず、12:00 の [1/3] はその下に埋まっていた。
    // 対策は 2 つ。**① 返信を含まないタブを先に見る ② スクロールして読み込む。**
    const want1 = head(TEXTS[0], 24);
    const collect = (me) => p.evaluate((m) => {
      const out = [];
      for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
        const href = [...art.querySelectorAll('a[href*="/status/"]')]
          .map((x) => x.getAttribute("href") || "")
          .find((h) => new RegExp("^/" + m + "/status/\\d+$").test(h.split("/photo/")[0]));
        const t = art.querySelector('[data-testid="tweetText"]');
        out.push({ href: href ? href.split("/photo/")[0] : null,
                   text: t ? t.textContent : "" });
        if (out.length >= 60) break;
      }
      return out;
    }, me);

    let root = null, seenMax = 0, wherePrint = [];
    // **返信を含まないタブが先。** [1/3] は元投稿なので、こちらなら埋まりにくい
    for (const tab of ["https://x.com/" + ME, "https://x.com/" + ME + "/with_replies"]) {
      log("見るタブ:", tab);
      await p.goto(tab, { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(4500);
      for (let s = 0; s < 8; s++) {
        const rows = await collect(ME);
        if (rows.length > seenMax) seenMax = rows.length;
        wherePrint = rows;
        root = rows.find((r) => r.href && head(r.text, 24) === want1) || null;
        if (root) { log("  " + (s + 1) + " 回目の読みで見つけた（" + rows.length + " 件 中）"); break; }
        // **スクロールして読み込ませる。** `x168` が抜かしていたのはここ
        await p.evaluate(() => window.scrollBy(0, 3000));
        await p.waitForTimeout(1800);
      }
      if (root) break;
    }
    if (!root) {
      result.error = "[1/3] が TL に無い（頭 24 字で一致しない）。最大 " + seenMax + " 件まで読んだ";
      log(result.error);
      for (const r of wherePrint.slice(0, 12)) log("  候補:", r.href, "|", norm(r.text).slice(0, 34));
      console.log(JSON.stringify(result, null, 2));
      return;
    }
    const rootUrl = "https://x.com" + root.href;
    result.found_root = rootUrl;
    log("[1/3] を見つけた:", rootUrl);

    // --- 門② すでに続きが在るか ------------------------------------------
    await p.goto(rootUrl, { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(5000);
    const inThread = await p.evaluate(() => {
      const out = [];
      for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
        const t = art.querySelector('[data-testid="tweetText"]');
        if (t) out.push(t.textContent);
      }
      return out;
    });
    const has = (txt) => inThread.some((x) => head(x, 16) === head(txt, 16));
    log("スレッドに見えている投稿:", inThread.length, "件");

    // --- 足りない分を順に出す --------------------------------------------
    // [2/3] は [1/3] へ、[3/3] は [2/3] へ返信する
    let replyTo = rootUrl;
    for (let i = 1; i < TEXTS.length; i++) {
      const label = "[" + (i + 1) + "/" + TEXTS.length + "]";
      if (has(TEXTS[i])) {
        log(label, "すでに在る。触らない");
        result.skipped.push(label);
        // 既に在るものの URL を次の返信先にする
        const u = await p.evaluate((h16) => {
          for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
            const t = art.querySelector('[data-testid="tweetText"]');
            if (!t) continue;
            const n = t.textContent.replace(/\s+/g, "").replace(/[…‥]/g, "").slice(0, 16);
            if (n !== h16) continue;
            const a = [...art.querySelectorAll('a[href*="/status/"]')]
              .map((x) => x.getAttribute("href") || "")
              .find((hh) => /\/status\/\d+$/.test(hh.split("/photo/")[0]));
            if (a) return "https://x.com" + a.split("/photo/")[0];
          }
          return null;
        }, head(TEXTS[i], 16));
        if (u) replyTo = u;
        continue;
      }

      log(label, "を出す。返信先:", replyTo);
      await p.goto(replyTo, { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3500);

      // **返信先のページに居るか**（x150 の守りと同じ考え）
      const wantId = (replyTo.match(/status\/(\d+)/) || [])[1];
      if (!wantId || !p.url().includes(wantId)) {
        throw new Error(label + " 返信先のページに居ない: " + p.url().slice(0, 100));
      }

      const ta = await p.waitForSelector(
        'div[data-testid^="tweetTextarea_"][contenteditable="true"]',
        { timeout: 15000 });
      await ta.click();
      // **フォーカスが載ったかを確かめる。** 載っていなければ打たない
      const focused = await p.waitForFunction(() => {
        const a = document.activeElement;
        return !!a && a.getAttribute && a.getAttribute("contenteditable") === "true";
      }, { timeout: 8000 }).catch(() => null);
      if (!focused) throw new Error(label + " 入力欄にフォーカスが載らない（打たずに止まる）");

      const readBox = () => p.evaluate(() => {
        const el = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]');
        return el ? el.textContent : "";
      });

      await p.keyboard.insertText(TEXTS[i]);
      await p.waitForTimeout(1200);
      let got = await readBox();

      // **`insertText` が効かない版がある。** 空振りしたら `type` で入れ直す
      if (norm(got) !== norm(TEXTS[i])) {
        log(label, "insertText では入らなかった（" + norm(got).length + " 字）。type で入れ直す");
        await p.keyboard.down("Meta"); await p.keyboard.press("a"); await p.keyboard.up("Meta");
        await p.keyboard.press("Backspace");
        await p.waitForTimeout(400);
        await ta.type(TEXTS[i], { delay: 12 });
        await p.waitForTimeout(1200);
        got = await readBox();
      }

      // **打った文が意図した文と一致するか。** 違えば送らない
      if (norm(got) !== norm(TEXTS[i])) {
        throw new Error(label + " 打った文が違う: 意図 " + norm(TEXTS[i]).length +
                        " 字 / 実際 " + norm(got).length + " 字 / 頭: " + norm(got).slice(0, 30));
      }
      log(label, "文の照合 OK（" + norm(got).length + " 字）");

      // 送信
      let sent = false;
      for (const sel of ['[data-testid="tweetButtonInline"]', '[data-testid="tweetButton"]']) {
        const btn = await p.$(sel);
        if (!btn) continue;
        if (await btn.isDisabled().catch(() => false)) { log("  ", sel, "が無効"); continue; }
        await btn.click();
        sent = true;
        log("  送信ボタンを押した:", sel);
        break;
      }
      if (!sent) throw new Error(label + " 送信ボタンが無い／押せない");

      // **出たかを確かめる**（押したことは出たことではない）
      await p.waitForTimeout(6000);
      await p.goto(replyTo, { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(5000);
      const after = await p.evaluate((h16) => {
        for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
          const t = art.querySelector('[data-testid="tweetText"]');
          if (!t) continue;
          const n = t.textContent.replace(/\s+/g, "").replace(/[…‥]/g, "").slice(0, 16);
          if (n !== h16) continue;
          const a = [...art.querySelectorAll('a[href*="/status/"]')]
            .map((x) => x.getAttribute("href") || "")
            .find((hh) => /\/status\/\d+$/.test(hh.split("/photo/")[0]));
          return a ? "https://x.com" + a.split("/photo/")[0] : "出たが URL が取れない";
        }
        return null;
      }, head(TEXTS[i], 16));
      if (!after) throw new Error(label + " 押したのに出ていない");
      log(label, "出た:", after);
      result.posted.push({ label, url: after });
      if (String(after).startsWith("https://")) replyTo = after;
      await p.waitForTimeout(2500);
    }
    result.ok = true;
  } catch (e) {
    result.error = String((e && e.message) || e).slice(0, 220);
    log("失敗:", result.error);
  } finally {
    try { if (p) await p.close(); } catch {}
    try { if (b) await b.close(); } catch {}
  }
  console.log(JSON.stringify(result, null, 2));
})();
PJS

RUNLOG="$W/.x169-run.log"
echo '```'
X_ME="$ME" X169_COPY="$COPY" run_limited 240 "$RUNLOG" node "$PROBE"
RC=$?
printf '  rc=%s%s\n' "$RC" "$( [ "$RC" = "124" ] && echo '  ← **240 秒 で打ち切った**' )"
echo
cat "$RUNLOG" 2>/dev/null | cut -c1-300 | clean | sed 's/^/  /'
echo '```'
rm -f "$PROBE" "$COPY" "$RUNLOG"

echo
echo "## 4. 結果の読み方"
echo
echo "| \`§3\` の出方 | 意味 |"
echo "| --- | --- |"
echo "| \`ok:true\` ／ \`posted\` に 2 本 | **スレッドが揃った。** URL を報告する |"
echo "| \`ok:true\` ／ \`skipped\` に 2 本 | **すでに揃っていた。** 何もしていない |"
echo "| \`[1/3] が TL に無い\` | **[1/3] も出ていない。** 出し直しが要る（候補を §3 に出してある） |"
echo "| \`打った文が違う\` | **守りが働いた。** 送っていない。入力の壊れ方を見る |"
echo "| \`押したのに出ていない\` | **X 側で弾かれた。** 重み・画像・レート制限を見る |"
echo
echo "**\`posted\` が空で \`error\` も無いことは起きない。** どちらかが必ず出る。"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '結果の読み方' "$OUT" 2>/dev/null; then
  echo "PAY ID スレッドの続きを処理した / $(basename "$OUT")"
else
  echo "**処理できていない。レポートを確認すること** / $(basename "$OUT")"
fi
