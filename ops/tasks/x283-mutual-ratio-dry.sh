#!/bin/bash
# **相互フォローの整理に「未認証で、釣り合いが悪い（相手のフォロー÷フォロワー ≥ 0.8）」を足し、DRY で候補を数える。1 件も外さない。費用 $0。**
#
# ## 指示（2026-10-12）
#
#   > フォロ数／フォロワー数のバランスがたいしたことない青バッジがついていないアカウントなどはフォローを外しても
#   > 特にアンフォローされたり、将来的にみてデメリットがないと思うので、自身のフォロー数／フォロワー数の比率を
#   > 良く維持することでのブランディングについては徹底的に気をつけて
#   ダイアログ: 外す線は「0.8 以上」・進め方は「候補を数えてから本番」
#
# ## やること
#
#   ① mutual-prune.js に判定を 1 つ足す。**環境変数 MUTUAL_RATIO_CUT があるときだけ効く**。
#      plist には入れないので、**定時の本番の動きは変わらない**（利用者の確認後に plist に足す）
#      - プロフィールから「フォロー中」の数も読む
#      - 未認証 かつ 相手のフォロー中 ÷ フォロワー ≥ MUTUAL_RATIO_CUT → 外す候補（理由「釣り合い 0.xx」）
#      - 認証済み・ホワイトリスト・猶予中は、これまでどおり外さない
#   ② DRY_RUN=1・MUTUAL_RATIO_CUT=0.8・候補 15 件で打ち切り で走らせ、候補の数と内訳を出す（**外さない**）
#   ③ follow-balance.js の比率まわりの行を出す（次に「フォロワーが増えるほど上限を下げる」を入れるため）
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。** 4 分前後で終わる。
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-ratio-dry.md"
PATCH="$W/.x283-patch.js"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

cat > "$PATCH" <<'PATCHJS'
const fs = require("fs");
const { execFileSync } = require("child_process");
const p = process.argv[2] + "/mutual-prune.js";
let src = fs.readFileSync(p, "utf8");
if (src.includes("x283")) { console.log(JSON.stringify({ ok: true, note: "もう当たっている" })); process.exit(0); }
const edits = [
  // 定数
  ["const GRACE_DAYS = Number(", "after", "// 2026-10-12 x283: 未認証で釣り合いが悪い相互を外す（相手のフォロー中÷フォロワー がこれ以上）。未設定なら効かない\nconst RATIO_CUT = process.env.MUTUAL_RATIO_CUT ? Number(process.env.MUTUAL_RATIO_CUT) : null;"],
  // プロフィールで「フォロー中」も読む
  ["if (a) res.followersText = (a.innerText || \"\").trim();", "after", "// x283: フォロー中の数も読む\nconst fw = document.querySelector('a[href$=\"/following\"]');\nres.followingText = fw ? (fw.innerText || \"\").trim() : null;"],
  // 判定
  ["if (idle >= INACTIVE_DAYS) reasons.push(", "after", "// x283: 未認証（認証済みは上で残している）で、相手のフォロー中÷フォロワー が RATIO_CUT 以上\nif (RATIO_CUT !== null && fc > 0) { const fwc = parseCount(p.followingText); if (fwc !== null && fwc / fc >= RATIO_CUT) reasons.push(\"釣り合い \" + (fwc / fc).toFixed(2) + \"（\" + fwc + \"/\" + fc + \"）\"); }"],
];
let lines = src.split("\n");
for (const [needle, kind, add] of edits) {
  const hits = lines.map((l, i) => l.includes(needle) ? i : -1).filter((i) => i >= 0);
  if (hits.length !== 1) { console.log(JSON.stringify({ ok: false, error: "「" + needle.slice(0, 50) + "」を含む行が " + hits.length + " 行。書かない" })); process.exit(0); }
  const i = hits[0], ind = lines[i].match(/^\s*/)[0];
  const extra = add.split("\n").map((x) => ind + x);
  if (kind === "after") lines.splice(i + 1, 0, ...extra); else lines.splice(i, 0, ...extra);
}
fs.copyFileSync(p, p + ".bak-x283");
fs.writeFileSync(p, lines.join("\n"));
const chk = process.argv[2] + "/.x283-check-mutual-prune.js";
fs.copyFileSync(p, chk);
try { execFileSync(process.execPath, ["--check", chk], { stdio: "pipe" }); console.log(JSON.stringify({ ok: true, note: "書いた・node --check 通過" })); }
catch (e) { fs.copyFileSync(p + ".bak-x283", p); console.log(JSON.stringify({ ok: false, error: "node --check に落ちたので戻した " + String(e.stderr || e.message).slice(0, 200) })); }
finally { try { fs.unlinkSync(chk); } catch {} }
PATCHJS

{
echo "# 相互フォローの整理に「釣り合い」を足して DRY で数える（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・1 件も外していない）"
echo
echo "## ① パッチ"
echo '```json'
cd "$W" && node "$PATCH" "$S" 2>&1 | tail -2
echo '```'
echo
echo "## ② DRY（MUTUAL_RATIO_CUT=0.8・候補 15 件で打ち切り）"
echo
if grep -q "x283" "$S/mutual-prune.js"; then
  if pgrep -f "mutual-prune.js" >/dev/null 2>&1; then echo "**本番の mutual-prune が走っている。DRY は見送る。**"; else
  L="$W/.x283-dry.log"
  ( cd "$W" && env DRY_RUN=1 MUTUAL_RATIO_CUT=0.8 MAX_UNFOLLOW=15 GRACE_DAYS=1 OPS_WS="$W" CDP_URL="${CDP_URL:-http://127.0.0.1:18810}" /usr/local/bin/node "$S/mutual-prune.js" > "$L" 2>&1 ) &
  P=$!; w=0; while kill -0 "$P" 2>/dev/null && [ "$w" -lt 230 ]; do sleep 5; w=$((w+5)); done
  kill -0 "$P" 2>/dev/null && { echo "**230 秒で打ち切った（途中まで）**"; kill "$P" 2>/dev/null; }
  echo '```'
  grep -E "相互フォロー:|見たプロフィール|✂|DRY_RUN" "$L" | sed -E 's/^\[[^]]*\] //' | hide | head -40
  echo '```'
  echo
  echo "理由の内訳（✂ のみ）:"
  echo '```'
  grep "✂" "$L" | grep -o "釣り合い\|休眠\|格下" | sort | uniq -c
  echo "残した理由（上位）:"
  grep "・ " "$L" | sed -E 's/.* — //; s/（.*//; s/[0-9]+ 日.*//' | sort | uniq -c | sort -rn | head -8
  echo '```'
  rm -f "$L"
  fi
else
  echo "**パッチが当たっていないので DRY は走らせない。**"
fi
echo
echo "## ③ follow-balance.js の比率まわり"
echo '```javascript'
grep -n -i "RATIO\|CEIL\|FLOOR\|header\|ヘッダー\|target\|目標" "$S/follow-balance.js" 2>/dev/null | head -60
echo '```'
echo
echo "**1 件も外していない。plist も触っていない（定時の本番は従来どおり）。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 戻すときは mutual-prune.js.bak-x283。"
} > "$OUT" 2>&1
rm -f "$PATCH"
echo "相互フォローの整理に釣り合いを足して DRY で数えた / $(basename "$OUT")"
