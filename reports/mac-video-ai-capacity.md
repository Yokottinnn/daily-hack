# Mac で動画 AI を動かせるか（2026-10-03 20:07 JST・$0）

**このレポートが作られた時刻: 2026-10-03 20:07:08 JST**

> **何も入れない。何も生成しない。LLM も API も呼ばない（$0／回・$0／日・$0／月）。**

## ① チップ・メモリ・GPU

```
  チップ        : Apple M3 Pro
  arm64 か      : 1
  メモリ        : 18 GB
  CPU コア      : 11（性能 5 / 効率 6）
  Chipset Model: Apple M3 Pro
  Total Number of Cores: 14
  Metal Support: Metal 4
  macOS         : 26.3.1
```

## ② 空き容量

```
  Filesystem      Size    Used   Avail Capacity iused ifree %iused  Mounted on
  /dev/disk3s5   460Gi   329Gi    94Gi    78%    3.9M  987M    0%   /System/Volumes/Data
```

## ③ 道具

```
  在る  python3    /usr/bin/python3  Python 3.9.6
  無い  python3.12
  在る  python3.11 /opt/homebrew/bin/python3.11  Python 3.11.14
  無い  python3.10
  在る  pip3       /usr/bin/pip3  pip 21.2.4 from /Library/Developer/CommandLineTools/Library/
  在る  git        /usr/bin/git  git version 2.50.1 (Apple Git-155)
  無い  git-lfs
  無い  ffmpeg
  在る  brew       /opt/homebrew/bin/brew  Homebrew 7.0.6
  無い  uv
  無い  conda
  venv: 使える
```

## ④ 既に入っている AI 系の道具

```
  無い  torch
  無い  diffusers
  無い  transformers
  無い  accelerate
  無い  gradio_client
  無い  huggingface_hub
  無い  mlx
  無い  ollama
```

## ⑤ Hugging Face に届くか

```
  huggingface.co: HTTP 200
  ltx の Space  : HTTP 200
```

**何も入れていない。何も生成していない。LLM も API も呼んでいない（$0／回・$0／日・$0／月）。**
