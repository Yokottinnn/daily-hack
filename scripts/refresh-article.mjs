// **公開済みの記事を 1 本 選んで、古くなったところを調べ、更新案を出す。**
//
//   node scripts/refresh-article.mjs            # 1 本 選んで実行
//   node scripts/refresh-article.mjs --slug X   # 記事を指定
//   node scripts/refresh-article.mjs --dry-run  # **API を呼ばない。** 選定だけ見る
//   node scripts/refresh-article.mjs --apply    # 確度「高」だけ本文に当てる
//
// ## 費用（CLAUDE.md 最上位ルール 2-B）
//
// | 単位 | 金額 |
// | --- | --- |
// | 1 回あたり | **約 $0.07**（推定・Sonnet 5・入力 2 万 tok / 出力 3 千 tok） |
// | 1 日あたり | **約 $0.07**（1 日 1 本） |
// | 1 か月あたり | **約 $2.1** |
//
// 単価は `claude-api` スキルの料金表から引いている（$2/$10 per MTok）。
// **実額は毎回レポートと `ops/data/refresh-state.json` に書く。** 推定のままにしない。
//
// **web 検索ツールは従量課金が別にかかり、単価を確認できていない。**
// 既定は無効で、`USE_WEB_SEARCH=1` を付けたときだけ有効になる。
//
// ## やらないこと
//
// - **記事を直接 書き換えない。** 出すのは更新案だけ
// - **自動マージしない。** 人が見て入れる
// - **出典 URL の無い指摘は捨てる。** 数字を創らせないための関門
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const POSTS = path.join(ROOT, 'src/content/posts');
const STATE = path.join(ROOT, 'ops/data/refresh-state.json');
const MODEL = process.env.REFRESH_MODEL || 'claude-sonnet-5';
const DRY = process.argv.includes('--dry-run');
const USE_WEB = process.env.USE_WEB_SEARCH === '1';
// **確度「高」の指摘だけを本文に当てる。** 中・低はレポートに載せて人が選ぶ
const APPLY = process.argv.includes('--apply');
const KEY_ENV = 'ANTHROPIC' + '_API_KEY';

// 料金は claude-api スキルの表から（$/1M トークン）。**記憶で書かない**
const PRICE = {
  'claude-sonnet-5': { in: 2.0, out: 10.0 },
  'claude-opus-5': { in: 5.0, out: 25.0 },
  'claude-haiku-4-5': { in: 1.0, out: 5.0 },
};

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

function readState() {
  try {
    return JSON.parse(fs.readFileSync(STATE, 'utf8'));
  } catch {
    return { done: {} };
  }
}

/** **どの記事を直すかを決める。** 一周するまで同じ記事に戻らない。
 *
 * 順番は 3 段。**放置日数だけで選ぶのをやめた**（2026-09-22）。
 *
 *   1. **未インデックス**（`ops/data/unindexed.txt`）でまだ見ていないもの
 *   2. **期限切れの語を含む記事**（`ops/data/stale-words.txt`）。最終更新が古い順
 *   3. いちばん放置されている記事
 *
 * ## なぜ 2 を足したか
 *
 * 実際に古くて差し戻されたのは**期限のあるもの**だった。
 * 東京湾大華火祭の節が「チケット発売は 7月予定」「料金は 5,000〜10,000円の予定」の
 * まま 3 か月 残っていて、**実際には抽選が 3 回とも終わっていた**（2026-09-21）。
 *
 * **放置日数順だと、これが 75 日 後まで回ってこない。**
 * 「発売予定」「告知待ち」のような**時間が経つと嘘になる語**を持つ記事を先に回す。
 *
 * 語は `check-stale-wording.py` と**同じファイルを読む**。2 箇所に書かない。
 */
function pick(state) {
  const forced = arg('--slug');
  if (forced) return forced;

  const prioPath = path.join(ROOT, 'ops/data/unindexed.txt');
  let prio = [];
  try {
    prio = fs
      .readFileSync(prioPath, 'utf8')
      .split('\n')
      .map((l) => l.replace(/#.*$/, '').trim())
      .filter(Boolean);
  } catch {
    prio = [];
  }
  // **まだ一度も見ていない優先記事**があれば、そこから
  const unseen = prio.filter(
    (s) => fs.existsSync(path.join(POSTS, `${s}.md`)) && !(state.done || {})[s],
  );
  if (unseen.length) return unseen[0];

  // **期限切れの語**。`check-stale-wording.py` と同じファイルを読む
  let stale = null;
  try {
    const words = fs
      .readFileSync(path.join(ROOT, 'ops/data/stale-words.txt'), 'utf8')
      .split('\n')
      .map((l) => l.split('#')[0].trim())
      .filter(Boolean)
      .map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    if (words.length) stale = new RegExp(words.join('|'));
  } catch {
    stale = null; // 無ければ 3 段目だけで選ぶ
  }

  const rows = fs
    .readdirSync(POSTS)
    .filter((f) => f.endsWith('.md'))
    .map((f) => {
      const slug = f.replace(/\.md$/, '');
      const src = fs.readFileSync(path.join(POSTS, f), 'utf8');
      if (/^draft:\s*true/m.test(src)) return null;
      const pub = (src.match(/^publishDate:\s*(\S+)/m) || [])[1] || '1970-01-01';
      const upd = (src.match(/^updatedDate:\s*(\S+)/m) || [])[1] || pub;
      const seen = (state.done && state.done[slug]) || upd;
      // **フロントマターは見ない。** title や tags の語で誤爆させない
      const body = src.replace(/^---[\s\S]*?\n---\n/, '');
      return { slug, seen, stale: stale ? stale.test(body) : false };
    })
    .filter(Boolean)
    .sort((a, b) => a.seen.localeCompare(b.seen));

  // **期限切れの語を持つ記事を先に。** 同じ区分の中では放置が長い順
  const staleRows = rows.filter((r) => r.stale && !(state.done || {})[r.slug]);
  if (staleRows.length) return staleRows[0].slug;
  return rows.length ? rows[0].slug : null;
}

const SYSTEM = `あなたは日本語のお得情報ブログ「Daily Hack」の校閲担当です。
公開済みの記事を読み、**いま古くなっている箇所だけ**を指摘します。

## 守ること

- **出典 URL を書けない指摘は出さない。** 推測で数字を変えない
- **記事の書き方・語り口は変えない。** 直すのは事実だけ
- **制作の裏側を記事に書かせない。**「取れなかった」「確認できなかった」は不可
- 値上げ・改定・終了したキャンペーン・新しく始まったものを優先する
- **変わっていないなら「変更なし」と答える。** 無理に指摘を作らない
- quote は記事から**一字一句そのまま**写す。言い換えない`;

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'findings'],
  properties: {
    verdict: { type: 'string', enum: ['変更あり', '変更なし'] },
    summary: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['kind', 'quote', 'proposal', 'source_url', 'confidence'],
        properties: {
          kind: {
            type: 'string',
            enum: ['数字が古い', '終了した', '新しく始まった', '表記が誤り'],
          },
          quote: { type: 'string', description: '記事から一字一句そのまま写した、直す箇所' },
          proposal: { type: 'string', description: '差し替える文。記事の語り口に合わせる' },
          source_url: { type: 'string', description: '一次情報の URL。公式・決算資料・プレスリリース' },
          confidence: { type: 'string', enum: ['高', '中', '低'] },
        },
      },
    },
  },
};

async function main() {
  const state = readState();
  const slug = pick(state);
  if (!slug) {
    console.log('対象の記事が無い');
    return;
  }
  const file = path.join(POSTS, `${slug}.md`);
  const body = fs.readFileSync(file, 'utf8');
  console.log(`対象: ${slug}（${body.length} 文字 / 最終確認 ${(state.done || {})[slug] || '未'}）`);

  if (DRY) {
    console.log('--dry-run のため API は呼ばない。ここで終わり。');
    return;
  }
  if (!process.env[KEY_ENV]) {
    console.error(`${KEY_ENV} が無い。中止する。`);
    process.exit(1);
  }

  const { default: Anthropic } = await import('@anthropic-ai/sdk');
  const client = new Anthropic();
  const tools = USE_WEB
    ? [{ type: 'web_search_20260209', name: 'web_search', max_uses: 6 }]
    : undefined;

  const res = await client.messages.create({
    model: MODEL,
    max_tokens: 8000,
    system: SYSTEM,
    ...(tools ? { tools } : {}),
    output_config: { format: { type: 'json_schema', schema: SCHEMA } },
    messages: [
      {
        role: 'user',
        content:
          `今日は ${new Date().toISOString().slice(0, 10)} です。\n` +
          '次の記事で、いま古くなっている箇所を挙げてください。\n\n' +
          '```markdown\n' + body + '\n```',
      },
    ],
  });

  const u = res.usage;
  const p = PRICE[MODEL] || PRICE['claude-sonnet-5'];
  const cost = (u.input_tokens * p.in + u.output_tokens * p.out) / 1e6;
  const text = res.content
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('');
  let out;
  try {
    out = JSON.parse(text);
  } catch {
    console.error('JSON として読めなかった。生の先頭 300 字:', text.slice(0, 300));
    process.exit(1);
  }

  // **出典 URL が無い／引用が本文に無い指摘は落とす。** 創作を入れないための関門
  const all = out.findings || [];
  const kept = all.filter(
    (f) => /^https?:\/\//.test(f.source_url || '') && f.quote && body.includes(f.quote),
  );
  const dropped = all.length - kept.length;

  // **本文に当てるのは確度「高」だけ。** 当てたものはレポートに印を付ける
  let applied = 0;
  if (APPLY) {
    let next = body;
    for (const f of kept) {
      if (f.confidence !== '高') continue;
      if (!next.includes(f.quote)) continue;   // 直前の置換で消えていることがある
      next = next.replace(f.quote, f.proposal);
      f.applied = true;
      applied += 1;
    }
    if (applied) {
      const today = new Date().toISOString().slice(0, 10);
      next = /^updatedDate:/m.test(next)
        ? next.replace(/^updatedDate:.*$/m, `updatedDate: ${today}`)
        : next.replace(/^(publishDate:.*)$/m, `$1\nupdatedDate: ${today}`);
      fs.writeFileSync(file, next);
    }
  }

  const report = [
    `# 記事の更新案: ${slug}`,
    '',
    `- 生成: ${new Date().toISOString()}`,
    `- モデル: \`${MODEL}\`${USE_WEB ? '（web 検索あり）' : '（web 検索なし）'}`,
    `- 入力 ${u.input_tokens} tok / 出力 ${u.output_tokens} tok / **実額 $${cost.toFixed(4)}**`,
    `- 判定: **${out.verdict}** / 指摘 ${all.length} 件 のうち **採用 ${kept.length} 件**`,
    APPLY
      ? `- **本文に当てた: ${applied} 件**（確度「高」のみ）。残りは下の一覧から手で選ぶ`
      : '- 本文には当てていない（`--apply` を付けると確度「高」だけ当たる）',
    '',
    out.summary ? `${out.summary}\n` : '',
    dropped ? `**${dropped} 件 を落とした**（出典 URL が無い、または引用が本文に無い）。\n` : '',
    '## 指摘',
    '',
  ];
  if (!kept.length) report.push('**採用できる指摘は無かった。**', '');
  for (const f of kept) {
    report.push(`### ${f.kind}（確度 ${f.confidence}）${f.applied ? ' — **当てた**' : ''}`, '');
    report.push('```text', f.quote, '```', '');
    report.push(`→ ${f.proposal}`, '', `出典: ${f.source_url}`, '');
  }

  const dir = process.env.OPS_REPORT_DIR || '/tmp';
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, `refresh-${slug}.md`), report.join('\n'));
  console.log(report.join('\n'));

  state.done = state.done || {};
  state.done[slug] = new Date().toISOString().slice(0, 10);
  state.last = {
    slug,
    at: new Date().toISOString(),
    cost_usd: Number(cost.toFixed(4)),
    model: MODEL,
    kept: kept.length,
    dropped,
  };
  state.total_usd = Number(((state.total_usd || 0) + cost).toFixed(4));
  fs.mkdirSync(path.dirname(STATE), { recursive: true });
  fs.writeFileSync(STATE, JSON.stringify(state, null, 2) + '\n');
  JSON.parse(fs.readFileSync(STATE, 'utf8')); // **自分で parse して確かめる**（ルール 13）
  console.log(`\n累計: $${state.total_usd}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
