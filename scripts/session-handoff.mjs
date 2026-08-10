#!/usr/bin/env node
// docs/session-handoff.md の「セッション記録」に 1 件追記する。
//
//   npm run handoff -- "やったこと"
//   npm run handoff -- "やったこと" --next "次にやること" --next "もう一つ"
//
// 記録は Git にコミットされるため、セッションや実行環境が消えても残る。

import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HANDOFF_PATH = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../docs/session-handoff.md",
);
const MARKER = "<!-- 新しい記録がこの下に追加される（新しいものが上） -->";

function parseArgs(argv) {
  const summary = [];
  const next = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--next") {
      const value = argv[++i];
      if (!value) {
        throw new Error("--next には内容を指定すること");
      }
      next.push(value);
    } else {
      summary.push(argv[i]);
    }
  }
  return { summary: summary.join(" ").trim(), next };
}

function today() {
  // ブログ本体が日本向けのため、記録も JST の日付で揃える。
  return new Date().toLocaleDateString("sv-SE", { timeZone: "Asia/Tokyo" });
}

let args;
try {
  args = parseArgs(process.argv.slice(2));
} catch (error) {
  console.error(`エラー: ${error.message}`);
  process.exit(1);
}

if (!args.summary) {
  console.error('使い方: npm run handoff -- "やったこと" [--next "次にやること"]');
  process.exit(1);
}

let doc;
try {
  doc = readFileSync(HANDOFF_PATH, "utf8");
} catch {
  console.error(`エラー: ${HANDOFF_PATH} が見つからない`);
  process.exit(1);
}

if (!doc.includes(MARKER)) {
  console.error(`エラー: ${HANDOFF_PATH} に挿入位置のマーカーが無い`);
  process.exit(1);
}

const lines = [`### ${today()} — ${args.summary}`];
if (args.next.length > 0) {
  // markdownlint(MD032) がリストの前後に空行を要求するため空行を挟む。
  lines.push("", "次のアクション:", "");
  for (const item of args.next) {
    lines.push(`- [ ] ${item}`);
  }
}
const entry = `\n\n${lines.join("\n")}`;

writeFileSync(HANDOFF_PATH, doc.replace(MARKER, `${MARKER}${entry}`), "utf8");
console.log(`記録を追加した: ${HANDOFF_PATH}`);
