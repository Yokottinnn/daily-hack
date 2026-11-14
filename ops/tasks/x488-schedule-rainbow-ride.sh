#!/bin/bash
# **11/23 お台場・有明の交通規制（レインボーライド）の告知を 11/18（水）12:00 JST に 1 回だけ出す予約（x488）。費用 $0。**
# 利用者（2026-11-15 01:0x JST チャット）:「11/23 お台場・有明の交通規制（レインボーライド）／この投稿水曜日に予約投稿して」。水曜日＝11/18。
# 時刻の指定は無いので、決まりの既定 12:00（CLAUDE.md 最上位ルール 4）。2 投稿のスレッド。[1/2] は長文（冒頭＋👇＋本体・青バッジ）、画像 2 枚（主催者のチラシ・要点）。ALT は panels.json から。
POST_APPROVAL_QUOTE="この投稿水曜日に予約投稿して"
POST_APPROVAL_AT="2026-11-15 01:0x JST（チャット）"
POST_SET_KEY="news-rainbow-ride"
#
# ジョブの名前は com.dailyhack.publish-<slug>-oneshot（ai.openclaw.* は tab-guard の全停止で外れる・2026-11-04）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。常駐させない。ハンドルと秘密は伏せる。**
set -uo pipefail
SCHED_JST="2026-11-18 12:00"
ID="x-blog-20261118-rainbow-ride"
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"
LABEL="com.dailyhack.publish-rainbow-ride-oneshot"; UID_N="$(id -u)"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="rainbow-ride-traffic-restrictions-2026"
IMGDIR="$D/x-$SLUG"; SRCDIR="public/images/$SLUG/x"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x488-schedule-rainbow-ride.md"
LOG="$W/logs/publish-rainbow-ride-oneshot.log"; ALTF="$D/.x488-rainbow-ride-alts.json"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g; s/(Bearer )[A-Za-z0-9._-]{12,}/$1<伏せ>/g'; }
{
echo "# レインボーライドの交通規制の告知を予約する（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 0. 予約時刻"; echo '```'
EPOCH="$(date -j -f '%Y-%m-%d %H:%M' "$SCHED_JST" '+%s' 2>/dev/null || echo "")"
[ -n "$EPOCH" ] || { echo "時刻が読めない。止まる"; echo '```'; exit 1; }
NOW="$(date '+%s')"; UTC_ISO="$(date -u -r "$EPOCH" '+%Y-%m-%dT%H:%M:00.000Z')"
MO="$(date -r "$EPOCH" '+%-m')"; DY="$(date -r "$EPOCH" '+%-d')"; HH="$(date -r "$EPOCH" '+%-H')"; MI="$(date -r "$EPOCH" '+%-M')"
printf '  JST %s ／ UTC %s ／ いまから %s 分後\n' "$SCHED_JST" "$UTC_ISO" "$(( (EPOCH - NOW) / 60 ))"
echo '```'
[ "$EPOCH" -gt "$NOW" ] || { echo "- **過去の時刻。止まる。**"; exit 1; }
echo; echo "## 1. 画像 2 枚を origin/main から取る"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null || true
mkdir -p "$IMGDIR"; CSV=""; N=0
for f in 1-official.jpg 2-point.jpg; do
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f" 2>/dev/null && [ "$(wc -c < "$IMGDIR/$f" | tr -d ' ')" -ge 50000 ]; then
    printf '  %-16s %8s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"; CSV="${CSV:+$CSV,}$IMGDIR/$f"; N=$((N + 1))
  else printf '  %-16s **取れない**\n' "$f"; fi
done
printf '  対象 2 枚 / 取れた %s 枚\n' "$N"
echo '```'
[ "$N" = "2" ] || { echo "- **画像が揃わない。積まずに止まる。**"; exit 1; }
echo; echo "## 2. 文面を確かめて積む"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),{execFileSync}=require("child_process");
const [qp,id,csv,iso,repo]=process.argv.slice(1);
const show=p=>execFileSync("git",["-C",repo,"show","origin/main:"+p],{encoding:"utf8",maxBuffer:16*1024*1024});
const t=JSON.parse(show("scripts/image-review/posts.json"))["news-rainbow-ride"];
const w=s=>{let n=0;for(const c of s.replace(/https?:\/\/\S+/g,"#".repeat(23)))n+=c.codePointAt(0)<0x80?1:2;return n};
if(!Array.isArray(t)||t.length!==2){console.log("FAIL 文面が 2 本ではない");process.exit(1);}
if(!t[0].includes("自転車イベント「レインボーライド2026」")||!t[1].includes("https://daily-hack.fieldbeside.com/posts/rainbow-ride-traffic-restrictions-2026/")){console.log("FAIL レビューページの版ではない");process.exit(1);}
t.forEach((x,i)=>console.log("  ["+(i+1)+"/2] 文字 "+x.length+" ／ 重み "+w(x)));
const head=t[0].split("👇")[0];if(!t[0].includes("👇")||w(head)>275||w(t[0])>25000||w(t[1])>275){console.log("FAIL 冒頭（👇まで）が 275 を超える・本体が長すぎる・[2/2] が 275 を超える");process.exit(1);}console.log("  冒頭（👇まで）の重み "+w(head));
const pj=JSON.parse(show("ops/data/x-cards/rainbow-ride-traffic-restrictions-2026.panels.json"));
const alts=["1-official.jpg","2-point.jpg"].map(f=>((pj.panels||[]).find(x=>x.file===f)||{}).alt||"");
if(alts.some(a=>!a)){console.log("FAIL ALT が無い画像がある");process.exit(1);}
fs.writeFileSync(process.argv[6],JSON.stringify(alts));console.log("  ALT: "+alts.map((a,i)=>(i+1)+"枚目 "+a.length+"字").join(" ／ "));
const q=JSON.parse(fs.readFileSync(qp,"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);
if(!Array.isArray(rows)){console.log("FAIL キューの配列が取れない");process.exit(1);}
if(rows.some(r=>r&&r.id===id)){console.log("FAIL 同じ id がもう在る: "+id);process.exit(1);}
rows.push({id,kind:"thread",status:"awaiting_approval",auto_publish:false,scheduled_at:iso,created_at:new Date().toISOString(),
 text:t[0],image_path:csv,thread_chain:[{text:t[0],role:"hook",image_path:csv},{text:t[1],role:"cta"}],
 _note:"2026-11-15 利用者「この投稿水曜日に予約投稿して」。11/18 12:00 の 1 回だけのジョブ（com.dailyhack.publish-rainbow-ride-oneshot）が run-publish.sh で出す。文面は指示なく変えない"});
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);JSON.parse(fs.readFileSync(qp,"utf8"));
console.log("OK 積んだ: "+id);' "$D/post_queue.json" "$ID" "$CSV" "$UTC_ISO" "$REPO" "$ALTF" 2>&1 | clean
QRC=${PIPESTATUS[0]}; echo '```'
[ "$QRC" -eq 0 ] || { echo "- **積めなかった。予約も置かない。**"; exit 1; }
echo; echo "## 3. 11/18 12:00 に 1 回だけ走るジョブ"; echo '```'
RUNNER="$S/publish-rainbow-ride-oneshot.sh"; WB="$S/.publish-rainbow-ride-writeback.js"
cat > "$WB" <<'WBJS'
const fs=require("fs");const [qp,id]=process.argv.slice(2);let raw="";
process.stdin.on("data",d=>raw+=d).on("end",()=>{const q=JSON.parse(fs.readFileSync(qp,"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);
const e=rows.find(x=>x&&x.id===id);if(!e){console.log("[wb] entry なし");return;}e.auto_publish=false;
const line=raw.split(/\r?\n/).filter(l=>l.trim().startsWith("{")).pop();let r=null;try{r=JSON.parse(line)}catch(_){}
const t1=r&&(r.tweet_id||null);const rs=(r&&r.thread_results)||[];const t2=(rs[1]&&(rs[1].reply_tweet_id||rs[1].tweet_id))||null;
if(t1){e.status="posted";e.x_tweet_id=t1;e.posted_at=new Date().toISOString();if(e.thread_chain&&e.thread_chain[0])e.thread_chain[0].x_tweet_id=t1;if(e.thread_chain&&e.thread_chain[1]&&t2)e.thread_chain[1].x_tweet_id=t2;}
e.last_result=r?{ok:!!r.ok,step:r.step||null,error:(r.error||"").slice(0,300)}:{ok:false,step:"no-json"};
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);console.log("[wb] t1="+t1+" t2="+t2+" ok="+(r&&r.ok));});
WBJS
cat > "$RUNNER" <<RUNEOF
#!/bin/bash
# 1 回だけ走る。結果をキューに書き戻し、自分を外して plist を消す（常駐させない）
set -uo pipefail
cd "$W" || exit 1
echo "[\$(date '+%F %T')] start" >> "$LOG"
OUTP="\$(ALT_TEXTS_FILE="$ALTF" /bin/bash "$S/run-publish.sh" "$ID" 2>&1)"; RC=\$?
printf '%s\n' "\$OUTP" >> "$LOG"
printf '%s' "\$OUTP" | "$NODE_BIN" "$WB" "$D/post_queue.json" "$ID" >> "$LOG" 2>&1
echo "[\$(date '+%F %T')] done rc=\$RC" >> "$LOG"
/bin/launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
/bin/rm -f "$LA/$LABEL.plist"
RUNEOF
chmod +x "$RUNNER"
cat > "$LA/$LABEL.plist" <<PLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$RUNNER</string></array>
  <key>StartCalendarInterval</key><dict>
    <key>Month</key><integer>$MO</integer><key>Day</key><integer>$DY</integer>
    <key>Hour</key><integer>$HH</integer><key>Minute</key><integer>$MI</integer>
  </dict>
  <key>StandardOutPath</key><string>$W/logs/publish-rainbow-ride-oneshot-out.log</string>
  <key>StandardErrorPath</key><string>$W/logs/publish-rainbow-ride-oneshot-err.log</string>
</dict></plist>
PLEOF
launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$LA/$LABEL.plist" 2>&1)"; echo "  bootstrap rc=$? $(printf '%s' "$BS" | head -1)"
echo '```'
echo; echo "## 4. 載ったことの証拠（print で見る）"; echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E '^\s+(state|runs|path|program) ' | sed 's/^/  /'; echo "  → **載っている**"
else echo "  → **載っていない。予約は効かない。**"; fi
echo '```'
echo; echo "## 取り消すとき"; echo '```bash'
echo "  launchctl bootout gui/$UID_N/$LABEL; rm -f \"$LA/$LABEL.plist\" \"$RUNNER\""
echo '```'
echo; echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。常駐させない。**"
} > "$OUT" 2>&1
if grep -q '→ \*\*載っている' "$OUT" 2>/dev/null; then echo "レインボーライドの交通規制の告知を 11/18 12:00 に予約した / $(basename "$OUT")"; else echo "**予約できていない。レポートを確認すること** / $(basename "$OUT")"; fi
