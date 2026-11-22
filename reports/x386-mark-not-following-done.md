# 「もうフォローしていない」を解除済みにする（2026-10-31 12:02:25 JST・$0）
```
入れた
構文 OK
--- 直したところ
88:      } else if (uo.status === "not_following") {
89-        // x386: もうフォローしていない相手は解除済みにする（印を付けないと毎時 先頭 20 件に居座る）
90-        e.followback_status = "unfollowed";
91-        e.unfollowed_at = new Date().toISOString();
92:        e.unfollow_note = "not_following（解除ボタンが無い・x386）";
93-        e.scheduled_unfollow_at = null;
94-        log(`@${r.handle}: already not following — marked done (x386)`);
95-      } else {
96-        log(`@${r.handle}: unfollow failed (${uo.reason || "unknown"})`);
97-      }
98-    } catch (e2) {
99-      log(`@${r.handle}: unfollow exec error: ${e2.message}`);
--- いま動いている回（直す前の中身で動いている。次の毎時から効く）
20507          02:21 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js
```
**LLM を呼んでいない（$0／回・$0／日・$0／月）。外していない。**
