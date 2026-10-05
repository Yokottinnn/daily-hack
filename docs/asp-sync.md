# ASP の同期（アフィリエイトリンクを自分で取れる状態を保つ）

> 利用者: 「以降どんな場合でも、ちゃんとあなた自身で A8 やバリューコマースを使えるようにしてほしい。
> その場しのぎのやり方になってない？」（2026-10-05）

**記事にアフィリエイトリンクを貼るとき、ログインを利用者に頼まない。** そのための仕組み。

## 何が動いているか

| もの | どこ | 役目 |
| --- | --- | --- |
| `scripts/asp/asp-sync.mjs` | repo（Mac は毎回 `origin/main` から取り出す） | 各 ASP を開き、切れていたら Keychain で入り直し、提携中の広告を書き出す |
| `com.dailyhack.asp-sync` | Mac の launchd（**毎週 月曜 06:12**） | 上を週 1 で走らせる。入れたのは `ops/tasks/t237` |
| `reports/asp-sync/` | `ops/heartbeat` ブランチ | `status.json`（ログイン状態）と ASP ごとの md。**クラウドからはここを読む** |
| Keychain `dailyhack-asp-<id>` | Mac | ID・パスワード。**repo にも報告にも出さない** |

対象: `a8`（A8.net）・`moshimo`（もしもアフィリエイト）・`vc`（バリューコマース）・`rakuten`（楽天アフィリエイト）。

費用は **$0**（LLM を呼ばない）。`docs/recurring-job-costs.md` に載せてある。

## 利用者が 1 回だけやること（Mac のターミナル）

1 行ずつ打つ。**最後の `-w` で、パスワードを打つ欄が出る**（画面に表示されず、履歴にも残らない）。

```bash
security add-generic-password -U -s dailyhack-asp-a8      -a 'A8のログインID' -w
security add-generic-password -U -s dailyhack-asp-moshimo -a 'もしものログインID' -w
security add-generic-password -U -s dailyhack-asp-vc      -a 'バリューコマースのログインID' -w
security add-generic-password -U -s dailyhack-asp-rakuten -a '楽天ID' -w
```

## 止まるところ（自分では越えない）

| 状況 | `status.json` | どうする |
| --- | --- | --- |
| 二段階認証・画像認証が出た | `needsHuman: true` | 利用者に Mac の Chrome で 1 回 通してもらう。**突破しようとしない** |
| Keychain が無い／値が違う | `loggedIn: false` と理由 | 利用者に上の登録をお願いする |
| 新しい広告と提携したい | — | **提携申請は広告主の審査**。申請先を一覧にして利用者に渡す |

## 記事に貼るとき

1. `git show origin/ops/heartbeat:reports/asp-sync/status.json` でログイン状態を見る
2. `reports/asp-sync/<id>.md` で提携中の広告とメニュー URL を見る
3. 既に取れているリンクは `src/data/banner-catalog.ts`（A8）・`src/data/referrals.ts`（紹介）にある
4. 楽天は `reports/asp-sync/rakuten.md` の**アフィリエイト ID**で、楽天ウェブサービスの API からも商品リンクを作れる
