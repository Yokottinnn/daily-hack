# parse-main-result の原因を読む（2026-10-24 21:53:09 JST・$0）
## 1. run-publish.sh の単発経路の後半（行番号つき・170 行目から最後まで）
```
   170	ERR_TMP=$(mktemp)
   171	# 2026-10-23 x332: IMAGE_PATH はカンマ区切りで最大 4 枚。旧判定 [ -f "$IMAGE_PATH" ] は 2 枚以上で偽になり、黙って画像なしで出していた
   172	IMG_STATE=$(IMAGE_PATH="$IMAGE_PATH" /usr/local/bin/node -e 'const fs=require("fs");const p=(process.env.IMAGE_PATH||"").split(",").map(s=>s.trim()).filter(Boolean);process.stdout.write(p.length===0?"none":(p.every(x=>fs.existsSync(x
   173	if [ "$IMG_STATE" = "missing" ]; then
   174	  echo '{"ok":false,"step":"image-missing","error":"image_path is set but some files are missing - refusing to post without images"}'
   175	  exit 1
   176	fi
   177	if [ "$IMG_STATE" = "ok" ]; then
   178	  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" "$IMAGE_PATH" 2>"$ERR_TMP")
   179	else
   180	  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" 2>"$ERR_TMP")
   181	fi
   182	if [ -s "$ERR_TMP" ]; then cat "$ERR_TMP" >&2; fi
   183	rm -f "$ERR_TMP"
   184	
   185	MAIN_OK=$(echo "$MAIN_RES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
   186	MAIN_URL=$(echo "$MAIN_RES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).url||'')}catch{console.log('')}})")
   187	
   188	THREAD_RES=""
   189	if [ "$MAIN_OK" = "true" ] && [ -n "$THREAD_TEXT" ] && [ -n "$MAIN_URL" ]; then
   190	  echo "[run-publish] thread_url_text present, sleeping 8s..." >&2
   191	  sleep 8
   192	  THREAD_TEXT_B64=$(printf "%s" "$THREAD_TEXT" | base64)
   193	  ERR_TMP2=$(mktemp)
   194	  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")
   195	  if [ -s "$ERR_TMP2" ]; then cat "$ERR_TMP2" >&2; fi
   196	  rm -f "$ERR_TMP2"
   197	  echo "[run-publish] thread reply: $THREAD_RES" >&2
   198	fi
   199	
   200	/usr/local/bin/node -e "
   201	let main;
   202	try {
   203	  const raw = process.env.MAIN_RES || '';
   204	  // 2026-07-19: log line が stdout 混入する場合対策 — LAST line で { で始まる ものを parse
   205	  const lines = raw.split(/\r?\n/).filter(x => x.trim().startsWith('{'));
   206	  const jsonLine = lines.length > 0 ? lines[lines.length - 1] : raw;
   207	  main = JSON.parse(jsonLine);
   208	}
   209	catch (e) { main = {ok:false, step:'parse-main-result', error:'main result not valid JSON', raw:(process.env.MAIN_RES||'').slice(0, 200)}; }
   210	const threadStr = process.env.THREAD_RES || '';
   211	const combined = {...main};
   212	if (threadStr) {
   213	  try { combined.thread = JSON.parse(threadStr); } catch (e) { combined.thread = {ok: false, raw: threadStr.slice(0, 200)}; }
   214	}
   215	console.log(JSON.stringify(combined));
   216	" MAIN_RES="$MAIN_RES" THREAD_RES="$THREAD_RES"
```
## 2. post-via-playwright.js の 255 行目から最後まで
```
   255	      const { spawn } = require("child_process");
   256	      const watchdog = spawn("/usr/local/bin/node", [require("path").join(__dirname, "post-publish-watchdog.js"), capturedTweetId], {
   257	        detached: true, stdio: "ignore", env: process.env,
   258	      });
   259	      watchdog.unref();
   260	    } catch (e) { /* watchdog spawn failure must not break main return */ }
   261	    out({
   262	      ok: true,
   263	      tweet_id: capturedTweetId,
   264	      url: `https://x.com/${X_PROFILE_USERNAME}/status/${capturedTweetId}`,
   265	      image_attached: imageAttached,
   266	      captured_via: capturedVia,
   267	    });
   268	  } catch (err) {
   269	    if (page) try { await page.close(); } catch {}
   270	    if (browser) try { await browser.close(); } catch {}
   271	    out({ ok: false, step, error: err.message });
   272	    process.exit(1);
   273	  }
   274	}
   275	
   276	main();
```
## 3. post-via-playwright.js の中の process.exit と out( の行
```
15:function out(obj) { console.log(JSON.stringify(obj)); }
22:  if (!arg) { out({ ok: false, error: "missing text arg (base64)" }); process.exit(1); }
26:    process.exit(1);
37:  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
44:    if (contexts.length === 0) { out({ ok: false, step, error: "no contexts" }); process.exit(1); }
97:        process.exit(1);
178:      process.exit(1);
251:      process.exit(1);
272:    process.exit(1);
```
**読んだだけ。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
