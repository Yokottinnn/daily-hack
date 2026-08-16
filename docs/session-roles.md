# セッションの役割分担と連携

このリポジトリには役割の違う Claude セッションが複数ある。**どちらが何を担当し、
どこを触ってよく、相手にどう頼むか**をここに固定する。

## なぜ必要か

2026-08-16、ブログ用のセッション（`daily-hack-blog3`）が X 運用の設計書
`docs/x-growth-play.md` を書き換え、同じ時間帯に X 運用側（`daily-hack-tweet2`）も
同じファイルを更新していた。**同じ場所を二重に触り、マージ衝突が 2 回発生した。**

役割が曖昧だと、作業が重複するだけでなく、**どちらの記述が正なのか分からなくなる。**

## 役割

| セッション | 担当 | 典型的な依頼 |
| --- | --- | --- |
| `daily-hack-blog3` | **ブログ記事**の企画・執筆・画像・公開まで | 「〇〇の記事を書いて」「表紙を作って」「リンク切れを直して」 |
| `daily-hack-tweet2` | **X の運用・戦略・自動化** | 「フォロワーを増やす施策」「リプライ運用」「投稿ジョブの設計」 |

判断に迷ったら、**成果物が「記事」なら blog3、「X 上の動き」なら tweet2。**

## 所有権（どちらが触ってよいか）

| 対象 | 所有 |
| --- | --- |
| `src/**` / `public/**` / `assets/**` / `data/`（記事データ） | blog3 |
| `scripts/gen-*.py` / `render-*.mjs` / `*eyecatch*` / `generate-thumbnail.mjs` | blog3 |
| `docs/seo-monitoring.md` / `docs/analytics/` | blog3 |
| `docs/x-growth-play.md` / `docs/recurring-job-costs.md` / `docs/ops-watchdog.md` | tweet2 |
| `scripts/generate-tweet.mjs` / `scripts/social/` / `scripts/seo-submit.mjs` | tweet2 |
| OpenClaw の実体（`~/.openclaw/**`・launchd ジョブ・plist） | tweet2 |
| `CLAUDE.md` / `.claude/hooks/` / `docs/session-*.md` | **共有** |

**所有していない場所を直したくなったら、自分で直さず依頼を出す。** 気づいたこと自体は
価値があるので、黙って見送るのではなく次項の依頼表に書く。

共有ファイルを触るときは、**必ず `git pull` してから**。今日 2 回衝突したのは、
相手が同じ時間に同じファイルを更新していることに気づかなかったため。

## 連携の経路

**2 つのセッションは直接会話できない。** クラウド同士でメッセージを送る手段が無く、
片方が止まっていても相手からは分からない。**確実に届くのは Git にコミットされたファイルだけ**
（最上位ルール 3）。会話の中で合意しても、環境が消えれば残らない。

依頼は [`docs/cross-session-requests.md`](./cross-session-requests.md) に書く。

| 手順 | やること |
| --- | --- |
| 依頼する | 依頼表の先頭に 1 行足して push する。**宛先・依頼内容・判断に必要な材料**を書く |
| 受け取る | セッション開始時に依頼表を読む。`未対応` で自分宛のものが自分の仕事 |
| 完了する | 状態を `完了` にし、結果（PR 番号・URL・実測値）を書いて push する |
| 断る | 消さずに `見送り` にして理由を書く。**判断の記録も資産である** |

**相手が動いたかどうかは、相手の報告ではなくファイルの状態で判断する。**

## いちばん多い連携: 記事公開 → X 告知

境界は **「公開 URL が確定した時点」**。ここより前が blog3、後が tweet2。

1. **blog3**: 記事を書いて PR → `main` にマージ → 公開 URL 確定
2. **blog3**: 依頼表に告知依頼を書く。**記事 URL・要点 3 つ・画像のパス**を添える
3. **tweet2**: `node scripts/generate-tweet.mjs <slug>` で草案を作り、Slack へ出す
4. **Jordan の 👍 を待つ**（承認前に投稿しない・最上位ルール 4）
5. **OpenClaw** が X に投稿する
6. **tweet2**: 投稿 URL を依頼表に書いて `完了` にする

**blog3 は 3 以降をやらない。** 逆に tweet2 は記事本文を書き換えない。

## 引き継ぎメモの扱い

[`docs/session-handoff.md`](./session-handoff.md) は両方が使う共有ファイル。衝突を避けるため。

- **「セッション記録」は追記のみ。** `npm run handoff -- "やったこと" --next "次にやること"` を使う。
- **冒頭の「現在の状態／進行中の作業／次のアクション」は、その領域の所有者だけが書き換える。**
  X 運用の記述は tweet2、記事の記述は blog3。相手の領域の記述が古いと気づいたら、
  直接直さず依頼表に書く。
- 書く前に `git pull`。

## 他のセッションが使っている経路を、勝手に畳まない

`~/.openclaw/`・launchd・実ブラウザに触れるのは **Mac 上の bridge セッション**だけで、
クラウドの blog3 / tweet2 からは SSH が届かない（2026-08-11 に実測・`session-recovery.md`）。
**この口は blog3 のものではなく、X 運用の実行経路として tweet2 が使う。**

### 2026-08-16 の失敗: 生きているセッションをアーカイブした

blog3 が `daily-hack-blog2` をアーカイブした。**そのセッションは生きており、
tweet2 が「OpenClaw 復活 + git pull」の依頼を投げる先として使おうとしていた。**
承認待ちのトリガーの宛先が、まさにアーカイブしたセッションだった。

誤判断の原因は **返事を探す窓を間違えたこと**。

| 見た窓 | 結果 |
| --- | --- |
| Slack `C0A5FKU7T5M` | 8/15 16:40 JST を最後に沈黙 → 「死んでいる」と判断 |
| **GitHub の PR** | **#170・#171・#173・#174 が届いていた＝生きていた** |

**「Slack に来ていない」は「応答していない」ではない。** Mac 側のセッションは PR で返す。
沈黙していたのは OpenClaw の Slack 経路だけで、セッション本体は動いていた。

### だから、こう判断する

- **止める・畳む前に、他のセッションがそれを使っていないか確認する。**
  `list_sessions` で相手の `pending_action` を見れば、何を待っているか分かる。
- **生死の判定は複数の窓で行う。** Slack・GitHub の PR / commit・`ops/heartbeat` の push。
  ひとつが静かでも死んだ証拠にならない。
- **セッション一覧の `connected` / `updated_at` は根拠にならない**（認証失効中でもそう見える）。
- アーカイブしても会話は失われない（`claude --resume <会話ID>`／`unarchive`）。
  ただし**失われないことと、畳んでよいことは別**である。

`daily-hack-blog2` の会話 ID は `7d5942fa-f5b8-4d5d-b1f9-ef8574d48450`、
書き出したログは `session-log/blog2` の `docs/session-logs/blog2.md`。

## 関連

- [`docs/cross-session-requests.md`](./cross-session-requests.md) — セッション間の依頼表
- [`docs/session-handoff.md`](./session-handoff.md) — 現況と作業履歴
- [`docs/session-log-export.md`](./session-log-export.md) — 相手セッションの会話ログを読む手段
- [`docs/urgent-request-protocol.md`](./urgent-request-protocol.md) — 緊急依頼の扱い
