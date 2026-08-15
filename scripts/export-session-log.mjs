#!/usr/bin/env node
/**
 * Claude Code の会話ログ（~/.claude/projects/**\/*.jsonl）を、
 * 別のセッションから読める Markdown に書き出す。
 *
 *   node scripts/export-session-log.mjs --list
 *   node scripts/export-session-log.mjs --list --grep "ららぽーと"
 *   node scripts/export-session-log.mjs <session-uuid|jsonlのパス> --label blog2
 *   node scripts/export-session-log.mjs <session-uuid> --label blog2 --push
 *
 * Claude のログインは不要（ただの JSONL 読み取り）。認証切れのマシンでも動く。
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';

const PROJECTS_DIR = path.join(os.homedir(), '.claude', 'projects');

// スクリプト自体をリポジトリ外（/tmp など）に置いて実行できるよう、
// まず cwd のリポジトリを見る。見つからなければ自分の 1 つ上を使う。
const REPO_ROOT = (() => {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
  } catch {
    return path.resolve(import.meta.dirname, '..');
  }
})();

// ---------------------------------------------------------------- 引数

function parseArgs(argv) {
  const opts = {
    list: false,
    target: null,
    label: null,
    out: null,
    grep: null,
    project: null,
    maxChars: 4000,
    limit: 20,
    thinking: false,
    tools: true,
    push: false,
    branch: null,
    latest: false,
    all: false,
    each: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    const next = () => argv[(i += 1)];
    if (a === '--list') opts.list = true;
    else if (a === '--latest') opts.latest = true;
    else if (a === '--all') opts.all = true;
    else if (a === '--each') opts.each = true;
    else if (a === '--label') opts.label = next();
    else if (a === '--out') opts.out = next();
    else if (a === '--grep') opts.grep = next();
    else if (a === '--project') opts.project = next();
    else if (a === '--max-chars') opts.maxChars = Number(next());
    else if (a === '--limit') opts.limit = Number(next());
    else if (a === '--include-thinking') opts.thinking = true;
    else if (a === '--no-tools') opts.tools = false;
    else if (a === '--push') opts.push = true;
    else if (a === '--branch') opts.branch = next();
    else if (a === '--help' || a === '-h') opts.help = true;
    else if (a.startsWith('--')) fail(`不明なオプション: ${a}`);
    else opts.target = a;
  }
  return opts;
}

function fail(message) {
  console.error(`エラー: ${message}`);
  process.exit(1);
}

const USAGE = `使い方:
  node scripts/export-session-log.mjs --list [--all] [--project <部分一致>] [--grep <本文の部分一致>] [--limit N]
  node scripts/export-session-log.mjs --each [--label <名前>] [--limit N] [--push]   # 候補をまとめて
  node scripts/export-session-log.mjs <session-uuid|jsonlのパス> [--label <名前>] [--out <パス>]
      [--max-chars N] [--include-thinking] [--no-tools] [--push] [--branch <ブランチ名>]`;

// ---------------------------------------------------------------- 走査

function listJsonlFiles() {
  if (!fs.existsSync(PROJECTS_DIR)) {
    fail(`${PROJECTS_DIR} が無い。このマシンには Claude Code の履歴が残っていない。`);
  }
  const files = [];
  for (const dir of fs.readdirSync(PROJECTS_DIR)) {
    const dirPath = path.join(PROJECTS_DIR, dir);
    if (!fs.statSync(dirPath).isDirectory()) continue;
    for (const name of fs.readdirSync(dirPath)) {
      if (!name.endsWith('.jsonl')) continue;
      const full = path.join(dirPath, name);
      files.push({ project: dir, file: full, mtime: fs.statSync(full).mtimeMs, size: fs.statSync(full).size });
    }
  }
  return files.sort((a, b) => b.mtime - a.mtime);
}

/**
 * セッションの作業ディレクトリだけを安く取る。
 * ~/.claude/projects のディレクトリ名は cwd をハイフンに潰したもので、
 * リポジトリ名と一致するとは限らない（例: `-Users-ny-projects-anta-baka-x-blog`）。
 * 名前ではなく cwd で判定するために使う。
 */
function headCwd(file) {
  let head;
  try {
    const fd = fs.openSync(file, 'r');
    const buf = Buffer.alloc(64 * 1024);
    const read = fs.readSync(fd, buf, 0, buf.length, 0);
    fs.closeSync(fd);
    head = buf.subarray(0, read).toString('utf8');
  } catch {
    return '';
  }
  for (const line of head.split('\n')) {
    if (!line.includes('"cwd"')) continue;
    try {
      const cwd = JSON.parse(line).cwd;
      if (cwd) return cwd;
    } catch {
      /* 末尾の切れた行 */
    }
  }
  return '';
}

function readRecords(file) {
  const records = [];
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    try {
      records.push(JSON.parse(line));
    } catch {
      /* 壊れた行は読み飛ばす（書き込み中の末尾など） */
    }
  }
  return records;
}

function summarize(file) {
  const records = readRecords(file);
  // 先頭は queue-operation など cwd を持たない行のことがあるので、揃っている行を探す
  const meta = records.find((r) => r.cwd) ?? records.find((r) => r.sessionId) ?? {};
  const stamps = records.map((r) => r.timestamp).filter(Boolean).sort();
  const firstPrompt = records
    .filter((r) => r.type === 'user' && !r.isMeta)
    .map((r) => plainText(r.message?.content))
    .find((t) => t && t.trim());
  return {
    sessionId: meta.sessionId ?? path.basename(file, '.jsonl'),
    cwd: meta.cwd ?? '',
    branch: meta.gitBranch ?? '',
    first: stamps[0] ?? '',
    last: stamps.at(-1) ?? '',
    turns: records.filter((r) => r.type === 'user' || r.type === 'assistant').length,
    firstPrompt: (firstPrompt ?? '').replace(/\s+/g, ' ').slice(0, 80),
  };
}

// ---------------------------------------------------------------- 整形

function plainText(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content
    .filter((c) => c?.type === 'text')
    .map((c) => c.text ?? '')
    .join('\n');
}

const SECRET_PATTERNS = [
  /sk-ant-[A-Za-z0-9_-]{10,}/g,
  /sk-[A-Za-z0-9]{20,}/g,
  /xox[baprs]-[A-Za-z0-9-]{10,}/g,
  /gh[pousr]_[A-Za-z0-9]{20,}/g,
  /AKIA[0-9A-Z]{16}/g,
  /AIza[0-9A-Za-z_-]{30,}/g,
  /(?<=Bearer\s)[A-Za-z0-9._-]{20,}/g,
  /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/g,
];

function redact(text) {
  let out = text;
  for (const pattern of SECRET_PATTERNS) out = out.replace(pattern, '[REDACTED]');
  return out;
}

function clip(text, max) {
  const trimmed = text.replace(/\s+$/, '');
  if (trimmed.length <= max) return trimmed;
  return `${trimmed.slice(0, max)}\n\n…（${trimmed.length - max} 文字省略）`;
}

function stamp(iso) {
  if (!iso) return '';
  return iso.replace('T', ' ').replace(/\.\d+Z$/, 'Z');
}

function toolLine(block, max) {
  const input = block.input ?? {};
  const keys = ['file_path', 'path', 'pattern', 'command', 'url', 'prompt', 'query'];
  const key = keys.find((k) => typeof input[k] === 'string');
  const arg = key ? `${key}=${input[key]}` : Object.keys(input).join(', ');
  return `- 🔧 \`${block.name}\` ${clip(String(arg).replace(/\n/g, ' '), max)}`;
}

function renderMarkdown(file, records, opts) {
  const info = summarize(file);
  const label = opts.label ?? info.sessionId.slice(0, 8);
  const out = [];

  out.push(`# 会話ログ: ${label}`);
  out.push('');
  out.push('| 項目 | 値 |');
  out.push('| --- | --- |');
  out.push(`| session id | \`${info.sessionId}\` |`);
  out.push(`| 元ファイル | \`${file.replace(os.homedir(), '~')}\` |`);
  out.push(`| 作業ディレクトリ | \`${info.cwd}\` |`);
  out.push(`| ブランチ | \`${info.branch}\` |`);
  out.push(`| 期間 | ${stamp(info.first)} 〜 ${stamp(info.last)} |`);
  out.push(`| メッセージ数 | ${info.turns} |`);
  out.push('');
  out.push('> 自動生成（`scripts/export-session-log.mjs`）。');
  out.push('> ツール結果の本文と thinking は省いてあるため、元の JSONL と完全には一致しない。');
  out.push('> API キーらしき文字列は `[REDACTED]` に置換済みだが、機密が残っていないか目視で確認すること。');
  out.push('');
  out.push('---');
  out.push('');

  for (const record of records) {
    if (record.type === 'user') {
      if (record.isMeta) continue;
      const text = plainText(record.message?.content).trim();
      if (!text) continue; // tool_result だけの user 行は落とす
      out.push(`## 👤 ユーザー — ${stamp(record.timestamp)}`);
      out.push('');
      out.push(clip(redact(text), opts.maxChars));
      out.push('');
      continue;
    }

    if (record.type !== 'assistant') continue;
    const content = record.message?.content;
    if (!Array.isArray(content)) continue;

    const lines = [];
    for (const block of content) {
      if (block.type === 'text' && block.text?.trim()) {
        lines.push(clip(redact(block.text), opts.maxChars));
      } else if (block.type === 'thinking' && opts.thinking && block.thinking?.trim()) {
        lines.push(`<details><summary>thinking</summary>\n\n${clip(redact(block.thinking), opts.maxChars)}\n\n</details>`);
      } else if (block.type === 'tool_use' && opts.tools) {
        lines.push(toolLine(block, 200));
      }
    }
    if (!lines.length) continue;
    out.push(`## 🤖 Claude — ${stamp(record.timestamp)}`);
    out.push('');
    out.push(lines.join('\n\n'));
    out.push('');
  }

  return `${out.join('\n').replace(/\n{3,}/g, '\n\n')}\n`;
}

// ---------------------------------------------------------------- 実行

function resolveTarget(target) {
  if (fs.existsSync(target) && target.endsWith('.jsonl')) return path.resolve(target);
  const hit = listJsonlFiles().find((f) => path.basename(f.file, '.jsonl') === target);
  if (hit) return hit.file;
  fail(`セッションが見つからない: ${target}\n--list で一覧を確認する。`);
  return '';
}

function filterFiles(opts) {
  let files = listJsonlFiles();

  if (opts.project) {
    // ディレクトリ名でも cwd でも当たるようにする
    files = files.filter((f) => f.project.includes(opts.project) || headCwd(f.file).includes(opts.project));
  } else if (!opts.all) {
    // 既定は「いま居るリポジトリで動いたセッション」。当たらなければ絞り込まない。
    const here = files.filter((f) => {
      const cwd = headCwd(f.file);
      return cwd === REPO_ROOT || cwd.startsWith(`${REPO_ROOT}/`);
    });
    if (here.length) {
      console.log(`このリポジトリ（${REPO_ROOT}）のセッションに絞った。全部見るなら --all。\n`);
      files = here;
    } else {
      console.log(`このリポジトリ（${REPO_ROOT}）で動いたセッションは見つからなかった。全件から探す。\n`);
    }
  }

  if (opts.grep) {
    files = files.filter((f) => {
      try {
        return fs.readFileSync(f.file, 'utf8').includes(opts.grep);
      } catch {
        return false;
      }
    });
  }
  return files;
}

function hintAvailable() {
  const files = listJsonlFiles();
  if (!files.length) return `${PROJECTS_DIR} に会話ログが 1 件も無い。`;
  const byProject = new Map();
  for (const f of files) {
    const entry = byProject.get(f.project) ?? { count: 0, mtime: 0 };
    byProject.set(f.project, { count: entry.count + 1, mtime: Math.max(entry.mtime, f.mtime) });
  }
  const lines = [...byProject.entries()]
    .sort((a, b) => b[1].mtime - a[1].mtime)
    .slice(0, 10)
    .map(([project, v]) => `  ${project}  (${v.count} 件)`);
  return ['見つかったプロジェクト（新しい順）:', ...lines, '', '--project は上の名前の一部か、セッションの作業ディレクトリの一部を渡す。'].join('\n');
}

function runList(opts) {
  const files = filterFiles(opts);
  if (!files.length) {
    console.log('該当する会話ログが無い。');
    console.log(hintAvailable());
    return;
  }
  for (const f of files.slice(0, opts.limit)) {
    const info = summarize(f.file);
    console.log(`${info.sessionId}  ${stamp(info.last)}  ${String(Math.round(f.size / 1024)).padStart(6)}KB  ${info.turns} msg`);
    console.log(`  project: ${f.project}`);
    console.log(`  最初の発話: ${info.firstPrompt || '(なし)'}`);
    console.log('');
  }
  console.log(`書き出すとき: node scripts/export-session-log.mjs <session-id> --label <名前> --push`);
}

function gitPush(outPaths, opts, label) {
  const git = (...args) => execFileSync('git', args, { cwd: REPO_ROOT, encoding: 'utf8' }).trim();
  const branch = opts.branch ?? `session-log/${label}`;
  const current = git('rev-parse', '--abbrev-ref', 'HEAD');
  // ブランチを作るだけなので、他のファイルの未コミット変更はそのまま持ち越される。
  if (current !== branch) git('checkout', '-B', branch);
  git('add', '--', ...outPaths.map((p) => path.relative(REPO_ROOT, p)));
  const staged = git('diff', '--cached', '--name-only');
  if (!staged) {
    console.log('変更が無いので commit は省略した。');
  } else {
    git('commit', '-m', `docs: ${label} の会話ログを書き出す`);
  }
  execFileSync('git', ['push', '-u', 'origin', branch], { cwd: REPO_ROOT, stdio: 'inherit' });
  console.log(`\npush 済み: ${branch}`);
  // 元いたブランチへ戻す。作業ツリーを勝手に移動させたままにしない。
  if (current !== branch) {
    git('checkout', current);
    console.log(`${current} に戻した（書き出したログは ${branch} 側にある）。`);
  }
}

/**
 * 候補をまとめて書き出す。どれが目的のセッションか手元で判別できないときに、
 * 往復を 1 回で済ませるための道。索引も一緒に作る。
 */
function runEach(opts) {
  const candidates = filterFiles(opts).slice(0, opts.limit);
  if (!candidates.length) fail(`条件に合う会話ログが無い。\n${hintAvailable()}`);

  const label = opts.label ?? 'sessions';
  const dir = path.join(REPO_ROOT, 'docs', 'session-logs', label);
  fs.mkdirSync(dir, { recursive: true });

  const written = [];
  const rows = [];
  for (const candidate of candidates) {
    const info = summarize(candidate.file);
    const day = (info.last || info.first || '').slice(0, 10).replace(/-/g, '');
    const name = `${day}-${info.sessionId.slice(0, 8)}.md`;
    const outPath = path.join(dir, name);
    // 見出しは 1 件ずつ区別できるようにする（全部 "blog2" になってしまわないように）
    const perFile = { ...opts, label: `${label} / ${info.sessionId.slice(0, 8)}` };
    fs.writeFileSync(outPath, renderMarkdown(candidate.file, readRecords(candidate.file), perFile));
    written.push(outPath);
    rows.push(`| [${name}](./${name}) | ${stamp(info.last)} | ${info.turns} | ${(info.firstPrompt || '(なし)').replace(/\|/g, '\\|')} |`);
    console.log(`${name}  ${stamp(info.last)}  ${info.turns} msg  ${info.firstPrompt || '(なし)'}`);
  }

  const indexPath = path.join(dir, 'README.md');
  fs.writeFileSync(
    indexPath,
    [
      `# 会話ログ一覧: ${label}`,
      '',
      `\`scripts/export-session-log.mjs --each\` による自動生成。${written.length} 件（新しい順）。`,
      '',
      '| ファイル | 最終更新 | メッセージ数 | 最初の発話 |',
      '| --- | --- | --- | --- |',
      ...rows,
      '',
    ].join('\n'),
  );
  written.push(indexPath);

  console.log(`\n${written.length - 1} 件を書き出した: ${dir}`);
  if (opts.push) gitPush(written, opts, label);
  else console.log('git に載せるなら --push を付けて再実行する。');
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    console.log(USAGE);
    return;
  }
  if (opts.list || (!opts.target && !opts.latest && !opts.each)) {
    if (!opts.target && !opts.list) console.log(`${USAGE}\n\n--- 履歴一覧 ---\n`);
    runList(opts);
    return;
  }

  if (opts.each) {
    runEach(opts);
    return;
  }

  let file;
  if (opts.latest) {
    // UUID を手で貼らずに済ませる道。--project / --grep で絞った中の最新を選ぶ。
    const candidates = filterFiles(opts);
    if (!candidates.length) fail(`条件に合う会話ログが無い。\n${hintAvailable()}`);
    file = candidates[0].file;
    if (candidates.length > 1) {
      console.log(`候補が ${candidates.length} 件あり、最新のものを選んだ。違うなら --list で確認して session-id を指定する。\n`);
    }
  } else {
    file = resolveTarget(opts.target);
  }
  const records = readRecords(file);
  const info = summarize(file);
  const label = opts.label ?? info.sessionId.slice(0, 8);
  const outPath = path.resolve(opts.out ?? path.join(REPO_ROOT, 'docs', 'session-logs', `${label}.md`));
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, renderMarkdown(file, records, opts));

  const kb = Math.round(fs.statSync(outPath).size / 1024);
  console.log(`書き出した: ${outPath} (${kb}KB, ${info.turns} メッセージ)`);
  console.log(`  session id: ${info.sessionId}`);
  console.log(`  期間: ${stamp(info.first)} 〜 ${stamp(info.last)}`);
  console.log(`  最初の発話: ${info.firstPrompt || '(なし)'}`);
  if (opts.push) gitPush([outPath], opts, label);
  else console.log('git に載せるなら --push を付けて再実行する。');
}

main();
