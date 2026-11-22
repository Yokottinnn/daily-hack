# 1 件あたりの入力/出力トークン（実測）

**このレポートが作られた時刻: 2026-09-10 21:38:26 JST**

> **推定で設計を決めない。**
> 単価は 入力 $1.00/MTok ／ **出力 $5.00/MTok**（Haiku 4.5）。
> **出力は入力の 5 倍 高い。** どちらを削るべきかは内訳で決まる。

## 1. 実際の `usage`（ログに残っていれば）

```
  **どのログにも usage が記録されていない。**
  → 生成器が usage を捨てている。**記録するようにしないと実測できない。**
```

### 生成器は usage を記録しているか

```javascript
  # asuka-reply.cjs — 246 行
  146:      model: cfg.model,
  167:    //     model: MODEL, system: SYSTEM, user: userMsg,
  168:    //     max_tokens: 500, temperature: 0.7,
  176:      model: cfg.model,
  179:      max_tokens: Number(cfg.max_tokens || 300),
  180:      temperature: Number(cfg.temperature || 0.9),
  243:  out({ ok: true, text, weight: w, target_text: target, model: cfg.model, shared: rel.shared, warns: rel.warns });
```

## 2. プロンプトの実サイズ（**4,096 tok を超えるか**）

Haiku 4.5 のキャッシュ最低は **4,096 tok**。未満だと静かに効かない。

```
  --- 生成器が読み込んでいる固定ファイル ---
    readFileSync(p, 'utf8')
    readFileSync(queuePath, 'utf8')

  --- その実サイズ（バイト → おおよそのトークン: 日本語は約 1.5 B/tok） ---
    reply-style-prompt.json               10030 B  ≒   5015 tok
    comment-templates.json                 7585 B  ≒   3792 tok
    reply-ng-rules.json                    4160 B  ≒   2080 tok

  --- 生成器そのものに埋め込まれた文字列（system プロンプト） ---
    バッククォート内の長文: 0 B  ≒ 0 tok
```

**合計が 4,096 tok 未満なら、いまのままではキャッシュは効かない。**
**まとめ判定で入力を増やすと、逆にキャッシュが使えるようになる。**

## 3. skip の理由文は何文字 使っているか（**出力単価は入力の 5 倍**）

```
  --- 直近 20 件の skip 理由の長さ ---
     123 文字 ≒   61 tok   "reason":"噛み合い検査で弾いた: 末尾の絵文�
     336 文字 ≒  168 tok   "reason":"生成側が skip: 相手の投稿は著名人�
     180 文字 ≒   90 tok   "reason":"生成側が skip: 紹介コード・招待リ�
     327 文字 ≒  163 tok   "reason":"生成側が skip: 相手が具体的な銘柄�
     120 文字 ≒   60 tok   "reason":"生成側が skip: 紹介コード・招待URL�
     106 文字 ≒   53 tok   "reason":"PR/アフィリ/拡散キャンペーンの投�
     286 文字 ≒  143 tok   "reason":"生成側が skip: 相手は損失を報告し�
     123 文字 ≒   61 tok   "reason":"噛み合い検査で弾いた: 末尾の絵文�
     124 文字 ≒   62 tok   "reason":"PR/アフィリ/拡散キャンペーンの投�
     109 文字 ≒   54 tok   "reason":"PR/アフィリ/拡散キャンペーンの投�
     123 文字 ≒   61 tok   "reason":"噛み合い検査で弾いた: 末尾の絵文�
     204 文字 ≒  102 tok   "reason":"噛み合い検査で弾いた: 相手の語を�
     249 文字 ≒  124 tok   "reason":"生成側が skip: 相手が具体的な案件�
     123 文字 ≒   61 tok   "reason":"噛み合い検査で弾いた: 末尾の絵文�
     112 文字 ≒   56 tok   "reason":"PR/アフィリ/拡散キャンペーンの投�
     118 文字 ≒   59 tok   "reason":"PR/アフィリ/拡散キャンペーンの投�
     114 文字 ≒   57 tok   "reason":"生成側が skip: 紹介コード・招待コ�
     293 文字 ≒  146 tok   "reason":"生成側が skip: 楽天公式のキャンペ�
     226 文字 ≒  113 tok   "reason":"噛み合い検査で弾いた: 相手の投稿�
     276 文字 ≒  138 tok   "reason":"生成側が skip: 店舗の販売促進投稿�

  20 件の合計: 3692 文字 ≒ 1846 tok
  1 件あたり平均: 184 文字 ≒ 92 tok

  **skip をコード 1 語（例 skip:money_advice ≒ 5 tok）にすれば、ここはほぼ 0 になる。**
```

## 4. 前段で落とせるはずの候補は何件あるか（**LLM を呼ばずに $0**）

いま **LLM を呼んでから** skip している理由のうち、
**投稿本文を見るだけで判定できるもの**を数える。

```
  直近 7 日の gen failed: 30 件
    うち LLM を呼ばずに $0 : 7 件
    **うち課金して 0 件**  : 23 件

  --- 課金して skip した理由（前段に移せそうなものを探す） ---
       4 噛み合い検査で弾いた: 末尾の絵文字「�
       2 噛み合い検査で弾いた: 相手の投稿と共有
       1 生成側が skip: 紹介コード・招待リンク・�
       1 生成側が skip: 紹介コード・招待コード・�
       1 生成側が skip: 紹介コード・招待URL・キャ�
       1 生成側が skip: 紹介URLの誘導が含まれてお�
       1 生成側が skip: 相手は損失を報告している�
       1 生成側が skip: 相手は投資判断の決め手に�
       1 生成側が skip: 相手の投稿は著名人への好�
       1 生成側が skip: 相手の投稿は商品販売告知�
       1 生成側が skip: 相手が具体的な銘柄・買値�
       1 生成側が skip: 相手が具体的な案件名・条�

  **「hashtag のみ」「本文が短い」「内容がない」は本文を見るだけで判定できる。**
  **＝ 前段に移せば LLM 課金がゼロになる。**
```

### いまの前段フィルタは何を見ているか

```javascript
  # ng-filter-candidates.cjs — 87 行
  28:    if (!Array.isArray(list)) throw new Error('配列ではない');
  32:    return;
  44:    return;
  69:    if (v.ng) dropped.push(v);
  73:  if (dropped.length) {
  78:      `  ng-filter: ${list.length} 件中 ${dropped.length} 件を弾いた (${detail})\n`
  84:    process.stderr.write(`  ng-filter: ${list.length} 件すべて通過\n`);
```

---

## この実測で決まること

| 測った値 | 決まること |
| --- | --- |
| 入力/出力の内訳 | **入力と出力のどちらを削るべきか** |
| プロンプトの実サイズ | **キャッシュが使えるか**（4,096 tok の壁） |
| skip 理由の長さ | **コード化でいくら浮くか** |
| 課金して skip した件数 | **前段フィルタでいくら浮くか** |

**LLM を呼んでいない。投稿もしていない（$0）。**
