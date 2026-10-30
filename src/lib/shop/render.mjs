// 3 店ボタン（楽天市場・Yahoo!ショッピング・Amazon）の HTML を作る。記事の Markdown に
//   <div data-shop-table="<シリーズ>"></div>          … 比較表（全商品）
//   <div data-shop-card="<シリーズ>:<商品 id>"></div>  … 商品カード（推し理由・仕様・3 店の価格とボタン）
//   <div data-shop-buttons="<シリーズ>:<商品 id>"></div> … 3 店ボタンだけ
// と書くと、rehype-shop.mjs がビルド時にこの関数の出力へ置き換える。データは src/data/shop/<シリーズ>.json。
// 使い方と決まりは docs/shop-comparison.md。LLM 不使用・$0。
import fs from 'node:fs';
import path from 'node:path';

const SHOP_DIR = path.join(process.cwd(), 'src/data/shop');

const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const yen = (n) => '¥' + Math.round(n).toLocaleString('ja-JP');
const enc = encodeURIComponent;

export function loadConfig() {
  return JSON.parse(fs.readFileSync(path.join(SHOP_DIR, 'config.json'), 'utf8'));
}

const seriesCache = new Map();
export function loadSeries(id) {
  if (!/^[a-z0-9-]+$/.test(id)) throw new Error(`shop: シリーズ名が不正: ${id}`);
  const file = path.join(SHOP_DIR, `${id}.json`);
  const mtime = fs.statSync(file).mtimeMs;
  const hit = seriesCache.get(id);
  if (hit && hit.mtime === mtime) return hit.data;
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  seriesCache.set(id, { mtime, data });
  return data;
}

// ---- リンク ----
// 楽天: 取れた商品 URL（無ければ検索結果）を、設定のアフィリエイト ID で hgc に包む。
// API の affiliateUrl は使わない（ID を法人に替えたとき、保存済みの URL が古い ID のまま残るため）
export function rakutenLink(r, cfg) {
  if (!r || !(r.itemUrl || r.keyword)) return null;
  const target = r.itemUrl || `https://search.rakuten.co.jp/search/mall/${enc(r.keyword)}/`;
  return `https://hb.afl.rakuten.co.jp/hgc/${cfg.rakuten.affiliateId}/?pc=${enc(target)}&m=${enc(target)}`;
}
// Yahoo!: 素のリンク。isPR の記事では LinkSwitch が成果リンクに変える（rehype-shop.mjs が isPR を必須にしている）
export function yahooLink(y) {
  if (!y || !(y.url || y.keyword)) return null;
  return y.url || `https://shopping.yahoo.co.jp/search?p=${enc(y.keyword)}`;
}
// Amazon: アソシエイトに直接（2026-10-30・もしもは 10/28 に否認）。tag が null のあいだは出さない
export function amazonLink(a, cfg) {
  const m = cfg.amazon || {};
  if (!a || !(a.asin || a.keyword)) return null;
  const target = a.asin ? `https://www.amazon.co.jp/dp/${a.asin}` : `https://www.amazon.co.jp/s?k=${enc(a.keyword)}`;
  if (m.via === 'associates') return m.tag ? `${target}${target.includes('?') ? '&' : '?'}tag=${enc(m.tag)}` : null;
  if (!m.moshimoAId || !m.moshimoPId || !m.moshimoPcId || !m.moshimoPlId) return null;
  return `https://af.moshimo.com/af/c/click?a_id=${m.moshimoAId}&p_id=${m.moshimoPId}&pc_id=${m.moshimoPcId}&pl_id=${m.moshimoPlId}&url=${enc(target)}`;
}

// ---- 価格 ----
// 実質 = 本体価格 − その店で付く通常ポイント（楽天は倍率 × 1%、Yahoo!は API の付与ポイント）。送料は足さず「送料別」と書く
export function offers(item, cfg) {
  const out = [];
  const r = item.rakuten || {}, y = item.yahoo || {}, a = item.amazon || {};
  const rl = rakutenLink(r, cfg);
  if (rl) {
    const pts = r.price != null && r.pointRate != null ? Math.floor(r.price * r.pointRate / 100) : null;
    out.push({ store: 'rakuten', label: '楽天市場', href: rl, price: r.price ?? null, net: r.price != null ? r.price - (pts || 0) : null,
      notes: [r.postageIncluded === true ? '送料込' : r.postageIncluded === false ? '送料別' : null, r.pointRate > 1 ? `ポイント${r.pointRate}倍` : null].filter(Boolean),
      review: r.reviewCount ? { avg: r.reviewAverage, n: r.reviewCount } : null });
  }
  const yl = yahooLink(y);
  if (yl) {
    out.push({ store: 'yahoo', label: 'Yahoo!ショッピング', href: yl, price: y.price ?? null, net: y.price != null ? y.price - (y.point || 0) : null,
      notes: [y.shippingFree === true ? '送料無料' : y.shippingFree === false ? '送料別' : null, y.point ? `${y.point}ポイント` : null].filter(Boolean),
      review: y.reviewCount ? { avg: y.reviewAverage, n: y.reviewCount } : null });
  }
  const al = amazonLink(a, cfg);
  if (al) out.push({ store: 'amazon', label: 'Amazon', href: al, price: null, net: null, notes: [], review: null });
  // 「いちばん安い」は送料込み（無料）の店どうしで比べる。送料別の店しか無いときだけ全部で比べる（送料を足すと順位が変わるため）
  const withPrice = out.filter((o) => o.net != null);
  const freeShip = withPrice.filter((o) => o.notes.includes('送料込') || o.notes.includes('送料無料'));
  const priced = freeShip.length ? freeShip : withPrice;
  if (withPrice.length > 1) { const min = Math.min(...priced.map((o) => o.net)); priced.forEach((o) => { o.cheapest = o.net === min; }); }
  return out;
}

const SHORT = { rakuten: '楽天', yahoo: 'Yahoo!', amazon: 'Amazon' };
const btn = (o, small, short) => `<a class="shop-btn shop-btn--${o.store}${small ? ' shop-btn--sm' : ''}" href="${esc(o.href)}" target="_blank" rel="sponsored noopener nofollow">${short ? SHORT[o.store] : esc(o.label) + 'で見る'}</a>`;

function offerRow(o) {
  const price = o.price != null ? `<b>${yen(o.price)}</b>` : '<span class="shop-muted">価格はリンク先で</span>';
  const bits = [...o.notes.map(esc), o.review ? `レビュー★${Number(o.review.avg).toFixed(1)}（${o.review.n.toLocaleString('ja-JP')}件）` : null].filter(Boolean);
  const notes = bits.length ? `<span class="shop-notes">${bits.join('・')}</span>` : '';
  return `<li class="shop-offer${o.cheapest ? ' is-cheapest' : ''}"><span class="shop-store">${esc(o.label)}</span><span class="shop-price">${price}${o.cheapest ? '<em class="shop-tag">いちばん安い</em>' : ''}</span>${notes}${btn(o, true)}</li>`;
}

function checkedNote(series) {
  const d = series.pricesCheckedAt ? String(series.pricesCheckedAt).slice(0, 10) : null;
  return `<p class="shop-foot">${d ? `価格は ${esc(d)} 時点の税込本体価格（楽天市場・Yahoo!ショッピングの API で自動取得）。` : '価格は自動取得の前です。'}「いちばん安い」は価格が取れた店（楽天市場・Yahoo!ショッピング）の中での比較で、Amazon の価格は載せていません。送料・ポイントの条件と最新の価格は各ショップで確認してください。<span class="shop-pr">PR</span>リンクから購入されると当サイトに紹介料が入ることがあります。</p>`;
}

export function renderButtons(series, item, cfg) {
  const os = offers(item, cfg);
  return `<div class="shop-buttons">${os.map((o) => btn(o, false)).join('')}</div>`;
}

export function renderCard(series, item, cfg) {
  const cols = series.columns || [];
  const specs = cols.filter((c) => item.specs && item.specs[c.key] != null && item.specs[c.key] !== '')
    .map((c) => `<dt>${esc(c.label)}</dt><dd>${esc(item.specs[c.key])}</dd>`).join('');
  return `<div class="shop-card" id="shop-${esc(item.id)}">`
    + (item.badge ? `<span class="shop-badge">${esc(item.badge)}</span>` : '')
    + `<p class="shop-brand">${esc(item.brand || '')}</p><p class="shop-name">${esc(item.name)}</p>`
    + (item.summary ? `<p class="shop-summary">${esc(item.summary)}</p>` : '')
    + (specs ? `<dl class="shop-specs">${specs}</dl>` : '')
    + `<ul class="shop-offers">${offers(item, cfg).map(offerRow).join('')}</ul>`
    + (item.source ? `<p class="shop-src">仕様の出典: <a href="${esc(item.source)}" target="_blank" rel="noopener">メーカー公式</a></p>` : '')
    + `</div>`;
}

export function renderTable(series, cfg) {
  const cols = series.columns || [];
  const head = `<tr><th>商品</th>${cols.map((c) => `<th>${esc(c.label)}</th>`).join('')}<th>いちばん安い店</th><th>買う</th></tr>`;
  const rows = (series.items || []).map((it) => {
    const os = offers(it, cfg);
    const best = os.find((o) => o.cheapest) || os.filter((o) => o.price != null).sort((a, b) => a.net - b.net)[0];
    return `<tr${it.recommended ? ' class="recommended"' : ''}><td class="shop-cell-name"><a href="#shop-${esc(it.id)}">${esc(it.name)}</a>${it.badge ? `<span class="shop-badge shop-badge--sm">${esc(it.badge)}</span>` : ''}</td>`
      + cols.map((c) => `<td>${esc((it.specs || {})[c.key] ?? '—')}</td>`).join('')
      + `<td>${best ? `${yen(best.price)}<br><span class="shop-muted">${esc(best.label)}</span>` : '<span class="shop-muted">リンク先で</span>'}</td>`
      + `<td class="shop-cell-btns">${os.map((o) => btn(o, true, true)).join('')}</td></tr>`;
  }).join('');
  return `<div class="cmp-table-wrap shop-table-wrap"><table class="cmp-table shop-table"><thead>${head}</thead><tbody>${rows}</tbody></table></div>${checkedNote(series)}`;
}

// 1 つの指示（属性名と値）を HTML にする。見つからなければビルドを落とす（黙って空にしない）
export function renderDirective(kind, value, cfg = loadConfig()) {
  const [sid, iid] = String(value).split(':');
  const series = loadSeries(sid);
  if (kind === 'table') return renderTable(series, cfg);
  const item = (series.items || []).find((x) => x.id === iid);
  if (!item) throw new Error(`shop: ${sid}.json に商品 ${iid} が無い`);
  if (kind === 'card') return renderCard(series, item, cfg);
  if (kind === 'buttons') return renderButtons(series, item, cfg);
  throw new Error(`shop: 種類が不明: ${kind}`);
}
