# follow-balance の片思いの判定と除外（2026-10-17 15:17:19 JST・$0）
```javascript
5:// **部品は mutual-prune.js から写している。書き直して壊さない。**
10:// **なぜ要るか。** mutual-prune.js は「相互だけを対象にする。片思いは既存の別ジョブの担当」
12:// 結果、9/25 時点で `フォロー中 249 − 相互 173 = 76 件` の片思いが放置されていた。
18://   GRACE_DAYS=7         フォローしてからこの日数 未満は触らない
31:const GRACE_DAYS = Number(process.env.GRACE_DAYS || 7);
48:// **片思いは「反応をくれた人」でも外す**（既定 on。0 で従来に戻る）
53:const ENGAGED = path.join(WS, "data", "reply-followers.json");
55:const LISTS = path.join(WS, "data", "follow-balance-lists.json");
72:  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
75:      const arr = Array.isArray(d) ? d : (d.handles || d.whitelist || Object.keys(d));
183:    const res = { followersText: null, lastPost: null, verified: false };
184:    const a = document.querySelector('a[href$="/verified_followers"]') ||
185:              document.querySelector('a[href$="/followers"]');
186:    if (a) res.followersText = (a.innerText || "").trim();
193:    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
200:      " grace=" + GRACE_DAYS + "d inactive=" + INACTIVE_DAYS + "d big=" + BIG + ") ===");
224:  let following, followers;
236:    followers = new Set(c.followers || []);
237:    log("キャッシュから読んだ（" + ageH.toFixed(1) + " 時間 前）: フォロー中 " + following.size + " / フォロワー " + followers.size);
245:    followers = await scrapeList(page, "https://x.com/" + me + "/followers", 1000);
247:    log("フォロワー: " + followers.size + " 件（" + Math.round((t2 - t1) / 1000) + " 秒）");
253:        following: [...following], followers: [...followers],
254:        secs: { following: Math.round((t1 - t0) / 1000), followers: Math.round((t2 - t1) / 1000) },
266:  const lowerFollowers = new Set([...followers].map((h) => h.toLowerCase()));
323:        followers: toN(pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]')),
330:  if (hdr && Number.isFinite(hdr.following) && Number.isFinite(hdr.followers) && hdr.followers > 0) {
336:        const f = hdr.followers; let t = pts[0][1];
343:    const ceilN = Math.floor(hdr.followers * CEIL_RATIO);
344:    const floorN = Math.floor(hdr.followers * FLOOR_RATIO);
346:    log("実数（ヘッダー）: フォロー中 " + hdr.following + " / フォロワー " + hdr.followers +
347:        " → 比率 " + (hdr.following / hdr.followers).toFixed(3) +
348:        "（目標 " + Math.floor(hdr.followers * TARGET_RATIO) + " 件 / 警戒 " + ceilN +
350:    const targetN = Math.floor(hdr.followers * TARGET_RATIO);
356:      // 2026-10-14 x289: 片思い（猶予を過ぎて返っていない）は比率に関係なく毎回 上限まで外す（利用者の指摘）。
357:      // 比率が目標以内でも片思いを残さない。目標を超えていれば、その分も同じ上限の中で外す
386:  // **片思いのときは「反応をくれた人」で守らない**（2026-09-27 に利用者が選択）。
388:  // **相互は今までどおり守る。** ホワイトリストと猶予は片思いでも効かせる
394:    if (d !== null && d < GRACE_DAYS) return "フォローしてまだ " + Math.floor(d) + " 日（猶予 " + GRACE_DAYS + " 日）";
398:  // ① 片思い（フォロバが無い）。**いま誰も担当していない**
399:  // **覚えている未フォローは、そもそも一覧から除く。** 片思いにも相互にも入れない
408:  const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
409:  log("片思い: " + oneWay.length + " 件 / 相互: " + mutual.length + " 件");
410:  // x227: 外された人（前回はフォロワー・今回いない）と、フォロバ判定で外す予定日を過ぎた人を、片思いの先頭に並べる（2026-10-04 に指示）
411:  const FPREV = path.join(WS, "data", "follow-balance-followers-prev.json");
413:  const fComplete = !!(hdr && Number.isFinite(hdr.followers) && followers.size >= hdr.followers);
415:  try { prevF = new Set((JSON.parse(fs.readFileSync(FPREV, "utf8")).followers || []).map((x) => String(x).toLowerCase())); } catch (e) { prevF = null; }
428:  const x227Why = (h) => { const r = x227Rank(h); return r === 0 ? "外された（前回はフォロワー・今回いない）" : r === 1 ? "フォロバ無し・外す予定日を過ぎた" : "返していない（片思い）"; };
431:      (fComplete ? (prevF ? "" : "（前回の記録が無い。今回は記録だけ）") : "（フォロワーを読み切れていない " + followers.size + " / " + (hdr && hdr.followers) + "。比べない）") +
432:      " / 外す予定日を過ぎたフォロバ無し: 記録 " + x227Due.size + " 件 → いまも片思い " + oneWay.filter((h) => x227Due.has(h.toLowerCase())).length + " 件");
434:    try { fs.writeFileSync(FPREV, JSON.stringify({ at: new Date().toISOString(), followers: [...followers] })); JSON.parse(fs.readFileSync(FPREV, "utf8")); }
446:  // ① 片思い。プロフィールを開かずに決められるので速い
449:    const why = protectedWhy(h, true);   // ← 片思いの段
453:  log("① 片思いから " + cuts.length + " 件");
460:    for (const h of mutual) {
468:      if (p.verified) continue;
469:      const fc = parseCount(p.followersText);
595:  // x227: 外した人を reply-followers.json にも書く（フォロバ判定の側が「外す予定」を持ち続けないように）
609:      log("reply-followers.json に反映: " + wrote + " 件");
610:    } catch (e) { log("reply-followers.json に反映できない: " + String(e.message).slice(0, 80)); }
```

## follow-balance.log の「外した」行の形（直近 6 行・伏せ）
```
[2026-10-17T02:50:41.095Z]   ✂ @<伏せ> — 外れた（返していない（片思い））
[2026-10-17T02:50:41.095Z]   ✂ @<伏せ> — 外れた（返していない（片思い））
[2026-10-17T02:50:50.717Z]   ✂ @<伏せ> — 外れた（返していない（片思い））
[2026-10-17T02:50:50.717Z]   ✂ @<伏せ> — 外れた（返していない（片思い））
[2026-10-17T02:51:03.292Z] === 外した: 7 件 / 候補 12 件（今日のフォロー 16 件） / **一覧に混ざっていた未フォロー 3 件** ===
[2026-10-17T02:51:03.292Z] === 外した: 7 件 / 候補 12 件（今日のフォロー 16 件） / **一覧に混ざっていた未フォロー 3 件** ===
```
**読むだけ。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
