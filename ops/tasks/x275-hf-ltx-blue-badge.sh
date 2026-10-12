#!/bin/bash
# **青バッジ報告の動く版: キャラを AI（Hugging Face の無料 LTX-Video）で動かす。Mac から呼ぶ。費用 $0。**
#
# ## 指示（2026-10-12・レビューページのコメント）
#
#   > 動画に関しては、このリンクで投稿している GIF を参考にして、モーション等ももう少し派手にしてほしい
#   >（https://x.com/heng_ji31590/status/2106354716733235381 ＝フォロワー 300 のお礼。x212/x213 の LTX で作った）
#   > 動画の動くキャラクターが、少しタッチが元々のキャラクターの画像と違うので、そこだけ調整してほしい
#
#   x213 と同じ呼び方。**タッチを元絵に寄せるため**、プロンプトで「入力画像と同じ線・塗り・色」を強く指定し、
#   動きは大きく（派手に）・カメラは固定。同じ入力で seed を変えて 2 本ずつ作り、元絵に近いものを選ぶ。
#
#   - 入力: origin/main の ops/data/x-cards/blue-badge-grok/in-{smug,cheer}.png（カードの背景にキャラを置いた 640x640）
#   - 出力: $OPS_REPORT_DIR/x275-ltx-<pose>-<seed>.mp4
#
# **投稿しない。アカウントもキーも使わない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${OPS_MAIN_REPO:-$HOME/projects/anta-baka-x/blog}"
VENV="$W/.venv-video"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/hf-ltx-blue-badge.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
PY="$W/.x275-run-$STAMP.py"
LOG="$W/.x275-log-$STAMP.txt"

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
NEG = "worst quality, different art style, realistic, 3d, painterly, sketch, inconsistent motion, blurry, jittery, distorted, morphing face, color shift, extra fingers, extra arms, text, camera movement"
STYLE = "keep exactly the same 2D anime illustration as the input image: same clean line art, same flat cel shading, same pink hair and purple eyes, same face proportions, static camera"
JOBS = [
  ("smug", 42, "2D anime girl with a smug proud smile, she puffs out her chest, tosses her pink twin tails with a confident head shake, winks, then nods triumphantly, lively bouncy motion, " + STYLE),
  ("smug", 7,  "2D anime girl with a smug proud smile, she puffs out her chest, tosses her pink twin tails with a confident head shake, winks, then nods triumphantly, lively bouncy motion, " + STYLE),
  ("cheer", 42, "2D anime girl pumps both fists up and down excitedly with a big smile, bouncing energetically, twin tails bounce, sparkling eyes, " + STYLE),
  ("cheer", 7,  "2D anime girl pumps both fists up and down excitedly with a big smile, bouncing energetically, twin tails bounce, sparkling eyes, " + STYLE),
]
c = Client("Lightricks/ltx-video-distilled", verbose=False)
for key, seed, prompt in JOBS:
    t0 = time.time(); res = {"pose": key, "seed": seed}
    try:
        r = c.predict(prompt, NEG, handle_file(indir + "/in-" + key + ".png"), None, 512, 512, "image-to-video", 3, 9, seed, False, 1, False,
                      api_name="/image_to_video")
        v = r[0]["video"] if isinstance(r[0], dict) else r[0]
        shutil.copy(v, outdir + "/x275-ltx-" + key + "-" + str(seed) + ".mp4"); res["saved"] = True
    except Exception as e:
        res["error"] = str(e)[:300]
    res["sec"] = round(time.time() - t0)
    print(json.dumps(res, ensure_ascii=False), flush=True)
PYEOF

{
echo "# 青バッジ報告のキャラを LTX-Video で動かす（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。アカウントもキーも使わない（\$0／回・\$0／日・\$0／月）。**"
echo
echo '```'
INDIR="$W/.x275-in-$STAMP"; mkdir -p "$INDIR"
for k in smug cheer; do
  if git -C "$REPO" show "origin/main:ops/data/x-cards/blue-badge-grok/in-$k.png" > "$INDIR/in-$k.png" 2>/dev/null && [ -s "$INDIR/in-$k.png" ]; then
    printf '  入力 in-%s.png %s bytes\n' "$k" "$(wc -c < "$INDIR/in-$k.png" | tr -d ' ')"
  else printf '  **入力 in-%s.png が取れない**\n' "$k"; fi
done
P311="$(command -v python3.11 || echo /opt/homebrew/bin/python3.11)"
if [ ! -x "$VENV/bin/python" ]; then "$P311" -m venv "$VENV" 2>&1 | tail -2; fi
"$VENV/bin/python" -m pip install -q --disable-pip-version-check gradio_client 2>&1 | tail -2
printf '  gradio_client: %s\n' "$("$VENV/bin/python" -c 'import gradio_client; print(gradio_client.__version__)' 2>&1 | tail -1)"
rm -f "$OUTDIR"/x275-ltx-*.mp4
T0="$(date +%s)"
run_limited 280 "$LOG" "$VENV/bin/python" "$PY" "$INDIR" "$OUTDIR"; RC=$?
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
sed "s/^/  /" "$LOG" | cut -c1-400
for f in "$OUTDIR"/x275-ltx-*.mp4; do [ -s "$f" ] && printf '  %s（%s bytes）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
echo '```'
echo
echo "**投稿していない。アカウントもキーも使っていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -rf "$INDIR"; rm -f "$PY" "$LOG"

n=0; for f in "$OUTDIR"/x275-ltx-*.mp4; do [ -s "$f" ] && n=$((n+1)); done
if [ "$n" -gt 0 ]; then echo "LTX-Video で $n 本 できた / $(basename "$OUT")"; else echo "**動画はできていない。レポートを確認すること** / $(basename "$OUT")"; fi
