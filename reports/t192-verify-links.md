# リンクの死活を取り直す ＋ 実ブラウザで裏を取る（t192・**$0**）

生成: **2026-09-27T15:00:12+0900**

**curl の判定だけで「切れている」と書かない**（最上位ルール 11）。
t191 では **生きているサイトが 404 として並んだ**（WAF が bot に返していた）。

## ① curl で全件（抽出を直した版）

```
対象 1010 件 / 済 0 件 / これから 1010 件

**切れている**: 37
OK: 917
つながらない: 34
サーバ側のエラー: 4
弾かれた（生死は不明）: 18

**切れている** 404  https://docomo-cycle.jp/tokyo-bikeshare/
    ← mobility-cost-per-km-2026
**切れている** 404  https://event.rakuten.co.jp/furusato/guide/simulator/
    ← furusato-tax-beginner-guide-2026
**切れている** 404  https://kakakumag.com/money/?id=20897
    ← point-service-complete-guide-2026
**切れている** 404  https://looop.co.jp/denki/
    ← electricity-gas-savings-2026
**切れている** 404  https://mst.monex.co.jp/mst/servlet/ITS/fx/
    ← fx-account-comparison-2026
**切れている** 404  https://news.yahoo.co.jp/articles/c21c95237e5e9bd4f3e0fe21a319c9e3fe9e6ef4
    ← furusato-tax-beginner-guide-2026
**切れている** 404  https://travel.yahoo.co.jp/dir-00000070/
    ← summer-cospa-travel-2026
**切れている** 404  https://travel.yahoo.co.jp/dir-00000998/
    ← summer-cospa-travel-2026
**切れている** 404  https://travel.yahoo.co.jp/dir-00003354/
    ← summer-cospa-travel-2026
**切れている** 404  https://travel.yahoo.co.jp/h/?keyword=%E6%9D%89%E4%B9%83%E4%BA%95
    ← summer-cospa-travel-2026
**切れている** 404  https://www.amazon.co.jp/b?node=5961517051
    ← hoso-daigaku-gakuwari-2026
**切れている** 404  https://www.ana.co.jp/ja/jp/amc/reference/anamile/pocket/
    ← walk-poikatsu-2026
**切れている** 404  https://www.ana.co.jp/ja/jp/guide/ana-pocket/
    ← walk-poikatsu-2026
**切れている** 404  https://www.bang.co.jp/auto/
    ← car-insurance-comparison-2026
**切れている** 404  https://www.bang.co.jp/insurance/
    ← car-insurance-comparison-2026
**切れている** 404  https://www.click-sec.com/corp/fx/
    ← fx-account-comparison-2026
**切れている** 404  https://www.eneos.co.jp/citygas/
    ← electricity-gas-savings-2026
**切れている** 404  https://www.eneos.co.jp/denki/
    ← electricity-gas-savings-2026
**切れている** 404  https://www.furusato-tax.jp/
    ← furusato-tax-beginner-guide-2026
**切れている** 404  https://www.furusato-tax.jp/about/easy_simulation
    ← furusato-tax-beginner-guide-2026
**切れている** 404  https://www.ikea.com/jp/ja/cat/cushion-covers-20535/
    ← ikea-toyosu-2026
**切れている** 404  https://www.ikea.com/jp/ja/cat/cushions-cushion-covers-18749/
    ← ikea-toyosu-2026
**切れている** 404  https://www.ikea.com/jp/ja/cat/stools-benches-20655/
    ← ikea-toyosu-2026
**切れている** 404  https://www.ikea.com/jp/ja/p/raskog-trolley-black-70517477/
    ← ikea-toyosu-2026
**切れている** 404  https://www.ikea.com/jp/ja/p/risatorp-basket-white-10221101/
    ← ikea-toyosu-2026
**切れている** 404  https://www.jalan.net/uw/uwp3500/uww3551.do
    ← summer-cospa-travel-2026
**切れている** 404  https://www.lucidchart.com/pages/ja/education
    ← hoso-daigaku-gakuwari-2026
**切れている** 404  https://www.lucidchart.com/pages/ja/pricing
    ← hoso-daigaku-gakuwari-2026
**切れている** 404  https://www.matsui.co.jp/service/fx/
    ← fx-account-comparison-2026
**切れている** 404  https://www.parallels.com/jp/products/desktop/education/
    ← hoso-daigaku-gakuwari-2026
**切れている** 404  https://www.paypay-card.co.jp/
    ← credit-card-no-annual-fee-comparison-2026 / june-2026-campaigns-roundup / paypay-2026-june-revision-guide
**切れている** 404  https://www.pointtown.com/ptu/static/companyData
    ← pointsite-comparison-2026
**切れている** 404  https://www.soumu.go.jp/main_sosiki/jichi_zeisei/czaisei/czaisei_seido/furusato/index.html
    ← summer-cospa-travel-2026
**切れている** 404  https://www.sugi-net.jp/sugisapo/
    ← walk-poikatsu-2026
**切れている** 404  https://www.toys.or.jp/toyshow/
    ← wangan-august-events-2026
**切れている** 404  https://www.wolframalpha.com/pro-for-students
    ← hoso-daigaku-gakuwari-2026
**切れている** 404  https://www.wolframalpha.com/pro/pricing/students
    ← hoso-daigaku-gakuwari-2026
つながらない 0  https://ahamo.com/
    ← cheap-sim-comparison-2026
つながらない 0  https://appdigitalhealth.com/rakuten-healthcare-report/
    ← move-to-earn-poikatsu-apps-2026
つながらない 0  https://arucoin.jp/
    ← walk-poikatsu-2026
つながらない 0  https://dcard.docomo.ne.jp/std/campaigns/202607_1cm/cpn-shinkinyuukai-tokuten/index.html
    ← credit-card-campaign-2026-07
つながらない 0  https://dcard.docomo.ne.jp/std/info/correction20251101.html
    ← credit-card-kaiaku-2026
つながらない 0  https://denki.docomo.ne.jp/
    ← fixed-cost-reduction-guide-2026
つながらない 0  https://dpoint.docomo.ne.jp/article/2009_07.html
    ← point-exchange-route-2026
つながらない 0  https://every-point.jp/
    ← walk-poikatsu-2026
つながらない 0  https://health.docomo.ne.jp/
    ← walk-poikatsu-2026
つながらない 0  https://healthcare.smt.docomo.ne.jp/
    ← walk-poikatsu-2026
つながらない 0  https://healthree.io/
    ← walk-poikatsu-2026
つながらない 0  https://poisura.com/
    ← walk-poikatsu-2026
つながらない 0  https://service.smt.docomo.ne.jp/keitai_payment/
    ← june-2026-campaigns-roundup / qr-payment-comparison-2026
つながらない 0  https://service.smt.docomo.ne.jp/keitai_payment/assets/top/image/illust_point_description_01.png
    ← june-2026-campaigns-roundup / qr-payment-comparison-2026
つながらない 0  https://service.smt.docomo.ne.jp/keitai_payment/campaign/
    ← qr-payment-comparison-2026
つながらない 0  https://stellarwalk.jp/
    ← walk-poikatsu-2026
つながらない 0  https://www.axa-direct.co.jp/auto/
    ← car-insurance-comparison-2026
つながらない 0  https://www.emsc.meti.go.jp/
    ← electricity-gas-savings-2026
つながらない 0  https://www.gyomusuper.jp/
    ← tokyo-discount-supermarket-2026
つながらない 0  https://www.gyomusuper.jp/product/index.php
    ← tokyo-discount-supermarket-2026
つながらない 0  https://www.gyomusuper.jp/saiyasune.php
    ← tokyo-discount-supermarket-2026
つながらない 0  https://www.gyomusuper.jp/shop/list.php?pref_id=13
    ← tokyo-discount-supermarket-2026
つながらない 0  https://www.inzweb.jp/
    ← car-insurance-comparison-2026
つながらない 0  https://www.j-fsa.go.jp/
    ← cardloan-comparison-2026
つながらない 0  https://www.nmwa.go.jp/
    ← hoso-daigaku-gakuwari-2026
つながらない 0  https://www.orixcredit.jp/
    ← cardloan-comparison-2026
つながらない 0  https://www.promise.co.jp/
    ← cardloan-comparison-2026
つながらない 0  https://www.satofull.jp/
    ← furusato-tax-2026-reform-guide / furusato-tax-beginner-guide-2026
つながらない 0  https://www.smbc.co.jp/kojin/olive/imgs/index_img_18_pc.png
    ← june-2026-campaigns-roundup
つながらない 0  https://www.ueshima-coffee-ten.jp/menu/morning/
    ← morning-500-2026
つながらない 0  https://www.yoshinoya.com/menu/morningset/
    ← morning-500-2026
つながらない 0  https://www.yoshinoya.com/menu/morningset/nattou-tei/
    ← morning-500-2026
つながらない 0  https://www.yoshinoya.com/menu/morningset/shiosaba-gyu-tei/
    ← morning-500-2026
つながらない 0  https://www.yoshinoya.com/menu/morningset/shiosaba-tokuasa-tei/
    ← morning-500-2026

## 転送でパスが変わったもの（**別商品に飛んでいないか見る**）
  https://apps.apple.com/JP/app/id1088184021
    -> https://apps.apple.com/jp/app/coke-on-%E3%82%B3%E3%83%BC%E3%82%AF%E3%82%AA%E3%83%B3/id1088184021
    ← walk-poikatsu-2026
  https://apps.apple.com/jp/app/id1352137023
    -> https://apps.apple.com/jp/app/d%E3%83%98%E3%83%AB%E3%82%B9%E3%82%B1%E3%82%A2-%E6%AD%A9%E6%95%B0%E3%81%A7d%E3%83%9D%E3%82%A4%E3%83%B3%E3%83%88%E3%81%8C%E3%81%9F%E3%81%BE%E3%82%8B%E5%81%A5%E5%BA%B7%E7%AE%A1%E7%90%86%E3%82%A2%E3%83%97%E3%83%AA/id1352137023
    ← move-to-earn-poikatsu-apps-2026
  https://apps.apple.com/jp/app/id921446819
    -> https://apps.apple.com/jp/app/%E4%B8%89%E4%BA%95%E3%82%B7%E3%83%A7%E3%83%83%E3%83%94%E3%83%B3%E3%82%B0%E3%83%91%E3%83%BC%E3%82%AF%E3%82%A2%E3%83%97%E3%83%AA/id921446819
    ← lalaport-guide-2026
  https://bitwalk.jp/
    -> https://lp.bitwalk.jp/
    ← walk-poikatsu-2026
  https://commons.wikimedia.org/wiki/File:25%20BTC%20Gold%20Casascius%20coin%202011%20by%20Gage%20Skidmore.jpg
    -> https://commons.wikimedia.org/wiki/File:25_BTC_Gold_Casascius_coin_2011_by_Gage_Skidmore.jpg
    ← walk-poikatsu-2026
  https://commons.wikimedia.org/wiki/File:Airliner%20wing%20and%20clouds%20over%20South%20Pacific.jpg
    -> https://commons.wikimedia.org/wiki/File:Airliner_wing_and_clouds_over_South_Pacific.jpg
    ← walk-poikatsu-2026
  https://commons.wikimedia.org/wiki/File:April%202025%2C%20meat%20prices%20at%20Hanamasa%20in%20Tokyo.jpg
    -> https://commons.wikimedia.org/wiki/File:April_2025,_meat_prices_at_Hanamasa_in_Tokyo.jpg
    ← tokyo-discount-supermarket-2026
  https://commons.wikimedia.org/wiki/File:Don%20Quichote%20Roppongi.jpg
    -> https://commons.wikimedia.org/wiki/File:Don_Quichote_Roppongi.jpg
    ← tokyo-discount-supermarket-2026
  https://commons.wikimedia.org/wiki/File:Feet%20of%20women%20cycling%20and%20walking.jpg
    -> https://commons.wikimedia.org/wiki/File:Feet_of_women_cycling_and_walking.jpg
    ← walk-poikatsu-2026
  https://commons.wikimedia.org/wiki/File:Gyomu%20Super%20Fukaebashi.jpg
    -> https://commons.wikimedia.org/wiki/File:Gyomu_Super_Fukaebashi.jpg
    ← tokyo-discount-supermarket-2026
  https://commons.wikimedia.org/wiki/File:JAP%20Tokyo%20Shibuya%20Hachiko%20Square.jpg
    -> https://commons.wikimedia.org/wiki/File:JAP_Tokyo_Shibuya_Hachiko_Square.jpg
    ← walk-poikatsu-2026
  https://commons.wikimedia.org/wiki/File:Kids%20walking%20on%20park%20path%20(Unsplash).jpg
    -> https://commons.wikimedia.org/wiki/File:Kids_walking_on_park_path_(Unsplash).jpg
    ← walk-poikatsu-2026
  https://commons.wikimedia.org/wiki/File:Lopia--sushi--2024-06-08%2001.jpg
    -> https://commons.wikimedia.org/wiki/File:Lopia--sushi--2024-06-08_01.jpg
    ← tokyo-discount-supermarket-2026
  https://commons.wikimedia.org/wiki/File:My%20Basket%20Iogi%20eki%20Higashi.jpg
    -> https://commons.wikimedia.org/wiki/File:My_Basket_Iogi_eki_Higashi.jpg
    ← tokyo-discount-supermarket-2026
  https://commons.wikimedia.org/wiki/File:OK%20Hiyoshi%20store.jpg
    -> https://commons.wikimedia.org/wiki/File:OK_Hiyoshi_store.jpg
    ← tokyo-discount-supermarket-2026
  https://commons.wikimedia.org/wiki/File:TRIAL%20SEIYU%20Hanakoganei%20202604.jpg
    -> https://commons.wikimedia.org/wiki/File:TRIAL_SEIYU_Hanakoganei_202604.jpg
    ← tokyo-discount-supermarket-2026
  https://emaxis.jp/
    -> https://emaxis.am.mufg.jp/
    ← nisa-recommended-index-funds-2026
  https://faq.tokyodisneyresort.jp/tdr/faq_detail.html?id=25436
    -> https://faq.tokyodisneyresort.jp/
    ← hoso-daigaku-gakuwari-2026
  https://go.mo-t.com/
    -> https://go.goinc.jp/
    ← june-2026-campaigns-roundup
  https://hapitas.jp/
    -> https://hapitas.jp/register
    ← pointsite-comparison-2026
  https://healthcare.faq.rakuten.net/
    -> https://healthcare.faq.rakuten.net/s/
    ← walk-poikatsu-2026
  https://kakaku.com/kuruma_hoken/
    -> https://hoken.kakaku.com/kuruma_hoken/
    ← car-insurance-comparison-2026
  https://kakakumag.com/money/?id=20897
    -> https://kakakumag.com/error.aspx?404;
    ← point-service-complete-guide-2026
  https://kencom.jp/
    -> https://kencom.jp/login
    ← walk-poikatsu-2026
  https://lemongas.co.jp/
    -> https://www.lemongas.co.jp/
    ← electricity-gas-savings-2026
  https://mitsui-shopping-park.com/lalaport/nangang/
    -> https://mitsui-shopping-park.com/lalaport/404.html
    ← lalaport-guide-2026
  https://mitsui-shopping-park.com/lalaport/shanghai/
    -> https://mitsui-shopping-park.com/lalaport/404.html
    ← lalaport-guide-2026
  https://mitsui-shopping-park.com/lalaport/toyosu/event/3420509.html
    -> https://mitsui-shopping-park.com/lalaport/toyosu/404.html
    ← wangan-august-events-2026
  https://mitsui-shopping-park.com/lalaport/toyosu/shopguide/1539727/
    -> https://mitsui-shopping-park.com/lalaport/toyosu/404.html
    ← wangan-supermarkets-2026
  https://paradise-otemachi.com/facility_spa.html
    -> https://paradise-otemachi.com/service-spa/
    ← sauna-openings-2026

✅ 全部 見た（1010 件）
```

## ② 実ブラウザで裏を取る（**403 は除く**）

```
怪しいもの 75 件 / 全 1010 件
```

## ② 実ブラウザで裏を取る（**403 は除く**）

```
怪しいもの 75 件 / 全 1010 件

ALIVE: 29
DEAD: 23
OPEN_FAILED: 23

## DEAD
  https://docomo-cycle.jp/tokyo-bikeshare/
    curl=404 http=404 title="Object not found!"
    ← mobility-cost-per-km-2026
  https://event.rakuten.co.jp/furusato/guide/simulator/
    curl=404 http=404 title="指定されたページが見つかりません"
    ← furusato-tax-beginner-guide-2026
  https://looop.co.jp/denki/
    curl=404 http=404 title="ページが見つかりません | Ｌｏｏｏｐ (ループ)"
    ← electricity-gas-savings-2026
  https://mst.monex.co.jp/mst/servlet/ITS/fx/
    curl=404 http=404 title="アクセスしようとしたページが見つかりませんでした／マネックス証券"
    ← fx-account-comparison-2026
  https://travel.yahoo.co.jp/dir-00000070/
    curl=404 http=404 title="［Yahoo!トラベル］ページが見つかりません"
    ← summer-cospa-travel-2026
  https://travel.yahoo.co.jp/dir-00000998/
    curl=404 http=404 title="［Yahoo!トラベル］ページが見つかりません"
    ← summer-cospa-travel-2026
  https://travel.yahoo.co.jp/dir-00003354/
    curl=404 http=404 title="［Yahoo!トラベル］ページが見つかりません"
    ← summer-cospa-travel-2026
  https://travel.yahoo.co.jp/h/?keyword=%E6%9D%89%E4%B9%83%E4%BA%95
    curl=404 http=404 title="［Yahoo!トラベル］ページが見つかりません"
    ← summer-cospa-travel-2026
  https://www.amazon.co.jp/b?node=5961517051
    curl=404 http=404 title="ページが見つかりません"
    ← hoso-daigaku-gakuwari-2026
  https://www.ana.co.jp/ja/jp/amc/reference/anamile/pocket/
    curl=404 http=404 title="指定されたページが見つかりません│ANA"
    ← walk-poikatsu-2026
  https://www.ana.co.jp/ja/jp/guide/ana-pocket/
    curl=404 http=404 title="指定されたページが見つかりません│ANA"
    ← walk-poikatsu-2026
  https://www.bang.co.jp/auto/
    curl=404 http=404 title="404 Not Found"
    ← car-insurance-comparison-2026
  https://www.bang.co.jp/insurance/
    curl=404 http=404 title="404 Not Found"
    ← car-insurance-comparison-2026
  https://www.click-sec.com/corp/fx/
    curl=404 http=404 title="ページが見つかりません。Not Found 404 | GMOクリック証券"
    ← fx-account-comparison-2026
  https://www.eneos.co.jp/citygas/
    curl=404 http=404 title="お探しのページが見つかりません - Page Not Found｜ENEOS"
    ← electricity-gas-savings-2026
  https://www.eneos.co.jp/denki/
    curl=404 http=404 title="お探しのページが見つかりません - Page Not Found｜ENEOS"
    ← electricity-gas-savings-2026
  https://www.jalan.net/uw/uwp3500/uww3551.do
    curl=404 http=404 title="該当ページURLは存在しません"
    ← summer-cospa-travel-2026
  https://www.lucidchart.com/pages/ja/education
    curl=404 http=404 title="404 Page Not Found | Lucid Software"
    ← hoso-daigaku-gakuwari-2026
  https://www.lucidchart.com/pages/ja/pricing
    curl=404 http=404 title="404 ページが見つかりません | Lucid Software"
    ← hoso-daigaku-gakuwari-2026
  https://www.matsui.co.jp/service/fx/
    curl=404 http=404 title="お探しのページは見つかりませんでした | 松井証券"
    ← fx-account-comparison-2026
  https://www.parallels.com/jp/products/desktop/education/
    curl=404 http=404 title="Page Not Found"
    ← hoso-daigaku-gakuwari-2026
  https://www.pointtown.com/ptu/static/companyData
    curl=404 http=404 title="404 not found | ポイ活・ポイントサイトはポイントタウン"
    ← pointsite-comparison-2026
  https://www.soumu.go.jp/main_sosiki/jichi_zeisei/czaisei/czaisei_seido/furusato/index.html
    curl=404 http=404 title="総務省｜ご案内ページ　－ご利用のページが見つかりません－"
    ← summer-cospa-travel-2026

## OPEN_FAILED
  https://appdigitalhealth.com/rakuten-healthcare-report/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://appdigitalhealth.com/
    ← move-to-earn-poikatsu-apps-2026
  https://arucoin.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://arucoin.jp/
Call log:
    ← walk-poikatsu-2026
  https://every-point.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://every-point.jp/
Call 
    ← walk-poikatsu-2026
  https://healthcare.smt.docomo.ne.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://healthcare.smt.docomo
    ← walk-poikatsu-2026
  https://healthree.io/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://healthree.io/
Call lo
    ← walk-poikatsu-2026
  https://poisura.com/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://poisura.com/
Call log
    ← walk-poikatsu-2026
  https://stellarwalk.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://stellarwalk.jp/
Call 
    ← walk-poikatsu-2026
  https://www.emsc.meti.go.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://www.emsc.meti.go.jp/

    ← electricity-gas-savings-2026
  https://www.inzweb.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://www.inzweb.jp/
Call l
    ← car-insurance-comparison-2026
  https://www.j-fsa.go.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://www.j-fsa.go.jp/
Call
    ← cardloan-comparison-2026
  https://www.orixcredit.jp/
    curl=0 http=null title=null err=page.goto: Timeout 20000ms exceeded.
Call log:
  - navigating to "http
    ← cardloan-comparison-2026
  https://www.promise.co.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_ADDRESS_UNREACHABLE at https://www.promise.co.jp/

    ← cardloan-comparison-2026
  https://www.satofull.jp/
    curl=0 http=null title=null err=page.goto: net::ERR_NAME_NOT_RESOLVED at https://www.satofull.jp/
Call
    ← furusato-tax-2026-reform-guide / furusato-tax-beginner-guide-2026
  https://www.spotify.com/jp-ja/student/
    curl=502 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.spotify.com/
    ← hoso-daigaku-gakuwari-2026
  https://www.sugi-net.jp/sugisapo/
    curl=404 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.sugi-net.jp/
    ← walk-poikatsu-2026
  https://www.toys.or.jp/toyshow/
    curl=404 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.toys.or.jp/t
    ← wangan-august-events-2026
  https://www.ueshima-coffee-ten.jp/menu/morning/
    curl=0 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.ueshima-coff
    ← morning-500-2026
  https://www.wolframalpha.com/pro-for-students
    curl=404 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.wolframalpha
    ← hoso-daigaku-gakuwari-2026
  https://www.wolframalpha.com/pro/pricing/students
    curl=404 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.wolframalpha
    ← hoso-daigaku-gakuwari-2026
  https://www.yoshinoya.com/menu/morningset/
    curl=0 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.yoshinoya.co
    ← morning-500-2026
  https://www.yoshinoya.com/menu/morningset/nattou-tei/
    curl=0 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.yoshinoya.co
    ← morning-500-2026
  https://www.yoshinoya.com/menu/morningset/shiosaba-gyu-tei/
    curl=0 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.yoshinoya.co
    ← morning-500-2026
  https://www.yoshinoya.com/menu/morningset/shiosaba-tokuasa-tei/
    curl=0 http=null title=null err=page.goto: net::ERR_CERT_AUTHORITY_INVALID at https://www.yoshinoya.co
    ← morning-500-2026

## ALIVE（**curl の誤判定**。記事は直さなくてよい）
  https://ahamo.com/  ← "ahamo"
  https://dcard.docomo.ne.jp/std/campaigns/202607_1cm/cpn-shinkinyuukai-tokuten/index.html  ← "【dカード】はじめてのdカード新規入会で合計最大12,400ポイントもらえる！"
  https://dcard.docomo.ne.jp/std/info/correction20251101.html  ← "dカード | 【重要】公共料金・税金などの一部ご利用先におけるdポイント還元率の見直し"
  https://denki.docomo.ne.jp/  ← "ドコモでんき｜電気料金の支払いでdポイントを還元"
  https://dpoint.docomo.ne.jp/article/2009_07.html  ← "【dポイントクラブ】dポイントとJALのマイルはお互い交換可能！メリットと方法を解説"
  https://fx.dmm.com/  ← "DMM.com証券のFX-【DMM FX】"
  https://health.docomo.ne.jp/  ← "dヘルスケア｜毎日の歩数がdポイントに！"
  https://kakakumag.com/money/?id=20897  ← "楽天ポイント、Vポイント、dポイント、Pontaポイント、PayPayポイントを徹底比較 - 価格.comマガジン"
  https://news.yahoo.co.jp/articles/c21c95237e5e9bd4f3e0fe21a319c9e3fe9e6ef4  ← "Yahoo!ニュース"
  https://service.smt.docomo.ne.jp/keitai_payment/  ← "d払い - dポイントがたまる！かんたん、便利なスマホ決済"
  https://service.smt.docomo.ne.jp/keitai_payment/assets/top/image/illust_point_description_01.png  ← "illust_point_description_01.png (566×428)"
  https://service.smt.docomo.ne.jp/keitai_payment/campaign/  ← "キャンペーン｜d払い - かんたん、便利なスマホ決済"
  https://www.axa-direct.co.jp/auto/  ← "自動車保険ならアクサ損害保険｜ネット申込で最大22,000円割引"
  https://www.furusato-tax.jp/  ← "【ふるさとチョイス】お礼の品掲載数No.1のふるさと納税サイト"
  https://www.furusato-tax.jp/about/easy_simulation  ← "年収別にすぐわかる。ふるさと納税の控除上限額かんたんシミュレーション｜ふるさとチョイス"
  https://www.gpoint.co.jp/pen/charge/  ← "Ｇポイント　メンテナンスのお知らせ"
  https://www.gyomusuper.jp/  ← "業務スーパー | プロの品質とプロの価格"
  https://www.gyomusuper.jp/product/index.php  ← "商品紹介｜プロの品質とプロの価格の業務スーパー"
  https://www.gyomusuper.jp/saiyasune.php  ← "特売情報｜プロの品質とプロの価格の業務スーパー"
  https://www.gyomusuper.jp/shop/list.php?pref_id=13  ← "東京都の店舗一覧 - 店舗案内｜プロの品質とプロの価格の業務スーパー"
  https://www.ikea.com/jp/ja/cat/cushion-covers-20535/  ← "洗える枕（羽毛枕・羽根枕）の通販 - IKEA"
  https://www.ikea.com/jp/ja/cat/cushions-cushion-covers-18749/  ← "商品一覧 - IKEA"
  https://www.ikea.com/jp/ja/cat/stools-benches-20655/  ← "商品一覧 - IKEA"
  https://www.ikea.com/jp/ja/p/raskog-trolley-black-70517477/  ← "商品一覧 - IKEA"
  https://www.ikea.com/jp/ja/p/risatorp-basket-white-10221101/  ← "商品一覧 - IKEA"
  https://www.nmwa.go.jp/  ← "国立西洋美術館"
  https://www.paypay-card.co.jp/  ← "クレジットカードなら、PayPayカード PayPayと一緒に使うと便利でおトク - PayPayカード"
  https://www.smbc.co.jp/kojin/olive/imgs/index_img_18_pc.png  ← "index_img_18_pc.png (800×523)"
  https://www.sonysonpo.co.jp/auto/  ← "ソニー損保の自動車保険【公式サイト】"

✅ 全部 見た（75 件）
```

---

curl で見た件数: 1010/1010
実ブラウザで見た件数: 75/75

経過 **460 秒**。

**DEAD と書かれたものだけが「切れている」。** ALIVE は curl の誤判定なので記事は直さない。
**OPEN_FAILED は生死が分からない**（そう書く。切れていることにしない）。
