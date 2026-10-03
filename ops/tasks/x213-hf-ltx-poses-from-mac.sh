#!/bin/bash
# **Hugging Face の無料デモ（LTX-Video）を Mac から呼んで、残り 3 ポーズの動画を作る。費用 $0。**
#
# x212 で手を振る 1 本が 12 秒で取れた（Mac 側の無料枠で足りた）。同じ呼び方で、
# 腕組み（in-cross）・ふくれ顔（in-pout）・ガッツポーズ（in-cheer）を作る。
#
# （以下は x212 のときの説明）
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
#   - 入力: origin/main の ops/data/x-cards/follower-300-grok/in-{cross,pout,cheer}.png
#   - 出力: $OPS_REPORT_DIR/x213-ltx-{cross,pout,cheer}.mp4
#
# **投稿しない。アカウントもキーも使わない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${OPS_MAIN_REPO:-$HOME/projects/anta-baka-x/blog}"
VENV="$W/.venv-video"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/hf-ltx-poses.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
PY="$W/.x213-run-$STAMP.py"
LOG="$W/.x213-log-$STAMP.txt"

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
indir, outdir = sys.argv[1], sys.argv[2]
NEG = "worst quality, inconsistent motion, blurry, jittery, distorted, realistic, 3d, morphing, extra fingers, extra arms, text"
JOBS = [
  ("cross", "2D anime girl with her arms crossed, tsundere, she turns her face away with a little huff, then glances back with blushing cheeks, hair sways slightly, static camera, flat anime cel shading, same character design and colors"),
  ("pout",  "2D anime girl puffs her cheeks in a cute pout and shakes her head slightly side to side, blushing, twin tails sway, static camera, flat anime cel shading, same character design and colors"),
  ("cheer", "2D anime girl pumps both fists up and down excitedly with a big smile, bouncing slightly, twin tails bounce, static camera, flat anime cel shading, same character design and colors"),
]
c = Client("Lightricks/ltx-video-distilled", verbose=False)
for key, prompt in JOBS:
    t0 = time.time(); res = {"pose": key}
    try:
        r = c.predict(prompt, NEG, handle_file(indir + "/in-" + key + ".png"), None, 512, 512, "image-to-video", 3, 9, 42, False, 1, False,
                      api_name="/image_to_video")
        v = r[0]["video"] if isinstance(r[0], dict) else r[0]
        shutil.copy(v, outdir + "/x213-ltx-" + key + ".mp4"); res["saved"] = True
    except Exception as e:
        res["error"] = str(e)[:300]
    res["sec"] = round(time.time() - t0)
    print(json.dumps(res, ensure_ascii=False), flush=True)
PYEOF

{
echo "# Hugging Face の LTX-Video を Mac から呼ぶ・残り 3 ポーズ（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。アカウントもキーも使わない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
INDIR="$W/.x213-in-$STAMP"; mkdir -p "$INDIR"
for k in cross pout cheer; do
  if git -C "$REPO" show "origin/main:ops/data/x-cards/follower-300-grok/in-$k.png" > "$INDIR/in-$k.png" 2>/dev/null && [ -s "$INDIR/in-$k.png" ]; then
    printf '  入力 in-%s.png %s bytes\n' "$k" "$(wc -c < "$INDIR/in-$k.png" | tr -d ' ')"
  else printf '  **入力 in-%s.png が取れない**\n' "$k"; fi
done
P311="$(command -v python3.11 || echo /opt/homebrew/bin/python3.11)"
if [ ! -x "$VENV/bin/python" ]; then "$P311" -m venv "$VENV" 2>&1 | tail -2; fi
"$VENV/bin/python" -m pip install -q --disable-pip-version-check gradio_client 2>&1 | tail -2
printf '  gradio_client: %s\n' "$("$VENV/bin/python" -c 'import gradio_client; print(gradio_client.__version__)' 2>&1 | tail -1)"
rm -f "$OUTDIR"/x213-ltx-*.mp4
T0="$(date +%s)"
run_limited 240 "$LOG" "$VENV/bin/python" "$PY" "$INDIR" "$OUTDIR"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
sed "s/^/  /" "$LOG" | cut -c1-400
for f in "$OUTDIR"/x213-ltx-*.mp4; do [ -s "$f" ] && printf '  %s（%s bytes）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
echo '```'
echo
echo "**投稿していない。アカウントもキーも使っていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -rf "$INDIR"; rm -f "$PY" "$LOG"

n=0; for f in "$OUTDIR"/x213-ltx-*.mp4; do [ -s "$f" ] && n=$((n+1)); done
if [ "$n" -gt 0 ]; then echo "LTX-Video で $n 本 できた / $(basename "$OUT")"; else echo "**動画はできていない。レポートを確認すること** / $(basename "$OUT")"; fi
