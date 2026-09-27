// **図を描くスクリプトが共通で要るもの。** パスの決め打ちをここ 1 か所に閉じ込める。
//
// 2026-09-26 に `sns-templates` が Mac から消えているのが分かった
// （`ops/tasks/t190-find-sns-assets.sh` で実測。図の最終生成は 8/7）。
// **6 本の render / shot スクリプトが全部 `/Users/ny_taxa/…` を決め打ちしていて、
// どれも動かない状態だった。** しかも `ny_taxa` は誤りで、実際は `/Users/ny/…`。
//
// 要るものは 3 つだけで、**2 つはもう手元に在る。**
//
// | 要るもの | どこから |
// | --- | --- |
// | マスコット | **ブログのリポジトリ**（`public/images/expr-*.png`） |
// | `playwright-core` | リポジトリの `node_modules` か OpenClaw の workspace |
// | フォント | **`@fontsource/*`**（SIL OFL・`devDependencies` に入れてある） |
//
// **これでクラウドだけで描画が完結する。** Mac への 30 分 待ちが要らない。
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const HOME = process.env.HOME || '';
export const optDir = (cands) => cands.find((c) => c && fs.existsSync(c)) || null;

/** `sns-templates`。**もう無いのが既定。** 在れば使う */
export const SNS = optDir([
  process.env.SNS_DIR,
  `${HOME}/projects/anta-baka-x/sns-templates`,
  '/Users/ny/projects/anta-baka-x/sns-templates',
  '/Users/ny_taxa/projects/anta-baka-x/sns-templates',
]);

/** ブログのリポジトリ。**決め打ちにしない** */
export const REPO = process.env.BLOG_REPO || process.env.DAILY_HACK_REPO || optDir([
  process.cwd(),
  `${HOME}/projects/anta-baka-x/blog`,
  '/Users/ny/projects/anta-baka-x/blog',
]) || process.cwd();

/** マスコット（`expr-*.png`）の置き場 */
export const MASCOTS = optDir([
  process.env.ASSETS_DIR,
  SNS && SNS + '/assets-transparent',
  REPO + '/public/images',
]);

/** **`playwright-core` を先に見る**（最上位ルール 14）。X のループが使っている実体と同じ */
export function loadChromium() {
  for (const base of [process.env.PW_DIR, process.cwd() + '/node_modules',
                      REPO + '/node_modules',
                      `${HOME}/.openclaw/workspace/node_modules`,
                      `${HOME}/openclaw/node_modules`, SNS && SNS + '/node_modules']) {
    if (!base) continue;
    try { return createRequire(base + '/x.js')('playwright-core').chromium; } catch { /* 次 */ }
  }
  try { return createRequire(process.cwd() + '/x.js')('playwright').chromium; } catch { /* 次 */ }
  console.error('playwright-core も playwright も読めない。`npm i` を先に通すこと。');
  process.exit(1);
}

/** ブラウザの実体は環境で違う。クラウドは `/opt/pw-browsers/chromium` */
export async function launch(chromium, extra = {}) {
  const exe = process.env.CHROME_PATH || optDir(['/opt/pw-browsers/chromium']);
  return chromium.launch(exe ? { headless: true, executablePath: exe, ...extra }
                             : { headless: true, ...extra });
}

// --- フォント ---
// **当たらないと黙って代替に落ちる。** 丸ゴシックがただのゴシックになるだけで
// エラーは出ない（2026-09-26 に実際そうなった）。だから**揃わなければ止める。**
const FONTS = SNS ? SNS + '/fonts' : null;
const fontFile = (pkg, file) => {
  if (FONTS && fs.existsSync(`${FONTS}/${file}.woff2`)) return `${FONTS}/${file}.woff2`;
  try {
    const dir = path.dirname(createRequire(process.cwd() + '/x.js').resolve(`${pkg}/package.json`));
    const p = `${dir}/files/${file}-normal.woff2`;
    if (fs.existsSync(p)) return p;
  } catch { /* 無い */ }
  return null;
};
const FACES = [
  ['RocknRoll One', 400, fontFile('@fontsource/rocknroll-one', 'rocknroll-one-japanese-400')],
  ['Zen Maru Gothic', 400, fontFile('@fontsource/zen-maru-gothic', 'zen-maru-gothic-japanese-400')],
  ['Zen Maru Gothic', 700, fontFile('@fontsource/zen-maru-gothic', 'zen-maru-gothic-japanese-700')],
  ['Zen Maru Gothic', 900, fontFile('@fontsource/zen-maru-gothic', 'zen-maru-gothic-japanese-900')],
  ['Bebas Neue', 400, fontFile('@fontsource/bebas-neue', 'bebas-neue-latin-400')],
];

/** `<style>` の先頭に入れる `@font-face` 一式。**揃っていなければ止まる** */
export function fontCss() {
  const missing = FACES.filter(([, , f]) => !f).map(([n, w]) => `${n} ${w}`);
  if (missing.length) {
    console.error('フォントが見つからない: ' + missing.join(' / '));
    console.error('**代替フォントで描くと丸ゴシックでなくなる。** `npm i` を先に通すこと。');
    process.exit(1);
  }
  return FACES.map(([n, w, f]) =>
    `  @font-face{font-family:"${n}";font-weight:${w};src:url("file://${f}") format("woff2");}`).join('\n');
}
