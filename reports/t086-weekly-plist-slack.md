# 週次レポートの plist に --slack を足す（t086）

生成: **2026-09-15T02:26:21+0900**

## 着手前

```
["\/opt\/homebrew\/bin\/python3.11","\/Users\/ny\/scripts\/weekly-blog-report.py"]
```

## 書き換えた

- 退避: `/Users/ny/Library/LaunchAgents/com.dailyhack.weekly-blog-report.plist.bak-20260915-022621`
- `plutil -insert` の rc: 0

```
["\/opt\/homebrew\/bin\/python3.11","\/Users\/ny\/scripts\/weekly-blog-report.py","--slack"]
```

## 読み直した

- `bootstrap` の rc: 0

### **これが証拠**（rc ではなく状態を見る・ルール 13）

```
-	0	com.dailyhack.weekly-blog-report
```

✅ **載っている。** 次の月曜 08:00 に `--slack` 付きで走る。

## 次の月曜に見ること

- Slack `#fun_reward-hack_blog` にレポートが**届くこと**
- そこに `${ALL_VISITS}` のような**未展開の変数が無いこと**
