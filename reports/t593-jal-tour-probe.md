# JAL のツアーと別々の予約の下調べ（t593・**$0**）

生成: **2026-11-08T23:53:04+0900**

- `playwright-core`: **`/Users/ny/.openclaw/workspace/node_modules`** に在る
- Chrome: **CDP 18810 で応答あり**

終了コード **0**

## J-TRIP トップ

https://www.jtrip.co.jp/

- HTTP 200 ／ 題名: 【公式】ジェイトリップツアー｜JALで行く格安国内旅行・国内ツアー ／ 最終: https://www.jtrip.co.jp/

```text
FORM get https://tour.jtrip.co.jp/tour40/
  depAirport=[|GHND|GOSA|GCHU|GFKK|GSPK]
  arrAirport=[]
  date=2026-12-09
  year=2026
  month=12
  day=9
  days=[2|3|4|5]
  rtype=[1|2|TW|SD|DB|TR]
  submit=ツアーを検索
  dec=1
  pid=ts
  icon1=6
  kID=JTRIPKAK
--- リンク ---
https://www.jtrip.co.jp/sp/coupon-list/
https://www.jtrip.co.jp/j-okinawa/freeplan/round-tour/
https://www.jtrip.co.jp/j-hokkaido/freeplan/shuyu/
https://www.jtrip.co.jp/j-shikoku/freeplan/free/
https://www.instagram.com/jtrip_tour/
https://twitter.com/jtrip_tour
https://www.facebook.com/okinawatour/
```

## JAL ダイナミックパッケージ

https://www.jal.co.jp/jp/ja/domtour/

- HTTP 200 ／ 題名: JALパック | 国内旅行・国内ツアーのご予約、おすすめツアーや旅のお役立ち情報をご案内 ／ 最終: https://www.jal.co.jp/ja-jp/book-dom/tour.html

```text
FORM get https://www.jal.co.jp/jp/ja/insite-search/
  keyword
  collection=jalcojp
  charset=utf-8
FORM post https://sp5971.jal.co.jp/JmbSp/JR/LogIn_ja.do
  TopCategory=DOM
FORM get https://www.jal.co.jp/jp/ja/insite-search/
  keyword
FORM post https://www121.jal.co.jp/JmbWeb/JR/DomTop_ja.do
  
FORM post https://www.jal.co.jp/ja-jp/book-dom/tour.html
  memberPattern=6,13
  memberBackUrl
FORM get https://www121.jal.co.jp/JmbWeb/Dispatcher_ja.do
  memberBackUrl=https://digital.jal.co.jp/ssci
  guestBackUrl=https://digital.jal.co.jp/ssci
  memberPattern=5,6,13,30
  guestPattern=5,6
  lang=ja-JP
--- リンク ---
https://www.jal.co.jp/ja-jp/book-dom/tour.html
https://www.jal.co.jp/jp/ja/domtour/tabitoku-park/
https://www.jal.co.jp/ja-jp/book/tour.html
https://www.jal.co.jp/jp/ja/intltour/tabitoku-park/
https://jalcard.jal.co.jp/cgi-bin/cardlist/af.cgi?f=online&root=CUJALNMENU
https://www.jal.co.jp/jp/ja/domtour/tabitoku-park/?tour-domtop=mv_1
https://www121.jal.co.jp/JmbWeb/JR/Dispatcher_ja.do?memberBackUrl=https%3A%2F%2Fdomdp.jal.co.jp%2Fjaldp%2FccCartForm%2Fdisp&memberPattern=5%2C9&guestBackUrl=https%3A%2F%2Fdomdp.jal.co.jp%2Fjaldp%2FccCartForm%2Fdisp&guestPattern=5&discount_coupon_cd=&top_link_disp=1&domain=EJALTOURS&param1=&param2=&param3=&param4=&param5=&option_area_jump=1&TranID=DOM_JDPTOUR
https://www.jal.co.jp/jp/ja/domtour/osusume-portal/
https://jmbtour.jal.co.jp/sp/booking/common/historylogin/init?useKbn=7
https://jmbtour.jal.co.jp/pc/history/common/welcome/init
https://domdp.jal.co.jp/jaldp/ccReservationSearch/disp
https://www.jal.co.jp/jp/ja/intltour/manage-booking/
https://booking.jal.co.jp/jl/dom-other/irregularSearch
https://www.5931.jal.co.jp/rsvInter/IrregularFlightListInput.do
https://www.jal.co.jp/jp/ja/domtour/jaldp/okaidoku-flight/?tour-domtop=wide
https://www.jal.co.jp/jp/ja/tour/dp_coupon/?tour-domtop=base
https://www.jal.co.jp/jp/ja/tour/otoku-guide/?tour-domtop=base
https://www.jal.co.jp/jp/ja/domtour/jaldp/jalplaza-coupon/?tour-domtop=base
https://www.jal.co.jp/jp/ja/domtour/heijitsu-camp/?tour-domtop=base
https://www.jal.co.jp/jp/ja/domtour/jaldp/skisp/?tour=domprA
https://www.jal.co.jp/jp/ja/domtour/jaldp/tdr/?tour=domprA
https://www.jal.co.jp/jp/ja/domtour/jaldp/oka/asobou/?tour=domprA
https://www.jal.co.jp/jp/ja/domtour/ssy/miyajima-fireworks/?tour=domprA
```

## JAL 国内線 トップ

https://www.jal.co.jp/jp/ja/dom/

- HTTP 200 ／ 題名: JAL | 国内線・国内ツアー − 航空券 予約・空席照会・運賃案内− ／ 最終: https://www.jal.co.jp/ja-jp/book-dom.html

```text
FORM get https://www.jal.co.jp/jp/ja/insite-search/
  keyword
  collection=jalcojp
  charset=utf-8
FORM post https://sp5971.jal.co.jp/JmbSp/JR/LogIn_ja.do
  TopCategory=DOM
FORM get https://www.jal.co.jp/jp/ja/insite-search/
  keyword
FORM post https://www121.jal.co.jp/JmbWeb/JR/DomTop_ja.do
  
FORM post https://www.jal.co.jp/ja-jp/book-dom.html
  memberPattern=6,13
  memberBackUrl
FORM get https://www121.jal.co.jp/JmbWeb/Dispatcher_ja.do
  memberBackUrl=https://digital.jal.co.jp/ssci
  guestBackUrl=https://digital.jal.co.jp/ssci
  memberPattern=5,6,13,30
  guestPattern=5,6
  lang=ja-JP
--- リンク ---
https://www.jal.co.jp/ja-jp/book-dom/tour.html
https://www.jal.co.jp/jp/ja/domtour/tabitoku-park/
https://www.jal.co.jp/ja-jp/book/tour.html
https://www.jal.co.jp/jp/ja/intltour/tabitoku-park/
https://jalcard.jal.co.jp/cgi-bin/cardlist/af.cgi?f=online&root=CUJALNMENU
https://www121.jal.co.jp/JmbWeb/JR/Dispatcher_ja.do?memberBackUrl=https%3A%2F%2Fdomdp.jal.co.jp%2Fjaldp%2FccCartForm%2Fdisp&memberPattern=5%2C9&guestBackUrl=https%3A%2F%2Fdomdp.jal.co.jp%2Fjaldp%2FccCartForm%2Fdisp&guestPattern=5&discount_coupon_cd=&top_link_disp=1&domain=EJALTOURS&param1=&param2=&param3=&param4=&param5=&option_area_jump=1&TranID=DOM_JDPTOUR
https://www.jal.co.jp/jp/ja/domtour/osusume-portal/
https://jmbtour.jal.co.jp/sp/booking/common/historylogin/init?useKbn=7
https://jmbtour.jal.co.jp/pc/history/common/welcome/init
https://domdp.jal.co.jp/jaldp/ccReservationSearch/disp
https://www.jal.co.jp/jp/ja/intltour/manage-booking/
https://booking.jal.co.jp/jl/dom-other/irregularSearch
https://www.5931.jal.co.jp/rsvInter/IrregularFlightListInput.do
https://www.jal.co.jp/jp/ja/domtour/tabitoku-park/?book-domtop=default
https://www.jal.co.jp/jp/ja/tour/dp_coupon/
https://jalcard.jal.co.jp/cgi-bin/cardlist/af.cgi?f=online&root=BUJCITOPGSTBTN&_gl=1*1j6nf7p*_gcl_au*MTE2MzIzOTI0OC4xNzY2OTgzMTAx
https://www.jal.co.jp/jp/ja/tour/info/kyushu-fukko-ouen.html
https://www.jal.co.jp/jp/ja/tour/info/20260924.html
https://www.jal.co.jp/jp/ja/tour/info/260417.html
https://www.jal.co.jp/ja-jp/news/domtour.html
https://faq-tour-jp.jal.co.jp/s/article/jdsp000000R0000000014629tourdom
https://faq-tour-jp.jal.co.jp/s/article/jdsp000000R0000000004627tourdom
```

## エアトリ 国内ツアー

https://tour.airtrip.jp/

- HTTP 200 ／ 題名: 海外ツアー・海外旅行予約はエアトリ｜ソウル・ハワイなど人気ツアー ／ 最終: https://tour.airtrip.jp/

```text
FORM get https://tour.airtrip.jp/
  departure_airport=東京(成田・羽田)
  destination=ソウル
  departure_date=11月未定
  to_date
  rooms=1部屋、おとな 2名、子ども 0名
  rooms_query=2,0,0,0
--- リンク ---
https://tour.airtrip.jp/
https://domdp.airtrip.jp/?source=globalnavi
https://japantour.airtrip.jp/
https://www.skygate.co.jp/dp/
https://japantour.airtrip.jp/special/oka/
https://japantour.airtrip.jp/special/hok/
https://www.airtrip.jp/traindp/
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=SEL,PUS,CJU,CJJ,SWU,RSU,KAG,YNY,HIN,TAE&departure_date=20261208&to_date=20261210&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=TPE,TXG,KHH,TNN,HUN,TTT,MZG,PIF,MFK,CYI&departure_date=20261208&to_date=20261210&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=BKK,HKT,CNX,PYX,KOP,USM,CEI&departure_date=20261208&to_date=20261211&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=SGN,HAN,DAD,PQC,HUI,NHA,HPH,VDH&departure_date=20261208&to_date=20261211&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=HKG&departure_date=20261208&to_date=20261210&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=SIN&departure_date=20261208&to_date=20261211&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=CEB,NOP,TAG&departure_date=20261208&to_date=20261211&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=KUL,MKZ,BKI,PEN,JHB&departure_date=20261208&to_date=20261211&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=DPS,JOG,JKT,LBJ&departure_date=20261208&to_date=20261211&rooms=2,0,0,0
https://tour.airtrip.jp/list?departure_airport=TYO&destination_city=MFM&departure_date=20261208&to_date=20261210&rooms=2,0,0,0
```


LLM 不使用。**$0/回**（1 回きり）。予約はしない。
