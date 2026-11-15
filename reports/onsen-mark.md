# 温泉マークを Commons から取る（2026-08-30 21:10 JST）

> クラウド側は egress ポリシーで Commons に届かない。**Mac から取る。**
> `fetch-commons-photo.py` を使うので `_manifest.json` に出典が残る。

- 作業ブランチ: `ops/onsen-mark-20260830-121039`
- python: /opt/homebrew/bin/python3.11

## 1. 候補を探す

```
Public domain      1500x1125   File:Tokko-no-yu 20110919.jpg
```

## 2. 取得する

- 試す: `File:Japanese Map symbol (Hot spring).svg`
  → 取れない
- 試す: `File:Hot spring symbol.svg`
  → 取れない
- 試す: `File:Japanese Map symbol (Hot spring) w.svg`
  → 取れない

**どれも取れなかった。当て推量で別の画像を置かない。**
上の検索結果から、使えそうなファイル名を人が選んで指定すること。
