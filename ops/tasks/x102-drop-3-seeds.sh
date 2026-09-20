#!/bin/bash
# **返り率の悪い 3 種 を外す。承認済み。費用 $0（DOM 操作のみ・LLM を呼ばない）。**
#
# ## 根拠（x93・x99・x101 の実測）
#
#   種ごとの返り率            群で見ると
#     himawari56757  26.0%      残す 4 つ  mature 133 件 → 28 人  **21.1%**
#     haiji_doctor   20.8%      外す 3 つ  mature  89 件 →  7 人   **7.9%**
#     okamiler_pn    18.2%
#     tokufree3      16.2%      **2.7 倍 の差。n も足りている。**
#     POIKATSU_OTAKE 10.0%  ← 外す
#     money_yossy     8.6%  ← 外す
#     ukk_hx          4.2%  ← 外す
#
# x99 では、9/08→9/20 に返ってきた 27 人 のうち
# **外す 3 種 が連れてきたのは 2 人 だけ**だった（残す 4 種 は 21 人）。
#
# ## 「外すと空振りが増える」は実測で否定された（x101）
#
# 4 種 に減ると同じ種を 4 日ごとに触るため、`全 follower 既 follow` で
# 空振りが増えるのではないかと懸念していた。**ログを数えたら該当 0 件。**
# **一度も起きていない。** 懸念の根拠は無かった。
#
# ## 急ぐ理由
#
# 順番は配列の並びそのまま（`epoch 日 % 種数`）。x101 のログで確認済み。
#
#   9/18  ukk_hx          → 6 件（前日 19 件）
#   9/19  POIKATSU_OTAKE  → 4 件
#   9/22  money_yossy     ← **このままだと また落ちる日**
#
# **期限（9/30）まで 10 日 のうち 3〜4 日 が悪い種に当たる。**
#
# ## 戻し方
#
# 退避を残す。**候補が揃ったら 7 種 に戻す**（差し替え先を決めてから）。
#
# ## 当て方（x89 と同じ作法）
#
# **完全一致で 1 箇所だけ**であることを確かめてから置き換える。
# 0 箇所でも 2 箇所以上でも**何もしない。**
# 置き換えたら `node --check` を通してから入れ替える。
# **一時ファイルの拡張子は `.js` のまま**（最上位ルール 14）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
F="$S/competitor-follower-follow.js"
OUT="${OPS_REPORT_DIR:-/tmp}/drop-3-seeds.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
TMP="$S/.competitor-seeds-install.js"

{
echo "# 返り率の悪い 3 種 を外す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 外す 3 つ  mature  89 件 →  7 人   **7.9%**"
echo "> 残す 4 つ  mature 133 件 → 28 人   **21.1%**"
echo ">"
echo "> x99 では、返ってきた 27 人 のうち**外す 3 種 が連れてきたのは 2 人 だけ。**"
echo "> 「外すと空振りが増える」懸念は、x101 で **該当 0 件** と実測で否定された。"
echo
echo "**\$0**（DOM 操作のみ。LLM を呼ばない）。**退避を残すので戻せる。**"

# ═══════════ 0. 当てる前 ═══════════
echo
echo "## 0. 当てる前"
echo
echo '```'
GO=1
if [ ! -f "$F" ]; then
  echo "  **$F が無い。**"
  GO=0
else
  echo "  $(wc -l < "$F" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$F" 2>/dev/null)"
  echo
  echo "  --- いまの配列 ---"
  grep -n -A6 'const COMPETITORS' "$F" 2>/dev/null | head -10 | sed 's/^/    /'
fi
echo '```'

# ═══════════ 1. 当てる ═══════════
echo
echo "## 1. 置き換える（**完全一致で 1 箇所だけ**）"
echo
echo '```'
if [ "$GO" = "0" ]; then
  echo "  **対象が無いので何もしない。**"
else
  /usr/local/bin/node -e '
const fs = require("fs");
const src = fs.readFileSync(process.argv[1], "utf8");
const OLD = `const COMPETITORS = [
  "himawari56757", "ukk_hx", "POIKATSU_OTAKE",
  "tokufree3", "okamiler_pn",
  "money_yossy", "haiji_doctor",
];`;
const NEW = `// 2026-09-20 x102: **返り率の悪い 3 種 を外した。**
//   ukk_hx 4.2% / money_yossy 8.6% / POIKATSU_OTAKE 10.0%
//   群で見ると 外した 3 つ は mature 89 件 → 7 人（7.9%）、
//   残した 4 つ は mature 133 件 → 28 人（21.1%）で **2.7 倍 の差**。
//   9/08→9/20 に返ってきた 27 人 のうち、外した 3 種 は **2 人 だけ**だった。
//   「全 follower 既 follow」で終わった回はログ上 **0 件** で、空振りの懸念は否定済み。
//   **候補が揃ったら 7 種 に戻す。** 退避は .bak-* にある。
const COMPETITORS = [
  "himawari56757", "haiji_doctor",
  "okamiler_pn", "tokufree3",
];`;
// **数を先に確かめる。** 0 でも 2 以上でも触らない
let n = 0, i = 0;
while ((i = src.indexOf(OLD, i)) !== -1) { n++; i += OLD.length; }
console.log("  目印の出現回数: " + n + " 箇所");
if (n !== 1) {
  console.log("  **1 箇所 ではないので何もしない。**");
  process.exit(3);
}
fs.writeFileSync(process.argv[2], src.replace(OLD, NEW));
console.log("  置き換えた（**検査待ち**）");
' "$F" "$TMP" > "${TMPDIR:-/tmp}/.x102-replace.out" 2>&1
  # **パイプ越しに rc を見ない。** `sed` の終了コードを拾ってしまい、
  # 構文エラーでも「成功」と読めてしまう（最上位ルール 13 と同じ根）
  RC=$?
  sed 's/^/  /' "${TMPDIR:-/tmp}/.x102-replace.out" 2>/dev/null
  rm -f "${TMPDIR:-/tmp}/.x102-replace.out" 2>/dev/null || true
  if [ "$RC" != "0" ] || [ ! -s "$TMP" ]; then
    echo "    **置き換えなかった。元のまま。**（rc=$RC）"
    rm -f "$TMP" 2>/dev/null || true
    GO=0
  else
    echo
    echo "  --- 検査（**\`.js\` のままなので macOS でも通る**）---"
    /usr/local/bin/node --check "$TMP" > "${TMPDIR:-/tmp}/.x102-check.out" 2>&1
    CHK=$?
    head -3 "${TMPDIR:-/tmp}/.x102-check.out" 2>/dev/null | sed 's/^/    /'
    rm -f "${TMPDIR:-/tmp}/.x102-check.out" 2>/dev/null || true
    if [ "$CHK" = "0" ]; then
      echo "    node --check: **通った**"
      cp "$F" "$F.bak-$STAMP" 2>/dev/null && echo "    退避: $(basename "$F").bak-$STAMP"
      mv "$TMP" "$F" && echo "    **入れ替えた**"
    else
      echo "    **構文エラー（rc=$CHK）。入れ替えない。**"
      rm -f "$TMP" 2>/dev/null || true
      GO=0
    fi
  fi
fi
echo '```'

# ═══════════ 2. 当てた後 ═══════════
echo
echo "## 2. 当てた後（**実物**）"
echo
echo '```javascript'
if [ -f "$F" ]; then
  grep -n -B7 -A5 'const COMPETITORS' "$F" 2>/dev/null | head -20 | cut -c1-190 | sed 's/^/  /'
  echo
  echo "  --- 回し方の行（**種数が 4 になっているか**）---"
  grep -n -E 'dayIndex|COMPETITORS\.length' "$F" 2>/dev/null | head -4 | cut -c1-190 | sed 's/^/  /'
fi
echo '```'
echo
echo "**載せ直しは要らない。** 種はスクリプトの中身で、毎回 読み直される（plist の環境変数ではない）。"
echo "**次の定時（11:30 / 18:30）から 4 種 で回る。**"

# ═══════════ 3. これで何日 変わるか ═══════════
echo
echo "## 3. 期限（9/30）までの当たり方"
echo
echo '```'
echo "    いままで（7 種）"
echo "      9/21 okamiler_pn 18.2%   9/22 **money_yossy 8.6%**   9/23 haiji_doctor 20.8%"
echo "      9/24 himawari 26.0%      9/25 **ukk_hx 4.2%**        9/26 **POIKATSU 10.0%**"
echo "      → **10 日 のうち 3〜4 日 が悪い種**"
echo
echo "    これから（4 種）"
echo "      **全部 16.2%〜26.0% の種だけ。** 悪い日は来ない"
echo '```'
echo
echo "**これは並びの見込みであって、実際の当たりは \`epoch 日 % 4\` で決まる。**"
echo "次の実行ログの \`day-rotation index\` で確かめる。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**\`competitor-follower-follow\` は DOM 操作のみで LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**種を減らしてもフォロー数の上限は変わらない**（\`COMPETITOR_FOLLOW_DAILY_CAP=30\`）。"
echo "返信ループは \`MAX_PICKS\` を 6 にしたため **約 \$0.95/月（推定）**。"
echo "**実測は次の 24 時間 の \`cost_24h_usd\` で確かめる。**"
} > "$OUT" 2>&1

rm -f "$TMP" 2>/dev/null || true
echo "悪い 3 種 を外す / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
