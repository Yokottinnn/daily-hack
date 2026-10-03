# X の Grok で手を振る動画を作る（2026-10-03 17:07 JST・$0）

**このレポートが作られた時刻: 2026-10-03 17:07:07 JST**

> **投稿しない。** Grok の中で作るだけ。API は呼ばない（$0／回・$0／日・$0／月）。

```
  入力画像 347439 bytes
  node --check rc=0 
  rc=0 / かかった秒数 253
  x208-01-open.png（56347 bytes）
  x208-02-video-mode.png（58274 bytes）
  x208-03-uploaded.png（79242 bytes）
  x208-04-prompt.png（104887 bytes）
  x208-05-timeout.png（143830 bytes）
```

## 結果

- 同意を押した: false ／ 動画ボタン: true ／ 押したあとの入力欄: どんなことでもお尋ねください /  ／ 添付欄: 画像専用 ／ 画像を添付: true ／ 送信: button
- 動画の src: **出てこなかった** ／ 保存: **できていない**

## 段階ごとの画面と UI

### open（11 秒・`x208-01-open.png`）

```
URL: https://x.com/i/grok
ボタン: キーボードショートカットを表示 | ホームタイムラインに移動 | トレンドに移動 | X | ホーム | 調べたいものを検索 | 通知 | ダイレクトメッセージ | Grok | 履歴 | クリエイタースタジオ | プレミアム | プロフィール | その他のメニュー項目 | ポストする | アカウントメニュー | フォーカスモード | チャット履歴 | 非公開 | 口座を連携 | 新しいポストがあります。新しいポストに移動するには、ピリオドキーを押してください | 高速 | 音声モードに入る | 動画を作成 | 画像を作成 | 画像を編集 | 最新ニュース | Grokに話しかける grok.comにアクセスするとさらに多くの機能が利用でき | もっと見る
ファイル入力: ["image/jpeg,image/png,image/webp,application/pdf,text/plain,text/xml,text/csv,text/markdown,text/x-markdown,text/md,text/calendar,text/vcard,text/json,text/yaml,text/x-python,text/x-csrc,text/x-c++src,text/x-csharp,text/x-ruby,text/x-java-source,text/x-go,text/x-rust,text/x-swift,text/x-kotlin,text/x-sql,text/x-lua,text/x-scala,text/x-haskell,text/x-php,text/x-perl,text/x-shellscript,text/x-rsrc,text/x-dart,application/markdown,application/xml,application/json,application/x-yaml,application/x-latex,application/x-sh,application/x-msdownload,application/x-httpd-php,application/sql,application/dicom,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","image/jpeg,image/webp,image/png"]
入力欄: ["どんなことでもお尋ねください","TEXTAREA"]
動画: []
```

### video-mode（15 秒・`x208-02-video-mode.png`）

```
URL: https://x.com/i/grok
ボタン: キーボードショートカットを表示 | ホームタイムラインに移動 | トレンドに移動 | X | ホーム | 調べたいものを検索 | 通知 | ダイレクトメッセージ | Grok | 履歴 | クリエイタースタジオ | プレミアム | プロフィール | その他のメニュー項目 | ポストする | アカウントメニュー | フォーカスモード | チャット履歴 | 非公開 | 口座を連携 | 新しいポストがあります。新しいポストに移動するには、ピリオドキーを押してください | 高速 | 音声モードに入る | 動画を作成 | 画像を作成 | 画像を編集 | 最新ニュース | Grokに話しかける grok.comにアクセスするとさらに多くの機能が利用でき | もっと見る
ファイル入力: ["image/jpeg,image/png,image/webp,application/pdf,text/plain,text/xml,text/csv,text/markdown,text/x-markdown,text/md,text/calendar,text/vcard,text/json,text/yaml,text/x-python,text/x-csrc,text/x-c++src,text/x-csharp,text/x-ruby,text/x-java-source,text/x-go,text/x-rust,text/x-swift,text/x-kotlin,text/x-sql,text/x-lua,text/x-scala,text/x-haskell,text/x-php,text/x-perl,text/x-shellscript,text/x-rsrc,text/x-dart,application/markdown,application/xml,application/json,application/x-yaml,application/x-latex,application/x-sh,application/x-msdownload,application/x-httpd-php,application/sql,application/dicom,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","image/jpeg,image/webp,image/png"]
入力欄: ["どんなことでもお尋ねください","TEXTAREA"]
動画: []
```

### uploaded（21 秒・`x208-03-uploaded.png`）

```
URL: https://x.com/i/grok
ボタン: キーボードショートカットを表示 | ホームタイムラインに移動 | トレンドに移動 | X | ホーム | 調べたいものを検索 | 通知 | ダイレクトメッセージ | Grok | 履歴 | クリエイタースタジオ | プレミアム | プロフィール | その他のメニュー項目 | ポストする | アカウントメニュー | フォーカスモード | チャット履歴 | 非公開 | 口座を連携 | 新しいポストがあります。新しいポストに移動するには、ピリオドキーを押してください | 高速 | Grokに聞く | Grokに話しかける grok.comにアクセスするとさらに多くの機能が利用でき | もっと見る
ファイル入力: ["image/jpeg,image/png,image/webp,application/pdf,text/plain,text/xml,text/csv,text/markdown,text/x-markdown,text/md,text/calendar,text/vcard,text/json,text/yaml,text/x-python,text/x-csrc,text/x-c++src,text/x-csharp,text/x-ruby,text/x-java-source,text/x-go,text/x-rust,text/x-swift,text/x-kotlin,text/x-sql,text/x-lua,text/x-scala,text/x-haskell,text/x-php,text/x-perl,text/x-shellscript,text/x-rsrc,text/x-dart,application/markdown,application/xml,application/json,application/x-yaml,application/x-latex,application/x-sh,application/x-msdownload,application/x-httpd-php,application/sql,application/dicom,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","*","*","*","*"]
入力欄: ["どのように画像を編集しますか？","TEXTAREA"]
動画: []
```

### prompt（22 秒・`x208-04-prompt.png`）

```
URL: https://x.com/i/grok
ボタン: キーボードショートカットを表示 | ホームタイムラインに移動 | トレンドに移動 | X | ホーム | 調べたいものを検索 | 通知 | ダイレクトメッセージ | Grok | 履歴 | クリエイタースタジオ | プレミアム | プロフィール | その他のメニュー項目 | ポストする | アカウントメニュー | フォーカスモード | チャット履歴 | 非公開 | 口座を連携 | 新しいポストがあります。新しいポストに移動するには、ピリオドキーを押してください | 高速 | Grokに聞く | Grokに話しかける grok.comにアクセスするとさらに多くの機能が利用でき | もっと見る
ファイル入力: ["image/jpeg,image/png,image/webp,application/pdf,text/plain,text/xml,text/csv,text/markdown,text/x-markdown,text/md,text/calendar,text/vcard,text/json,text/yaml,text/x-python,text/x-csrc,text/x-c++src,text/x-csharp,text/x-ruby,text/x-java-source,text/x-go,text/x-rust,text/x-swift,text/x-kotlin,text/x-sql,text/x-lua,text/x-scala,text/x-haskell,text/x-php,text/x-perl,text/x-shellscript,text/x-rsrc,text/x-dart,application/markdown,application/xml,application/json,application/x-yaml,application/x-latex,application/x-sh,application/x-msdownload,application/x-httpd-php,application/sql,application/dicom,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","*","*","*","*"]
入力欄: ["どのように画像を編集しますか？","TEXTAREA"]
動画: []
```

### timeout（252 秒・`x208-05-timeout.png`）

```
URL: https://x.com/i/grok?conversation=2106295059071279517
ボタン: キーボードショートカットを表示 | ホームタイムラインに移動 | トレンドに移動 | X | ホーム | 調べたいものを検索 | 通知 | ダイレクトメッセージ | Grok | 履歴 | クリエイタースタジオ | プレミアム | プロフィール | その他のメニュー項目 | ポストする | アカウントメニュー | フォーカスモード | 共有リンクをコピー | ブックマーク | チャット履歴 | 口座を連携 | 新しいチャット | 新しいポストがあります。新しいポストに移動するには、ピリオドキーを押してください | 再生成 | テキストをコピー | 共有 | いいね | 好きではない | Learn about AI video generation models | Generate the static image | Make her smile more | 高速 | 音声モードに入る
ファイル入力: ["image/jpeg,image/png,image/webp,application/pdf,text/plain,text/xml,text/csv,text/markdown,text/x-markdown,text/md,text/calendar,text/vcard,text/json,text/yaml,text/x-python,text/x-csrc,text/x-c++src,text/x-csharp,text/x-ruby,text/x-java-source,text/x-go,text/x-rust,text/x-swift,text/x-kotlin,text/x-sql,text/x-lua,text/x-scala,text/x-haskell,text/x-php,text/x-perl,text/x-shellscript,text/x-rsrc,text/x-dart,application/markdown,application/xml,application/json,application/x-yaml,application/x-latex,application/x-sh,application/x-msdownload,application/x-httpd-php,application/sql,application/dicom,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]
入力欄: ["どんなことでもお尋ねください","TEXTAREA"]
動画: []
```


**投稿していない。API を呼んでいない（$0／回・$0／日・$0／月）。**
