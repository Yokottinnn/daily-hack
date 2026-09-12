# モデルに「弾かれる条件」を教える

**このレポートが作られた時刻: 2026-09-13 02:34:20 JST**

> **弾く条件を全部 知っているのに、モデルには 1 つも伝えていなかった。**
> プロンプトへ渡すのは直近 **8 件の全文**、ゲートが見るのは **20 件**。
> 9〜20 件前に使った書き出しは、モデルから見えないので避けようがない。

## 0. 前提

```
  3 ループ    : **8 / 8 本**
  CDP         : 健全
  login ロック: 無い
  修理(x43)   : 入っている
  本日の返信  : **0 件** / 累計 857 件
```

## 1. 禁止リストをプロンプトに入れる（**根本原因**）

```
  --- 当てる前 ---
    142:  const userMsg = String(cfg.user_template || '{TARGET}')
  パッチの node --check: OK
    書き換えた。userMsg 行=142 / DRY_RUN 行=146
  対象の node --check: OK
  --- 当てた後 ---
    142:  let userMsg = String(cfg.user_template || '{TARGET}')
    158:  // BANNED_LIST (2026-09-13): **弾く条件をモデルにも教える。**
    181:    const badHead = [...new Set(prev2.concat(runR2).map((x) => x.slice(0, oc2)).filter(Boolean))].slice(0,
    198:    const okE = (BR.allowed_emoji || []).filter((e) => !badE.includes(e));
    202:    if (badHead.length) parts.push(BAN_B + badHead.map((o) => KO + o + KC).join(TEN));
```

## 2. 広告を入口で落とす（LLM を呼ぶ前に）

ログに残っていた**生成後**の skip ＝ **LLM 代を払ってから捨てていた。**

```
  --- 当てる前 ---
    campaign_words 14 件 / domains 11 件
    opening_phrases 11 件 / allowed_emoji 14 件
    campaign_words: 14 → 27 件
    domains       : 11 → 15 件
  --- 当てた後 ---
    campaign_words 27 件 / domains 15 件
    opening_phrases 11 件 / allowed_emoji 14 件
```

## 3. 目標 16 件に届くまで繰り返す（最大 8 回）

1 回あたり 最大 4 件・約 $0.012。**最大 8 回で $0.096。**
目標に届けば途中で止まる。候補が尽きても止まる。

```
  開始時: 本日 0 件 / 累計 857 件 / 目標 16 件

  --- 1 回目 ---
