#!/bin/bash
# **Mac の中で動画 AI（ToonCrafter / LTX-Video / Wan など）を動かせるかを測る。読むだけ。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > 基本的に無料で作って欲しいので、無料でどうやって作れるかを考えて
#   → 「② Mac の性能を調べる」を選んでもらった
#
# Hugging Face の無料デモ（ToonCrafter / LTX-Video）は呼び出し方まで確かめたが、
# クラウドの接続元では匿名の GPU 枠が尽きていた（「180s requested vs. 163s left」「120s requested vs. -60s left」）。
# 枠の無い道は Mac の中で動かすことなので、**動かせる力があるか**を先に見る。
#
#   ① チップ・メモリ・GPU コア数（Apple Silicon か、統合メモリが何 GB か）
#   ② 空き容量（モデルは 5〜20GB）
#   ③ Python と pip / venv、ffmpeg、git-lfs の有無
#   ④ 既に入っている AI 系の道具（ComfyUI / diffusers / torch / ollama など）
#   ⑤ Hugging Face に Mac から届くか（匿名の GPU 枠は接続元ごと。Mac 側の残りは呼ばないと分からないので、届くかだけ見る）
#
# **何も入れない。何も生成しない。LLM も API も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/mac-video-ai-capacity.md"

{
echo "# Mac で動画 AI を動かせるか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **何も入れない。何も生成しない。LLM も API も呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo "## ① チップ・メモリ・GPU"
echo
echo '```'
printf '  チップ        : %s\n' "$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
printf '  arm64 か      : %s\n' "$(sysctl -n hw.optional.arm64 2>/dev/null || echo '?')"
mem="$(sysctl -n hw.memsize 2>/dev/null)"; [ -n "$mem" ] && printf '  メモリ        : %s GB\n' "$(( mem / 1073741824 ))"
printf '  CPU コア      : %s（性能 %s / 効率 %s）\n' "$(sysctl -n hw.ncpu 2>/dev/null)" "$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo '?')" "$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null || echo '?')"
system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Chipset Model|Total Number of Cores|Metal' | sed 's/^ */  /' | head -5
printf '  macOS         : %s\n' "$(sw_vers -productVersion 2>/dev/null)"
echo '```'
echo
echo "## ② 空き容量"
echo
echo '```'
df -h "$HOME" 2>/dev/null | sed 's/^/  /'
echo '```'
echo
echo "## ③ 道具"
echo
echo '```'
for c in python3 python3.12 python3.11 python3.10 pip3 git git-lfs ffmpeg brew uv conda; do
  p="$(command -v "$c" 2>/dev/null)"
  if [ -n "$p" ]; then v="$("$c" --version 2>&1 | head -1 | cut -c1-60)"; printf '  在る  %-10s %s  %s\n' "$c" "$p" "$v"
  else printf '  無い  %s\n' "$c"; fi
done
python3 -c "import venv; print('  venv: 使える')" 2>/dev/null || echo "  venv: 使えない"
echo '```'
echo
echo "## ④ 既に入っている AI 系の道具"
echo
echo '```'
for m in torch diffusers transformers accelerate gradio_client huggingface_hub mlx; do
  python3 -c "import importlib.util,sys; s=importlib.util.find_spec('$m'); print('  在る  $m' if s else '  無い  $m')" 2>/dev/null
done
python3 -c "import torch; print('  torch', torch.__version__, '/ MPS 使える:', torch.backends.mps.is_available())" 2>/dev/null || true
for d in "$HOME/ComfyUI" "$HOME/comfyui" "$HOME/Documents/ComfyUI" "/Applications/ComfyUI.app" "/Applications/DiffusionBee.app" "/Applications/Draw Things.app"; do
  [ -e "$d" ] && printf '  在る  %s\n' "${d/#$HOME/~}"
done
command -v ollama >/dev/null 2>&1 && echo "  在る  ollama" || echo "  無い  ollama"
du -sh "$HOME/.cache/huggingface" 2>/dev/null | sed 's/^/  HF のキャッシュ: /'
echo '```'
echo
echo "## ⑤ Hugging Face に届くか"
echo
echo '```'
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 https://huggingface.co/api/spaces/Lightricks/ltx-video-distilled 2>/dev/null)"
printf '  huggingface.co: HTTP %s\n' "${code:-失敗}"
code2="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 https://lightricks-ltx-video-distilled.hf.space/ 2>/dev/null)"
printf '  ltx の Space  : HTTP %s\n' "${code2:-失敗}"
echo '```'
echo
echo "**何も入れていない。何も生成していない。LLM も API も呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -aq '## ⑤' "$OUT" 2>/dev/null; then echo "Mac の動画 AI の力を測った / $(basename "$OUT")"; else echo "**測れていない** / $(basename "$OUT")"; fi
