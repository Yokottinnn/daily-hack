# Web Analytics の siteTag を確かめる（t062）

## 1) アカウント一覧（id はマスク）
```
name=N-yokota@fieldbeside.com's Account id=72c7f0…d69a
success: True errors: []
```

## 2) Web Analytics のサイト一覧（本当の site_tag）
```
site_tag=73990e5796764bce8626e8706c08ce82  host=fieldbeside.com  auto=True
件数: 1
```

## 3) siteTag で絞らずに RUM を引く（素の合計）
```
期間: 2026-08-30 〜 2026-09-05
siteTag=73990e5796764bce8626e8706c08ce82  pv=10  visits=10
```

## 4) GSC をもう一度（t061 ではネットワークで落ちた）
```
oauth2.googleapis.com http=404 time=0.106111s
```
