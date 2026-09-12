# 相互でも「休眠・格下」なら そっと外すジョブを常駐化

**このレポートが作られた時刻: 2026-09-13 03:02:55 JST**

> フォロワー数をどんどん増やしていきたいので、お互いにフォローしている場合でも、
> 相手のアカウントがあまり活動していない場合とか、自分のアカウントと比べた時に
> 大したことない場合にはそっとアンフォローするジョブを常駐化してほしい。

**このタスクの実行は DRY_RUN。1 件も外さない。** 誰をどの理由で外すかだけ出す。
常駐ジョブは載せるが **`RunAtLoad` は false**。最初の自動実行は 12 時間後。

## 0. 前提

```
  CDP: 健全
  login ロック: 無い
  playwright-core: 在る
  既存の同種ジョブ:
    auto-detect-and-unfollow-inactive: plist はあるが未ロード
    reply-followers-cleanup: plist はあるが未ロード
    revenge-unfollow: plist はあるが未ロード
```

## 1. `mutual-prune.js` を置く

**x17 で実際に動いたコードをそのまま使う。** `playwright-core` ／ `connectOverCDP` ／
`data-testid` の `*-unfollow` を押して確認ダイアログを確定する流れは書き直さない。

```
  **構文エラー。置かない。**
    node:internal/modules/esm/get_format:185
      throw new ERR_UNKNOWN_FILE_EXTENSION(ext, filepath);
            ^
    
    TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".new" for /Users/ny/.openclaw/workspace/scripts/mutual-prune.js.new
```
