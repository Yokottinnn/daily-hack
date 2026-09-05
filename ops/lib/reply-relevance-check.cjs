'use strict';
// **返信が相手の投稿と噛み合っているかを判定する。判定だけ。**
//
// 2026-09-02、Jordan の指摘:
//   「トンチンカンなことを言っている」「AI が自動で返信しているのがバレバレ」
//
// `tone-gate` は**危ない語**を弾くが、**噛み合っているか**は見ていない。
// そこが穴だった。ここはその穴だけを塞ぐ。
//
// ## 考え方
//
// **「相手の投稿を読んだ形跡があるか」を機械で見る。**
// 形態素解析は入れない（依存を増やさない）。日本語は
// **カタカナ・漢字・英数の 2 文字以上の連なりを内容語とみなす**だけで十分に効く。
// ひらがなは助詞・語尾が大半なので数えない。
//
// ## 何を弾くか
//
//   1. 相手の投稿と**内容語をひとつも共有しない**返信（＝読んでいない）
//   2. **どの投稿にも当てはまる定型だけ**の返信（「いいわね！」だけ、など）
//   3. テンプレが前提にする話題が**相手の投稿に無い**のに使われている
//   4. 直近と**同じ書き出し**が続いている（1 件ずつは自然でも、並ぶと機械に見える）
//   5. 「組み合わせも組み合わせる」のような**直近重複**
//   6. 使用禁止テンプレ（見下し・詰問）
//
// **throw しない。** ここで投げると返信ジョブごと落ちる。

/** 内容語を取り出す。カタカナ / 漢字 / 英数 の 2 文字以上。 */
function tokenize(text) {
  const s = String(text || '');
  const out = new Set();
  const re = /[ァ-ヴー]{2,}|[一-龠々]{2,}|[A-Za-z0-9][A-Za-z0-9._-]{1,}/g;
  let m;
  while ((m = re.exec(s)) !== null) {
    const t = m[0];
    if (t.length >= 2) out.add(t);
  }
  return out;
}

/** 部分一致も拾う。「舞浜ユーラシア」と「ユーラシア」を別物にしない。 */
function sharedTokens(a, b) {
  const A = [...tokenize(a)];
  const B = [...tokenize(b)];
  const hit = [];
  for (const x of A) {
    for (const y of B) {
      // **2 文字から包含を見る。** 3 文字以上だと「外貨」と「外貨建」が別語になり、
      // 明らかに同じ話題なのに「読んでいない返信」と誤判定した（2026-09-05 に実測）。
      // 日本語の 2 字漢語は独立した語なので、包含は同語とみなしてよい。
      if (x === y || (x.length >= 2 && y.includes(x)) || (y.length >= 2 && x.includes(y))) {
        hit.push(x);
        break;
      }
    }
  }
  return [...new Set(hit)];
}

/** 直近で同じ 4 文字以上が繰り返されているか（「組み合わせも組み合わせる」） */
function immediateRepeats(text) {
  const s = String(text || '');
  const re = /(.{4,12}).{0,3}\1/g;
  const hits = [];
  let m;
  while ((m = re.exec(s)) !== null) hits.push(m[1]);
  return hits;
}

/**
 * @param {object} input
 *   text          … こちらが出そうとしている返信
 *   targetText    … 相手の投稿の本文
 *   templateId    … 使ったテンプレ id
 *   recentReplies … 直近に出した返信の配列（新しい順でも古い順でもよい）
 * @param {object} rules  reply-relevance-rules.json
 * @returns {{ok:boolean, reasons:string[], warns:string[], shared:string[]}}
 */
function checkRelevance(input, rules) {
  const r = rules || {};
  const text = String((input && input.text) || '');
  const target = String((input && input.targetText) || '');
  const tpl = String((input && input.templateId) || '');
  const recent = Array.isArray(input && input.recentReplies) ? input.recentReplies : [];

  const reasons = [];
  const warns = [];
  let shared = [];

  if (!text.trim()) {
    return { ok: false, reasons: ['空文'], warns: [], shared: [] };
  }

  // 6. 使用禁止テンプレ
  const banned = Array.isArray(r.banned_templates) ? r.banned_templates : [];
  if (tpl && banned.some(b => tpl === b || tpl.startsWith(b))) {
    reasons.push(`使用禁止テンプレ ${tpl}（見下し・詰問）`);
  }

  // 相手の投稿が無いと噛み合いは判定できない。**素通しにせず warn で残す。**
  // 判定できないことを「問題なし」にすると、記録漏れが永久に見えなくなる。
  if (!target.trim()) {
    warns.push('相手の投稿が記録されていないため噛み合いを判定できない');
  } else {
    // 1. 内容語の共有
    shared = sharedTokens(text, target);
    const need = Number.isFinite(r.min_shared_tokens) ? r.min_shared_tokens : 1;
    if (shared.length < need) {
      reasons.push(`相手の投稿と共有する内容語が ${shared.length} 個（${need} 個必要）＝読んでいない返信`);
    }

    // 3. テンプレが前提にする話題
    const req = (r.template_requires || {})[tpl];
    if (Array.isArray(req) && req.length) {
      const hit = req.some(w => target.includes(w));
      if (!hit) {
        reasons.push(`テンプレ ${tpl} は「${req.slice(0, 3).join('/')}」を前提にしているが、相手の投稿に無い`);
      }
    }

  }

  // 2. 定型だけ
  if (r.generic_only_block) {
    const generics = Array.isArray(r.generic_phrases) ? r.generic_phrases : [];
    let stripped = text;
    for (const g of generics) stripped = stripped.split(g).join('');
    if (tokenize(stripped).size === 0) {
      reasons.push('どの投稿にも当てはまる定型だけで、中身が無い');
    }
  }

  // 2-B. **相手の語をなぞっただけ**
  //
  // 「楽天ポイント還元キャンペーン、同意😉」が実際に出た。
  // 語の共有だけを見ると満点になるが、**こちらから足した情報がゼロ**。
  // 相手の投稿に無い内容語が 1 つも無ければ、なぞっただけである。
  if (target.trim() && r.require_new_token !== false) {
    const tTok = tokenize(target);
    // **定型語・締め文句は「足した情報」に数えない。**
    // 「同意」を内容語として数えたせいで、なぞりだけの返信を通していた。
    let body = text;
    for (const g of [].concat(r.generic_phrases || [], r.closer_phrases || [])) {
      body = body.split(g).join('');
    }
    const own = [...tokenize(body)].filter(x => {
      for (const y of tTok) {
        if (x === y || (x.length >= 3 && y.includes(x)) || (y.length >= 3 && x.includes(y))) return false;
      }
      return true;
    });
    if (own.length === 0) {
      reasons.push('相手の語をなぞっただけで、こちらから足した情報がゼロ');
    }
  }

  // 4. 書き出し**と語尾**の重複
  //
  // 実物 15 件は**書き出しはバラバラだが語尾の型が同じ**だった。
  //   「試してみなさい💡」×2 ／「教えなさいよ😤」×2 ／「同意😉」×2
  //   「アタシもこれは早めにやっといてよかったわ💸」×2
  // **反対側を見ていては捕まらない。両端を見る。**
  const win = Number.isFinite(r.recent_window) ? r.recent_window : 20;
  const maxSame = Number.isFinite(r.max_same_opening_in_recent) ? r.max_same_opening_in_recent : 2;
  const prev = recent.slice(-win).map(x => String(x || ''));

  const oc = Number.isFinite(r.opening_chars) ? r.opening_chars : 8;
  const head = text.slice(0, oc);
  if (head) {
    const same = prev.filter(x => x.slice(0, oc) === head).length;
    if (same >= maxSame) {
      reasons.push(`同じ書き出し「${head}」が直近 ${win} 件に ${same} 件＝並ぶと機械に見える`);
    }
  }

  const tc = Number.isFinite(r.tail_chars) ? r.tail_chars : 7;
  const tail = text.slice(-tc);
  if (tail && text.length >= tc) {
    const same = prev.filter(x => x.length >= tc && x.slice(-tc) === tail).length;
    if (same >= maxSame) {
      reasons.push(`同じ語尾「${tail}」が直近 ${win} 件に ${same} 件＝並ぶと機械に見える`);
    }
  }

  // 4-B. **締めの決まり文句**の使い回し
  const closers = Array.isArray(r.closer_phrases) ? r.closer_phrases : [];
  const maxCloser = Number.isFinite(r.max_same_closer_in_recent) ? r.max_same_closer_in_recent : 2;
  for (const c of closers) {
    if (!text.includes(c)) continue;
    const same = prev.filter(x => x.includes(c)).length;
    if (same >= maxCloser) {
      reasons.push(`締めの「${c}」が直近 ${win} 件に ${same} 件＝同じ型の使い回し`);
      break;
    }
  }

  // 4-C. **根拠のない金額断定**
  //
  // 「年間3650円浮く」「年間40000円浮く」が実際に出た。
  // 朝食を変えて年 4 万円は雑な捏造で、金融の話題では実害が出る。
  if (r.block_money_claim !== false) {
    const money = /(年間?|月|毎月|毎年)[^。、]{0,12}?[0-9０-９,，]{2,}\s*(円|万円|ポイント|pt)[^。、]{0,6}?(浮く|得|お得|貯まる|変わる|節約)/;
    if (money.test(text)) {
      reasons.push('根拠のない金額断定（相手の条件を知らずに「年◯◯円浮く」と言い切っている）');
    }
  }

  // 4-D. **壊れた活用**
  //
  // 2026-09-05 に「焦ら**なさい**」が出た。正しくは「焦らないで」か「焦りなさんな」。
  // 否定の語幹（〜ら/〜わ/〜さ/〜か/〜が/〜ば/〜ま/〜な/〜た）に「なさい」を直付けした形で、
  // **人は書かない壊れ方**。AI っぽさが一番出るのがここ。
  //
  // 「〜しなさい」「試してみなさい」「気をつけなさい」は**正しいので通す**
  //（連用形＋なさい）。弾くのは未然形＋なさい だけ。
  if (r.block_broken_conjugation !== false) {
    // 未然形をとる行の音 + なさい。「し|み|け|ち|り|び|ぎ|に|み」等の連用形は含めない
    const broken = /[らわさかがばまなただ]なさい/;
    const m = text.match(broken);
    if (m) {
      reasons.push(`活用が壊れている「${m[0]}」＝人は書かない形（例: 焦らなさい → 焦らないで）`);
    }
  }

  // 4-E. **他人の資産・結果への根拠のない断定**
  //
  // 2026-09-05 に「インデックス軸なら長期で見れば**大丈夫よ**」が出た。
  // 相手の保有比率も期間も知らないのに、資産が大丈夫だと言い切っている。
  // 金額断定（4-C）を禁じた理由と同じで、**金融の話題では実害が出る。**
  //
  // 「美味しいから大丈夫」のような日常文まで弾かないよう、**金融語と同居したときだけ**弾く。
  if (r.block_unfounded_reassurance !== false) {
    const money = Array.isArray(r.finance_words) && r.finance_words.length
      ? r.finance_words
      : ['投資', '資産', 'NISA', 'iDeCo', '株', '為替', 'ドル', '円安', '円高', '利回り',
         '配当', 'インデックス', '積立', '含み損', '暴落', '相場', '外貨', '損失'];
    const calm = /(大丈夫|心配ない|心配いらない|問題ない|安心して|必ず戻|絶対戻|いずれ戻|放っておけば)/;
    const c = text.match(calm);
    if (c && money.some(w => text.includes(w) || target.includes(w))) {
      reasons.push(`他人の資産への根拠のない断定「${c[0]}」＝相手の条件を知らずに言い切っている`);
    }
  }

  // 4-G. **相場の予測**
  //
  // 2026-09-05 に「ここからの**回復も早い**と思うわ」が出た。
  // 「回復」は相手の投稿に無く、**こちらが足した見通し。**
  //
  // 4-E は「大丈夫よ」の断定を弾いたが、**「思う」で緩めれば通ってしまう。**
  // 断定を避けただけで中身は予測のままなので、**語尾ではなく中身で弾く。**
  //
  // 相手が自分で書いた見通しに乗るのは可（投稿にその語があれば通す）。
  if (r.block_market_forecast !== false) {
    const money = Array.isArray(r.finance_words) && r.finance_words.length
      ? r.finance_words : [];
    const fc = /(回復|反発|戻る|戻す|上がる|上向|持ち直|伸びる|下がる|落ちる|暴落する)/;
    const m = text.match(fc);
    if (m && !target.includes(m[0]) && money.some(w => text.includes(w) || target.includes(w))) {
      reasons.push(`相場の予測「${m[0]}」＝相手の投稿に無い見通しを足している`);
    }
  }

  // 4-H. **金融語の言い換え**
  //
  // 2026-09-05 に、相手の「旧NISA からの**資産**がある」を
  // 「旧NISA の**貯金**がある」と書き換えた。**投資資産と貯金は別物。**
  //
  // 2026-09-04 の「サーモンゆず塩」→「塩辛いサーモン」と**同じ型**のずれ。
  // 程度は軽いが根は同じなので、**混同すると意味が変わる組**だけを見る。
  if (r.block_finance_paraphrase !== false) {
    const pairs = Array.isArray(r.finance_paraphrase_pairs) && r.finance_paraphrase_pairs.length
      ? r.finance_paraphrase_pairs
      : [[['資産', '投資', '運用', '株', '投信', 'NISA', 'iDeCo'], ['貯金', '預金', '貯蓄']],
         [['ポイント', 'pt'], ['現金', 'キャッシュバック']],
         [['還元', '付与'], ['割引', '値引き']]];
    for (const [src, dst] of pairs) {
      // **こちらが使った語**が相手の投稿に無く、かつ**対になる語**が相手の投稿にある
      const used = dst.find(w => text.includes(w) && !target.includes(w));
      if (used && src.some(w => target.includes(w))) {
        const orig = src.find(w => target.includes(w));
        reasons.push(`言い換えている「${orig}」→「${used}」＝別物になっている`);
        break;
      }
    }
  }

  // 4-F. **テンプレに無い絵文字**
  //
  // 2026-09-05 に 😌 が出た。テンプレ 35 件が使っているのは 14 種で、そこに無い。
  // **絵文字も声の一部**なので、範囲の外に出たら別人の顔になる。
  const allowed = Array.isArray(r.allowed_emoji) ? r.allowed_emoji : [];
  if (allowed.length) {
    // サロゲートペア・異体字セレクタ・ZWJ をまたいで拾う
    const emojiRe = /(?:\p{Extended_Pictographic}(?:️)?(?:‍\p{Extended_Pictographic}(?:️)?)*)/gu;
    const used = String(text).match(emojiRe) || [];
    const bad = [...new Set(used.map(e => e.replace(/️/g, '')))]
      .filter(e => !allowed.map(a => a.replace(/️/g, '')).includes(e));
    if (bad.length) {
      reasons.push(`テンプレに無い絵文字「${bad.slice(0, 3).join('')}」＝声の範囲の外`);
    }
  }

  // 5. 直近重複
  const reps = immediateRepeats(text);
  const maxRep = Number.isFinite(r.max_immediate_repeat) ? r.max_immediate_repeat : 1;
  if (reps.length >= maxRep) {
    reasons.push(`同じ語の繰り返し「${reps[0]}」＝日本語が壊れている`);
  }

  return {
    ok: reasons.length === 0,
    reasons,
    warns,
    shared,
  };
}

module.exports = { checkRelevance, tokenize, sharedTokens, immediateRepeats };
