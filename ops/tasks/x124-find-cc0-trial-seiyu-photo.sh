#!/bin/bash
# **トライアル／西友の店舗写真で、出所を書かずに使えるものを探す。費用 $0（HTTP と JSON だけ）。**
#
# ## なぜ要るのか
#
# 利用者の指摘（2026-09-21・レビューページ）:
#
#   「これもトライアルと西友のロゴが入った店舗画像を透過した背景にして」
#
# **手元にある `trial-seiyu-hanakoganei.jpg` は CC BY-SA 4.0。**
# **X の告知画像に出所の行は出さない**と決まっている（CLAUDE.md 最上位ルール 8）ので、
# **表記が要る素材は使えない。** 消すのではなく**素材のほうを変える**のが決めごと。
#
# ## 使ってよいもの／だめなもの
#
#   使ってよい: CC0 / パブリックドメイン / 各社ロゴ（商標・識別目的）/ 自作の合成
#   使わない  : CC BY / CC BY-SA / 出典表記が要るもの
#
# ## 何をするか
#
#   ① Commons を 5 つの言い方で検索する（**1 語で諦めない**・最上位ルール 17）
#   ② **ライセンスを必ず一緒に取る。** 名前だけ見て使わない
#   ③ CC0 / PD のものは **base64 で持ち帰る**（250KB 未満のものだけ）
#
# ## macOS の作法（最上位ルール 14）
#
#   * **`base64 < file`**。引数でファイル名を渡すと macOS は受け付けない
#   * **出した base64 の長さを必ず出す。** 2026-09-20 に rc=0 のまま 1 行も出ず、
#     レポートだけ正常に見えた
#   * `timeout` は使わない。`curl --max-time` で代える
#
# ## やらないこと
#
# **画像を作らない。投稿しない。LLM を呼ばない。**
set -uo pipefail

OUT="${OPS_REPORT_DIR:-/tmp}/find-cc0-trial-seiyu-photo.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
TMP="${TMPDIR:-/tmp}/.x124"
mkdir -p "$TMP"
API="https://commons.wikimedia.org/w/api.php"

{
echo "# 出所を書かずに使えるトライアル／西友の店舗写真（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 手元の \`trial-seiyu-hanakoganei.jpg\` は **CC BY-SA 4.0**。"
echo "> **出所の行を出さない**と決まっているので（最上位ルール 8）、表記が要る素材は使えない。"
echo "> **消すのではなく素材のほうを変える。** CC0 / PD を探す。"

echo
echo "## 1. 検索（**1 語で諦めない**）"
echo
echo '```'
QUERIES="TRIAL supermarket Japan store|Seiyu supermarket store|西友 店舗|トライアル 店舗 スーパー|TRIAL SEIYU"
IFS='|' read -ra QS <<< "$QUERIES"
i=0
for q in "${QS[@]}"; do
  i=$((i+1))
  enc="$("$NODE_BIN" -e 'console.log(encodeURIComponent(process.argv[1]))' "$q")"
  f="$TMP/q$i.json"
  curl -sS --max-time 25 \
    "$API?action=query&generator=search&gsrsearch=${enc}&gsrnamespace=6&gsrlimit=20&prop=imageinfo&iiprop=url%7Csize%7Cextmetadata&format=json" \
    -o "$f" 2>/dev/null
  n="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  printf '  [%d] %-32s 応答 %s bytes\n' "$i" "$q" "$n"
done
echo '```'

echo
echo "## 2. 候補（**ライセンスつき。名前だけで使わない**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const dir=process.argv[1];
const seen=new Map();
for (const f of fs.readdirSync(dir).filter(x=>/^q\d+\.json$/.test(x))) {
  let j; try{ j=JSON.parse(fs.readFileSync(dir+"/"+f,"utf8")); }catch(e){ continue; }
  const pages=(j.query&&j.query.pages)||{};
  for (const p of Object.values(pages)) {
    const ii=(p.imageinfo||[])[0]; if(!ii) continue;
    const em=ii.extmetadata||{};
    const lic=(em.LicenseShortName&&em.LicenseShortName.value)||"?";
    seen.set(p.title,{lic, url:ii.url, size:ii.size||0, w:ii.width, h:ii.height});
  }
}
if(!seen.size){ console.log("  1 件も取れなかった"); process.exit(0); }
const free=[], other=[];
for (const [t,v] of seen) (/^(CC0|Public domain|PD)/i.test(v.lic) ? free : other).push([t,v]);
console.log("  ===== 出所が要らない（CC0 / PD）=====");
if(!free.length) console.log("    （無し）");
free.forEach(([t,v])=>console.log("    "+String(v.lic).padEnd(14)+" "+v.w+"x"+v.h+" "+Math.round(v.size/1024)+"KB  "+t));
console.log("");
console.log("  ===== 出所が要る（**使わない**）"+" 計 "+other.length+" 件 =====");
other.slice(0,12).forEach(([t,v])=>console.log("    "+String(v.lic).padEnd(14)+" "+t));
fs.writeFileSync(dir+"/free.json", JSON.stringify(free.map(([t,v])=>({t,...v})),null,1));
' "$TMP" 2>&1
echo '```'

echo
echo "## 3. CC0 / PD のものを持ち帰る"
echo
echo "**\`base64 < file\`**（macOS は引数のファイル名を受け付けない・最上位ルール 14）。"
echo "**長さを必ず出す。** rc=0 のまま 1 行も出ないことが実際に起きた。"
echo
FREE="$TMP/free.json"
if [ ! -s "$FREE" ]; then
  echo "- **候補リストが作れていない。**"
else
  CNT="$("$NODE_BIN" -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).length)' "$FREE" 2>/dev/null || echo 0)"
  case "$CNT" in ''|*[!0-9]*) CNT=0 ;; esac
  echo "- CC0 / PD の候補: **${CNT} 件**"
  if [ "$CNT" = "0" ]; then
    echo
    echo "### **CC0 / PD が 1 枚も無い**"
    echo
    echo "**この場合は写真をあきらめ、\`trial.png\` / \`seiyu.png\` のロゴを大きく薄く敷いた"
    echo "自作の合成に切り替える**（ロゴは商標・識別目的で使えて、出所の行が要らない）。"
  else
    k=0
    while [ "$k" -lt "$CNT" ] && [ "$k" -lt 3 ]; do
      U="$("$NODE_BIN" -e 'const a=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(a[+process.argv[2]].url)' "$FREE" "$k")"
      T="$("$NODE_BIN" -e 'const a=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(a[+process.argv[2]].t)' "$FREE" "$k")"
      IMG="$TMP/cand$k.bin"
      curl -sS --max-time 40 -A "daily-hack-ops/1.0" "$U" -o "$IMG" 2>/dev/null
      SZ="$(wc -c < "$IMG" 2>/dev/null | tr -d ' ')"
      case "$SZ" in ''|*[!0-9]*) SZ=0 ;; esac
      echo
      echo "### 候補 $k: $T"
      echo
      echo '```'
      echo "  url  : $U"
      echo "  bytes: $SZ"
      if [ "$SZ" -gt 0 ] && [ "$SZ" -lt 260000 ]; then
        B64="$TMP/cand$k.b64"
        base64 < "$IMG" > "$B64" 2>/dev/null
        BL="$(wc -c < "$B64" 2>/dev/null | tr -d ' ')"
        case "$BL" in ''|*[!0-9]*) BL=0 ;; esac
        echo "  base64 長: $BL 文字"
        [ "$BL" = "0" ] && echo "  **base64 が空。別の口で試すこと**"
      elif [ "$SZ" -ge 260000 ]; then
        echo "  **大きすぎるので base64 にしない。** URL から取り直す"
      else
        echo "  **取得できなかった**"
      fi
      echo '```'
      if [ -s "$TMP/cand$k.b64" ] && [ "$SZ" -lt 260000 ]; then
        echo
        echo '```base64'
        cat "$TMP/cand$k.b64"
        echo '```'
      fi
      k=$((k+1))
    done
  fi
fi

echo
echo "## 4. 使い方"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| CC0 / PD が在る | \`photos/\` に置き、\`_manifest.json\` に**取得元 URL と取得日**を残す |"
echo "| 無い | **ロゴを大きく薄く敷いた自作の合成に切り替える**（出所の行が要らない） |"
echo
echo "**どちらにせよ、出所の行はカードに出さない**（2026-09-20 の指示・最上位ルール 8）。"

echo
echo "## 5. 費用"
echo
echo "**Commons の API を 5 回 叩いて JSON を読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

rm -rf "$TMP" 2>/dev/null || true
echo "CC0 のトライアル／西友写真を探した / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
