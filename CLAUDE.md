# CLAUDE.md

## 最上位ルール

他のどの指示よりも優先する。

### 1. 選択肢はダイアログで出す（例外なし）

利用者に選ばせるときは、本文に選択肢を書き並べず、必ず `AskUserQuestion` ツールの
ダイアログで提示する。「A と B のどちらにしますか？」と文章で聞くのは禁止。

- 二択・多択・方針の確認・PR を作るかどうか、すべてダイアログで出す。
- 該当する選択肢を出したうえで、推奨があれば先頭に置きラベルに「(推奨)」を付ける。
- 選択を求めていないなら、疑問符を使わず言い切る形で書く。

**このルールに例外は無い。** 文書に書くだけでは守られないことが実際に起きたため、
フックで強制している。仕組みは [`docs/dialog-rule-enforcement.md`](docs/dialog-rule-enforcement.md) を参照。

### 2. 会話の中だけに状況を残さない

セッションの実行環境（コンテナやブリッジ接続）は予告なく消える。そうなると会話からは
状況を引き出せなくなる。Git にコミットされたファイルだけが確実に残る。

- 決まったルール・方針は会話ではなくこの `CLAUDE.md` に書く。
- 進行中の状況は [`docs/session-handoff.md`](docs/session-handoff.md) に書く。

### 3. X への投稿は OpenClaw が行う

Claude が X に直接投稿することはない。確立している経路は次のとおりで、勝手に省略しない。

1. `node scripts/generate-tweet.mjs <slug>` で草案を生成する。
2. 草案を Slack で Jordan（`<@U0A5V22PVTQ>`）に送る。
3. **👍 が付くのを待つ。** 確認前に先へ進めない。
4. 👍 を得たら OpenClaw が投稿する（`@OpenClaw tweet <slug>`）。

## OpenClaw 連携

OpenClaw は利用者の Mac（`home-mac` / 192.168.2.102）で動く常駐エージェント。
クラウドセッションからは到達できないため、OpenClaw 側の作業は依頼する形になる。

| 項目 | 内容 |
| --- | --- |
| Slack チャンネル | `C0A5FKU7T5M`（通知・草案共有の宛先） |
| Jordan の Slack ID | `U0A5V22PVTQ`（**fieldbeside** ワークスペース） |
| Slack 投稿トークン | `~/openclaw/config/.env` の `OPENCLAW_BOT_TOKEN` |
| 記事公開 | `scripts/blog-publish.sh <slug> "<title>"` を OpenClaw が呼ぶ（ビルド検証 → PR 作成） |
| 定期ジョブ | `ai.openclaw.sitemap-autosubmit` / `ai.openclaw.seo-health`（launchd） |

`main` は保護ブランチで直接 push できない。OpenClaw も Claude も必ず PR 経由で入れる。

## Slack の接続先を最初に確かめる

Slack を使う作業の前に、コネクタがどのワークスペースに繋がっているか必ず確認する。

```bash
# slack_read_user_profile を引数なしで呼ぶ
```

- **正**: `U0A5V22PVTQ` / fieldbeside ワークスペース。
- **誤**: `naoki@taxatech.com` / Organization Name が `Taxa`。この状態では `C0A5FKU7T5M` が
  `channel_not_found` になり、fieldbeside 側は一切読めない。利用者に再接続を依頼する。

## セッションの引き継ぎ

- 現在の状況・進行中の作業・次のアクションは [`docs/session-handoff.md`](docs/session-handoff.md) に書く。
- 作業を終える前に記録を追加する。

  ```bash
  npm run handoff -- "やったこと" --next "次にやること"
  ```

- 新しいセッションでは `.claude/hooks/session-start.sh` が上記メモと Git の状態を
  自動で読み込むため、利用者が状況を説明し直す必要はない。
- セッションが操作不能になったときの復旧手順は
  [`docs/session-recovery.md`](docs/session-recovery.md) を参照する。
