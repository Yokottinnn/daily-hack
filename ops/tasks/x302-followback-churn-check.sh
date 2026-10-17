#!/bin/bash
# **フォロー返しした認証済みフォロワーを、別のジョブが外していないかをログで照らし合わせる。何も押さない。費用 $0。**
# 利用者の選択「3 人を外していないかログで確かめる」（2026-10-17）。
# x301: 返し漏れ 7 人のうち 3 人はボタンが「フォローバック」ではなく「フォロー」。一度返したあとで外された疑い。
# ① いまの返し漏れのうち、ボタンが「フォロー」の人について、全ログでの出現（返した・外した）を並べる
# ② 全体: badge-followback が返した人のうち、そのあと unfollow 系のログに出た人の数（ジョブ別）
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-churn-check.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/"handles":\[[^\]]*\]/"handles":["<伏せ>"]/g'; }
P="$W/.x302.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590/verified_followers", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('[data-testid="UserCell"]', { timeout: 25000 });
  const seen = new Map(); let still = 0;
  for (let i = 0; i < 40 && still < 4; i++) {
    const rows = await p.evaluate(() => [...document.querySelectorAll('[data-testid="UserCell"]')].map((c) => {
      const a = [...c.querySelectorAll('a[href^="/"]')].map((x) => x.getAttribute("href")).find((h) => /^\/[A-Za-z0-9_]{1,15}$/.test(h));
      const btn = c.querySelector('button[data-testid$="-follow"], button[data-testid$="-unfollow"]');
      const t = btn ? btn.getAttribute("data-testid") : "";
      return { h: a ? a.slice(1) : null, not: t.endsWith("-follow"), txt: btn ? btn.innerText.trim() : "" };
    }));
    const before = seen.size; for (const r of rows) if (r.h && !seen.has(r.h)) seen.set(r.h, r);
    still = seen.size === before ? still + 1 : 0;
    await p.evaluate(() => window.scrollBy(0, 2500)); await p.waitForTimeout(1600);
  }
  await p.close();
  console.log([...seen.values()].filter((r) => r.not).map((r) => r.h + "\t" + r.txt).join("\n"));
  process.exit(0);
})().catch((e) => { console.log("ERROR\t" + String(e.message).slice(0, 150)); process.exit(0); });
JS
LIST="$W/.x302-list.txt"
(cd "$W" && node "$P" 2>&1) > "$LIST"
rm -f "$P"
{
echo "# フォロー返しした人を別のジョブが外していないか（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo
echo "## ① いまの返し漏れ（ボタンの文字ごと）"
echo '```'
cut -f2 "$LIST" | sort | uniq -c
echo '```'
echo
echo "## ② ボタンが「フォロー」の人の、全ログでの出現（新しい順に最大 6 行／人）"
n=0
while IFS=$'\t' read -r h txt || [ -n "$h" ]; do
  [ -n "$h" ] || continue; [ "$h" = "ERROR" ] && { echo "一覧を読めなかった: $txt"; continue; }
  case "$txt" in *バック*) continue;; esac
  n=$((n+1)); echo; echo "### 人 $n（ボタン「$txt」）"; echo '```'
  grep -rn -- "$h" "$W/logs" 2>/dev/null | sed -E "s#^$W/logs/##" | cut -c1-220 | tail -6 | H="$h" perl -pe 's/\Q$ENV{H}\E/<伏せ>/gi' | hide
  echo "data での出現: $(grep -rl -- "$h" "$W/data" 2>/dev/null | sed -E "s#^$W/data/##" | tr '\n' ' ')"
  echo '```'
done < "$LIST"
echo
echo "## ③ 全体: badge-followback が返した人のうち、あとで外された人（ログのファイル別）"
echo '```'
node -e '
const fs=require("fs"),path=require("path");
const st=JSON.parse(fs.readFileSync(process.argv[1]+"/data/badge-followback-state.json","utf8"));
const fb=new Map((st.followed_back||[]).map(x=>[x.handle,x.at]));
const dir=process.argv[1]+"/logs"; const hit={}; const who=new Set();
for(const f of fs.readdirSync(dir)){ if(!/\.log$/.test(f)||/badge-followback/.test(f)) continue;
  let s; try{s=fs.readFileSync(path.join(dir,f),"utf8")}catch{continue}
  for(const line of s.split("\n")){ if(!/外れた|外した|unfollow|アンフォロー|✂/i.test(line)) continue;
    const m=line.match(/@([A-Za-z0-9_]{1,15})/); if(!m||!fb.has(m[1])) continue;
    const t=(line.match(/\d{4}-\d{2}-\d{2}T[\d:.]+Z/)||[])[0]; if(t&&t<fb.get(m[1])) continue;
    hit[f]=(hit[f]||0)+1; who.add(m[1]); } }
console.log("返した人: "+fb.size+" / あとで外す側のログに出た人: "+who.size);
for(const [f,c] of Object.entries(hit)) console.log("  "+f+": "+c+" 行");
' "$W" 2>&1 | hide
echo '```'
echo
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$LIST"
echo "フォロー返しした人を別のジョブが外していないか照らし合わせた / $(basename "$OUT")"
