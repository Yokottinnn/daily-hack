#!/usr/bin/env node
// Generate an X (Twitter) post draft for a Daily Hack article.
//
// Usage:
//   node scripts/generate-tweet.mjs <slug>
//
// Reads frontmatter from src/content/posts/<slug>.md, picks one of the
// 5 templates (A/B/C/D/E) based on category, and prints a JSON object
// containing the tweet text, weighted character count, hashtags, etc.
//
// Intended to be called by:
//   - Manual review flow (Claude Code prints draft, Jordan reviews)
//   - OpenClaw via Slack DM ("@OpenClaw tweet <slug>")
//   - Future GitHub Action on main push

import { readFile } from 'fs/promises';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const SITE_URL = 'https://daily-hack.fieldbeside.com';

// ---------------------------- frontmatter parser -----------------------------
function parseFrontmatter(raw) {
  const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) throw new Error('No frontmatter found');
  const yaml = match[1];
  const body = match[2];
  const data = {};
  for (const line of yaml.split('\n')) {
    const m = line.match(/^(\w+):\s*(.*)$/);
    if (!m) continue;
    const key = m[1];
    let val = m[2].trim();
    if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
    if (val === 'true') val = true;
    else if (val === 'false') val = false;
    else if (val.startsWith('[') && val.endsWith(']')) {
      val = val
        .slice(1, -1)
        .split(',')
        .map((s) => s.trim().replace(/^"|"$/g, ''))
        .filter(Boolean);
    }
    data[key] = val;
  }
  return { data, body };
}

// ---------------------------- twitter weighted length ----------------------
// Simplified version of Twitter's weighted-character-count algorithm.
// CJK / emoji = 2, ASCII = 1, URLs are clamped at 23 characters.
function weightedLength(text) {
  // First strip URLs (they always count as 23) then count the rest with weights.
  let nonUrlText = text;
  const urls = text.match(/https?:\/\/[^\s]+/g) || [];
  for (const url of urls) {
    nonUrlText = nonUrlText.replace(url, '');
  }
  let len = 0;
  for (const ch of nonUrlText) {
    const code = ch.codePointAt(0) ?? 0;
    if (
      (code >= 0x1100 && code <= 0x115f) ||
      (code >= 0x2e80 && code <= 0x303e) ||
      (code >= 0x3041 && code <= 0x33ff) ||
      (code >= 0x3400 && code <= 0x4dbf) ||
      (code >= 0x4e00 && code <= 0x9fff) ||
      (code >= 0xa000 && code <= 0xa4cf) ||
      (code >= 0xac00 && code <= 0xd7a3) ||
      (code >= 0xf900 && code <= 0xfaff) ||
      (code >= 0xfe30 && code <= 0xfe4f) ||
      (code >= 0xff00 && code <= 0xff60) ||
      (code >= 0xffe0 && code <= 0xffe6) ||
      (code >= 0x1f000 && code <= 0x1ffff)
    ) {
      len += 2;
    } else {
      len += 1;
    }
  }
  return len + urls.length * 23;
}

// ---------------------------- template selection ----------------------------
const TEMPLATE_MAP = {
  campaigns: 'A',
  services: 'C',
  comparisons: 'D',
  roundups: 'D',
  howto: 'B',
};

// Mascot-tone phrases by template
const TONE = {
  hook: {
    A: 'まだ {service} の {campaign} やってないの？😏',
    B: 'アタシが3年前にこれ知ってたら、年30万円浮いてた話。',
    C: 'ちょっと待って。\n{misconception} って言われてるけど、実は逆。',
    D: '{theme}、結局どれが正解？',
    E: '{theme} の正しい順番、わかる？',
  },
  closer: {
    A: '▶ 詳細 → {url}',
    B: '▶ 全部教えてあげる → {url}',
    C: '▶ 詳細 → {url}',
    D: '⭐ 用途別の選び方教えてあげる → {url}',
    E: '▶ 答え合わせ → {url}',
  },
};

// ---------------------------- builders --------------------------------------
function buildHashtags(tags = [], isPR = false) {
  const cleaned = tags
    .slice(0, 3)
    .map((t) => '#' + t.replace(/\s+/g, ''))
    .filter(Boolean);
  if (isPR && !cleaned.includes('#PR')) cleaned.push('#PR');
  return cleaned;
}

// Trim a string by weighted length, appending "…" when shortened.
function trimWeighted(text, maxWeighted) {
  let len = 0;
  let result = '';
  for (const ch of text) {
    const code = ch.codePointAt(0) ?? 0;
    const w =
      (code >= 0x1100 && code <= 0x115f) ||
      (code >= 0x2e80 && code <= 0x9fff) ||
      (code >= 0xa000 && code <= 0xa4cf) ||
      (code >= 0xac00 && code <= 0xd7a3) ||
      (code >= 0xf900 && code <= 0xfaff) ||
      (code >= 0xfe30 && code <= 0xff60) ||
      (code >= 0xffe0 && code <= 0xffe6) ||
      (code >= 0x1f000 && code <= 0x1ffff)
        ? 2
        : 1;
    if (len + w > maxWeighted) {
      return result + '…';
    }
    len += w;
    result += ch;
  }
  return result;
}

function buildTweet({ data, url, slug }) {
  const category = String(data.category || '').replace(/^"|"$/g, '');
  const template = TEMPLATE_MAP[category] || 'A';
  const title = (data.title || '').toString();
  const description = (data.description || '').toString();
  const tags = Array.isArray(data.tags) ? data.tags : [];
  const isPR = data.isPR === true || data.isPR === 'true';
  const hashtags = buildHashtags(tags, isPR);
  const hashtagLine = hashtags.join(' ');

  // Target weighted budget = 280
  // URL = 23, hashtags = weightedLength(hashtagLine + leading "\n"), template fixed = ~30-50
  // Body window for title+description: ~190 weighted chars total
  const fixedHashtagWeighted = weightedLength(hashtagLine ? '\n' + hashtagLine : '');
  const urlBudget = 23 + 1; // URL + leading space
  const templateFixedBudget = {
    A: weightedLength('まだやってない人、あんたバカぁ？😏\n\n\n\n⏰ 損する前に確認。\n\n▶ 詳細 → \n'),
    B: weightedLength('アタシが3年前これ知ってたら、年で数十万円浮いてた話。\n\n\n\n\n▶ 全部教えてあげる → \n'),
    C: weightedLength('ちょっと待って。\n9割の人がここを間違えてる。\n\n\n\n▶ 詳細 → \n'),
    D: weightedLength('\n\n結局どれが正解？整理してあげた。\n\n\n\n⭐ 用途別の選び方 → \n'),
    E: weightedLength('\n正しい順番、わかる？\n\n\n\n▶ 答え合わせ → \n'),
  }[template] || 60;
  const dynamicBudget = 280 - fixedHashtagWeighted - urlBudget - templateFixedBudget - 4; // safety buffer

  // Distribute dynamic budget between title (40%) and description (60%) for D/E, opposite for B
  const titleBudget = template === 'B' ? Math.floor(dynamicBudget * 0.35) : Math.floor(dynamicBudget * 0.4);
  const descBudget = dynamicBudget - titleBudget - 4;
  const trimmedTitle = trimWeighted(title, titleBudget);
  const trimmedDesc = trimWeighted(description, Math.max(40, descBudget));

  let body;
  switch (template) {
    case 'A':
      body =
        `まだやってない人、あんたバカぁ？😏\n\n` +
        `${trimmedTitle}\n` +
        `${trimmedDesc}\n\n` +
        `⏰ 損する前に確認。\n` +
        `▶ 詳細 → ${url}\n${hashtagLine}`;
      break;
    case 'B':
      body =
        `アタシが3年前これ知ってたら、年で数十万円浮いてた話。\n\n` +
        `${trimmedTitle}\n` +
        `${trimmedDesc}\n\n` +
        `▶ 全部教えてあげる → ${url}\n${hashtagLine}`;
      break;
    case 'C':
      body =
        `ちょっと待って。\n` +
        `9割の人がここを間違えてる。\n\n` +
        `${trimmedTitle}\n` +
        `${trimmedDesc}\n\n` +
        `▶ 詳細 → ${url}\n${hashtagLine}`;
      break;
    case 'D':
      body =
        `${trimmedTitle}\n\n` +
        `結局どれが正解？整理してあげた。\n\n` +
        `${trimmedDesc}\n\n` +
        `⭐ 用途別の選び方 → ${url}\n${hashtagLine}`;
      break;
    case 'E':
      body =
        `${trimmedTitle}\n` +
        `正しい順番、わかる？\n\n` +
        `${trimmedDesc}\n\n` +
        `▶ 答え合わせ → ${url}\n${hashtagLine}`;
      break;
    default:
      body = `${trimmedTitle}\n\n${trimmedDesc}\n\n▶ ${url}\n${hashtagLine}`;
  }

  return { template, body, hashtags };
}

// ---------------------------- main ------------------------------------------
async function main() {
  const slug = process.argv[2];
  if (!slug) {
    console.error('Usage: node scripts/generate-tweet.mjs <slug>');
    process.exit(1);
  }
  const articlePath = join(ROOT, 'src', 'content', 'posts', `${slug}.md`);
  const raw = await readFile(articlePath, 'utf8');
  const { data } = parseFrontmatter(raw);

  const url = `${SITE_URL}/posts/${slug}/`;
  const { template, body, hashtags } = buildTweet({ data, url, slug });
  const length = weightedLength(body);
  const fits = length <= 280;

  const result = {
    slug,
    template_type: template,
    tweet_text: body,
    weighted_length: length,
    within_limit: fits,
    url,
    hashtags,
    article_title: data.title,
    article_category: data.category,
    is_pr: data.isPR === true || data.isPR === 'true',
    instructions: fits
      ? 'Ready for review. Send via Slack DM to Jordan, get 👍, then OpenClaw posts.'
      : `Over limit by ${length - 280} weighted chars. Trim before posting.`,
  };
  console.log(JSON.stringify(result, null, 2));
  if (!fits) process.exit(2);
}

main().catch((err) => {
  console.error('[tweet-gen] failed:', err.message);
  process.exit(1);
});
