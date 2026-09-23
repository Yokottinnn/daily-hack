# JAL と さとふる をフルヘッダで取り直す（t163・**$0**）

生成: **2026-09-23T18:20:55+0900**

**UA だけでは足りなかった**ので、実ブラウザが送るヘッダを揃えた。
**取れなかったときは理由を出す**（最上位ルール 17）。

## JAL（日本航空）

`https://www.jal.co.jp/jp/ja/`

- HTML **382 bytes**（UA だけのときは t155/t156 の表を参照）
- ⚠️ **フルヘッダでも開けない。** 次は規格の場所を直接叩く

### 規格の場所を直接（`https://www.jal.co.jp`）
  - ❌ `https://www.jal.co.jp/apple-touch-icon.png` → **403** / text/html / 401 bytes
  - ❌ `https://www.jal.co.jp/apple-touch-icon-precomposed.png` → **403** / text/html / 417 bytes
  - ⬇️ `jal-icon0.ico`（**9662 bytes** / image/x-icon）← `https://www.jal.co.jp/favicon.ico`
  - ❌ `https://www.jal.co.jp/favicon.png` → **403** / text/html / 384 bytes

## さとふる

`https://www.satofull.jp/`

  - ❌ `https://www.satofull.jp/apple-touch-icon.png` → **000** / - / 0 bytes
- HTML **0 bytes**（UA だけのときは t155/t156 の表を参照）
- ⚠️ **フルヘッダでも開けない。** 次は規格の場所を直接叩く

### 規格の場所を直接（`https://www.satofull.jp`）
  - ❌ `https://www.satofull.jp/apple-touch-icon-precomposed.png` → **000** / - / 0 bytes
  - ❌ `https://www.satofull.jp/favicon.ico` → **404** / text/html / 185415 bytes
  - ❌ `https://www.satofull.jp/apple-touch-icon.png` → **000** / - / 0 bytes
  - ❌ `https://www.satofull.jp/favicon.png` → **000** / - / 0 bytes
  - ⚠️ **1 つも取れなかった**

---

**1 件 持ち帰った。**
**favicon は 16〜32px のことがある。** 小さすぎるものは記事には使えない。
**採否とサイズの確認はクラウド側でコンタクトシートを見てやる。**

経過 **56 秒**。
