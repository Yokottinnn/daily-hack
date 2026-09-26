#!/bin/bash
# **PAY ID パターンA を予約投稿する。まだ走らない（`pending/` に在る）。費用 $0。**
#
# ## これは `ops/tasks/pending/` に置いてある＝**実行されない**
#
# `scripts/ops-run-tasks.sh:176` は `origin/main:ops/tasks` を**非再帰**で回し、
# `*.sh` でないものを飛ばす。`pending` はディレクトリなので飛ばされる。
#
#   走らせるとき: **`SCHED_JST` を埋めてから `ops/tasks/` の直下へ移す**
#
# ## なぜ 1 回だけ走るジョブなのか（2026-09-26 にダイアログで決定）
#
# `x156` で分かったこと: **実行側が 1 本も載っていない。**
#
#   auto-x-publisher / poll-approvals / x-publisher / publish-queue  → 全部 載っていない
#   `auto-x-publisher.js` は在る（250 行）が **plist 自体が無い**
#
# 常駐のポーラー（`poll-approvals`）を戻すと、**8/15 の誤爆と同じ形**になりうる
# （承認から 8 日 経った滞留エントリを拾ってタイムラインへ投稿した）。
# **1 回だけ走るジョブなら、拾うのはこの 1 件だけ。**
# 前例も在る（`ai.openclaw.publish-hanabi-oneshot.plist`）。
#
# ## やること
#
#   ① 画像 4 枚を **`origin/main` から取り直す**（Mac の作業ツリーは main とは限らない）
#   ② キューに 1 件 積む（契約書 §3 の 5 条件をすべて満たす形）
#   ③ **その時刻に 1 回だけ走る plist** を置く。走ったら**自分を外して消える**
#   ④ 載ったことを `launchctl print` で確かめる（rc は証拠にならない・最上位ルール 13）
#
# ## 承認は取れている
#
# 利用者が**画像を見たうえで**「登録してOK」と言った（2026-09-26・版 28）。
# 文面は `payid-a`（[1/3] に招待コードとリンク）。**勝手に変えない**（最上位ルール 18）。
set -uo pipefail

# ============================================================
# **ここを埋めてから直下へ移すこと。** 空のままなら何もせずに止まる
SCHED_JST=""          # 例: "2026-09-28 21:00"（JST・分まで）
# ============================================================

ID="blog-promo-$(date '+%Y%m%d')-payid-a"
W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
LABEL="ai.openclaw.publish-payid-oneshot"
UID_N="$(id -u)"
REPO="${OPS_MAIN_REPO:-$HOME/projects/anta-baka-x/blog}"
IMGDIR="$W/data/payid-invite"
OUT="${OPS_REPORT_DIR:-/tmp}/schedule-payid.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

{
echo "# PAY ID パターンA を予約する（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"

echo
echo "## 0. 予約時刻"
echo
if [ -z "$SCHED_JST" ]; then
  echo "- **\`SCHED_JST\` が空。何もせずに止まる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
# macOS の date。**`date -d` は使えない**（最上位ルール 14）
EPOCH="$(date -j -f '%Y-%m-%d %H:%M' "$SCHED_JST" '+%s' 2>/dev/null || echo "")"
if [ -z "$EPOCH" ]; then
  echo "- **\`SCHED_JST\` の書式が読めない（\`YYYY-MM-DD HH:MM\`）。止まる。**"
  rm -rf "$IMGDIR" 2>/dev/null
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
NOW="$(date '+%s')"
UTC_ISO="$(date -u -r "$EPOCH" '+%Y-%m-%dT%H:%M:00.000Z')"
MO="$(date -r "$EPOCH" '+%-m')"; DY="$(date -r "$EPOCH" '+%-d')"
HH="$(date -r "$EPOCH" '+%-H')"; MI="$(date -r "$EPOCH" '+%-M')"
echo '```'
printf '  JST          %s\n' "$SCHED_JST"
printf '  scheduled_at %s  (UTC)\n' "$UTC_ISO"
printf '  いまから      %s 分後\n' "$(( (EPOCH - NOW) / 60 ))"
echo '```'
if [ "$EPOCH" -le "$NOW" ]; then
  echo
  echo "- **過去の時刻。止まる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 1. 画像を \`origin/main\` から取り直す"
echo
echo "**Mac の作業ツリーは main とは限らない。** 絵を直しても取り直さないと古い絵が出る。"
echo
mkdir -p "$IMGDIR"
CSV=""
ok=1
echo '```'
for f in 1-summary.jpg 2-atobarai.jpg 3-shops.jpg 4-rating.jpg; do
  p="public/images/payid-invite/x/$f"
  if git -C "$REPO" show "origin/main:$p" > "$IMGDIR/$f" 2>/dev/null && [ -s "$IMGDIR/$f" ]; then
    printf '  %-18s %8s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    CSV="${CSV:+$CSV,}$IMGDIR/$f"
  else
    printf '  %-18s **取れない**\n' "$f"
    ok=0
  fi
done
echo '```'
if [ "$ok" -ne 1 ]; then
  echo
  echo "- **画像が揃わない。積まずに止まる**（画像なしでは出さない）。"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 2. キューに 1 件 積む"
echo
echo "契約書 §3 の 5 条件をすべて満たす形にする。"
echo
node -e '
  const fs = require("fs");
  const [qp, id, csv, iso, repo] = process.argv.slice(1);
  const posts = JSON.parse(fs.readFileSync(repo + "/scripts/image-review/posts.json", "utf8"));
  const t = posts["payid-a"];
  if (!Array.isArray(t) || t.length !== 3) { console.log("FAIL 文面が 3 本ではない"); process.exit(1); }
  const q = JSON.parse(fs.readFileSync(qp, "utf8"));
  const rows = Array.isArray(q) ? q : (q.items || q.queue || q.posts);
  if (!Array.isArray(rows)) { console.log("FAIL キューの配列が取れない"); process.exit(1); }
  if (rows.some((r) => r && r.id === id)) { console.log("FAIL 同じ id がもう在る: " + id); process.exit(1); }
  rows.push({
    id, kind: "thread", status: "awaiting_approval", auto_publish: true,
    scheduled_at: iso, created_at: new Date().toISOString(),
    text: t[0], image_path: csv,
    thread_chain: [
      { text: t[0], role: "hook", image_path: csv },
      { text: t[1], role: "body" },
      { text: t[2], role: "cta" },
    ],
    _note: "2026-09-26 に利用者が画像を見たうえで承認（レビューページ 版 28・payid-a）。文面は指示なく変えない",
  });
  fs.writeFileSync(qp, JSON.stringify(q, null, 2));
  // **書いたあとに自分で parse して確かめる**（最上位ルール 13）
  JSON.parse(fs.readFileSync(qp, "utf8"));
  const w = (s) => { let n = 0; for (const c of s.replace(/https?:\/\/\S+/g, "#".repeat(23))) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
  console.log("OK 積んだ: " + id);
  t.forEach((x, i) => console.log("  [" + (i + 1) + "/3] 重み " + w(x) + " / 280"));
' "$D/post_queue.json" "$ID" "$CSV" "$UTC_ISO" "$REPO" > /tmp/.x158q 2>&1
QRC=$?
echo '```'
cat /tmp/.x158q | clean | sed 's/^/  /'
printf '  rc=%s\n' "$QRC"
echo '```'
rm -f /tmp/.x158q
if [ "$QRC" -ne 0 ]; then
  echo
  echo "- **積めなかった。plist も置かずに終わる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 3. その時刻に 1 回だけ走るジョブ"
echo
echo "**走ったら自分を外して消える。** 常駐しない＝滞留を拾わない。"
echo
RUNNER="$S/publish-payid-oneshot.sh"
cat > "$RUNNER" <<RUNEOF
#!/bin/bash
# 1 回だけ走る。走ったら自分を外して plist を消す（常駐させない）
set -uo pipefail
cd "$W" || exit 1
/bin/bash "$S/run-publish.sh" "$ID" >> "$W/logs/publish-payid-oneshot.log" 2>&1
echo "[\$(date '+%F %T')] done rc=\$?" >> "$W/logs/publish-payid-oneshot.log"
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
  <key>StandardOutPath</key><string>$W/logs/publish-payid-oneshot.log</string>
  <key>StandardErrorPath</key><string>$W/logs/publish-payid-oneshot-err.log</string>
</dict></plist>
PLEOF

launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$LA/$LABEL.plist" 2>&1)"; BRC=$?
echo '```'
printf '  bootstrap rc=%s  %s\n' "$BRC" "$(printf '%s' "$BS" | head -1)"
echo '```'

echo
echo "## 4. 載ったことの証拠（**rc ではなく \`print\` で見る**）"
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
echo "キューに入ったことの確認:"
echo
echo '```'
grep -c "$ID" "$D/post_queue.json" 2>/dev/null | head -1 | sed 's/^/  id の出現: /'
echo '```'

echo
echo "---"
echo
echo "## 取り消すとき"
echo
echo '```bash'
echo "  launchctl bootout gui/$UID_N/$LABEL"
echo "  rm -f \"$LA/$LABEL.plist\" \"$RUNNER\""
echo "  # キューの $ID を status=cancelled にする"
echo '```'
echo
echo "## 費用"
echo
echo "**キューを 1 行 足して plist を置くだけ。投稿も DOM 操作のみで LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "> **常駐させない**ので、この先 毎日 かかるものは増えない。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '載っている' "$OUT" 2>/dev/null; then
  echo "PAY ID パターンA を予約した / $(basename "$OUT")"
else
  echo "**予約できていない。レポートを確認すること** / $(basename "$OUT")"
fi
