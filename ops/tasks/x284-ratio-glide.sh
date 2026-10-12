#!/bin/bash
# **フォロー比率の目標を「フォロワーが増えるほど下げる」にする。あわせて相互の整理の DRY を切り離して最後まで走らせる。費用 $0。**
#
# ## 指示（2026-10-12）
#
#   > 最初はいまの比率くらいでいいが、徐々にフォロワー数の方が圧倒的に多くなるようにして設計して。
#   > 常に比率はモニタリングして、高い水準を保つような工夫と努力をしてください
#   > これからはブルーバッジをつけたアカウントとして、最速で1kフォロワーまで駆け抜けたい
#
# ## ① follow-balance.js（比率の番人）
#
#   いまは目標 0.58・警戒 0.65・下限 0.45 で固定（環境変数が無いので既定値）。
#   **FOLLOW_RATIO_GLIDE があれば、ヘッダーのフォロワー数から目標を線形に決める。** 警戒＝目標＋0.05、下限＝目標−0.15。
#
#     フォロワー  370 → 目標 0.57（いま 213/370＝0.576 とほぼ同じ）
#                 500 → 0.50
#                 700 → 0.42
#                1000 → 0.33（フォロー中 330 前後）
#
#   plist に FOLLOW_RATIO_GLIDE="370:0.57,500:0.50,700:0.42,1000:0.33" を足して載せ直す。
#   1 回に外す上限（MIN/MAX_UNFOLLOW=20）と猶予（GRACE_DAYS=1）は変えない。
#
# ## ② mutual-prune の DRY（x283 の続き）
#
#   x283 は 230 秒で打ち切られ、判定の一覧（最後にまとめて書く）が取れなかった。
#   **ops から切り離して（新しいセッションで）最後まで走らせる。** 1 件も外さない（DRY_RUN=1）。結果は次のタスクで読む。
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/ratio-glide.md"
LABEL="ai.openclaw.follow-balance"
PL="$HOME/Library/LaunchAgents/$LABEL.plist"
GLIDE="370:0.57,500:0.50,700:0.42,1000:0.33"
PATCH="$W/.x284-patch.js"

cat > "$PATCH" <<'PATCHJS'
const fs = require("fs");
const { execFileSync } = require("child_process");
const p = process.argv[2] + "/follow-balance.js";
let src = fs.readFileSync(p, "utf8");
if (src.includes("x284")) { console.log(JSON.stringify({ ok: true, note: "もう当たっている" })); process.exit(0); }
let lines = src.split("\n");
const one = (needle) => { const h = lines.map((l, i) => l.includes(needle) ? i : -1).filter((i) => i >= 0); if (h.length !== 1) throw new Error("「" + needle + "」を含む行が " + h.length + " 行"); return h[0]; };
try {
  for (const n of ["const CEIL_RATIO = Number(", "const FLOOR_RATIO = Number(", "const TARGET_RATIO = Number("]) {
    const i = one(n); lines[i] = lines[i].replace("const ", "let ");
  }
  const i = one("const ceilN = Math.floor(hdr.followers * CEIL_RATIO);");
  const ind = lines[i].match(/^\s*/)[0];
  const add = [
    "// 2026-10-12 x284: フォロワーが増えるほど目標を下げる（「徐々にフォロワー数の方が圧倒的に多くなるように」）",
    "// FOLLOW_RATIO_GLIDE=\"370:0.57,500:0.50,700:0.42,1000:0.33\" を線形に補う。警戒＝目標＋0.05、下限＝目標−0.15",
    "if (process.env.FOLLOW_RATIO_GLIDE) {",
    "  const pts = process.env.FOLLOW_RATIO_GLIDE.split(\",\").map((s) => s.split(\":\").map(Number)).filter((a) => a.length === 2 && a.every(isFinite)).sort((a, b) => a[0] - b[0]);",
    "  if (pts.length) {",
    "    const f = hdr.followers; let t = pts[0][1];",
    "    if (f >= pts[pts.length - 1][0]) t = pts[pts.length - 1][1];",
    "    else for (let k = 0; k < pts.length - 1; k++) { const [x0, y0] = pts[k], [x1, y1] = pts[k + 1]; if (f >= x0 && f <= x1) { t = y0 + (y1 - y0) * (f - x0) / (x1 - x0); break; } }",
    "    TARGET_RATIO = t; CEIL_RATIO = t + 0.05; FLOOR_RATIO = Math.max(0.1, t - 0.15);",
    "    log(\"比率の目標（GLIDE）: フォロワー \" + f + \" → 目標 \" + t.toFixed(3) + \" / 警戒 \" + CEIL_RATIO.toFixed(3) + \" / 下限 \" + FLOOR_RATIO.toFixed(3));",
    "  }",
    "}",
  ].map((x) => ind + x);
  lines.splice(i, 0, ...add);
} catch (e) { console.log(JSON.stringify({ ok: false, error: e.message })); process.exit(0); }
fs.copyFileSync(p, p + ".bak-x284");
fs.writeFileSync(p, lines.join("\n"));
const chk = process.argv[2] + "/.x284-check-follow-balance.js";
fs.copyFileSync(p, chk);
try { execFileSync(process.execPath, ["--check", chk], { stdio: "pipe" }); console.log(JSON.stringify({ ok: true, note: "書いた・node --check 通過" })); }
catch (e) { fs.copyFileSync(p + ".bak-x284", p); console.log(JSON.stringify({ ok: false, error: "node --check に落ちたので戻した " + String(e.stderr || e.message).slice(0, 200) })); }
finally { try { fs.unlinkSync(chk); } catch {} }
PATCHJS

{
echo "# フォロー比率の目標をフォロワー数で下げる・相互の整理の DRY（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## ① follow-balance.js"
echo '```json'
cd "$W" && node "$PATCH" "$S" 2>&1 | tail -2
echo '```'
if grep -q "x284" "$S/follow-balance.js"; then
  cp "$PL" "$PL.bak-x284" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Delete :EnvironmentVariables:FOLLOW_RATIO_GLIDE" "$PL" >/dev/null 2>&1
  /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:FOLLOW_RATIO_GLIDE string $GLIDE" "$PL" 2>&1 | head -2
  echo '```'
  echo "plist の値: $(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:FOLLOW_RATIO_GLIDE' "$PL" 2>&1)"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>&1 | head -1
  sleep 2
  launchctl bootstrap "gui/$(id -u)" "$PL" 2>&1 | head -1
  launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "state =|FOLLOW_RATIO_GLIDE" | head -3
  echo '```'
fi
echo
echo "## ② mutual-prune の DRY（切り離して起動）"
echo
if pgrep -f "mutual-prune.js" >/dev/null 2>&1; then echo "**mutual-prune が走っている。DRY は見送る。**"; else
  L="$W/logs/x284-mutual-dry.log"
  # 新しいセッションで起動する（ops の終了と一緒に落ちないように。x279 は nohup だけで落ちた）
  perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' /usr/bin/env DRY_RUN=1 MUTUAL_RATIO_CUT=0.8 MAX_UNFOLLOW=999 GRACE_DAYS=1 OPS_WS="$W" CDP_URL="${CDP_URL:-http://127.0.0.1:18810}" /usr/local/bin/node "$S/mutual-prune.js" > "$L" 2>&1 < /dev/null &
  sleep 5
  pgrep -f "mutual-prune.js" >/dev/null 2>&1 && echo "- 起動した（全件を判定する。198 件 × 5〜6 秒で 20 分ほど。ログ \`logs/x284-mutual-dry.log\`）" || { echo "- **起動直後に終わった**"; echo '```'; head -10 "$L"; echo '```'; }
fi
echo
echo "**外していない（DRY）。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 戻すときは follow-balance.js.bak-x284 と plist の .bak-x284。"
} > "$OUT" 2>&1
rm -f "$PATCH"
echo "比率の目標をフォロワー数で下げる設定を入れ、相互の DRY を起動した / $(basename "$OUT")"
