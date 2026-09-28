#!/bin/bash
# **「今日 増えた分だけ外す」をやめて、目標比率へ寄せる作りにする。費用 $0。**
#
# ## `x194` で前提が崩れた
#
# 「フォローは 2 件/日」と報告したが、**ファネルの実績と合っていなかった。**
#
#   競合フォロワー刈り取り  毎日 **180 件 試して 8〜22 件 通過**
#   ハッシュタグ            毎日 10〜26 件 集めて 0〜4 件 通過
#   → **実勢 10〜24 件/日**
#
# 一方 `follow-balance.js` が読む `followed.json` からは **2 件**しか出ていない。
# **どちらかが嘘だが、ここからは決められない。**
#
# ## なぜ直さないといけないか
#
# いまの維持の式は **`quota = min(MAXN, 今日フォローした数)`**。
# **その数が 2 と出ている間は、実際に 16 件 増えても 2 件 しか外さない。**
#
#   実勢 +16 / 外す −2 = **1 日 +14 件**
#   → 173 件 は **2 日 と経たず 警戒線 192 を超える**
#   → そこで初めて「超過分を外す」段に入るので、**比率は 0.65 に張り付く**
#
# **利用者の指示は「これくらいの比率（0.584）を保て」。0.65 は保ったことにならない。**
#
# ## 直す: 数えるのをやめて、位置で決める
#
# **「今日 何件 増えたか」を数えるから、数え間違いに引きずられる。**
# **いま何件 居るかは、ヘッダーを見れば分かる。** そちらだけで決める。
#
#   目標 `FOLLOW_RATIO_TARGET` = **0.58**（指示を受けた時点の比率）→ 296 × 0.58 = **171 件**
#   警戒 `FOLLOW_RATIO_CEIL`   = 0.65 → **192 件**（超えていることを報告に出すだけ）
#   下限 `FOLLOW_RATIO_FLOOR`  = 0.45 → **133 件**（これ以下なら外さない）
#
#   **quota = min(MAXN, max(0, いまのフォロー中 − 171))**
#
# **`followedToday` に一切 依存しない。** 記録が壊れていても、実勢が何件でも、
# **毎回「目標より何件 多いか」だけを見て、その分 外す。** ずれれば次の回で戻る。
#
# いまなら 173 − 171 = **2 件**。実勢が 16 件/日 なら翌日は 187 − 171 = **16 件** 外す。
# **絶対上限 `MAX_UNFOLLOW`（20）はそのまま内側に残る。**
#
# ## あわせて `followed.json` を数え直す
#
# **`x194` の §1 は私の数え方が雑で、2 件 と出た。**
# 実際は入れ子で、`follow-balance.js` の `harvest()` は **195 件** 見つけている
# （9/28 のログに「フォロー日時の記録 195 件」と出ている）。
# **同じ歩き方で日ごとに数えて、ファネルと突き合わせる。**
#
# ## やらないこと
#
# **フォローしない。1 件も外さない（DRY）。plist も触らない。**
# **猶予・ホワイトリスト・相互の守りも触らない。LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
TARGET="$S/follow-balance.js"
FOLLOWED="$D/followed.json"
LF="$D/follow-balance-lists.json"
STAMP="$(date '+%Y%m%d-%H%M%S')"
TMPJS="$S/.follow-balance-setpoint-$STAMP.js"
PATCHER="$S/.follow-balance-setpoint-patch-$STAMP.js"
COUNTER="$S/.follow-balance-count-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/ratio-setpoint.md"
RUNLOG="$W/.x195-run.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

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

# ---- 置換器: アンカー 3 本 を literal で照合。1 本でも欠ければ 1 文字も書かない ----
cat > "$PATCHER" <<'PATCHEOF'
const fs = require("fs");
// **ファイルとして実行する**ので argv[1] はこのスクリプト自身のパス
const src = process.argv[2];
const dst = process.argv[3];
let t = fs.readFileSync(src, "utf8");

if (t.indexOf("FOLLOW_RATIO_TARGET") !== -1) { process.stdout.write("ALREADY\n"); process.exit(0); }
if (t.indexOf("FOLLOW_RATIO_CEIL") === -1) { process.stdout.write("NO_RATIO_BLOCK\n"); process.exit(2); }

const pairs = [
  [
    '  const FLOOR_RATIO = Number(process.env.FOLLOW_RATIO_FLOOR || 0.45);\n',
    '  const FLOOR_RATIO = Number(process.env.FOLLOW_RATIO_FLOOR || 0.45);\n' +
    '  // **目標。ここへ寄せる**（2026-09-28 に指示を受けた時点の比率）。\n' +
    '  // 「今日 何件 増えたか」を数えるのをやめた。`followed.json` の件数が\n' +
    '  // ファネルの実績（10〜24 件/日）と合っておらず、数え間違いに引きずられるため。\n' +
    '  // **いま何件 居るかはヘッダーで分かる。目標より多い分だけ外す。**\n' +
    '  const TARGET_RATIO = Number(process.env.FOLLOW_RATIO_TARGET || 0.58);\n',
  ],
  [
    '        "（帯 " + floorN + "〜" + ceilN + " 件 / " + FLOOR_RATIO + "〜" + CEIL_RATIO + "）");\n',
    '        "（目標 " + Math.floor(hdr.followers * TARGET_RATIO) + " 件 / 警戒 " + ceilN +\n' +
    '        " 件 / 下限 " + floorN + " 件）");\n',
  ],
  [
    '    if (over > 0) {\n' +
    '      quota = Math.min(MAXN, over + followedToday);\n' +
    '      ratioNote = "**上限 " + ceilN + " 件 を " + over + " 件 超えている → 超過分＋今日の増分**";\n' +
    '    } else if (hdr.following <= floorN) {\n' +
    '      quota = 0;\n' +
    '      ratioNote = "**下限 " + floorN + " 件 以下。外しすぎなので今回は外さない**";\n' +
    '    } else {\n' +
    '      quota = Math.min(MAXN, followedToday);\n' +
    '      ratioNote = "**帯の中。今日 増えた分だけ外して維持する**";\n' +
    '    }\n',
    '    const targetN = Math.floor(hdr.followers * TARGET_RATIO);\n' +
    '    if (hdr.following <= floorN) {\n' +
    '      quota = 0;\n' +
    '      ratioNote = "**下限 " + floorN + " 件 以下。外しすぎなので今回は外さない**";\n' +
    '    } else {\n' +
    '      // **目標より多い分だけ外す。** 今日の増分は数えない（記録に依存しない）\n' +
    '      quota = Math.min(MAXN, Math.max(0, hdr.following - targetN));\n' +
    '      if (quota === 0) {\n' +
    '        ratioNote = "**目標 " + targetN + " 件 以内。外さない**";\n' +
    '      } else if (over > 0) {\n' +
    '        ratioNote = "**警戒線 " + ceilN + " 件 を超えている。目標 " + targetN +\n' +
    '          " 件 まで戻す（あと " + (hdr.following - targetN) + " 件 / 今回 " + quota + " 件）**";\n' +
    '      } else {\n' +
    '        ratioNote = "**目標 " + targetN + " 件 へ寄せる（あと " + (hdr.following - targetN) +\n' +
    '          " 件 / 今回 " + quota + " 件）**";\n' +
    '      }\n' +
    '    }\n',
  ],
];

for (const [a] of pairs) {
  if (t.split(a).length !== 2) {
    process.stdout.write("ANCHOR_MISS:" + a.trim().slice(0, 48) + "\n");
    process.exit(2);
  }
}
for (const [a, b] of pairs) t = t.split(a).join(b);
fs.writeFileSync(dst, t);
process.stdout.write("PATCHED\n");
PATCHEOF

# ---- followed.json を harvest と同じ歩き方で日ごとに数える ----
cat > "$COUNTER" <<'CNTEOF'
const fs = require("fs");
const file = process.argv[2];
let root;
try { root = JSON.parse(fs.readFileSync(file, "utf8")); }
catch (e) { console.log("  **読めない: " + String(e.message).slice(0, 80) + "**"); process.exit(0); }

// **follow-balance.js の harvest() と同じ歩き方**（入れ子を辿る）
const byHandle = new Map();
const seen = new Set();
const walk = (node, keyHint) => {
  if (!node || typeof node !== "object" || seen.has(node)) return;
  seen.add(node);
  if (Array.isArray(node)) { for (const v of node) walk(v, null); return; }
  const at = node.followed_at || node.at || node.created_at || node.followedAt;
  const isLeaf = !Object.values(node).some((v) => v && typeof v === "object");
  const h = node.handle || node.screen_name || node.username || (isLeaf ? keyHint : null);
  if (h && typeof h === "string" && /^[A-Za-z0-9_]{1,15}$/.test(h.replace(/^@/, ""))) {
    const k = h.replace(/^@/, "").toLowerCase();
    const prev = byHandle.get(k);
    if (!prev || (at && !prev.at)) byHandle.set(k, { at: at || (prev && prev.at) || null });
  }
  for (const [k, v] of Object.entries(node)) walk(v, typeof k === "string" ? k : null);
};
walk(root, null);

const day = (ms) => new Date(ms + 9 * 3600 * 1000).toISOString().slice(0, 10);
const by = new Map();
let noAt = 0;
for (const [, v] of byHandle) {
  if (!v.at) { noAt++; continue; }
  const t = new Date(v.at).getTime();
  if (!Number.isFinite(t)) { noAt++; continue; }
  const k = day(t);
  by.set(k, (by.get(k) || 0) + 1);
}
console.log("  harvest と同じ歩き方で見つけた記録: " + byHandle.size + " 件");
console.log("  そのうち日時が無い/読めない: " + noAt + " 件");
console.log("");
const ks = [...by.keys()].sort().slice(-10);
if (!ks.length) { console.log("  **日付つきの記録が 1 件も無い**"); process.exit(0); }
console.log("  直近 10 日（この数が `今日フォローした数` の元）:");
for (const k of ks) console.log("    " + k + "  " + String(by.get(k)).padStart(4) + " 件");
console.log("");
console.log("  ※ ファネルの実績は competitor 8〜22 + hashtag 0〜4 = **10〜24 件/日**");
console.log("  ※ **大きく食い違うなら、この記録は上限の根拠に使えない**");
CNTEOF

{
echo "# 目標比率へ寄せる作りにする（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **\`x194\` で前提が崩れた。** ファネルは **10〜24 件/日** 通しているのに、"
echo "> \`follow-balance.js\` が読む数は **2 件**。**その数で維持すると比率が 0.65 に張り付く。**"
echo "> **数えるのをやめて、位置（いま何件 居るか）で決める。**"
echo "> **1 件も外さない（DRY）。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 1. \`followed.json\` を数え直す（**\`x194\` の §1 は私の数え方が雑だった**）"
echo
echo '```'
if [ ! -f "$FOLLOWED" ]; then
  echo "  **followed.json が無い: $FOLLOWED**"
else
  node "$COUNTER" "$FOLLOWED" 2>&1 | clean
fi
echo '```'
rm -f "$COUNTER"

echo
echo "## 2. 差し込む（アンカー 3 本・**1 本でも欠ければ書かない**）"
echo
echo '```'
if [ ! -f "$TARGET" ]; then
  echo "  **follow-balance.js が無い**"
  echo '```'
  rm -f "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
printf '  直す前: %s 行 / 目標比率が入っている箇所 %s（0 なら未導入）\n' \
  "$(wc -l < "$TARGET" | tr -d ' ')" "$(cnt 'FOLLOW_RATIO_TARGET' "$TARGET")"
echo
R="$(node "$PATCHER" "$TARGET" "$TMPJS" 2>&1)"; PRC=$?
printf '  %s (rc=%s)\n' "$(printf '%s' "$R" | head -2 | tr '\n' ' ')" "$PRC"
case "$R" in
  ALREADY*)
    echo "  → **もう入っている。書き換えない。**"
    rm -f "$PATCHER" "$TMPJS"
    ;;
  PATCHED*)
    echo
    echo "  --- 構文検査（**置く名前で打つ**）---"
    CK="$(node --check "$TMPJS" 2>&1)"; CRC=$?
    printf '    node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -2 | cut -c1-140)"
    if [ "$CRC" -ne 0 ]; then
      echo "    → **構文が通らない。置かない。**"
      rm -f "$PATCHER" "$TMPJS"
      echo '```'
      echo
      echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
      exit 1
    fi
    cp "$TARGET" "$TARGET.bak-$STAMP"
    mv "$TMPJS" "$TARGET"
    printf '    置いた。%s 行（控え: follow-balance.js.bak-%s）\n' "$(wc -l < "$TARGET" | tr -d ' ')" "$STAMP"
    ;;
  *)
    echo "  → **アンカーが合わない。1 文字も書いていない。**"
    echo
    echo "  --- いまの比率の行 ---"
    grep -an 'RATIO\|ratioNote' "$TARGET" 2>/dev/null | head -8 | cut -c1-180 | sed 's/^/    /'
    rm -f "$TMPJS"
    ;;
esac
rm -f "$PATCHER"
echo
printf '  目標比率  %s 箇所（1 以上が正）\n' "$(cnt 'FOLLOW_RATIO_TARGET' "$TARGET")"
printf '  今日の増分に依存する式 %s 箇所（**0 が正**）\n' "$(cnt 'Math.min(MAXN, followedToday)' "$TARGET")"
printf '  守りは残っているか: 猶予 %s / ホワイトリスト %s / 片思いの緩め %s\n' \
  "$(cnt 'GRACE_DAYS' "$TARGET")" "$(cnt 'ホワイトリスト' "$TARGET")" "$(cnt 'ONEWAY_IGNORE_ENGAGED' "$TARGET")"
echo '```'

echo
echo "## 3. 判定だけ見る（**DRY・1 件も外さない**）"
echo
echo '```'
T0="$(date +%s)"
MODE=decide DRY_RUN=1 CACHE_MAX_H=24 MAX_PROFILE_READS=3 DECIDE_BUDGET_S=20 \
  MIN_UNFOLLOW=20 MAX_UNFOLLOW=20 \
  run_limited 210 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **210 秒 で打ち切った**' || echo '← 自分で終わった' )"
echo
echo "  --- 比率の判定（**ここが見たいところ**）---"
grep -a -hE '実数（ヘッダー）|今回の上限|外す必要が無い|ヘッダーの実数が読めなかった' "$RUNLOG" 2>/dev/null \
  | tr -d '\000' | tail -6 | cut -c1-260 | clean | sed 's/^/    /'
echo
echo "  --- 出力 全部（**絞り込まない**）---"
cat "$RUNLOG" 2>/dev/null | tr -d '\000' | tail -30 | cut -c1-260 | clean | sed 's/^/    /'
echo '```'
rm -f "$RUNLOG"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 に出た行 | 意味 |"
echo "| --- | --- |"
echo "| \`目標 171 件 へ寄せる（あと 2 件 / 今回 2 件）\` | **狙いどおり。** 記録に依存せず位置で決まった |"
echo "| \`目標 171 件 以内。外さない\` | もう目標以下。正常 |"
echo "| \`警戒線 192 件 を超えている\` | フォローが走りすぎ。**毎回 最大 20 件 ずつ戻す** |"
echo "| \`下限 133 件 以下\` | 外しすぎの保護 |"
echo
echo "**§1 の日ごとの数がファネル（10〜24 件/日）と合わなくても、もう上限は狂わない。**"
echo "その数は参考として出すだけで、**判定には使っていない。**"
echo
echo "**1 件も外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$PATCHER" "$TMPJS" "$COUNTER" "$RUNLOG"

if grep -aq '目標比率' "$OUT" 2>/dev/null; then
  echo "目標比率へ寄せる作りにした / $(basename "$OUT")"
else
  echo "**入っていない。レポートを確認すること** / $(basename "$OUT")"
fi
