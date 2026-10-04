# follow-balance.js の実物（2026-10-04 12:28:52 JST・$0）

## ① 全文（558 行・更新 10/03 21:26）

```javascript
   1  // フォローとアンフォローの収支を合わせる。
   2  //
   3  // 2026-09-27 作成。**LLM を呼ばない（DOM を読むだけ）ので API 課金は $0。**
   4  //
   5  // **部品は mutual-prune.js から写している。書き直して壊さない。**
   6  //   - playwright-core（`playwright` はこのワークスペースに存在しない）
   7  //   - connectOverCDP で既存の Chrome に繋ぐ（新しく起動しない）
   8  //   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
   9  //
  10  // **なぜ要るか。** mutual-prune.js は「相互だけを対象にする。片思いは既存の別ジョブの担当」
  11  // と明記しているが、**その別ジョブが 1 本も載っていない**（2026-09-27 に確認）。
  12  // 結果、9/25 時点で `フォロー中 249 − 相互 173 = 76 件` の片思いが放置されていた。
  13  //
  14  // 環境変数（既定値は安全側）:
  15  //   DRY_RUN=1            1 件も外さず、判定だけ出す
  16  //   MIN_UNFOLLOW=30      その日のフォロー数が読めないときの下限
  17  //   MAX_UNFOLLOW=60      1 回に外す絶対上限（暴走よけ）
  18  //   GRACE_DAYS=7         フォローしてからこの日数 未満は触らない
  19  //   INACTIVE_DAYS=30     最終投稿がこれより前なら「休眠」
  20  //   BIG_FOLLOWERS=5000   これ以上なら「大きいアカウント」
  21  //   MAX_PROFILE_READS=40 プロフィールを開く上限（時間の暴走よけ）
  22  const { chromium } = require("playwright-core");
  23  const fs = require("fs");
  24  const path = require("path");
  25  
  26  const WS = process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace");
  27  const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
  28  const DRY = process.env.DRY_RUN === "1";
  29  const MINN = Number(process.env.MIN_UNFOLLOW || 30);
  30  const MAXN = Number(process.env.MAX_UNFOLLOW || 60);
  31  const GRACE_DAYS = Number(process.env.GRACE_DAYS || 7);
  32  const INACTIVE_DAYS = Number(process.env.INACTIVE_DAYS || 30);
  33  const BIG = Number(process.env.BIG_FOLLOWERS || 5000);
  34  const MAX_READS = Number(process.env.MAX_PROFILE_READS || 40);
  35  // **一覧の取得と判定を分ける**（2026-09-27）。
  36  // まとめて走らせると 900 秒 の上限に当たって打ち切られ、出力が 1 行も残らなかった。
  37  //   MODE=collect  一覧だけ取ってキャッシュに書いて終わる（スクロールが重い）
  38  //   MODE=decide   キャッシュを読んで判定する（プロフィールを開く分が重い）
  39  //   MODE 未指定   従来どおり通しで走る
  40  const MODE = String(process.env.MODE || "all").toLowerCase();
  41  const CACHE_MAX_H = Number(process.env.CACHE_MAX_H || 6);
  42  // **1 本の scrapeList に持ち時間を持たせる。** 無いと片方で使い切る
  43  const LIST_BUDGET_S = Number(process.env.LIST_BUDGET_S || 150);
  44  // **プロフィールを開く側にも持ち時間を持たせる。**
  45  // `readProfile` は 1 件 30 秒 のタイムアウトを持つので、詰まると
  46  // 40 件 × 30 秒 で 900 秒 を超える。2026-09-27 に実際に打ち切られた
  47  const DECIDE_BUDGET_S = Number(process.env.DECIDE_BUDGET_S || 200);
  48  // **片思いは「反応をくれた人」でも外す**（既定 on。0 で従来に戻る）
  49  const ONEWAY_IGNORE_ENGAGED = process.env.ONEWAY_IGNORE_ENGAGED !== "0";
  50  
  51  const LOG = path.join(WS, "logs", "follow-balance.log");
  52  const STATE = path.join(WS, "data", "follow-balance-state.json");
  53  const ENGAGED = path.join(WS, "data", "reply-followers.json");
  54  const FOLLOWED = path.join(WS, "data", "followed.json");
  55  const LISTS = path.join(WS, "data", "follow-balance-lists.json");
  56  // **「そもそもフォローしていない」と分かった相手を覚える。**
  57  // 走査に「おすすめユーザー」が混ざるため、毎回 同じ相手にプロフィールを開いて
  58  // 約 12 秒 ずつ捨てていた（2026-09-28 に 9 件 で 114 秒）。**二度 見ない。**
  59  const NOTFOLLOW = path.join(WS, "data", "follow-balance-notfollowing.json");
  60  
  61  const FOLLOWING_RE = /^(フォロー中|Following)$/;
  62  const FOLLOW_RE = /^(フォロー|フォローする|Follow|Follow back|フォローバック)$/;
  63  
  64  function log(msg) {
  65    const line = "[" + new Date().toISOString() + "] " + msg;
  66    console.log(line);
  67    try { fs.appendFileSync(LOG, line + "\n"); } catch (e) {}
  68  }
  69  
  70  function loadWhitelist() {
  71    const out = new Set();
  72    for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
  73      try {
  74        const d = JSON.parse(fs.readFileSync(path.join(WS, p), "utf8"));
  75        const arr = Array.isArray(d) ? d : (d.handles || d.whitelist || Object.keys(d));
  76        for (const h of arr) out.add(String(h).replace(/^@/, "").toLowerCase());
  77      } catch (e) {}
  78    }
  79    return out;
  80  }
  81  
  82  // **どんな形で入っていても handle と followed_at を拾う。**
  83  // followed.json は {キー: {handle, followed_at}} の入れ子で、素朴に読むと 0 件になる
  84  // （2026-09-27 に実際そうなった）。**形を決め打ちしない。**
  85  function harvest(file) {
  86    const byHandle = new Map();
  87    let root;
  88    try { root = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { return byHandle; }
  89    const seen = new Set();
  90    const walk = (node, keyHint) => {
  91      if (!node || typeof node !== "object" || seen.has(node)) return;
  92      seen.add(node);
  93      if (Array.isArray(node)) { for (const v of node) walk(v, null); return; }
  94      const at = node.followed_at || node.at || node.created_at || node.followedAt;
  95      // **容器のキーを handle と見なさない。** 入れ子の {handles:{0:{...}}} で
  96      // "handles" を 1 件 数えてしまった（2026-09-27 のローカル検証で発見）。
  97      // **日付の有無では切らない**——日付が無い記録まで落ちて、守る側が弱くなる。
  98      // 中に子オブジェクトを持つものが容器、持たないものが記録、と見る。
  99      const isLeaf = !Object.values(node).some((v) => v && typeof v === "object");
 100      const h = node.handle || node.screen_name || node.username || (isLeaf ? keyHint : null);
 101      if (h && typeof h === "string" && /^[A-Za-z0-9_]{1,15}$/.test(h.replace(/^@/, ""))) {
 102        const k = h.replace(/^@/, "").toLowerCase();
 103        const prev = byHandle.get(k);
 104        if (!prev || (at && !prev.at)) byHandle.set(k, { at: at || (prev && prev.at) || null });
 105      }
 106      for (const [k, v] of Object.entries(node)) walk(v, typeof k === "string" ? k : null);
 107    };
 108    walk(root, null);
 109    return byHandle;
 110  }
 111  
 112  function parseCount(s) {
 113    if (!s) return null;
 114    const t = String(s).replace(/[\s,]/g, "");
 115    const m = t.match(/([0-9]+(?:\.[0-9]+)?)(万|億|K|M|k|m)?/);
 116    if (!m) return null;
 117    let n = parseFloat(m[1]);
 118    if (!isFinite(n)) return null;
 119    const u = m[2];
 120    if (u === "万") n *= 10000;
 121    else if (u === "億") n *= 100000000;
 122    else if (u === "K" || u === "k") n *= 1000;
 123    else if (u === "M" || u === "m") n *= 1000000;
 124    return Math.round(n);
 125  }
 126  
 127  async function scrapeList(page, url, want) {
 128    const seen = new Set();
 129    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
 130    await page.waitForTimeout(4000);
 131    let stable = 0, last = 0;
 132    // **持ち時間を超えたら、そこまでで返す。** want は実数より大きく置いてあるので
 133    // 終了条件は実質「6 回 変化なし」だけだった。それだけだと時間が読めない
 134    const deadline = Date.now() + LIST_BUDGET_S * 1000;
 135    while (seen.size < want && stable < 6) {
 136      if (Date.now() > deadline) { log("  ⏱ " + LIST_BUDGET_S + " 秒 を超えたので打ち切る（" + seen.size + " 件）"); break; }
 137      const got = await page.evaluate(() => {
 138        // **2026-09-28: `primaryColumn` に限る変更で 0 件 になったので戻した。**
 139        // 診断は正しかった（ヘッダーの実数 239 に対し、この走査は 271〜275 を返す）。
 140        // **だが直し方が間違っていた。** セレクタの当たり方を実物で確かめてから直す。
 141        //
 142        // **混ざっても害は出ないようにしてある** —— 押す直前に
 143        // 「`-follow` しか無い＝フォローしていない」を見て押さない門が在る。
 144        const all = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
 145        const out = [];
 146        for (const el of all) {
 147          const m = (el.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
 148          if (m && !["home", "explore", "notifications", "messages", "i"].includes(m[1])) out.push(m[1]);
 149        }
 150        // --- 診断: 次に直すための材料を出す（1 回だけ） ---
 151        if (!window.__fbDiag) {
 152          window.__fbDiag = true;
 153          const pc = document.querySelector('[data-testid="primaryColumn"]');
 154          const cells = Array.from(document.querySelectorAll("[data-testid=UserCell]"));
 155          const inPc = pc ? cells.filter((c) => pc.contains(c)).length : -1;
 156          const labels = Array.from(document.querySelectorAll("[aria-label]"))
 157            .map((e) => e.getAttribute("aria-label"))
 158            .filter((x) => x && x.length < 40).slice(0, 12);
 159          out.__diag = JSON.stringify({
 160            primaryColumn: !!pc,
 161            cells: cells.length,
 162            cells_in_primaryColumn: inPc,
 163            sample_aria_labels: labels,
 164          });
 165        }
 166        return out;
 167      });
 168      if (got.__diag) log("  [診断] " + got.__diag);
 169      got.forEach((h) => seen.add(h));
 170      if (seen.size === last) stable++; else stable = 0;
 171      last = seen.size;
 172      await page.mouse.wheel(0, 2600);
 173      await page.waitForTimeout(1200);
 174    }
 175    return seen;
 176  }
 177  
 178  async function readProfile(page, handle) {
 179    // **タイムアウトは短く。** 1 件で 30 秒 待つと 40 件で 20 分 になる
 180    await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 12000 });
 181    await page.waitForTimeout(4700 + Math.floor(Math.random() * 1500));   // x219: 続けて開きすぎると X が空のページを返す（2.2 秒 → 4.7〜6.2 秒）
 182    return await page.evaluate(() => {
 183      const res = { followersText: null, lastPost: null, verified: false };
 184      const a = document.querySelector('a[href$="/verified_followers"]') ||
 185                document.querySelector('a[href$="/followers"]');
 186      if (a) res.followersText = (a.innerText || "").trim();
 187      const ts = Array.from(document.querySelectorAll("article time[datetime]"))
 188        .map((t) => t.getAttribute("datetime")).filter(Boolean);
 189      if (ts.length) {
 190        const ms = ts.map((x) => new Date(x).getTime()).filter((n) => isFinite(n) && n > 0);
 191        if (ms.length) res.lastPost = new Date(Math.max.apply(null, ms)).toISOString();
 192      }
 193      res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
 194      return res;
 195    });
 196  }
 197  
 198  (async () => {
 199    log("=== follow-balance start (dry=" + DRY + " min=" + MINN + " max=" + MAXN +
 200        " grace=" + GRACE_DAYS + "d inactive=" + INACTIVE_DAYS + "d big=" + BIG + ") ===");
 201  
 202    let b;
 203    try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
 204    catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
 205    const ctx = b.contexts()[0];
 206    if (!ctx) { log("context が無い。何もしない。"); return; }
 207    const page = await ctx.newPage();
 208  
 209    let me = null;
 210    try {
 211      await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
 212      await page.waitForTimeout(3000);
 213      if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); process.exit(0); }
 214      me = await page.evaluate(() => {
 215        const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
 216        const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
 217        return m ? m[1] : null;
 218      });
 219    } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); process.exit(0); }
 220    if (!me) { log("**自分のハンドルが読めない。何もしない。**"); await page.close(); process.exit(0); }
 221  
 222    let following, followers;
 223    if (MODE === "decide") {
 224      // **キャッシュから読む。** 取り直さないので速い
 225      let c;
 226      try { c = JSON.parse(fs.readFileSync(LISTS, "utf8")); }
 227      catch (e) { log("**一覧のキャッシュが読めない。MODE=collect を先に走らせる。** " + String(e.message).slice(0, 80)); await page.close(); process.exit(0); }
 228      const ageH = (Date.now() - new Date(c.at || 0).getTime()) / 3600000;
 229      if (!isFinite(ageH) || ageH > CACHE_MAX_H) {
 230        log("**キャッシュが古い（" + (isFinite(ageH) ? ageH.toFixed(1) : "?") + " 時間）。取り直しが要る。**");
 231        await page.close(); process.exit(0);
 232      }
 233      following = new Set(c.following || []);
 234      followers = new Set(c.followers || []);
 235      log("キャッシュから読んだ（" + ageH.toFixed(1) + " 時間 前）: フォロー中 " + following.size + " / フォロワー " + followers.size);
 236      if (following.size === 0) { log("**キャッシュが空。何もしない。**"); await page.close(); process.exit(0); }
 237    } else {
 238      const t0 = Date.now();
 239      following = await scrapeList(page, "https://x.com/" + me + "/following", 800);
 240      const t1 = Date.now();
 241      log("フォロー中: " + following.size + " 件（" + Math.round((t1 - t0) / 1000) + " 秒）");
 242      if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); process.exit(0); }
 243      followers = await scrapeList(page, "https://x.com/" + me + "/followers", 1000);
 244      const t2 = Date.now();
 245      log("フォロワー: " + followers.size + " 件（" + Math.round((t2 - t1) / 1000) + " 秒）");
 246  
 247      // **取れたら必ず書く。** collect でも all でも残す
 248      try {
 249        fs.writeFileSync(LISTS, JSON.stringify({
 250          at: new Date().toISOString(), me,
 251          following: [...following], followers: [...followers],
 252          secs: { following: Math.round((t1 - t0) / 1000), followers: Math.round((t2 - t1) / 1000) },
 253        }, null, 2));
 254        JSON.parse(fs.readFileSync(LISTS, "utf8"));   // **書いた JSON を自分で読み直す**
 255        log("一覧を書いた: " + path.basename(LISTS));
 256      } catch (e) { log("一覧を書けない: " + String(e.message).slice(0, 80)); }
 257  
 258      if (MODE === "collect") {
 259        log("=== MODE=collect なのでここで終わる（判定はしない） ===");
 260        await page.close(); process.exit(0);
 261      }
 262    }
 263  
 264    const lowerFollowers = new Set([...followers].map((h) => h.toLowerCase()));
 265    const wl = loadWhitelist();
 266    // **覚えている「未フォロー」を読む。** 壊れていたら空で続ける（fail-open）
 267    let notFollowSet = new Set();
 268    try {
 269      const raw = JSON.parse(fs.readFileSync(NOTFOLLOW, "utf8"));
 270      for (const h of (Array.isArray(raw) ? raw : Object.keys(raw || {}))) {
 271        notFollowSet.add(String(h).replace(/^@/, "").toLowerCase());
 272      }
 273    } catch (e) { notFollowSet = new Set(); }
 274    if (notFollowSet.size) log("覚えている未フォロー: " + notFollowSet.size + " 件（今回は見ない）");
 275    const engaged = harvest(ENGAGED);
 276    const followedMap = harvest(FOLLOWED);
 277    log("ホワイトリスト " + wl.size + " 件 / 反応の記録 " + engaged.size + " 件 / フォロー日時の記録 " + followedMap.size + " 件");
 278  
 279    // **その日にフォローした数。** 読めなければ下限を使う
 280    const now = Date.now();
 281    const jstDay = (ms) => new Date(ms + 9 * 3600 * 1000).toISOString().slice(0, 10);
 282    const today = jstDay(now);
 283    let followedToday = 0;
 284    for (const [, v] of followedMap) {
 285      if (!v.at) continue;
 286      const t = new Date(v.at).getTime();
 287      if (isFinite(t) && jstDay(t) === today) followedToday++;
 288    }
 289    // **フォロワーより フォローが少ない状態を保つ**（2026-09-28 に利用者が指示）。
 290    //   「フォロー数よりフォロワー数が多い方が圧倒的に魅力なアカウントに見える」
 291    //
 292    // **走査の数は使わない。** おすすめユーザーが混ざって 17〜21 件 多く出る
 293    // （9/28 実測: 走査 190 / ヘッダーの実数 173）。多いと思い込んで外しすぎる。
 294    // **X が表示しているヘッダーの数だけを使い、読めなければ比率を見ない**（fail-open）。
 295    const CEIL_RATIO = Number(process.env.FOLLOW_RATIO_CEIL || 0.65);
 296    const FLOOR_RATIO = Number(process.env.FOLLOW_RATIO_FLOOR || 0.45);
 297    // **目標。ここへ寄せる**（2026-09-28 に指示を受けた時点の比率）。
 298    // 「今日 何件 増えたか」を数えるのをやめた。`followed.json` の件数が
 299    // ファネルの実績（10〜24 件/日）と合っておらず、数え間違いに引きずられるため。
 300    // **いま何件 居るかはヘッダーで分かる。目標より多い分だけ外す。**
 301    const TARGET_RATIO = Number(process.env.FOLLOW_RATIO_TARGET || 0.58);
 302    let hdr = null;
 303    try {
 304      await page.goto("https://x.com/" + me, { waitUntil: "domcontentloaded", timeout: 30000 });
 305      await page.waitForTimeout(4500);
 306      hdr = await page.evaluate(() => {
 307        const pick = (sel) => {
 308          const a = document.querySelector(sel);
 309          return a ? ((a.querySelector("span span") || a).textContent || "").trim() : null;
 310        };
 311        const toN = (x) => {
 312          if (!x) return null;
 313          const s = String(x).replace(/,/g, "");
 314          if (/万/.test(s)) return Math.round(parseFloat(s) * 10000);
 315          if (/[kK]/.test(s)) return Math.round(parseFloat(s) * 1000);
 316          const n = parseInt(s, 10);
 317          return Number.isFinite(n) ? n : null;
 318        };
 319        return {
 320          following: toN(pick('a[href$="/following"]')),
 321          followers: toN(pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]')),
 322        };
 323      });
 324    } catch (e) { hdr = null; }
 325  
 326    let quota = Math.min(MAXN, Math.max(MINN, followedToday));
 327    let ratioNote = "ヘッダーが読めないので比率を見ない";
 328    if (hdr && Number.isFinite(hdr.following) && Number.isFinite(hdr.followers) && hdr.followers > 0) {
 329      const ceilN = Math.floor(hdr.followers * CEIL_RATIO);
 330      const floorN = Math.floor(hdr.followers * FLOOR_RATIO);
 331      const over = hdr.following - ceilN;
 332      log("実数（ヘッダー）: フォロー中 " + hdr.following + " / フォロワー " + hdr.followers +
 333          " → 比率 " + (hdr.following / hdr.followers).toFixed(3) +
 334          "（目標 " + Math.floor(hdr.followers * TARGET_RATIO) + " 件 / 警戒 " + ceilN +
 335          " 件 / 下限 " + floorN + " 件）");
 336      const targetN = Math.floor(hdr.followers * TARGET_RATIO);
 337      if (hdr.following <= floorN) {
 338        quota = 0;
 339        ratioNote = "**下限 " + floorN + " 件 以下。外しすぎなので今回は外さない**";
 340      } else {
 341        // **目標より多い分だけ外す。** 今日の増分は数えない（記録に依存しない）
 342        quota = Math.min(MAXN, Math.max(0, hdr.following - targetN));
 343        if (quota === 0) {
 344          ratioNote = "**目標 " + targetN + " 件 以内。外さない**";
 345        } else if (over > 0) {
 346          ratioNote = "**警戒線 " + ceilN + " 件 を超えている。目標 " + targetN +
 347            " 件 まで戻す（あと " + (hdr.following - targetN) + " 件 / 今回 " + quota + " 件）**";
 348        } else {
 349          ratioNote = "**目標 " + targetN + " 件 へ寄せる（あと " + (hdr.following - targetN) +
 350            " 件 / 今回 " + quota + " 件）**";
 351        }
 352      }
 353    } else {
 354      log("**ヘッダーの実数が読めなかった。比率の判定をしない**（従来どおりの上限で動く）");
 355    }
 356    log("今日フォローした数: " + followedToday + " 件 → **今回の上限 " + quota + " 件**（" +
 357        ratioNote + " / 絶対上限 " + MAXN + "）");
 358    if (quota <= 0) {
 359      log("**外す必要が無い。ここで終わる。**");
 360      try { await page.close(); } catch (e) {}
 361      process.exit(0);
 362    }
 363  
 364    const ageDays = (h) => {
 365      const e = followedMap.get(h.toLowerCase()) || engaged.get(h.toLowerCase());
 366      if (!e || !e.at) return null;
 367      const t = new Date(e.at).getTime();
 368      return isFinite(t) ? (now - t) / 86400000 : null;
 369    };
 370    // **片思いのときは「反応をくれた人」で守らない**（2026-09-27 に利用者が選択）。
 371    // 相手はこちらをフォローしていないので、過去に反応があっても外してよい。
 372    // **相互は今までどおり守る。** ホワイトリストと猶予は片思いでも効かせる
 373    const protectedWhy = (h, oneWayStage) => {
 374      const k = h.toLowerCase();
 375      if (wl.has(k)) return "ホワイトリスト";
 376      if (engaged.has(k) && !(oneWayStage && ONEWAY_IGNORE_ENGAGED)) return "反応をくれた人";
 377      const d = ageDays(h);
 378      if (d !== null && d < GRACE_DAYS) return "フォローしてまだ " + Math.floor(d) + " 日（猶予 " + GRACE_DAYS + " 日）";
 379      return null;
 380    };
 381  
 382    // ① 片思い（フォロバが無い）。**いま誰も担当していない**
 383    // **覚えている未フォローは、そもそも一覧から除く。** 片思いにも相互にも入れない
 384    const knownNot = (h) => notFollowSet.has(String(h).toLowerCase());
 385    const followingReal = [...following].filter((h) => !knownNot(h));
 386    if (following.size !== followingReal.length) {
 387      log("走査 " + following.size + " 件 から 未フォロー " +
 388          (following.size - followingReal.length) + " 件 を除いた → " + followingReal.length + " 件");
 389    }
 390    const oneWay = followingReal.filter((h) => !lowerFollowers.has(h.toLowerCase()));
 391    // 相互（②③ の対象）
 392    const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
 393    log("片思い: " + oneWay.length + " 件 / 相互: " + mutual.length + " 件");
 394  
 395    const cuts = [];
 396    const kept = { ホワイトリスト: 0, "反応をくれた人": 0, 猶予: 0 };
 397    const noteKeep = (why) => {
 398      if (/ホワイトリスト/.test(why)) kept["ホワイトリスト"]++;
 399      else if (/反応/.test(why)) kept["反応をくれた人"]++;
 400      else kept["猶予"]++;
 401    };
 402  
 403    // ① 片思い。プロフィールを開かずに決められるので速い
 404    for (const h of oneWay) {
 405      if (cuts.length >= quota) break;
 406      const why = protectedWhy(h, true);   // ← 片思いの段
 407      if (why) { noteKeep(why); continue; }
 408      cuts.push({ h, why: "返していない（片思い）", rank: 1 });
 409    }
 410    log("① 片思いから " + cuts.length + " 件");
 411  
 412    // ②③ 足りなければ相互を見る。**ここだけプロフィールを開く**
 413    let reads = 0;
 414    let timeUp = false;
 415    if (cuts.length < quota) {
 416      const dl2 = Date.now() + DECIDE_BUDGET_S * 1000;
 417      for (const h of mutual) {
 418        if (cuts.length >= quota || reads >= MAX_READS) break;
 419        if (Date.now() > dl2) { timeUp = true; break; }
 420        const why = protectedWhy(h, false);  // ← 相互の段。反応は守る
 421        if (why) { noteKeep(why); continue; }
 422        let p;
 423        try { p = await readProfile(page, h); reads++; }
 424        catch (e) { continue; }
 425        if (p.verified) continue;
 426        const fc = parseCount(p.followersText);
 427        const idle = p.lastPost ? Math.floor((now - new Date(p.lastPost).getTime()) / 86400000) : null;
 428        if (idle !== null && idle >= INACTIVE_DAYS) { cuts.push({ h, why: "休眠 " + idle + " 日", rank: 2 }); continue; }
 429        if (fc !== null && fc >= BIG) { cuts.push({ h, why: "大きいアカウント " + fc + " フォロワー", rank: 3 }); continue; }
 430      }
 431    }
 432    log("プロフィールを開いた: " + reads + " 件 / **外す候補 合計 " + cuts.length + " 件**" +
 433        (timeUp ? "（**" + DECIDE_BUDGET_S + " 秒 で打ち切った。相互を見切れていない**）" : ""));
 434    log("守った内訳: ホワイトリスト " + kept["ホワイトリスト"] + " / 反応をくれた人 " + kept["反応をくれた人"] + " / 猶予 " + kept["猶予"]);
 435    for (const c of cuts) log("  ✂ @" + c.h + " — " + c.why);
 436  
 437    if (DRY) {
 438      log("**DRY_RUN。1 件も外していない。**");
 439      await page.close();
 440      process.exit(0);
 441      return;
 442    }
 443  
 444    let state = {};
 445    try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
 446    let done = 0;
 447    let notF = 0;   // **一覧に混ざっていた「そもそもフォローしていない」人の数**
 448    for (const c of cuts) {
 449      const h = c.h;
 450      try {
 451        await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
 452        // x219: 空のページは開き直す（2026-10-03。下調べで続けて開いたあと、本文が空のページが返り 0 件になっていた）
 453        const x219Ready = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 15000 }).then(() => true).catch(() => false);
 454        if (!(await x219Ready())) {
 455          log("  @" + h + ": ページが空。開き直す");
 456          await page.reload({ waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {});
 457          await x219Ready();
 458        }
 459        await page.waitForTimeout(1500);
 460        const findBtn = () => page.evaluate(() => {
 461          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
 462          for (const b of bs) {
 463            const t = b.getAttribute("data-testid") || "";
 464            if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
 465          }
 466          for (const b of bs) {
 467            const x = (b.innerText || "").trim();
 468            if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid") || "", text: x };
 469          }
 470          return null;
 471        });
 472        // **固定待ちで 1 回 見るだけだと、描画前に「無い」と判定する。**
 473        // 2026-09-27 の本番初回で、8 件 中 4 件 が **約 4 秒** で「ボタンが無い」になった
 474        // （外れた 2 件 は 7〜10 秒 かかっている）。**出るまで待つ。**
 475        let btn = null;
 476        for (let w = 0; w < 12; w++) {
 477          btn = await findBtn();
 478          if (btn) break;
 479          await page.waitForTimeout(900);
 480        }
 481        if (!btn) {
 482          // **「無い」と決める前に、なぜ無いのかを出す。**
 483          // 凍結・削除・鍵・そもそも読み込めていない、を区別できないと直せない
 484          const why = await page.evaluate(() => {
 485            const t = (document.body && document.body.innerText || "").slice(0, 400);
 486            const seen = Array.from(document.querySelectorAll("button,[role=button]"))
 487              .map((b) => (b.getAttribute("data-testid") || "?") + ":" + (b.innerText || "").trim().slice(0, 10))
 488              .filter((x) => /follow/i.test(x)).slice(0, 4).join(" | ");
 489            return {
 490              path: location.pathname,
 491              suspended: /凍結|suspended/i.test(t),
 492              notfound: /存在しません|doesn.t exist|Account not found/i.test(t),
 493              locked: /鍵アカウント|protected|posts are protected/i.test(t),
 494              empty: t.length < 40,
 495              follow_btns: seen || "(無し)",
 496            };
 497          }).catch(() => null);
 498          // **`-follow`（＝「フォロー」）しか無いなら、そもそもフォローしていない。**
 499          // 一覧の取り込み間違い。**押す対象ではないので、そう書く。**
 500          const notFollowing = !!(why && !why.suspended && !why.notfound && !why.locked &&
 501                                  !why.empty && /-follow:/.test(String(why.follow_btns || "")) &&
 502                                  !/-unfollow:/.test(String(why.follow_btns || "")));
 503          if (notFollowing) {
 504            notF++;
 505            notFollowSet.add(String(h).toLowerCase());
 506            try {
 507              fs.writeFileSync(NOTFOLLOW, JSON.stringify([...notFollowSet].sort(), null, 2));
 508              JSON.parse(fs.readFileSync(NOTFOLLOW, "utf8"));   // **書いた JSON を読み直す**
 509            } catch (e) { log("  （覚えられない: " + String(e.message).slice(0, 60) + "）"); }
 510            log("  @" + h + ": **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）");
 511          } else {
 512            log("  @" + h + ": フォロー中のボタンが無い" +
 513                (why ? " — " + JSON.stringify(why) : "（理由も取れない）"));
 514          }
 515          continue;
 516        }
 517        if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
 518          log("  @" + h + ": 「フォロー中」ではないので押さない: " + (btn.text || btn.testid));
 519          continue;
 520        }
 521        await page.evaluate(() => {
 522          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
 523          const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
 524                    bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
 525          if (t) t.click();
 526        });
 527        await page.waitForTimeout(1200);
 528        await page.evaluate(() => {
 529          const c2 = document.querySelector("[data-testid=confirmationSheetConfirm]");
 530          if (c2) c2.click();
 531        });
 532        await page.waitForTimeout(2500);
 533        const after = await page.evaluate(() => {
 534          const bs = Array.from(document.querySelectorAll("button,[role=button]"));
 535          const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
 536          return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
 537        });
 538        if (FOLLOW_RE.test(after)) {
 539          done++;
 540          state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
 541          log("  ✂ @" + h + " — 外れた（" + c.why + "）");
 542        } else {
 543          log("  @" + h + ": 押したが外れていない（" + after + "）");
 544        }
 545        await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
 546      } catch (e) {
 547        log("  @" + h + ": 例外 " + String(e.message).slice(0, 80));
 548      }
 549    }
 550    try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
 551    log("=== 外した: " + done + " 件 / 候補 " + cuts.length + " 件（今日のフォロー " + followedToday + " 件）" +
 552        (notF ? " / **一覧に混ざっていた未フォロー " + notF + " 件**" : "") + " ===");
 553    await page.close();
 554    // **`connectOverCDP` の接続が開いたままだと node は終わらない。**
 555    // 2026-09-27、実作業 63 秒 のあと約 280 秒 ぶら下がって打ち切られた（rc=124）。
 556    // `b.close()` は利用者の Chrome に触りうるので、明示的に抜ける
 557    process.exit(0);
 558  })();
```

## ② follow-balance-lists.json の形

```
  at: 2026-10-04T02:46:07.929Z
  me: heng_ji31590
  following: [配列 267 件]
  followers: [配列 328 件]
  secs: {2 キー}
  11611 bytes  Oct 4 11:46  follow-balance-lists.json
  793 bytes  Oct 3 22:28  follow-balance-notfollowing.json
  5273 bytes  Oct 4 11:51  follow-balance-state.json
```

## ③ reply-followers.json の形

```
  トップ: オブジェクト（キー＝ハンドル） ／ 623 件
  中のキー: followed_at(623), followback_status(623), scheduled_unfollow_at(598), source(623), comment_id(204), followback_judgment_at(591), still_following(349), follows_back(346), checked_at(346), unfollowed_at(293), unfollow_source(277), revenge_checked_at(63), seed_post_url(57), seed_engagement(57), late_followback_at(24), incoming_reply_id(15), revenge_check_error(1), unfollow_reason(5), followers_at_follow(266), following_at_follow(266), phase_at_follow(197)
  status=no 471 件 ／ うち外す予定日を過ぎた 371 件
```

**外していない。フォローしていない。設定を変えていない（$0／回・$0／日・$0／月）。**
