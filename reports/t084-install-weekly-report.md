# 週次レポートの実体を入れ替える（t084）

生成: **2026-09-15T02:15:00+0900**

| | パス |
| --- | --- |
| コピー元（リポジトリ） | `/Users/ny/projects/anta-baka-x/blog/scripts/weekly-blog-report.py` |
| コピー先（plist が叩く先） | `/Users/ny/scripts/weekly-blog-report.py` |

## 着手前の状態

- コピー先は **ある**（152 行）
- 1 行目: `#!/usr/bin/env python3.11`
- `${ALL_VISITS}` を含む行数: **0
0**
- コピー元は 811 行

## 入れ替えた

- 退避: `/Users/ny/scripts/weekly-blog-report.py.bak-20260915-021500`
- コピー先は 811 行になった

## 確かめる（**rc=0 では足りない・最上位ルール 13**）

- ✅ `/opt/homebrew/bin/python3.11 -m py_compile` **通った**
- 1 行目: `#!/usr/bin/env python3`
- 中身が同じか: **リポジトリ版と一致**

## 次の週次レポートで見ること

**`${ALL_VISITS}` が数字になっていること。** なっていなければ、
plist が別の場所を指しているか、python3.11 に依存が入っていない。
