#!/bin/bash
# **枠が 120 件/日 あるのに 2 件 しか出ていない理由を読む。測るだけ。費用 $0。**
#
# ## なぜ要るか（2026-09-29 に利用者が選択）
#
# 最上位ルール 19 で「フォロワー > フォロー」を保つ仕組みを入れた。そこで分かったのは、
# **いま余っているのはアンフォロー枠ではなくフォロー枠**だということ。
#
#   実数        フォロー中 **173** / フォロワー **296**
#   比率の上限  296 × 0.65 = **192** → **あと 19 件 フォローできる**
#   日次の枠    competitor **30** ＋ hashtag **90** = **120 件/日**
#   実績        **2 件/日**   ← **枠の 1.7%**
#
# **上限では止まっていない。** フォロワー増の主エンジンはフォローなので、ここが詰まっている
# ほうが効く。**どこで減っているかを先に測る**（測るものと直すものを分ける・最上位ルール 15）。
#
# ## 何を読むか（**直さない**）
#
#   ① **`data/followed.json` の日ごとの件数**（← 一次情報。ログの件数ではない・最上位ルール 11）
#   ② 2 つのジョブが**載っているか**（`launchctl print`。`list | grep` では足りない）
#   ③ **いつ・何回 撃っているか**（`StartCalendarInterval`）と**枠・フィルタの設定**
#   ④ **ファネル**: 発火 → 集めた → 試した → 通った（日ごと 10 日ぶん）
#   ⑤ **弾かれた理由の内訳**（`❌ …` の上位）
#
# ## この 3 つのどれかに落ちるはず
#
#   A. **候補が集まっていない**  → 集めた数が小さい。タグ・シードの供給の問題
#   B. **フィルタが厳しい**      → 試した数は多いが通った数が小さい。理由の内訳に出る
#   C. **そもそも撃っていない**  → 発火が 0。ジョブが載っていないか時刻の問題
#
# **A / B / C で打つ手が全く違う。推測で広げない。**
#
# ## やらないこと
#
# **フォローしない。枠もフィルタも変えない。ブラウザを触らない**（ファイルを読むだけ・ルール 15）。
# **LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
FOLLOWED="$D/followed.json"
OUT="${OPS_REPORT_DIR:-/tmp}/why-only-2-follows.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[abposr]-)[A-Za-z0-9-]+#\1<MASKED>#g' \
                   -e 's#([A-Z_]*(TOKEN|KEY|SECRET)[A-Z_]*[[:space:]]*=>?[[:space:]]*)[^[:space:]]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# **ファネルを日ごとに出す。** ログの文言は x69 で実物を確認したものを使う
funnel() {
  local lf="$1" label="$2"
  if [ ! -f "$lf" ]; then
    echo "    **$(basename "$lf") が無い。一度も走っていない可能性**"
    return
  fi
  printf '    更新 %s / %s bytes\n\n' \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$lf" 2>/dev/null)" "$(wc -c < "$lf" | tr -d ' ')"
  # **`grep -a` を付ける**（日本語の表示名でバイナリ判定されると全部 消える・ルール 13）
  grep -a '' "$lf" 2>/dev/null | tr -d '\000' | awk -v lbl="$label" '
    match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { d = substr($0, RSTART, RLENGTH) }
    d == "" { next }
    index($0, lbl " start") { fires[d]++ }
    /SKIP/ { skips[d]++ }
    match($0, /=== end: [0-9]+\/[0-9]+ OK ===/) {
      s = substr($0, RSTART + 9, RLENGTH - 16)
      split(s, a, "/"); ok[d] += a[1] + 0; tried[d] += a[2] + 0
    }
    match($0, /[0-9]+ (candidates|targets|authors|posts)/) {
      c = substr($0, RSTART, RLENGTH); split(c, b, " "); got[d] += b[1] + 0
    }
    { seen[d] = 1 }
    END {
      n = 0
      for (k in seen) ks[n++] = k
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (ks[i] > ks[j]) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
      st = (n > 10 ? n - 10 : 0)
      if (n == 0) { print "    （日付つきの行が無い）"; exit }
      printf("    %-12s %6s %6s %7s %6s %6s\n", "日付", "発火", "SKIP", "集めた", "試した", "通った")
      for (i = st; i < n; i++) {
        k = ks[i]
        printf("    %-12s %6d %6d %7d %6d %6d\n", k, fires[k], skips[k], got[k], tried[k], ok[k])
      }
    }
  ' 2>/dev/null | clean
  echo
  echo "    --- 弾かれた理由（上位 10）---"
  grep -a -oE '❌ [^(]{1,60}' "$lf" 2>/dev/null | sed 's/❌ //' | sed 's/ *$//' \
    | sort | uniq -c | sort -rn | head -10 | sed 's/^/      /' | clean
}

{
echo "# 枠 120 件/日 に対して 2 件 しか出ていない理由（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **測るだけ。フォローしない。枠もフィルタも変えない。ブラウザも触らない。**"
echo "> **LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo "いま余っているのは**アンフォロー枠ではなくフォロー枠**。"
echo "実数 **173 / 296**、比率の上限は **192** なので **あと 19 件** フォローできる。"

echo
echo "## 1. 実際にフォローした数（**一次情報**）"
echo
echo "\`data/followed.json\` の日付。**ログの件数ではない**（最上位ルール 11）。"
echo
echo '```'
if [ ! -f "$FOLLOWED" ]; then
  echo "  **followed.json が無い: $FOLLOWED**"
  ls -1 "$D" 2>/dev/null | grep -i follow | sed 's/^/    /' || true
else
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("  **読めない: " + e.message.slice(0, 80) + "**"); process.exit(0); }
    const rows = Array.isArray(j) ? j : Object.entries(j || {}).map(([h, v]) => ({ h, ...(v || {}) }));
    const day = (ms) => new Date(ms + 9 * 3600 * 1000).toISOString().slice(0, 10);
    const by = new Map();
    let noAt = 0;
    for (const r of rows) {
      const at = r.at || r.followed_at || r.time;
      if (!at) { noAt++; continue; }
      const t = new Date(at).getTime();
      if (!Number.isFinite(t)) { noAt++; continue; }
      const k = day(t);
      by.set(k, (by.get(k) || 0) + 1);
    }
    console.log("  記録 全体: " + rows.length + " 件（日時が無い/読めない: " + noAt + " 件）");
    console.log("");
    const ks = [...by.keys()].sort().slice(-12);
    if (!ks.length) { console.log("  **日付つきの記録が 1 件も無い**"); process.exit(0); }
    console.log("  直近 12 日:");
    let sum = 0;
    for (const k of ks) { console.log("    " + k + "  " + String(by.get(k)).padStart(4) + " 件"); sum += by.get(k); }
    console.log("");
    console.log("  平均 " + (sum / ks.length).toFixed(1) + " 件/日   ← **枠は 120 件/日**");
  ' "$FOLLOWED" 2>&1 | clean
fi
echo '```'

echo
echo "## 2. ジョブは載っているか（**\`list | grep\` では足りない**）"
echo
echo '```'
for j in competitor-follower-follow hashtag-follow; do
  LB="ai.openclaw.$j"
  printf '  %s\n' "$LB"
  if launchctl print "gui/$UID_N/$LB" >/dev/null 2>&1; then
    launchctl print "gui/$UID_N/$LB" 2>/dev/null \
      | grep -aE '^[[:space:]]+(state|runs|last exit code) ' | sed 's/^/      /'
    echo "      → **載っている**"
  else
    echo "      → **載っていない。撃てるわけがない**"
  fi
done
echo '```'

echo
echo "## 3. いつ撃つか・枠とフィルタ（**設定の実物**）"
echo
echo '```'
for j in competitor-follower-follow hashtag-follow; do
  P="$LA/ai.openclaw.$j.plist"
  printf '  === %s ===\n' "$j"
  if [ ! -f "$P" ]; then
    echo "    **plist が無い**"
    continue
  fi
  echo "    --- 起動時刻 ---"
  /usr/libexec/PlistBuddy -c "Print :StartCalendarInterval" "$P" 2>/dev/null \
    | grep -aE 'Hour|Minute|Weekday' | sed 's/^/      /' || echo "      （StartInterval かもしれない）"
  /usr/libexec/PlistBuddy -c "Print :StartInterval" "$P" 2>/dev/null | sed 's/^/      StartInterval = /'
  echo "    --- 環境変数（**秘密は伏せる**）---"
  /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$P" 2>/dev/null \
    | grep -avE '^[[:space:]]*(Dict|\{|\})' | cut -c1-160 | sed 's/^/      /' | clean
  echo
done
echo '```'

echo
echo "## 4. ファネル: 発火 → 集めた → 試した → 通った"
echo
echo "**どこで減っているかで打つ手が変わる。**"
echo
echo "### 4-A. 競合フォロワー刈り取り（枠 30/日）"
echo
echo '```'
funnel "$L/competitor-follower-follow.log" "competitor-follower-follow"
echo '```'
echo
echo "### 4-B. ハッシュタグ（枠 90/日）"
echo
echo '```'
funnel "$L/hashtag-follow.log" "hashtag-follow"
echo '```'

echo
echo "## 5. 候補の在庫（**集まっているのか**）"
echo
echo '```'
for f in competitor-seeds.json competitor-candidates.json hashtag-candidates.json follow-queue.json; do
  if [ -f "$D/$f" ]; then
    printf '  %-28s %s 件 / 更新 %s\n' "$f" \
      "$(node -e '
        const fs=require("fs");
        let j; try{j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));}catch(e){process.stdout.write("?");process.exit(0);}
        process.stdout.write(String(Array.isArray(j)?j.length:Object.keys(j||{}).length));
      ' "$D/$f" 2>/dev/null)" \
      "$(stat -f '%Sm' -t '%m-%d %H:%M' "$D/$f" 2>/dev/null)"
  fi
done
echo
echo "  --- data/ に在る follow 関連（参考）---"
ls -1 "$D" 2>/dev/null | grep -iE 'follow|seed|candidate|hashtag' | head -20 | sed 's/^/    /'
echo '```'

echo
echo "---"
echo
echo "## 読み方（**A / B / C で打つ手が全く違う**）"
echo
echo "| §4 の出方 | どれか | 次にやること |"
echo "| --- | --- | --- |"
echo "| **集めた**が小さい（0〜数件） | **A. 候補が来ていない** | タグ・シードの供給を直す。**枠を上げても無駄** |"
echo "| **試した**は多いが**通った**が小さい | **B. フィルタが厳しい** | §4 の理由の内訳を見て、効いている条件だけ緩める |"
echo "| **発火**が 0 | **C. 撃っていない** | §2 の \`載っている\` と §3 の起動時刻を見る |"
echo "| §1 の平均が §4 の\`通った\`と合わない | **記録か集計のどちらかが嘘** | \`followed.json\` を正とする（ルール 11）|"
echo
echo "**どれであっても、フォローを増やすときは比率の上限 192 件 を超えない**（最上位ルール 19）。"
echo "いまの余地は **19 件**。それ以上 増やすならフォロワーが増えるのが先。"
echo
echo "**フォローしていない。設定も変えていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -aq '読み方' "$OUT" 2>/dev/null; then
  echo "フォローが詰まっている場所を測った / $(basename "$OUT")"
else
  echo "**測れていない。レポートを確認すること** / $(basename "$OUT")"
fi
