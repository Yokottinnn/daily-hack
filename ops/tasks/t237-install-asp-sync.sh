#!/bin/bash
# **ASP（A8・もしも・バリューコマース・楽天アフィリエイト）のログインを保ち、週 1 で提携中の広告を
# 書き出すジョブを入れて、その場で 1 回 走らせる（t237）。** LLM 不使用・**$0**。
#
# 利用者: 「以降どんな場合でも、ちゃんとあなた自身で A8 やバリューコマースを使えるようにしてほしい」
#         「楽天アフィリエイトも、同じように仕組みを構築してほしい」（2026-10-05）
#
#   launchd（毎週 月曜 06:12）
#     → ~/.openclaw/bin/asp-sync-boot.sh   ← 薄いシム（t139 と同じ作り）
#         → git show origin/main:scripts/asp/asp-sync.mjs  ← 毎回 最新を取り出す
#             → Chrome（CDP 18810）で各 ASP を開き、切れていたら Keychain の ID・パスワードで入り直す
#             → reports/asp-sync/ に書き出す（heartbeat が push）
#
# ## 費用（最上位ルール 2-B）
#
# | 単位 | 金額 |
# | --- | --- |
# | 1 回あたり | **$0**（LLM を呼ばない。Chrome で 4 サイトを開くだけ） |
# | 1 日あたり | **$0** |
# | 1 か月あたり | **$0**（週 1 回 ＝ 月 4〜5 回） |
#
# **Keychain の値は読まない・出さない。** 出すのは「登録が在るか」だけ。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t237-install-asp-sync.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.asp-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BOOT="$HOME/.openclaw/bin/asp-sync-boot.sh"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"

{
  echo "# ASP の同期ジョブを入れる（t237・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

if [ ! -d "$REPO/.git" ]; then echo "⚠️ リポジトリが無い: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; fi
git -C "$REPO" fetch -q origin main 2>/dev/null || true
if ! git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > /dev/null 2>&1; then
  echo "⚠️ \`scripts/asp/asp-sync.mjs\` が origin/main に無い。止める。" >> "$OUT"; cat "$OUT"; exit 0
fi

NODE_BIN="$(command -v node || true)"
[ -x /opt/homebrew/bin/node ] && NODE_BIN=/opt/homebrew/bin/node
if [ -z "$NODE_BIN" ]; then echo "⚠️ node が無い。止める。" >> "$OUT"; cat "$OUT"; exit 0; fi

# --- Keychain に登録が在るか（**値は読まない**） ---
{
  echo "## 1) Keychain の登録"
  echo ""
  echo "| ASP | サービス名 | 登録 |"
  echo "| --- | --- | --- |"
} >> "$OUT"
for id in a8 moshimo vc rakuten; do
  if /usr/bin/security find-generic-password -s "dailyhack-asp-$id" >/dev/null 2>&1; then r="**在る**"; else r="無い"; fi
  echo "| $id | \`dailyhack-asp-$id\` | $r |" >> "$OUT"
done
echo "" >> "$OUT"

# --- シム ---
mkdir -p "$(dirname "$BOOT")" "$HOME/.openclaw/logs"
cat > "$BOOT" <<BOOTEOF
#!/bin/bash
# **毎回 origin/main から本体を取り出して走らせる。** 作業ツリーには触らない（t237）。
set -uo pipefail
REPO="$REPO"
LOG="\$HOME/.openclaw/logs/asp-sync.log"
echo "=== \$(date '+%Y-%m-%dT%H:%M:%S%z') boot" >> "\$LOG"
git -C "\$REPO" fetch -q origin main >> "\$LOG" 2>&1 || echo "fetch に失敗（続行する）" >> "\$LOG"
# **拡張子は保つ**（.new などを付けると node が弾く・最上位ルール 14）
LATEST="\${TMPDIR:-/tmp}/asp-sync-latest.mjs"
git -C "\$REPO" show origin/main:scripts/asp/asp-sync.mjs > "\$LATEST" 2>>"\$LOG" || { echo "本体を取り出せなかった" >> "\$LOG"; exit 1; }
[ -s "\$LATEST" ] || { echo "本体が空" >> "\$LOG"; exit 1; }
exec "$NODE_BIN" "\$LATEST" >> "\$LOG" 2>&1
BOOTEOF
chmod +x "$BOOT"

# --- plist（毎週 月曜 06:12） ---
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$BOOT</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>6</integer><key>Minute</key><integer>12</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/.openclaw/logs/asp-sync.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/.openclaw/logs/asp-sync.err.log</string>
</dict>
</plist>
PLISTEOF

launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1
BRC=$?
# **証拠は print**（list に出ないことは載っていない証拠にならない・最上位ルール 13）
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then LOADED="**載った**（launchctl print が通る）"; else LOADED="**載っていない**（bootstrap rc=$BRC）"; fi
{
  echo "## 2) ジョブ"
  echo ""
  echo "- ラベル: \`$LABEL\`（毎週 月曜 06:12）"
  echo "- 状態: $LOADED"
  echo "- node: \`$NODE_BIN\`"
  echo ""
} >> "$OUT"

# --- その場で 1 回 走らせる（本体は 230 秒で自分で打ち切る） ---
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
JS="$RDIR/.asp-sync.mjs"
git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$JS"
echo "## 3) 1 回目の結果" >> "$OUT"; echo "" >> "$OUT"; echo '```text' >> "$OUT"
OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=220000 run_limited 240 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "" >> "$OUT"
echo "- 詳細: \`reports/asp-sync/\`（status.json と ASP ごとの md）" >> "$OUT"
echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 2500 "$OUT"
