// 記事の Markdown に書いた <div data-shop-table|card|buttons="…"></div> を、3 店ボタンの HTML に置き換える。
// Astro は利用者の rehype プラグインのあとに rehype-raw を通すので、ここでは生 HTML（raw ノード）の文字列を置き換える。
// **isPR: true でない記事に使うとビルドを落とす**（PR 表記と Yahoo! の LinkSwitch が isPR の記事でしか効かないため）。
import { loadConfig, renderDirective } from './render.mjs';

const RE = /<div\s+data-shop-(table|card|buttons)="([a-z0-9-]+(?::[A-Za-z0-9_-]+)?)"\s*>\s*<\/div>/g;

export default function rehypeShop() {
  return (tree, file) => {
    let cfg = null;
    const walk = (node) => {
      if (node.type === 'raw' && typeof node.value === 'string' && node.value.includes('data-shop-')) {
        const fm = (file.data && file.data.astro && file.data.astro.frontmatter) || {};
        if (fm.isPR !== true) throw new Error(`shop: ${file.path} は isPR: true ではないのに 3 店ボタンを使っている（docs/shop-comparison.md）`);
        cfg = cfg || loadConfig();
        node.value = node.value.replace(RE, (_, kind, value) => renderDirective(kind, value, cfg));
        if (node.value.includes('data-shop-')) throw new Error(`shop: ${file.path} の data-shop- の書き方が違う（1 行で <div data-shop-card="シリーズ:商品"></div>）`);
      }
      if (node.children) node.children.forEach(walk);
    };
    walk(tree);
  };
}
