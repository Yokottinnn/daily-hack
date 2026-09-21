#!/bin/bash
# **`follower-history.json` の中身をそのまま出す。測るだけ。費用 $0。**
#
# ## なぜ
#
# `x115` でファイルは見つかった（1,577 bytes / 73 行）が、
# **こちらが仮定した形と違って 1 件も読めなかった。**
#
#   「日付つきの人数を 1 件も取れなかった」
#
# **推測を重ねない。** 形を見てから読む側を書く（x108 → x109 と同じ順）。
#
# ## 小さいので全部 出す
#
# 1,577 bytes。**ハンドルが入っていたら伏せる**（レポートは公開リポジトリに載る）。
#
# ## やらないこと
#
# **書き換えない。フォローしない。LLM を呼ばない。読むだけ。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
F="$W/data/follower-history.json"
OUT="${OPS_REPORT_DIR:-/tmp}/dump-follower-history.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# \`follower-history.json\` の中身（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x115\` でファイルは見つかったが、**仮定した形と違って 1 件も読めなかった。**"
echo "> **推測を重ねない。** 形を見てから読む側を書く。"

echo
echo "## 1. ファイル"
echo
echo '```'
if [ -f "$F" ]; then
  echo "  $F"
  echo "  $(wc -c < "$F" | tr -d ' ') bytes / $(wc -l < "$F" | tr -d ' ') 行"
  echo "  更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$F" 2>/dev/null)"
else
  echo "  **無い: $F**"
fi
echo '```'

echo
echo "## 2. 構造（キーだけ）"
echo
echo '```'
if [ -f "$F" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
let j; try{ j=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }
catch(e){ console.log("  **JSON として読めない: "+e.message+"**"); process.exit(0); }
const t=Array.isArray(j)?"配列":typeof j;
console.log("  トップ: "+t+(Array.isArray(j)?"（"+j.length+" 要素）":""));
if(Array.isArray(j)){
  if(j.length) console.log("  1 要素目のキー: "+Object.keys(j[0]||{}).join(", "));
}else if(j&&typeof j==="object"){
  const ks=Object.keys(j);
  console.log("  キー数: "+ks.length);
  console.log("  先頭 8 キー: "+ks.slice(0,8).join(", "));
  const v=j[ks[0]];
  console.log("  1 個目の値の型: "+(Array.isArray(v)?"配列":typeof v));
  if(v&&typeof v==="object"&&!Array.isArray(v))
    console.log("  1 個目の値のキー: "+Object.keys(v).join(", "));
}
' "$F" 2>&1 | hide
fi
echo '```'

echo
echo "## 3. 全文（1,577 bytes なのでそのまま）"
echo
echo '```json'
[ -f "$F" ] && head -c 3000 "$F" | hide
echo
echo '```'

echo
echo "## 4. 費用"
echo
echo "**ファイルを 1 本 読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "follower-history の中身 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
