# 収支を合わせる係を入れて DRY で確かめる（2026-09-27 15:17 JST・$0）

**このレポートが作られた時刻: 2026-09-27 15:17:13 JST**

> **DRY。1 件も外していない。** 既存のジョブも消していない。plist も置いていない。

## 1. 置く前の確認

```
  既に在るか: 無い（新規）
  書いたもの: 15621 bytes
```

**`node --check` を通してから置く。** 通らなければ置かない。

```
  rc=1
  node:internal/modules/esm/get_format:236
    throw new ERR_UNKNOWN_FILE_EXTENSION(ext, filepath);
          ^
  
  TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".new-20260927-151713" for /Users/ny/.openclaw/workspace/scripts/follow-balance.js.new-20260927-151713
      at Object.getFileProtocolModuleFormat [as file:] (node:internal/modules/esm/get_format:236:9)
      at defaultGetFormat (node:internal/modules/esm/get_format:262:36)
      at checkSyntax (node:internal/main/check_syntax:67:20) {
    code: 'ERR_UNKNOWN_FILE_EXTENSION'
  }
  
  Node.js v26.0.0
```

- **構文が通らない。置かずに終わる。**

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
