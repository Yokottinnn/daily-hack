#!/bin/bash
# ①会話の継続（返信への返信）を実装するために、実機の構造を持ち帰る。
#
# **コード本体は出さない。** 関数名・入出力・ログ書式・状態ファイルのキーだけ。
# 推測で実装して外すのを避けるためのもの。今日までにパスもログ書式も
# 推測で書いて外し、そのたびに 30 分〜3 日を失っている。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-structure.md"

{
  echo "# 実機の構造（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "## scripts ディレクトリ"
  ls -1 "$W/scripts" 2>/dev/null | head -40

  for f in incoming-reply-watcher.js asuka-fill.js comment-warmup.js quick-reply-watcher.js; do
    p="$W/scripts/$f"
    echo
    echo "## $f"
    if [ ! -f "$p" ]; then echo "（存在しない）"; continue; fi
    echo "行数: $(wc -l < "$p" | tr -d ' ')"
    echo
    echo '### 関数と入口'
    grep -nE '^(async )?function |^const [A-Za-z_]+ = (async )?\(|^module\.exports|^export ' "$p" 2>/dev/null | head -25
    echo
    echo '### 環境変数の参照（キー名のみ）'
    grep -oE 'process\.env\.[A-Z_]+' "$p" 2>/dev/null | sort -u | head -20
    echo
    echo '### 読み書きしているファイル'
    grep -oE "(data|state|logs)/[A-Za-z0-9._-]+" "$p" 2>/dev/null | sort -u | head -15
  done

  echo
  echo "## 状態ファイルのキー（値は出さない）"
  for s in "$W"/state/*.json "$W"/data/*.json; do
    [ -f "$s" ] || continue
    echo "- $(basename "$s"): $(python3 -c "
import json,sys
try:
    d=json.load(open('$s'))
    print(', '.join(list(d.keys())[:12]) if isinstance(d,dict) else 'list len=%d' % len(d))
except Exception as e:
    print('読めない')
" 2>/dev/null)"
  done

  echo
  echo "## ログの書式（直近3行・先頭80字）"
  echo
  echo "> **20 文字以上の連続した英数字は伏せている。** ログに値が入っていると"
  echo "> そのまま公開リポジトリに載るため（検証中に実際に漏れた）。"
  for l in comment-warmup incoming-reply-watcher; do
    echo "### $l.log"
    tail -3 "$W/logs/$l.log" 2>/dev/null \
      | sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g' \
      | cut -c1-80
  done
} > "$OUT" 2>&1

echo "書き出した: $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
