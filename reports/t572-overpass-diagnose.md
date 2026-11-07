# t572 Overpass の診断（2026-11-07 23:17:37）

## 小さな問い合わせ（駅 1 か所の周り）
- https://overpass-api.de/api/interpreter → HTTP 406 / 156 bytes
```
  406 Not Acceptable   406 Not Acceptable  nginx    
```
## 状態
```
<html>
<head><title>406 Not Acceptable</title></head>
<body>
<center><h1>406 Not Acceptable</h1></center>
<hr><center>nginx</center>
</body>
</html>

```
## 路線の一覧（https://overpass-api.de/api/interpreter）
- https://overpass-api.de/api/interpreter → HTTP 406 / 156 bytes
```
  406 Not Acceptable   406 Not Acceptable  nginx    
```
## 路線の一覧（https://overpass.kumi.systems/api/interpreter）
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t572-overpass-diagnose.sh: line 8: /Users/ny/.openclaw/ops-heartbeat-wt/reports/.t572.out: No such file or directory
- https://overpass.kumi.systems/api/interpreter → HTTP 000 /  bytes
```

```
## 路線の一覧（https://maps.mail.ru/osm/tools/overpass/api/interpreter）
- https://maps.mail.ru/osm/tools/overpass/api/interpreter → HTTP 504 / 695 bytes
```
 <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> OSM3S Response The data included in this document is from www.openstreetmap.org. The data is made available under ODbL. Error : runtime error: open64: 0 Success /osm3s_osm_base Dispatcher_Client::request_read_and_idx::timeout. The server is probably too busy to handle your request. 
```
## Wikidata（東京の駅と路線・路線の色）
- HTTP 200 / 122 bytes
```
{
  "head" : {
    "vars" : [ "s", "sL", "coord", "line", "lineL", "col" ]
  },
  "results" : {
    "bindings" : [ ]
  }
}
```
