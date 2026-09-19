#!/bin/bash
# **終了コード 5 と 2 が何を意味するかを、ソースで確定する。測るだけ。費用 $0。**
#
# ## なぜ（x87 で中身は見えたが、意味が確定していない）
#
# ### comment-warmup（終了コード 5）
#
#   [2026-09-20T01:17:39] enqueue: ... x_tweet_id 2101344972452848045  ← **出ている**
#   [2026-09-20T01:21:38] === comment orchestrator start (max_picks=4) ===
#   [2026-09-20T01:24:39] no candidates                                ← **これで終わった**
#
# **投稿は出ている。** つまり 5 は「壊れている」ではなく
# 「**候補が無かった**」の可能性が高い。だとすれば直すものではない。
# **ソースで `exit 5` を探して確定する。推測でコードを直さない。**
#
# 別に `[textarea] primary all failed → no reply btn either` も出ているが、
# これは**別の run の記録**。混ぜない。
#
# ### pipeline-heartbeat（終了コード 2）
#
#   {"ok":true,"overall":"CRIT","results":[{"name":"login","level":"OK",...
#
# **`overall` が CRIT。** ただしログが途中で切れていて、
# **どの check が CRIT なのかが見えていない。** そこを出す。
# `login` と `chrome_cdp` は OK なので、**認証でも CDP でもない。**
#
# ## やらないこと
#
# **直さない。設定を変えない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/exit-5-and-2.md"

hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xoxb-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 終了コード 5 と 2 の意味を確定する"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x87 でログは見えた。**意味が確定していない。**"
echo "> comment-warmup は**投稿が出ているのに 5 で終わっている**ので、"
echo "> 5 は異常ではなく「候補なし」かもしれない。**ソースで確かめる。**"
echo
echo "**測るだけ。直さない。**"

# ═══════════ 1. comment-warmup の exit 5 ═══════════
echo
echo "## 1. comment-warmup の \`exit 5\` はどこで打たれるか"
echo
echo '```'
echo "  --- plist が実行しているもの ---"
P="$HOME/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"
if [ -f "$P" ]; then
  /usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null | head -8 | sed 's/^/    /'
else
  echo "    **plist が無い**"
fi
echo
echo "  --- scripts/ の中で 5 を返している箇所 ---"
grep -rn -E 'exit\(5\)|exit 5|process\.exitCode *= *5' "$S" 2>/dev/null \
  | grep -v '\.bak' | head -12 | cut -c1-185 | sed 's/^/    /' | clean
echo
echo "  --- 「no candidates」を出している箇所（その直後が 5 かを見る） ---"
grep -rn -F 'no candidates' "$S" 2>/dev/null | grep -v '\.bak' | head -6 \
  | cut -c1-185 | sed 's/^/    /' | clean
echo
echo "  --- その前後 6 行 ---"
F="$(grep -rl -F 'no candidates' "$S" 2>/dev/null | grep -v '\.bak' | head -1)"
if [ -n "$F" ]; then
  echo "    ══ $(basename "$F")"
  grep -n -F -A6 -B2 'no candidates' "$F" 2>/dev/null | head -24 \
    | cut -c1-185 | sed 's/^/      /' | clean
fi
echo '```'
echo
echo "**5 が「候補なし」なら、直すものではない。** その場合は"
echo "「候補が出ない」ほうが本体の問題であり、終了コードは症状ではない。"

# ═══════════ 2. 直近の run は出たのか ═══════════
echo
echo "## 2. 直近の run で**実際に出たか**（一次情報＝\`x_tweet_id\`）"
echo
echo '```'
Q="$W/data/comment-queue.json"
if [ -f "$Q" ]; then
  node -e '
    const fs = require("fs");
    let d; try { d = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) {
      console.log("  **キューが読めない: " + e.message.slice(0,120) + "**"); process.exit(0);
    }
    const rows = Array.isArray(d) ? d : (d.entries || d.items || []);
    const withId = rows.filter((r) => r && (r.x_tweet_id || r.tweet_id));
    console.log("  キュー合計: " + rows.length + " 件 / **x_tweet_id を持つもの: " + withId.length + " 件**");
    const since = Date.now() - 24 * 3600 * 1000;
    const recent = withId.filter((r) => {
      const t = Date.parse(r.posted_at || r.updated_at || r.created_at || 0);
      return t && t >= since;
    });
    console.log("  **直近 24 時間に出たもの: " + recent.length + " 件**");
    for (const r of recent.slice(-8)) {
      console.log("    " + (r.posted_at || r.created_at || "?") + "  " + (r.x_tweet_id || r.tweet_id));
    }
  ' "$Q" 2>&1 | clean
else
  echo "  **$Q が無い。** data/ の候補:"
  ls -1 "$W/data" 2>/dev/null | grep -i -E 'queue|comment' | head -8 | sed 's/^/    /'
fi
echo '```'
echo
echo "**\`x_tweet_id\` と投稿 URL だけが一次情報**（最上位ルール 11）。"
echo "ログの行数や \`posted_today\` はここに含めない。"

# ═══════════ 3. pipeline-heartbeat の CRIT ═══════════
echo
echo "## 3. pipeline-heartbeat は**どの check が CRIT なのか**"
echo
echo '```'
PH="$L/pipeline-heartbeat.log"
if [ -f "$PH" ]; then
  echo "  --- 最後の判定 JSON を 1 本 取り出して、CRIT / WARN だけ並べる ---"
  grep -o '{"ok":true,"overall":.*' "$PH" 2>/dev/null | tail -1 > /tmp/.ph-last.json
  if [ -s /tmp/.ph-last.json ]; then
    node -e '
      const fs = require("fs");
      let d; try { d = JSON.parse(fs.readFileSync("/tmp/.ph-last.json", "utf8")); } catch (e) {
        console.log("  **判定 JSON が読めない: " + e.message.slice(0,120) + "**"); process.exit(0);
      }
      console.log("  overall = " + d.overall);
      for (const r of (d.results || [])) {
        const mark = r.level === "OK" ? "  " : "**";
        console.log("    " + mark + " " + String(r.level).padEnd(5) + " " +
          String(r.name).padEnd(24) + " " + String(r.detail || "").slice(0, 90) +
          (r.healable ? "  （自動復旧できる）" : ""));
      }
    ' 2>&1 | clean
  else
    echo "  **判定 JSON の行が見つからない。**"
  fi
  echo
  echo "  --- 直近 12 行 ---"
  tail -12 "$PH" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
else
  echo "  **$PH が無い。**"
  ls -1 "$L" 2>/dev/null | grep -i pipeline | head -6 | sed 's/^/    候補: /'
fi
echo
echo "  --- exit 2 を打っている箇所 ---"
grep -rn -E 'exit\(2\)|exit 2|process\.exitCode *= *2' "$S" 2>/dev/null \
  | grep -v '\.bak' | grep -i -E 'heartbeat|pipeline' | head -8 \
  | cut -c1-185 | sed 's/^/    /' | clean
echo '```'
echo
echo "**\`overall=CRIT\` で 2 を返しているだけなら、2 自体は正常な報告。**"
echo "問題は**どの check が CRIT のままか**で、そこは上の一覧に出る。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**ソースとログとキューを読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44"
echo "（\`MAX_PICKS\` は 4 のまま）。フォロー・アンフォロー系は \$0（DOM 操作のみ）。"
} > "$OUT" 2>&1

rm -f /tmp/.ph-last.json 2>/dev/null || true
echo "終了コード 5 と 2 の意味 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
