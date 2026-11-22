# Safari（WebKit）でチェックリストの崩れを測る（t774・$0）

**このレポートが作られた時刻: 2026-11-22 00:27:30 JST**

- macOS: 26.3.1 / Safari: 26.3.1 / safaridriver: /usr/bin/safaridriver
- WebKit（Playwright）: /Users/ny/Library/Caches/ms-playwright/webkit-2336 

node --check rc=0 
rc=0 / 69 秒

測り方: **Playwright の WebKit（iPhone 13 を再現）**

対象 21 本 / 測れた 20 本 / **崩れのある記事 0 本**

画面の幅 390px / :has が使える true / UA Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E1

| 記事 | 項目 | 包んだ項目 | 崩れ |
| --- | --- | --- | --- |
| alvark-tokyo-toyosu-events-2026-11 | エラー page.goto: Timeout 25000ms exceeded.
Call log:
  - navigating to "https://daily- |  |  |
| ariake-garden-events-2026-11-late | 4 | 4 | 0 |
| ariake-garden-parenting-events-2026-11 | 5 | 5 | 0 |
| cruise-expo-tokyo-2026 | 4 | 4 | 0 |
| doubletree-ariake-strawberry-afternoon-tea-2026 | 4 | 4 | 0 |
| gli-harumi-steam-event-2026 | 4 | 4 | 0 |
| hero-prime-international-school-tsukiji-2027 | 5 | 5 | 0 |
| hotel-villa-fontaine-ariake-winter-buffet-2026 | 3 | 3 | 0 |
| kyo-hayashiya-harumi-christmas-cake-2026 | 4 | 4 | 0 |
| minivelo-meet-ariake-2026 | 3 | 3 | 0 |
| penthouse-toyosu-afternoon-tea-2026 | 3 | 3 | 0 |
| pma-tokyo-vol11-bigsight-2026 | 3 | 3 | 0 |
| sakana-japan-festival-odaiba-2026 | 4 | 4 | 0 |
| shutoko-futures-lalaport-toyosu-2026 | 4 | 4 | 0 |
| tokyo-christmas-market-lighting-2026 | 3 | 3 | 0 |
| tokyo-culture-debut-park-toyosu-2026 | 5 | 5 | 0 |
| tokyobay-light-wish-odaiba-2026 | 8 | 4 | 0 |
| toyosu-senkyakubanrai-december-events-2026 | 5 | 5 | 0 |
| toyota-arena-tokyo-winter-light-2026 | 3 | 3 | 0 |
| tsukiji-jogai-year-end-fukubiki-2026 | 4 | 4 | 0 |
| tsukiji-redevelopment-update-2026-11 | 3 | 3 | 0 |
