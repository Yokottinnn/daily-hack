#!/bin/bash
# **Mac の Claude Code（サブスクリプション）の使用量を集計する。読むだけ。費用 $0。**
#
# ## 指示（2026-10-11）
#
#   > いまのClaudeの利用トークンとかをみて、どのプランにしたらいいかをアドバイスちょうだい
#   > 110ドルのMAXプランは高いんじゃないかと思って
#
# Claude Code は会話の記録（~/.claude/projects/**/*.jsonl）に、返答ごとの使用トークンを残している。
# それを日別・モデル別・プロジェクト別に足す（同じ返答が複数行に書かれるので message.id で重複を除く）。
#   ① 直近 35 日の日別（返答数・入力・出力・キャッシュ作成・キャッシュ読み込み）
#   ② モデル別の合計
#   ③ プロジェクト（作業フォルダ）別の合計
#   ④ 5 時間ごとの枠でいちばん使った時間帯（上位 10）
#   ⑤ Claude Code の版・認証の種類（サブスクリプションか API キーか。キーそのものは出さない）
#
# **LLM を呼ばない。会話の中身は出さない（数字だけ）。($0／回・$0／日・$0／月）**
set -uo pipefail

OUT="${OPS_REPORT_DIR:-/tmp}/claude-usage-mac.md"
W="$HOME/.openclaw/workspace"
AGG="$W/.x257-agg.js"

cat > "$AGG" <<'JSEOF'
// x257: ~/.claude/projects の jsonl から使用トークンを足す。中身は読まない（usage と model と timestamp だけ）
const fs = require("fs"), path = require("path"), readline = require("readline");
const root = path.join(process.env.HOME, ".claude", "projects");
const since = Date.now() - 35 * 864e5;
const files = [];
const walk = (d) => { for (const e of fs.readdirSync(d, { withFileTypes: true })) {
  const p = path.join(d, e.name);
  if (e.isDirectory()) walk(p); else if (e.name.endsWith(".jsonl") && fs.statSync(p).mtimeMs >= since) files.push(p);
} };
try { walk(root); } catch (e) { console.log(JSON.stringify({ error: "読めない: " + e.message })); process.exit(0); }
const seen = new Set(), days = {}, models = {}, projects = {}, blocks = {};
const add = (o, k, u) => { o[k] = o[k] || { n: 0, in: 0, out: 0, cw: 0, cr: 0 }; const x = o[k]; x.n++; x.in += u.input_tokens || 0; x.out += u.output_tokens || 0; x.cw += u.cache_creation_input_tokens || 0; x.cr += u.cache_read_input_tokens || 0; };
(async () => {
  for (const f of files) {
    const proj = path.relative(root, f).split(path.sep)[0];
    const rl = readline.createInterface({ input: fs.createReadStream(f), crlfDelay: Infinity });
    for await (const line of rl) {
      if (!line.includes('"usage"')) continue;
      let d; try { d = JSON.parse(line); } catch (e) { continue; }
      const m = d.message || {}; const u = m.usage; if (!u || d.type !== "assistant") continue;
      const id = m.id || (d.requestId + ":" + d.uuid); if (seen.has(id)) continue; seen.add(id);
      const t = Date.parse(d.timestamp || ""); if (!(t >= since)) continue;
      const day = new Date(t + 9 * 3600e3).toISOString().slice(0, 10);
      add(days, day, u); add(models, m.model || "?", u); add(projects, proj, u);
      const b = new Date(Math.floor((t + 9 * 3600e3) / (5 * 3600e3)) * 5 * 3600e3).toISOString().slice(0, 13).replace("T", " ") + "時台から5時間";
      add(blocks, b, u);
    }
  }
  console.log(JSON.stringify({ files: files.length, replies: seen.size, days, models, projects, blocks }));
})();
JSEOF

{
echo "# Mac の Claude Code の使用量（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## ⑤ 版と認証の種類"
echo
echo '```'
for c in claude "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do
  if command -v "$c" >/dev/null 2>&1; then printf '  %s: %s\n' "$c" "$("$c" --version 2>&1 | head -1)"; break; fi
done
node -e '
const fs=require("fs"),p=require("path").join(process.env.HOME,".claude.json");
try{const j=JSON.parse(fs.readFileSync(p,"utf8"));const a=j.oauthAccount||{};
console.log("  ログイン: "+(a.emailAddress?"OAuth（サブスクリプション）":"不明")+" ／ 組織の種類: "+(a.organizationRole||"?")+" ／ billingType: "+(a.billingType||j.billingType||"?")+" ／ プラン表示: "+(a.subscriptionType||j.subscriptionType||a.organizationType||"?"));}
catch(e){console.log("  ~/.claude.json が読めない: "+e.message)}' 2>&1
printf '  ANTHROPIC_API_KEY が環境にある: %s\n' "$([ -n "${ANTHROPIC_API_KEY:-}" ] && echo はい || echo いいえ)"
echo '```'
echo
node "$AGG" > "$W/.x257-out.json" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.error) { console.log("**" + j.error + "**"); process.exit(0); }
const f = (n) => n.toLocaleString("en-US");
const row = (k, x) => "| " + k + " | " + f(x.n) + " | " + f(x.in) + " | " + f(x.out) + " | " + f(x.cw) + " | " + f(x.cr) + " |";
const head = "| | 返答数 | 入力 | 出力 | キャッシュ作成 | キャッシュ読込 |\n| --- | ---: | ---: | ---: | ---: | ---: |";
console.log("対象ファイル " + j.files + " 本・返答 " + f(j.replies) + " 件（直近 35 日）\n");
console.log("## ① 日別（JST）\n\n" + head); for (const k of Object.keys(j.days).sort()) console.log(row(k, j.days[k]));
console.log("\n## ② モデル別\n\n" + head); for (const [k, x] of Object.entries(j.models).sort((a, b) => b[1].out - a[1].out)) console.log(row(k, x));
console.log("\n## ③ プロジェクト別\n\n" + head); for (const [k, x] of Object.entries(j.projects).sort((a, b) => b[1].out - a[1].out).slice(0, 15)) console.log(row(k.replace(/-Users-[^-]+-/, "~/"), x));
console.log("\n## ④ 5 時間の枠ごと（出力の多い順・上位 10）\n\n" + head); for (const [k, x] of Object.entries(j.blocks).sort((a, b) => b[1].out - a[1].out).slice(0, 10)) console.log(row(k, x));
' "$W/.x257-out.json" 2>&1
rm -f "$AGG" "$W/.x257-out.json"
echo
echo "**LLM を呼んでいない。会話の中身は読んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "Mac の Claude Code の使用量を集計した / $(basename "$OUT")"
