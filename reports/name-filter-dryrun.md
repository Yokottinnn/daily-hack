# 公式アカウントの名前フィルタを入れる（記録モード）（2026-09-25 17:05 JST・$0）

**このレポートが作られた時刻: 2026-09-25 17:05:53 JST**

> **既定は `log`。記録するだけでフォローは止めない。** 環境変数を足さない限り挙動は変わらない。

## 0. 当てる前の状態

```
  行数    : 220
  更新     : 2026-09-05 18:53:25
  sha256  : 00840ddb7d1e2f27b0fc41bb863335829474bc19214f71135a719923cf636c01
```

> x143 の時点は `220 行 / 00840ddb…`。**違っても sha では止めない。**
> **目印の文字列が在るかで判定する**（無ければ 1 文字も書かずに止まる）。

## 1. バックアップ

```
  follow-handle.js.bak-20260925-170553  (10814 bytes)
```

## 2. パッチを当てる（**目印が 1 つでも無ければ止まる**）

```
  OK 1. 定数と判定関数を入れた / 2. 表示名の取得を足した / 3. 返り値に display_name を足した / 4. passFilter の末尾に判定を差した
  rc=0
```

## 3. `node --check`（**通らなければ元に戻す**）

```
  rc=0
```

## 4. 当てたあと

```
  行数    : 272
  sha256  : f8121b65e524f107708f6ac40c85006dfc4f9afa62855c8235f10e7bbd73bebe
  差分    : +52 行
```

入った箇所（**行番号だけ。中身は §5 の動作確認で見る**）:

```
  27:const NAME_FILTER_MODE = process.env.FOLLOW_NAME_FILTER || "log";
  31:const OFFICIAL_NAME_RE = /[【\[(（]\s*公式\s*[】\])）]|公式(アカウント|ツイッター|ストア|通販|サイト)|株式会社|有限会社|合同会社|[(（]\s*[株有]\s*[)）]|Co\.,?\s?Ltd|Inc\.|Corporation|編集部|広報(部|室|担当)|カスタマー(サポート|サービス)|お客様(サポート|センター)|採用(担当|情報)/i;
  33:const OFFICIAL_WEAK_RE = /_(jp|pr|co|inc|corp|press|staff)$/i;
  35:function officialStrong(name, bio, h) {
  36:  let m = (name || "").match(OFFICIAL_NAME_RE); if (m) return "name:" + m[0];
  37:  m = (bio || "").match(OFFICIAL_NAME_RE);      if (m) return "bio:" + m[0];
  41:function officialWeak(h) {
  42:  const m = (h || "").match(OFFICIAL_WEAK_RE);
  154:  if (NAME_FILTER_MODE !== "off") {
  155:    const strong = officialStrong(profile.display_name, bio, handle);
  156:    const weak = strong ? null : officialWeak(handle);
  165:          name: profile.display_name || "",
  167:          mode: NAME_FILTER_MODE,
  168:          acted: NAME_FILTER_MODE === "on" && !!strong,
  171:      if (NAME_FILTER_MODE === "on" && strong) {
  217:      display_name: displayName,
```

## 5. 動作確認（**rc=0 は証拠にならない**・最上位ルール 13）

判定関数だけを切り出して、**当たるはずのものと当たらないはずのもの**を通す。
**X には 1 回も触らない。フォローもしない。**

```
  OK 当たる -> strong name:【公式】
  OK 当たる -> strong name:株式会社
  OK 当たる -> strong name:編集部
  OK 当たる(bio) -> strong bio:公式アカウント
  OK 当たる(handle) -> strong handle:official
  OK 当たらない -> (なし)
  OK 当たらない -> (なし)
  OK 弱い(記録のみ) -> weak handle:_jp
  ---
  NG 0 件
```

## 6. いまの挙動

| `FOLLOW_NAME_FILTER` | 何が起きるか |
| --- | --- |
| **未設定（＝いま）** | `log`。**当たったものを `data/name-filter-dryrun.jsonl` に書くだけ。フォローは止めない** |
| `on` | 強い手がかりに当たったものを弾く。**弱い手がかり（`_jp` 等）は on でも弾かない** |
| `off` | 何もしない（記録もしない） |

**plist を触っていないので、いまは `log` で動く。** 1 日 貯めれば
**表示名まで含めた実数**が出る。そこを見てから `on` にするかを決める。

戻すとき:

```bash
  cp -p "/Users/ny/.openclaw/workspace/scripts/follow-handle.js.bak-20260925-170553" "/Users/ny/.openclaw/workspace/scripts/follow-handle.js"
```

## 7. 費用

**ファイルを書き換えて構文を検査しただけ。LLM を呼んでいない。**
**フォロー自体も DOM 操作のみで LLM を呼ばない**ので、この変更で課金は増えない。

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
