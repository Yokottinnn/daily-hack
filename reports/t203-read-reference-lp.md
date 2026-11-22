# 参照 LP を実際に読む（t203・**$0**）

生成: **2026-10-01T23:14:13+0900**

対象: `app-mania.online/point/rank.php`（利用者から指定）

## ① HTML

| | |
| --- | --- |
| HTTP | **200** |
| 大きさ | **79695 bytes** |

## ② CSS

- 合計 **20777 bytes**（`reports/lp-ref/all.css` に置いた）
- 外部 CSS: **2 本**

## ③ 色（多い順・上位 30）

```text
  26 #ff5577
  14 #fff
   8 #fcfdff
   8 #f6faff
   5 #ffffff
   4 #fffffb
   4 #fffef7
   4 #333
   4 #00bcd4
   3 rgba(0, 102, 204, 0.7)
   3 #f7eec6
   3 #ccc
   3 #5e5eff
   3 #00aaff
   2 rgba(0, 0, 0, 0.1)
   2 #fffff4
   2 #ff9500
   2 #ff6b00
   2 #ddd
   2 #d02569
   2 #ccebfb
   2 #666
   2 #474747
   2 #127775
   1 rgba(0, 0, 0, 0.5)
   1 #fffde7
   1 #fff9c4
   1 #fff4e0
   1 #ffd700
   1 #ffcccc
```

グラデーションの指定:

```text
   4 linear-gradient(-45deg, #fcfdff, #fcfdff 3px, #f6faff 3px, #f6faff 7px)
   2 linear-gradient(-45deg, #fffffb, #fffffb 3px, #fffef7 3px, #fffef7 7px)
   1 linear-gradient(to bottom, #fffde7, #fff9c4)
```

## ④ class 名（多い順・上位 45）

```text
  26 section-heading
  26 scroll-infinity__item
  26 custom-listChk
  26 box-title
  14 ranking-item
  14 box1_title
  14 box1
  13 reviewbox
  13 ranking-info
  13 rank
  13 osusumebox
  13 button-container
  13 app-info-table
   3 title-row
   3 plan-name
   3 official-btn
   3 corner-image
   2 scroll-infinity__list--right
   2 scroll-infinity__list
   2 header-row
   2 fa-solid
   2 fa-crown
   2 container
   2 btn-row
   1 top3-description
   1 title
   1 table-wrapper
   1 scroll-infinity__wrap
   1 scroll-infinity
   1 rank_num
   1 cta-hidden
   1 cta-content
   1 comparison-table
   1 box-015
```

**順位・CTA・バッジらしきもの**（名前で引いた）:

```text
.btn-row
.crown-img
.cta-hidden
.cta-visible
.official-btn
.osusumebox
.rank
.rank_num
.ranking-button
.ranking-item
.star-icon
.star-line
.star-score
.star-vertical
.star-wrapper
```

## ⑤ 画面

- ⚠️ `playwright-core` が無い。**HTML と CSS だけ持ち帰る**

---

> **判断はしていない。素材を持ち帰っただけ**（最上位ルール 20）。
> 置き場: `reports/lp-ref/`（`page.html` / `all.css` / `pc.png` / `sp.png`）

LLM 不使用。**$0/回・$0/日・$0/月。**
