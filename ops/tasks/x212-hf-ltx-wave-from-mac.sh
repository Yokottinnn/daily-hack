#!/bin/bash
# **Hugging Face の無料デモ（LTX-Video）を Mac から呼んで、手を振る動画を 1 本 作る。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > 基本的に無料で作って欲しいので、無料でどうやって作れるかを考えて
#   → 「① Hugging Face の無料デモ」を選んでもらった
#
# クラウドから呼ぶと、匿名の GPU 枠が尽きていた（接続元を大勢と共有しているため。「120s requested vs. -60s left」）。
# **枠は接続元ごとなので、Mac から呼べば Mac 側の枠で 1 本 作れるはず。**
#
#   - 道具: gradio_client だけを Python 3.11 の venv（~/.openclaw/workspace/.venv-video）に入れる（小さい・数秒）
#   - 入力: origin/main の ops/data/x-cards/follower-300-grok/in-wave.png
#   - 出力: $OPS_REPORT_DIR/x212-ltx-wave.mp4
#
# **投稿しない。アカウントもキーも使わない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${OPS_MAIN_REPO:-$HOME/projects/anta-baka-x/blog}"
VENV="$W/.venv-video"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/hf-ltx-wave.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
IMG="$W/.x212-in-wave-$STAMP.png"
PY="$W/.x212-run-$STAMP.py"
LOG="$W/.x212-log-$STAMP.txt"

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

cat > "$PY" <<'PYEOF'
import sys, shutil, json, time
from gradio_client import Client, handle_file
img, out = sys.argv[1], sys.argv[2]
t0 = time.time()
res = {}
try:
    c = Client("Lightricks/ltx-video-distilled", verbose=False)
    r = c.predict(
        "2D anime girl cheerfully waving her raised hand left and right, smiling, gentle body sway, twin tails swaying, "
        "static camera, flat anime cel shading, same character design and colors",
        "worst quality, inconsistent motion, blurry, jittery, distorted, realistic, 3d, morphing, extra fingers, text",
        handle_file(img), None, 512, 512, "image-to-video", 3, 9, 42, False, 1, False,
        api_name="/image_to_video")
    v = r[0]["video"] if isinstance(r[0], dict) else r[0]
    shutil.copy(v, out)
    res["saved"] = out
except Exception as e:
    res["error"] = str(e)[:400]
res["sec"] = round(time.time() - t0)
print(json.dumps(res, ensure_ascii=False))
PYEOF

{
echo "# Hugging Face の LTX-Video を Mac から呼ぶ（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。アカウントもキーも使わない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
if git -C "$REPO" show "origin/main:ops/data/x-cards/follower-300-grok/in-wave.png" > "$IMG" 2>/dev/null && [ -s "$IMG" ]; then
  printf '  入力画像 %s bytes\n' "$(wc -c < "$IMG" | tr -d ' ')"
else
  echo "  **入力画像が取れない**"
fi
P311="$(command -v python3.11 || echo /opt/homebrew/bin/python3.11)"
if [ ! -x "$VENV/bin/python" ]; then "$P311" -m venv "$VENV" 2>&1 | tail -2; fi
"$VENV/bin/python" -m pip install -q --disable-pip-version-check gradio_client 2>&1 | tail -2
printf '  gradio_client: %s\n' "$("$VENV/bin/python" -c 'import gradio_client; print(gradio_client.__version__)' 2>&1 | tail -1)"
rm -f "$OUTDIR/x212-ltx-wave.mp4"
T0="$(date +%s)"
run_limited 230 "$LOG" "$VENV/bin/python" "$PY" "$IMG" "$OUTDIR/x212-ltx-wave.mp4"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
echo "  結果: $(tail -1 "$LOG" | cut -c1-500)"
[ -s "$OUTDIR/x212-ltx-wave.mp4" ] && printf '  x212-ltx-wave.mp4（%s bytes）\n' "$(wc -c < "$OUTDIR/x212-ltx-wave.mp4" | tr -d ' ')"
echo '```'
echo
echo "**投稿していない。アカウントもキーも使っていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$IMG" "$PY" "$LOG"

if [ -s "$OUTDIR/x212-ltx-wave.mp4" ]; then echo "LTX-Video で手を振る動画ができた / $(basename "$OUT")"; else echo "**動画はできていない。レポートを確認すること** / $(basename "$OUT")"; fi
