#!/bin/bash
# **東京湾大華火祭（10/24）直前の告知 B 案を 10/23 08:00 JST に 1 回だけ出す予約（x328）。費用 $0。**
POST_APPROVAL_QUOTE="投稿内容はB案でOK 午前中の視聴率が高いタイミングで投稿して"
POST_APPROVAL_AT="2026-10-22 23:0x JST（チャット）"
POST_SET_KEY="hanabi-b"
#
# ## 承認の状態
#
#   利用者が上の言葉で投稿を指示した。文面は posts.json の `hanabi-b`（1 本・長文）、画像は
#   public/images/tokyo-bay-hanabi-2026-weekend/x/ の 4 枚（レビューページ 版74＋1 枚目右下に撮影者名を小さく入れた版）。
#   引用ポストではなく通常の投稿にする（利用者「引用ポストじゃなくてもいいよ」）。
#   文面は posts.lock.json の `hanabi-b[0]` のハッシュと照合し、**1 文字でも違えば出さない**。
#
# ## 時刻
#
#   「午前中の視聴率が高いタイミング」→ **10/23(金) 08:00（通勤時間）**。
#
# ## 作り（x314 を写した。違いは文面が 1 本・ラベルは最初から com.dailyhack.*）
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。画面は撮らない。**
set -uo pipefail

SCHED_JST="2026-10-23 08:00"

ID="blog-promo-20261023-tokyo-bay-hanabi"
W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
LABEL="com.dailyhack.publish-hanabi-oneshot"
UID_N="$(id -u)"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
IMGDIR="$D/x-tokyo-bay-hanabi-weekend"
SRCDIR="public/images/tokyo-bay-hanabi-2026-weekend/x"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/schedule-hanabi.md"
LOG="$W/logs/publish-hanabi-oneshot.log"

hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# 花火の告知（B 案）を予約する（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"

echo
echo "## 0. 予約時刻"
echo
EPOCH="$(date -j -f '%Y-%m-%d %H:%M' "$SCHED_JST" '+%s' 2>/dev/null || echo "")"
if [ -z "$EPOCH" ]; then echo "- **時刻が読めない。止まる。**"; exit 1; fi
NOW="$(date '+%s')"
UTC_ISO="$(date -u -r "$EPOCH" '+%Y-%m-%dT%H:%M:00.000Z')"
MO="$(date -r "$EPOCH" '+%-m')"; DY="$(date -r "$EPOCH" '+%-d')"
HH="$(date -r "$EPOCH" '+%-H')"; MI="$(date -r "$EPOCH" '+%-M')"
echo '```'
printf '  JST          %s\n' "$SCHED_JST"
printf '  scheduled_at %s  (UTC)\n' "$UTC_ISO"
printf '  いまから      %s 分後\n' "$(( (EPOCH - NOW) / 60 ))"
echo '```'
if [ "$EPOCH" -le "$NOW" ]; then echo "- **過去の時刻。止まる。**"; exit 1; fi

echo
echo "## 1. 画像 4 枚を origin/main から取り直す"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null || true
mkdir -p "$IMGDIR"; CSV=""; N=0
echo '```'
for f in 1-checklist.jpg 2-alcohol.jpg 3-roads.jpg 4-no-ticket.jpg; do
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f" 2>/dev/null && [ "$(wc -c < "$IMGDIR/$f" | tr -d ' ')" -ge 50000 ]; then
    printf '  %-16s %8s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    CSV="${CSV:+$CSV,}$IMGDIR/$f"; N=$((N + 1))
  else
    printf '  %-16s **取れない**\n' "$f"
  fi
done
printf '  対象 4 枚 / 取れた %s 枚\n' "$N"
echo '```'
if [ "$N" != "4" ]; then echo "- **画像が揃わない。積まずに止まる。**"; exit 1; fi

echo
echo "## 2. 文面を origin/main から取り、ロックのハッシュと照合して積む"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),crypto=require("crypto"),{execFileSync}=require("child_process");
const [qp,id,csv,iso,repo]=process.argv.slice(1);
const show=(p)=>execFileSync("git",["-C",repo,"show","origin/main:"+p],{encoding:"utf8",maxBuffer:16*1024*1024});
const t=JSON.parse(show("scripts/image-review/posts.json"))["hanabi-b"];
const L=JSON.parse(show("scripts/image-review/posts.lock.json")).locked;
const sha=s=>crypto.createHash("sha256").update(s,"utf8").digest("hex");
const w=s=>{let n=0;for(const c of s.replace(/https?:\/\/\S+/g,"#".repeat(23)))n+=c.codePointAt(0)<0x80?1:2;return n};
if(!Array.isArray(t)||t.length!==1){ console.log("FAIL 文面が 1 本ではない"); process.exit(1); }
let ok=true;
t.forEach((x,i)=>{ const m=L["hanabi-b["+i+"]"]&&L["hanabi-b["+i+"]"].sha256===sha(x); if(!m) ok=false;
  console.log("  [1/1] ロック "+(m?"一致":"**不一致**")+" ／ 文字 "+x.length+" ／ 重み "+w(x)+" / 25000"); });
if(!ok||w(t[0])>25000){ console.log("FAIL 出さない"); process.exit(1); }
const q=JSON.parse(fs.readFileSync(qp,"utf8"));
const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);
if(!Array.isArray(rows)){ console.log("FAIL キューの配列が取れない"); process.exit(1); }
if(rows.some(r=>r&&r.id===id)){ console.log("FAIL 同じ id がもう在る: "+id); process.exit(1); }
rows.push({ id, kind:"thread", status:"awaiting_approval", auto_publish:false,
  scheduled_at:iso, created_at:new Date().toISOString(),
  text:t[0], image_path:csv,
  thread_chain:[ {text:t[0], role:"hook", image_path:csv} ],
  _note:"2026-10-22 に利用者が画像を見たうえで投稿を指示（B 案）。10/23 08:00 の 1 回だけのジョブが run-publish.sh で出す。文面は指示なく変えない" });
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp",qp);
JSON.parse(fs.readFileSync(qp,"utf8"));
console.log("OK 積んだ: "+id);
' "$D/post_queue.json" "$ID" "$CSV" "$UTC_ISO" "$REPO" 2>&1 | clean
QRC=${PIPESTATUS[0]}
printf '  rc=%s\n' "$QRC"
echo '```'
if [ "$QRC" -ne 0 ]; then echo "- **積めなかった。plist も置かずに終わる。**"; exit 1; fi

echo
echo "## 3. 10/23 08:00 に 1 回だけ走るジョブ"
echo
RUNNER="$S/publish-hanabi-oneshot.sh"
WB="$S/.publish-hanabi-writeback.js"
cat > "$WB" <<'WBJS'
// run-publish.sh の出力（stdin）から tweet_id を拾ってキューに書き戻す。
// **出ても出なくても auto_publish は false にする**（片肺のまま自動投稿に拾われる芽を摘む）
const fs = require("fs");
const [qp, id] = process.argv.slice(2);
let raw = ""; process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  const q = JSON.parse(fs.readFileSync(qp, "utf8"));
  const rows = Array.isArray(q) ? q : (q.queue || q.items || q.posts);
  const e = rows.find((x) => x && x.id === id); if (!e) { console.log("[wb] entry なし"); return; }
  e.auto_publish = false;
  const line = raw.split(/\r?\n/).filter((l) => l.trim().startsWith("{")).pop();
  let r = null; try { r = JSON.parse(line); } catch (_) {}
  const t1 = r && (r.tweet_id || null);
  const rs = (r && r.thread_results) || [];
  const t2 = (rs[1] && (rs[1].reply_tweet_id || rs[1].tweet_id)) || null;
  if (t1) { e.status = "posted"; e.x_tweet_id = t1; e.posted_at = new Date().toISOString();
    if (e.thread_chain && e.thread_chain[0]) e.thread_chain[0].x_tweet_id = t1;
    if (e.thread_chain && e.thread_chain[1] && t2) e.thread_chain[1].x_tweet_id = t2; }
  e.last_result = r ? { ok: !!r.ok, step: r.step || null, error: (r.error || "").slice(0, 300) } : { ok: false, step: "no-json" };
  fs.writeFileSync(qp + ".tmp", JSON.stringify(q, null, 2)); fs.renameSync(qp + ".tmp", qp);
  console.log("[wb] t1=" + t1 + " t2=" + t2 + " ok=" + (r && r.ok));
});
WBJS
cat > "$RUNNER" <<RUNEOF
#!/bin/bash
# 1 回だけ走る。結果をキューに書き戻し、自分を外して plist を消す（常駐させない）
set -uo pipefail
cd "$W" || exit 1
echo "[\$(date '+%F %T')] start" >> "$LOG"
OUTP="\$(/bin/bash "$S/run-publish.sh" "$ID" 2>&1)"; RC=\$?
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
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>$RUNNER</string>
  </array>
  <key>StartCalendarInterval</key><dict>
    <key>Month</key><integer>$MO</integer>
    <key>Day</key><integer>$DY</integer>
    <key>Hour</key><integer>$HH</integer>
    <key>Minute</key><integer>$MI</integer>
  </dict>
  <key>StandardOutPath</key><string>$W/logs/publish-hanabi-oneshot-out.log</string>
  <key>StandardErrorPath</key><string>$W/logs/publish-hanabi-oneshot-err.log</string>
</dict></plist>
PLEOF

launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$LA/$LABEL.plist" 2>&1)"; BRC=$?
echo '```'
printf '  bootstrap rc=%s  %s\n' "$BRC" "$(printf '%s' "$BS" | head -1)"
echo '```'

echo
echo "## 4. 載ったことの証拠（rc ではなく print で見る）"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E '^\s+(state|runs|path|program) ' | sed 's/^/  /'
  echo "  → **載っている**"
else
  echo "  → **載っていない。予約は効かない。**"
fi
echo '```'

echo
echo "## 5. Chrome は健全か（予約時点の参考。08:00 に run-publish.sh が ensure-chrome を呼ぶ）"
echo
echo '```'
"$NODE_BIN" "$S/cdp-health.js" 2>&1 | tail -3 | clean; echo "  (rc=$?)"
echo '```'

echo
echo "## 取り消すとき"
echo
echo '```bash'
echo "  launchctl bootout gui/$UID_N/$LABEL"
echo "  rm -f \"$LA/$LABEL.plist\" \"$RUNNER\""
echo '```'
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。常駐させないので、毎日の費用は増えない。**"
} > "$OUT" 2>&1

if grep -q '載っている' "$OUT" 2>/dev/null && ! grep -q '載っていない' "$OUT" 2>/dev/null; then
  echo "花火の告知を 10/23 08:00 に予約した / $(basename "$OUT")"
else
  echo "**予約できていない。レポートを確認すること** / $(basename "$OUT")"
fi
