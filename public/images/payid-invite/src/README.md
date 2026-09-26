# PAY ID の告知画像の素材

**ここに置くのは App Store 掲載素材だけ。**（`x-post-images` スキル §3・最上位ルール 8）

| ファイル | 中身 | 取得元 |
| --- | --- | --- |
| `icon.png` | アプリのアイコン（512px） | iTunes Search API `artworkUrl512` |
| `shot1.png` | スクリーンショット 1 枚目 | iTunes Search API `screenshotUrls[0]` |
| `shot2.png` | スクリーンショット 2 枚目 | iTunes Search API `screenshotUrls[1]` |

`ops/tasks/x153-fetch-payid-assets.sh` が Mac で取り、base64 でレポートに載せる
（クラウドからは `itunes.apple.com` に出られない）。
**取得日と実際の URL は、素材を置くときに `_manifest.json` に書く。**

- **アイコンは商標。改変しない**（余白を落とすのは可）。最上位ルール 17
- **出所の行は画像に焼き込まない。** この素材なら権利表記が要らない
