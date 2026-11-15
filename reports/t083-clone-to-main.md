# Mac のクローンを main に戻す（t083）

生成: **2026-09-15T02:14:54+0900**

## 着手前

| 項目 | 値 |
| --- | --- |
| ブランチ | `ops/t006-sauna-thread-v3` |
| HEAD | `ade78a1 2026-08-30 22:54:06 +0900 fix: サウナ告知が no candidate で終わ` |

### いまの HEAD が origin にも在るか（**ここが安全確認**）

✅ `origin/ops/t006-sauna-thread-v3` が **同じ SHA**（`ade78a1`）。切り替えても失うものは無い。

### 残す未追跡ファイル（消さない）

```
?? docs/session-logs/
?? drafts/
?? ops/tasks/t006-post-sauna-thread.sh
?? scripts/__pycache__/
```

## 実行した

```
Switched to branch 'main'
Your branch is behind 'origin/main' by 292 commits, and can be fast-forwarded.
  (use "git pull" to update your local branch)
 create mode 100644 src/content/posts/odaiba-drone-show-2026.md
 create mode 100644 src/content/posts/sauna-openings-2026.md
 create mode 100644 src/content/posts/tokyo-discount-supermarket-2026.md
 create mode 100644 src/content/posts/walk-poikatsu-2026.md
 create mode 100644 src/lib/headings.ts
```

## 着手後（**ここが証拠・ルール 13**）

| 項目 | 値 |
| --- | --- |
| ブランチ | **`main`** |
| HEAD | `634f84b 2026-09-15 02:14:40 +0900` |
| main に対して遅れ | **0 コミット** |

✅ **main の最新に戻った。**

### リポジトリのファイルが来ているか

- `scripts/weekly-blog-report.py` **ある**（811 行）
- `scripts/check-article-ux.py` **ある**（199 行）
- `docs/article-ux-baseline.json` **ある**（314 行）

### 未追跡ファイルが残っているか

```
?? drafts/
?? ops/tasks/t006-post-sauna-thread.sh
?? scripts/__pycache__/fix-md-bold.cpython-311.pyc
```
