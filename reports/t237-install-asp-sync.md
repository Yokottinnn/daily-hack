# ASP の同期ジョブを入れる（t237・**$0**）

生成: **2026-10-06T00:05:37+0900**

## 1) Keychain の登録

| ASP | サービス名 | 登録 |
| --- | --- | --- |
| a8 | `dailyhack-asp-a8` | 無い |
| moshimo | `dailyhack-asp-moshimo` | 無い |
| vc | `dailyhack-asp-vc` | 無い |
| rakuten | `dailyhack-asp-rakuten` | 無い |

## 2) ジョブ

- ラベル: `com.dailyhack.asp-sync`（毎週 月曜 06:12）
- 状態: **載った**（launchctl print が通る）
- node: `/opt/homebrew/bin/node`

## 3) 1 回目の結果

```text
a8: ログイン済み
moshimo: ログインできていない / ログインしていない。Keychain に ID・パスワードが無い
vc: ログインできていない / ログインしていない。Keychain に ID・パスワードが無い
rakuten: ログイン済み / 楽天ID 0 件
```

- 詳細: `reports/asp-sync/`（status.json と ASP ごとの md）
rc=0 /      913 bytes
