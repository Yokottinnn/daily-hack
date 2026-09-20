#!/bin/bash
# **種の候補を、既存のログから拾い出す。測るだけ。費用 $0。**
#
# ## なぜ（x96 で候補プールが空だと分かった）
#
# `influencers.json` は **7 件 ちょうど**で、いま使っている 7 種と同じだった。
# **差し替える先が手元に無い。**
#
# ## 使える材料が 2 つ ある
#
# ### ① `hashtag-follow` が「大きすぎる」と弾いたアカウント
#
#   @rakutenplay     ❌ follower count out of range (102000, need 100-50000)
#   @tsuruhaofficial ❌ follower count out of range (297000, need 100-50000)
#
# **フォローする相手としては大きすぎるが、種としてはその大きさが要る。**
# 種は「その人のフォロワーを追う」ための入口なので、**フォロワーが多いほどよい。**
# しかも自分たちのハッシュタグから出てきた＝**ジャンルが近い。**
#
# ### ② `comment-orchestrator` が返信先に選んだ投稿の主
#
# 返信経路は **21.9%（n=146）** で、競合の平均より高い。
# **そこで選ばれている人は、ジャンルが合っている証拠がある。**
# フォロワーが多い人は種の候補になる。
#
# ## 規模では選ばない（x96 で否定された）
#
#   okamiler_pn  18.2%  平均 7757
#   ukk_hx        4.2%  平均 6993
#
# **ほぼ同じ規模で 4 倍 違う。** 効いているのはジャンルの近さ。
# だから候補は「**自分たちの導線から出てきたか**」で選ぶ。
#
# ## ハンドルを伏せない
#
# **公開アカウントの候補一覧であり、伏せると選べない**（x96 と同じ判断）。
# **フォローした相手のハンドルは出さない。**
#
# ## やらないこと
#
# **配列を書き換えない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
L="$W/logs"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/seed-harvest.md"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }

{
echo "# 種の候補を既存のログから拾う"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x96 で候補プールが空だと分かった。\`influencers.json\` は **7 件 ちょうど**で、"
echo "> いま使っている 7 種と同じ。**差し替える先が手元に無い。**"
echo ">"
echo "> **規模では選ばない。** okamiler_pn 18.2%（平均 7757）と ukk_hx 4.2%（平均 6993）は"
echo "> ほぼ同じ規模で 4 倍 違う。効いているのは**ジャンルの近さ**。"
echo
echo "**測るだけ。書き換えない。フォローしない。**"

# ═══════════ 1. 大きすぎて弾かれたアカウント ═══════════
echo
echo "## 1. \`hashtag-follow\` が「**大きすぎる**」と弾いたアカウント"
echo
echo "**フォロー相手としては大きすぎるが、種としてはその大きさが要る。**"
echo "自分たちのハッシュタグから出てきているので、ジャンルも近い。"
echo
echo '```'
HF="$L/hashtag-follow.log"
if [ ! -f "$HF" ]; then
  echo "  **$HF が無い。** logs/ の候補:"
  ls -1 "$L" 2>/dev/null | grep -i hashtag | head -6 | sed 's/^/    /'
else
  echo "  ログ: $(wc -l < "$HF" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$HF" 2>/dev/null)"
  echo
  echo "  --- 上限超えで弾かれたもの（**フォロワー数の多い順**）---"
  grep -oE '@[A-Za-z0-9_]{3,15}: ❌ follower count out of range \([0-9]+' "$HF" 2>/dev/null \
    | sed -E 's/@([A-Za-z0-9_]+): .*\(([0-9]+)/\2 \1/' \
    | sort -u -k2,2 \
    | sort -rn \
    | head -25 \
    | awk '{ printf("    %9d  %s\n", $1, $2) }'
  echo
  echo "  --- 下限割れで弾かれたもの（**種には使えない。参考**）---"
  grep -cE 'follower count out of range \([0-9]{1,2},' "$HF" 2>/dev/null | head -1 | sed 's/^/    小さすぎ: /'
  echo
  echo "  --- ジャンル違いで弾かれたもの（**種にもしない**）---"
  grep -oE '@[A-Za-z0-9_]{3,15}: ❌ off-niche' "$HF" 2>/dev/null \
    | sed -E 's/@([A-Za-z0-9_]+).*/\1/' | sort | uniq -c | sort -rn | head -10 \
    | awk '{ printf("    %3d 回  %s\n", $1, $2) }'
fi
echo '```'
echo
echo "**50000 を大きく超えているものほど、種としての母数が大きい。**"
echo "ただし**大きすぎる公式アカウントはフォロワーの質がばらける**ので、"
echo "10 万 前後 までを優先する（26.0% の himawari56757 がその帯の外なら、この前提は外れる）。"

# ═══════════ 2. 返信経路で選ばれている人 ═══════════
echo
echo "## 2. \`comment-orchestrator\` が返信先に選んだ投稿の主"
echo
echo "返信経路は **21.9%（n=146）** で競合の平均より高い。"
echo "**そこで選ばれている人はジャンルが合っている証拠がある。**"
echo
echo '```'
CS="$D/comment-state.json"
CW="$L/comment-warmup.log"
if [ -f "$CS" ]; then
  echo "  --- comment-state.json の構造 ---"
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { console.log("    **読めない**"); process.exit(0); }
if (Array.isArray(j)) console.log("    配列 " + j.length + " 件");
else for (const [k, v] of Object.entries(j).slice(0, 10)) {
  const t = Array.isArray(v) ? ("配列 " + v.length + " 件")
    : (v && typeof v === "object" ? ("オブジェクト " + Object.keys(v).length + " キー") : JSON.stringify(v));
  console.log("    " + String(k).padEnd(24) + " " + String(t).slice(0, 110));
}
' "$CS" 2>&1 | secrets
fi
echo
echo "  --- ログに出ている「選んだ相手」の頻度（上位 20）---"
if [ -f "$CW" ]; then
  grep -oE 'processing #[0-9]+/[0-9]+ for @[A-Za-z0-9_]{3,15}' "$CW" 2>/dev/null \
    | sed -E 's/.*@([A-Za-z0-9_]+)/\1/' | sort | uniq -c | sort -rn | head -20 \
    | awk '{ printf("    %3d 回  %s\n", $1, $2) }'
else
  echo "    **comment-warmup.log が無い。**"
fi
echo '```'
echo
echo "**複数回 選ばれている人は、こちらの狙う層と重なっている。**"
echo "その人自身のフォロワーが多ければ、種の候補になる。"

# ═══════════ 3. いまの 7 種（比較用） ═══════════
echo
echo "## 3. いまの 7 種（**入れ替え先を決めるための基準**）"
echo
echo '```'
echo "    種                  返り率   判定"
echo "    ------------------------------------------------"
echo "    himawari56757        26.0%   **残す**"
echo "    haiji_doctor         20.8%   **残す**"
echo "    okamiler_pn          18.2%   **残す**"
echo "    tokufree3            16.2%   **残す**"
echo "    POIKATSU_OTAKE       10.0%   入れ替え候補"
echo "    money_yossy           8.6%   入れ替え候補"
echo "    ukk_hx                4.2%   入れ替え候補"
echo
echo "    外す 3 つ の群  mature  89 件 →  7 人   **7.9%**"
echo "    残す 4 つ の群  mature 133 件 → 28 人   **21.1%**"
echo '```'
echo
echo "**群で見れば 2.7 倍 の差があり、n も足りている。** 差し替えの根拠はここ。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**ログと JSON を読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**差し替える場合も \$0。** \`competitor-follower-follow\` は DOM 操作のみで"
echo "LLM を呼ばないため、**フォロー数を変えても API 費用は動かない。**"
echo "返信ループの実測は 1 回 \$0.003 ／ 1 日 \$0.021 ／ 1 か月 約 \$0.63（別勘定）。"
} > "$OUT" 2>&1

echo "種の候補を拾う / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
