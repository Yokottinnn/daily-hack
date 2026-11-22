# 週次レポート（t061 / IPv4 フォールバックあり）

## 到達性の切り分け
```
-- DNS: api.cloudflare.com --
name: api.cloudflare.com
ipv6_address: 2606:4700:300a::6813:c0b0
ipv6_address: 2606:4700:300a::6813:c01d
ipv6_address: 2606:4700:300a::6813:c0af
ipv6_address: 2606:4700:300a::6813:c0b1
ipv6_address: 2606:4700:300a::6813:c0ae
ipv6_address: 2606:4700:300a::6813:c11d

name: api.cloudflare.com
ip_address: 104.19.192.177
ip_address: 104.19.193.29
ip_address: 104.19.192.29

-- IPv4 だけで叩く（認証なし。401 が返れば到達している）--
http=400 time=1.206239s

-- 既定（IPv6 優先）で叩く --
http=400 time=0.201435s
```

## トークンの検証（Cloudflare の verify エンドポイント）
```
{"result":{"id":"***","status":"active"},"success":true,"errors":[],"messages":[{"code":10000,"message":"This API Token is valid and active","type":null}]}```

# Daily Hack 週次レポート（2026-09-06）

- アクセス: **2026-08-30 〜 2026-09-05**（7 日・Cloudflare Web Analytics）
- 検索: **2026-08-07 〜 2026-09-03**（28 日・Search Console）
  ※ GSC は確定まで 2〜3 日かかるため直近 3 日を除いている

## サマリー

| 指標 | 今回 | 前回比 |
| --- | --- | --- |
| **ページビュー** | 0 |  |
| **訪問（ユニーク）** | 0 |  |
| 検索指標 | ⚠️ 取得失敗 | gcloud の認証に失敗（rc=1）: ERROR: (gcloud.auth.print-access-token) HTTPSConnectionPool(host='oauth2.googleapis.com', port=443) |

## 流入経路

該当なし。

## 人気ページ TOP15（ページビュー順）

| # | PV | 訪問 | 前回比 | ページ |
| --- | --- | --- | --- | --- |

## 検索順位 TOP10（順位の高い順・表示 1 回以上）

⚠️ **取れなかった。** gcloud の認証に失敗（rc=1）: ERROR: (gcloud.auth.print-access-token) HTTPSConnectionPool(host='oauth2.googleapis.com', port=443): Max retries exceeded with url: /token (Caused by NewConnectionError("HTTPSConnection(host='oauth2.googleapis.com', port=443): Failed to establish a new connection: [Errno 65] No route to host"))

## 順位帯ごとの記事数

⚠️ **取れなかった。** gcloud の認証に失敗（rc=1）: ERROR: (gcloud.auth.print-access-token) HTTPSConnectionPool(host='oauth2.googleapis.com', port=443): Max retries exceeded with url: /token (Caused by NewConnectionError("HTTPSConnection(host='oauth2.googleapis.com', port=443): Failed to establish a new connection: [Errno 65] No route to host"))

## 惜しい記事（6〜20 位・表示 5 回以上＝あと一歩で 1 ページ目）

⚠️ **取れなかった。** gcloud の認証に失敗（rc=1）: ERROR: (gcloud.auth.print-access-token) HTTPSConnectionPool(host='oauth2.googleapis.com', port=443): Max retries exceeded with url: /token (Caused by NewConnectionError("HTTPSConnection(host='oauth2.googleapis.com', port=443): Failed to establish a new connection: [Errno 65] No route to host"))

## 順位が動いた記事（前回比）

⚠️ **取れなかった。** gcloud の認証に失敗（rc=1）: ERROR: (gcloud.auth.print-access-token) HTTPSConnectionPool(host='oauth2.googleapis.com', port=443): Max retries exceeded with url: /token (Caused by NewConnectionError("HTTPSConnection(host='oauth2.googleapis.com', port=443): Failed to establish a new connection: [Errno 65] No route to host"))

## 当たり語 TOP20（表示の多い順）

⚠️ **取れなかった。** gcloud の認証に失敗（rc=1）: ERROR: (gcloud.auth.print-access-token) HTTPSConnectionPool(host='oauth2.googleapis.com', port=443): Max retries exceeded with url: /token (Caused by NewConnectionError("HTTPSConnection(host='oauth2.googleapis.com', port=443): Failed to establish a new connection: [Errno 65] No route to host"))

## デバイスと国

該当なし。

## ⚠️ 取れなかったもの

- **Search Console**: gcloud の認証に失敗（rc=1）: ERROR: (gcloud.auth.print-access-token) HTTPSConnectionPool(host='oauth2.googleapis.com', port=443): Max retries exceeded with url: /token (Caused by NewConnectionError("HTTPSConnection(host='oauth2.googleapis.com', port=443): Failed to establish a new connection: [Errno 65] No 

**数字が出ていないまま気づかない状態を作らない**ための節。

---
出典: Cloudflare Web Analytics ／ Google Search Console。LLM 不使用のため API クレジットは消費しない（$0/回・$0/日・$0/月）。

---
t061: 終了コード=`1`
