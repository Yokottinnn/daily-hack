# 記事リフレッシュの定期ジョブを入れ直す（t139）

生成: **2026-09-21T01:57:33+0900**

## 1) 置いたもの

- シム: `/Users/ny/.openclaw/bin/refresh-daily-boot.sh`（**毎回 origin/main から本体を取り出す**）
- plist: `/Users/ny/Library/LaunchAgents/com.dailyhack.refresh-daily.plist`（毎日 05:30・`RunAtLoad` false）

## 2) 載せた結果

- `bootstrap` の rc: 0（**これは証拠にならない**）
- `launchctl list`: **載っていない** ← **こちらが証拠**

## 3) シムが本体を取り出せるか（**実際に打った**）

- 取り出せた（**136 行**）／ `bash -n` **通る**

## 4) 作業ツリーの状態（参考・触っていない）

- HEAD: `17107e9 feat: 記事を定期的に更新する仕組み（AIO ＋ 素材 ＋ リサーチ） (#593)`
- ⚠️ **未コミットが 2 件 ある。** この場合ジョブは**何もせずに終わる**

## 5) 鍵の有無

- ⚠️ **鍵が見つからない。** ジョブは走っても何もせずに終わる

## 6) 次に起きること

- **毎日 05:30 に 1 本** 調べ、確度「高」だけ当てて **PR を作る**
- **マージは人がやる。** 自動では入らない
- 1 本目は `ops/data/unindexed.txt` の先頭（未インデックスの記事から回す）
- 実額: `ops/data/refresh-state.json` の `total_usd`／ログ: `~/.openclaw/logs/refresh-daily.log`
