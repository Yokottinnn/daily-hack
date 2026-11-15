# 外すボタンの押し間違いを読む（2026-10-25 16:56:09 JST・読むだけ・$0）

## 1. 外す処理のコード（follow-balance.js・ボタンに関わる行の前後）
```
8://   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
12:// 結果、9/25 時点で `フォロー中 249 − 相互 173 = 76 件` の片思いが放置されていた。
61:const FOLLOWING_RE = /^(フォロー中|Following)$/;
72:  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
144:      const all = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
153:        const pc = document.querySelector('[data-testid="primaryColumn"]');
154:        const cells = Array.from(document.querySelectorAll("[data-testid=UserCell]"));
156:        const labels = Array.from(document.querySelectorAll("[aria-label]"))
157:          .map((e) => e.getAttribute("aria-label"))
193:    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
213:    { const ok = () => page.waitForSelector('[data-testid=AppTabBar_Profile_Link]', { timeout: 15000 }).then(() => true).catch(() => false);
217:      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
237:    log("キャッシュから読んだ（" + ageH.toFixed(1) + " 時間 前）: フォロー中 " + following.size + " / フォロワー " + followers.size);
243:    log("フォロー中: " + following.size + " 件（" + Math.round((t1 - t0) / 1000) + " 秒）");
346:    log("実数（ヘッダー）: フォロー中 " + hdr.following + " / フォロワー " + hdr.followers +
422:      if (!v || typeof v !== "object" || v.followback_status !== "no" || v.unfollowed_at || !v.scheduled_unfollow_at) continue;
423:      if (new Date(v.scheduled_unfollow_at).getTime() < now) x227Due.add(String(k).replace(/^@/, "").toLowerCase());
496:      const x219Ready = () => page.waitForSelector('[data-testid="UserName"], [data-testid="emptyState"]', { timeout: 15000 }).then(() => true).catch(() => false);
504:        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
506:          const t = b.getAttribute("data-testid") || "";
507:          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
511:          if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid") || "", text: x };
529:          const seen = Array.from(document.querySelectorAll("button,[role=button]"))
530:            .map((b) => (b.getAttribute("data-testid") || "?") + ":" + (b.innerText || "").trim().slice(0, 10))
543:        const notFollowing = !!(why && !why.suspended && !why.notfound && !why.locked &&
545:                                !/-unfollow:/.test(String(why.follow_btns || "")));
546:        if (notFollowing) {
555:          log("  @" + h + ": フォロー中のボタンが無い" +
560:      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
561:        log("  @" + h + ": 「フォロー中」ではないので押さない: " + (btn.text || btn.testid));
565:        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
566:        const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
567:                  bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
572:        const c2 = document.querySelector("[data-testid=confirmationSheetConfirm]");
577:        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
578:        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
579:        return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
583:        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
587:        log("  @" + h + ": 押したが外れていない（" + after + "）");
604:        rf[k].unfollowed_at = new Date().toISOString(); rf[k].unfollow_source = "follow-balance"; rf[k].unfollow_reason = u.why; wrote++;
```

## 2. 片思いの候補 1 件のプロフィールのボタン（押さない）
```
  testid=app-bar-back | aria=戻る | text=
  testid= | aria=プロフィールの要約 | text=
  testid= | aria=検索 | text=
  testid= | aria=新しいポストがあります。新しいポストに移動するには、ピリオドキーを押してください。 | text=新しいポストを表示
  testid=userActions | aria=もっと見る | text=
  testid=sendDMFromProfile | aria=メッセージ | text=
  testid= | aria=ポスト通知をオンにする | text=
  testid=1984853528851202054-unfollow | aria=フォロー中 @<伏せ> | text=フォロー中
  testid= | aria=認証済みアカウントについての詳細が表示されます。 | text=
  testid= | aria=前 | text=
  testid= | aria=次へ | text=
  testid= | aria=Grokのアクション | text=
  testid=caret | aria=もっと見る | text=
  testid=tweet-text-show-more-link | aria= | text=さらに表示
  testid=reply | aria=62 件の返信。返信する | text=62
  testid=retweet | aria=11 件のリポスト件。リポスト | text=11
  testid=like | aria=89 件のいいね。いいねする | text=89
  testid=bookmark | aria=ブックマーク | text=
  testid= | aria=ポストを共有 | text=
  testid= | aria=Grokのアクション | text=
  testid=caret | aria=もっと見る | text=
  testid= | aria=前 | text=
  testid= | aria=次へ | text=
  testid=reply | aria=10 件の返信。返信する | text=10
  testid=retweet | aria=2 件のリポスト件。リポスト | text=2
  testid=like | aria=22 件のいいね。いいねする | text=22
  testid=bookmark | aria=ブックマーク | text=
  testid= | aria=ポストを共有 | text=
  testid= | aria=Grokのアクション | text=
  testid=caret | aria=もっと見る | text=
  testid=tweet-text-show-more-link | aria= | text=さらに表示
  testid=reply | aria=45 件の返信。返信する | text=45
  testid=retweet | aria=5 件のリポスト件。リポスト | text=5
  testid=like | aria=60 件のいいね。いいねする | text=60
  testid=bookmark | aria=ブックマーク | text=
  testid= | aria=ポストを共有 | text=
  testid= | aria=Grokのアクション | text=
  testid=caret | aria=もっと見る | text=
  testid=reply | aria=36 件の返信。返信する | text=36
  testid=retweet | aria=5 件のリポスト件。リポスト | text=5
```

**押していない・外していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
