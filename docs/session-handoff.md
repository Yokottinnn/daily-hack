# セッション引き継ぎメモ

> **このファイルは Git にコミットされる。** セッションや実行環境（コンテナ／ブリッジ）が
> 消えても内容は残るため、新しいセッションはここから状況を復元できる。
>
> 新セッション開始時に `.claude/hooks/session-start.sh` が自動でこの内容を読み込む。
> 作業を終える前に `npm run handoff -- "やったこと" --next "次にやること"` で記録を追加すること。

## 現在の状態

- 本番ブログ（Astro）は `main` から Cloudflare Pages にデプロイされる。
- 直近のリリースは `#159`（アウトレット記事の表紙とタイルのリンク切れ修正）まで完了。

## 進行中の作業

**ららぽーとガイド 2026 の X 投稿**が止まっている。経路は
「ランキング画像を Slack に添付 → Jordan の 👍 → OpenClaw が X 投稿」。

- 画像は `main` にある: `assets/social/lalaport-guide-2026/ranking-top10.png`（2400×2400）。
- 8/11 に Slack で OpenClaw にアップロードを依頼済み。旧依頼はコミット指定が無効だったため訂正済み。

## 次のアクション

- [ ] OpenClaw が `main` から画像を Slack にアップロードしたか確認する。
- [ ] アップロードされたら Jordan の 👍 を得る。👍 の前に X へ投稿しない。
- [ ] `poll-approvals` が実際にロードされたかを `launchctl list` で確認する。

## 決定事項・注意点

- **セッションが「もう会話できません」になった場合**、会話履歴は失われていない。
  原因はセッション本体ではなく実行環境の消滅であり、復旧手順は
  [`docs/session-recovery.md`](./session-recovery.md) にまとめてある。

- **クラウドセッションから Mac へは SSH で届かない。** ssh 未インストール・鍵なし・
  生 TCP が出られない（2026-08-11 に実測）。OpenClaw を触るときは Mac で `claude` を
  起動して `/remote-control` で公開する。

- **リポジトリのパスは `/Users/ny/projects/anta-baka-x/blog`。** ディレクトリ名が
  `daily-hack` ではないため、名前で検索しても見つからない。

- **OpenClaw の MUST rule の実体は `~/.claude/projects/-Users-ny--openclaw-workspace/memory/`。**
  `~/.openclaw/workspace/memory/` ではない。場所を間違えると、有るのに「無い」とも、
  無いのに「有る」とも報告しうる。詳細は
  [`docs/openclaw-recovery.md`](./openclaw-recovery.md) を参照。

- **ログが動いても「ジョブが復活した」証拠にならない。** listener が生きているため、
  未ロードのまま同じログに書き込まれることがある。判定は `launchctl list` で行う。

<!-- session-log:start -->
## セッション記録

<!-- 新しい記録がこの下に追加される（新しいものが上） -->

### 2026-08-13 — OpenClaw 停止の原因を実機で特定（ジョブ未ロード／握り潰された空例外）。誤った前提3件を撤回し記録を訂正。画像の場所をSlackで訂正

次のアクション:

- [ ] OpenClaw が main から画像をアップロードするか確認し、👍 を得てから X 投稿
### 2026-08-11 — ダイアログ回避（検知語の言い換え）を塞ぎ両リポジトリに反映。OpenClaw 復旧手順を docs 化

次のアクション:

- [ ] home-mac で docs/openclaw-recovery.md の手順を実行し、MUST rule 復元→画像添付→👍→X投稿

### 2026-08-11 — ダイアログ強制の拡張を両リポジトリに反映（daily-hack #152 / bubblesnow #2 をマージ）

次のアクション:

- [ ] home-mac 復旧後に OpenClaw が画像を Slack へ添付し、承認を得て X へ投稿

### 2026-08-11 — ダイアログ強制を「疑問符」だけでなく「次の一手の提示」まで拡張。本文で残件を並べる形の見逃しを回帰テスト化

### 2026-08-11 — API課金ルールを「禁止」から「見積もり→提示→許可」の運用に修正。誤検知バグを修正し BubblesNow にも移植

次のアクション:

- [ ] BubblesNow の PR をレビューしてマージ

### 2026-08-11 — API課金の事前確認を最上位ルール2として記録し、PreToolUseフックで強制（テスト20件）

### 2026-08-11 — SessionStart フックの注入を要約のみに変更（履歴を除外、61%削減）。追記でキャッシュが失効する構造を解消

### 2026-08-11 — OpenClaw 不具合の原因を特定: 8/10 09:00 に MUST rule 7件が消失し復元失敗。verify_external_state_before_claiming が失われたことが虚偽報告の原因

次のアクション:

- [ ] home-mac で MUST rule を復元（旧ミラー MEMORY-MUST-MIRROR.md を確認）
- [ ] spawnSync ETIMEDOUT の解消と launchd ジョブの生存確認
- [ ] OpenClaw 復旧後に画像添付→承認→X投稿

### 2026-08-11 — OpenClaw の画像アップロード完了報告が虚偽と判明（f5771c7 はリモートに無く、スレッドに添付も無い）。Slackで訂正投稿

次のアクション:

- [ ] OpenClaw が実ファイルを添付するまで 👍 を出さない
- [ ] 添付されない場合は別の受け渡し手段を検討

### 2026-08-11 — Slack操作を全面許可。settings.json に mcp__Slack__* を登録し CLAUDE.md にも記録

### 2026-08-11 — 指定フォーマット（親＋[n/N]返信）でX投稿草案をSlackに再送。旧投稿には無視する旨を追記

次のアクション:

- [ ] OpenClaw の画像アップを待ち、Jordan の 👍 を得る

### 2026-08-11 — ランキング画像の共有依頼をSlackに新規投稿（OpenClawにアップロード依頼／承認前のX投稿を禁止と明記）

次のアクション:

- [ ] OpenClaw が画像をアップしたら Jordan の 👍 を待つ
- [ ] 👍 後に OpenClaw が X へ投稿

### 2026-08-11 — ランキング画像はX投稿用と確認。公開される public/ から assets/social/ へ退避（記事は未変更）

次のアクション:

- [ ] OpenClaw に画像アップを依頼して承認を得る
- [ ] 承認後 OpenClaw が X に投稿

### 2026-08-11 — 全国マップ画像は不要との判断により削除。SNS画像は売上ランキング1枚に確定

次のアクション:

- [ ] ランキング画像1枚をSlackで共有し承認を得る
- [ ] 承認後 OpenClaw に X 投稿を依頼

### 2026-08-11 — ランキング画像に公式ららぽーとロゴを右上配置（提供素材を余白除去して使用）

### 2026-08-11 — 依頼された2枚（売上ランキング正方形／全国マップ）を作成しブランチに保存

次のアクション:

- [ ] Slackへの共有方法を決める（リポジトリ経由で公開URL化 or チャット確認のみ）
- [ ] 承認後に OpenClaw へ X 投稿を依頼

### 2026-08-10 — 選択肢をダイアログで出すルールをフックで強制する仕組みを追加（予防＋差し戻しの二層、テスト12件）

### 2026-08-10 — OpenClaw 連携の前提（X 投稿は OpenClaw 経由・Slack 確認フロー）を CLAUDE.md に復元

### 2026-08-10 — Slack コネクタが Taxa ワークスペースに接続されており fieldbeside を読めないことが判明

次のアクション:

- [ ] Slack コネクタを fieldbeside.slack.com で認証し直す
- [ ] 認証後、依頼された画像の要件をスレッドから読み取って作成する
- [ ] 画像を Slack に投稿し、確認を得てから X に投稿する

### 2026-08-10 — 選択肢はダイアログで出すルールを CLAUDE.md の最上位に記録

### 2026-08-10 — セッション断絶に備えた引き継ぎ機構を追加

次のアクション:

- [ ] MOP記事の扱いを決める
- [ ] 決定後に記事を作成しビルド確認

### 2026-08-10 — 環境消滅によるセッション断絶への対応

- `daily-hack-tweet` / `daily-hack-blog` セッションが `environment_deleted` で操作不能になった。
  いずれも `environment_kind: bridge`（ローカル CLI を Remote Control で Web に公開したもの）。
- 会話履歴自体はローカルの `~/.claude/projects/` に残るため、`claude --resume` で継続可能。
- 再発対策として、この引き継ぎファイルと SessionStart フックを追加した。
- 消滅時点で判明していた各セッションの状態:
  - `daily-hack-tweet`: 「draft resent; auto-recovery enabled, notifications hardened」
  - `daily-hack-blog`: 「badge text color fixed; white now renders on prod」
  - `daily-hack-blog`（別セッション）: MOP 記事の扱いを問う質問で停止中

<!-- session-log:end -->
