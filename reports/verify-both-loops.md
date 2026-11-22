# 返信とアンフォローは本当に出たか（2026-09-06 21:32 JST・費用 $0）

> **「起動した」ではなく「出た」を数字で示す。**
> `x04` は待ち時間 10 秒で結果を取り逃した（この処理は 3 分かかる）。
> **何も触らない。読むだけ。**

## 1. ジョブのロード状態

```
  ロード      comment-warmup                     PID=-        最後のrc=0
  ロード      reply-followers-cleanup            PID=-        最後のrc=0
  ロード      reply-followback-check             PID=-        最後のrc=0
  ロード      competitor-follower-follow         PID=-        最後のrc=0
  ロード      hashtag-follow                     PID=-        最後のrc=0
  ロード      badge-followback                   PID=-        最後のrc=0
```

**最後の rc が 0 以外なら失敗している。**

## 2. 今日 出た返信（**本文つき**）

```
  comment/reply 合計: 908 件
  今日つくられた: 0 件
  **今日はまだ 1 件も出ていない。**
```

### `comment-warmup.log` の今日の行

```
[2026-09-06T21:23:17] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
[2026-09-06T21:26:17] picked 2 / max 2 (from 14 candidates)
[2026-09-06T21:26:17] recent template ids (newest first): T07,T11,T21,T22,T16c
[2026-09-06T21:26:18] today's reply-connected follows: 16 / 30
[2026-09-06T21:26:18] --- processing #1/2 for @<伏せ> ---
[2026-09-06T21:26:18] gen failed (#1): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / 拡散希望","skip":true,"reason":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / 拡散希望"}
[2026-09-06T21:26:18] --- processing #2/2 for @<伏せ> ---
[2026-09-06T21:26:20] gen failed (#2): {"ok":false,"error":"生成側が skip: 相手の投稿は商品販売告知。ハッカー子のキャラは節約・家計管理・投資の話題向け。ティッシュペーパーの販売情報には、キャラとして自然に乗る話題がない","skip":true,"reason":"生成側が skip: 相手の投稿は商品販売告知。ハッカー子のキャラは節約・家計管理・投資の話題向け。ティッシュペーパーの販売情報には、キャラとして自然に乗る話題がない"}
[2026-09-06T21:26:20] === orchestrator done: 2 drafts, 16 reply-connected follows today ===
```

## 3. アンフォローは外れたか

```
  総数: 309 件
    no                                207 件
    revenge_ghost_already_unfollowed  48 件
    pending                           23 件
    unfollowed                        16 件
    yes                               14 件
    yes_late                          1 件

  **今日 外した数: 0 件**
  期限到来で残っている: 197 件
  → **まだ外れていない。**
```

### `reply-followers-cleanup.log` の末尾

```
[2026-08-09T22:43:27.488Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:43:35.426Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:43:43.287Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:43:51.243Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:43:59.120Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:44:07.115Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:44:14.981Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:44:22.801Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:44:31.042Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:44:38.928Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-08-09T22:44:41.435Z] done
[2026-08-09T23:44:41.533Z] due unfollows: 165 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mono_koto,moyana75,pref_yamagata,x1qnsd,meta3d03,ebikaniaquarium,AC_SP500,ATOMONE0909,30san,shinsyu100par,numazu_enbando,shihomi8_02,shinjuku_dori,tonoshotown,kyoyasaga,soba_boro,is_official89,msakamoto1971,itsukachan0103,okamiler_pn,so_n_07,S_InvestorHiro,yamanobe_town,nousei_furusato,haiji_doctor,Raykauof,kanametajima,Shinpoi_OTOKU,chukenDr,paykopayka,paynomi,tanaka100p,pay_cashless,mild7000,chibiusachi,ourmoneybook,showchan82,KumikoTNGC,poruhei_,goriyama49676,TemebiNisiazabu,nadekoko705,blushmarypetal,yusa_nnnn,sathunn,ra_riri_rurere,riri_nn81,appreciate_neo,akimayume0130,rCXfRcspSq08XYV,7gook,DawnR44687,Yuika5667585388,5NWu45ylRDg4xQI,Rc9rbGEMcaBq16K,SYuScN0QoFge3bi,mn13148472,Yukiko642444,SEdetenbager,soratobuchannel,Yuuchan_iii,7muni7,yuppi93130629,Qr9S2Q7WpXUJPSk,fOLZ1mBkDhMXsTn,kitagawa1976101,junsan94470531,ONi2m,nao73400941,masa497tan,ZEROS_99,civic_55,SENTIA_666,otoshin2025,yuji1014s,R701_tw,Tokusan1968,dynghunj17546,kotone585078,nyanco93030543,mogu_mogu_104,kehanagasa29770,reiko454504,ycc106,hassy1217,health_aspect,rakurun_blog,pt4l_p,th__shufu,furunou_3nohe,takahashininja,Aibetu_kinoko,prob_future,KMomijinok47415,ITSOKALLOK,uhsinseoul,okasasa5,mayucosmelove,ururunrun_2525,ukiukichan1202,konatsuamego,hagirebiyori3,Zizi_nisa0316,pdo_lo,nekokabuotoko3,andrew_gogogo_,ohayotesuto,kazumax176,gifu_fujinoyu,himawari56757,otokulog_info,shiho_ns00,ayanon_v0u0v,kikutina8,shinomama__,day_trade_pro,t_e_r_u_1_2_,poiPottoNozomi,_hoshigaki_chan,sun_assets_lab,Umaane33,laletsu,hama_tora3,AskerBert,A38039891,paponyan_kabu,yutaro_osawa,920miso,noriyuki_0517,rmonsukikamo,taro_jiwa,yuyumi36,hwm7bq,ching__neng,zero_to_one_eng,teslamomy,showchan1129,money_sbest,EmbetsuMomochin,onigiri_finance,nyataromapo,obachanyo777,_donchanda4,tak06532,kaorutoblue,918_yoshi,ELGRANshuri,Gekko_Tenmondai,NTnakano,mochi_gohan55,tameo_money,aoisora_ema11,hana_kurashi_
[2026-08-09T23:48:07.253Z] recheck failed: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/check-followback.js mao_otk_tw cpaky1 sukesankoba fxmeitantei feldoman0504 STARPayment07 Kimama_FIRE hirouma888 gurisusan furunavi_PR kageyoshi_maki harunorikujyou new_mono_koto moyana75 pref_yamagata x1qnsd meta3d03 ebikaniaquarium AC_SP500 ATOMONE0909 30san shinsyu100par numazu_enbando shihomi8_02 shinjuku_dori tonoshotown kyoyasaga soba_boro is_official89 msakamoto1971 itsukachan0103 okamiler_pn so_n_07 S_InvestorHiro yamanobe_town nousei_furusato haiji_doctor Raykauof kanametajima Shinpoi_OTOKU chukenDr paykopayka paynomi tanaka100p pay_cashless mild7000 chibiusachi ourmoneybook showchan82 KumikoTNGC poruhei_ goriyama49676 TemebiNisiazabu nadekoko705 blushmarypetal yusa_nnnn sathunn ra_riri_rurere riri_nn81 appreciate_neo akimayume0130 rCXfRcspSq08XYV 7gook DawnR44687 Yuika5667585388 5NWu45ylRDg4xQI Rc9rbGEMcaBq16K SYuScN0QoFge3bi mn13148472 Yukiko642444 SEdetenbager soratobuchannel Yuuchan_iii 7muni7 yuppi93130629 Qr9S2Q7WpXUJPSk fOLZ1mBkDhMXsTn kitagawa1976101 junsan94470531 ONi2m nao73400941 masa497tan ZEROS_99 civic_55 SENTIA_666 otoshin2025 yuji1014s R701_tw Tokusan1968 dynghunj17546 kotone585078 nyanco93030543 mogu_mogu_104 kehanagasa29770 reiko454504 ycc106 hassy1217 health_aspect rakurun_blog pt4l_p th__shufu furunou_3nohe takahashininja Aibetu_kinoko prob_future KMomijinok47415 ITSOKALLOK uhsinseoul okasasa5 mayucosmelove ururunrun_2525 ukiukichan1202 konatsuamego hagirebiyori3 Zizi_nisa0316 pdo_lo nekokabuotoko3 andrew_gogogo_ ohayotesuto kazumax176 gifu_fujinoyu himawari56757 otokulog_info shiho_ns00 ayanon_v0u0v kikutina8 shinomama__ day_trade_pro t_e_r_u_1_2_ poiPottoNozomi _hoshigaki_chan sun_assets_lab Umaane33 laletsu hama_tora3 AskerBert A38039891 paponyan_kabu yutaro_osawa 920miso noriyuki_0517 rmonsukikamo taro_jiwa yuyumi36 hwm7bq ching__neng zero_to_one_eng teslamomy showchan1129 money_sbest EmbetsuMomochin onigiri_finance nyataromapo obachanyo777 _donchanda4 tak06532 kaorutoblue 918_yoshi ELGRANshuri Gekko_Tenmondai NTnakano mochi_gohan55 tameo_money aoisora_ema11 hana_kurashi_
[check-followback] connect attempt 1/3 failed: browserType.connectOverCDP: socket hang up
Call log:
  - <ws preparing> retrieving websocket url from http://127.0.0.1:1
[check-followback] connect attempt 2/3 failed: browserType.connectOverCDP: Timeout 60000ms exceeded.
Call log:
  - <ws preparing> retrieving websocket url from http://
[check-followback] connect attempt 3/3 failed: browserType.connectOverCDP: Timeout 60000ms exceeded.
Call log:
  - <ws preparing> retrieving websocket url from http://
 — abort cleanup
[2026-08-10T00:48:07.327Z] due unfollows: 165 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mono_koto,moyana75,pref_yamagata,x1qnsd,meta3d03,ebikaniaquarium,AC_SP500,ATOMONE0909,30san,shinsyu100par,numazu_enbando,shihomi8_02,shinjuku_dori,tonoshotown,kyoyasaga,soba_boro,is_official89,msakamoto1971,itsukachan0103,okamiler_pn,so_n_07,S_InvestorHiro,yamanobe_town,nousei_furusato,haiji_doctor,Raykauof,kanametajima,Shinpoi_OTOKU,chukenDr,paykopayka,paynomi,tanaka100p,pay_cashless,mild7000,chibiusachi,ourmoneybook,showchan82,KumikoTNGC,poruhei_,goriyama49676,TemebiNisiazabu,nadekoko705,blushmarypetal,yusa_nnnn,sathunn,ra_riri_rurere,riri_nn81,appreciate_neo,akimayume0130,rCXfRcspSq08XYV,7gook,DawnR44687,Yuika5667585388,5NWu45ylRDg4xQI,Rc9rbGEMcaBq16K,SYuScN0QoFge3bi,mn13148472,Yukiko642444,SEdetenbager,soratobuchannel,Yuuchan_iii,7muni7,yuppi93130629,Qr9S2Q7WpXUJPSk,fOLZ1mBkDhMXsTn,kitagawa1976101,junsan94470531,ONi2m,nao73400941,masa497tan,ZEROS_99,civic_55,SENTIA_666,otoshin2025,yuji1014s,R701_tw,Tokusan1968,dynghunj17546,kotone585078,nyanco93030543,mogu_mogu_104,kehanagasa29770,reiko454504,ycc106,hassy1217,health_aspect,rakurun_blog,pt4l_p,th__shufu,furunou_3nohe,takahashininja,Aibetu_kinoko,prob_future,KMomijinok47415,ITSOKALLOK,uhsinseoul,okasasa5,mayucosmelove,ururunrun_2525,ukiukichan1202,konatsuamego,hagirebiyori3,Zizi_nisa0316,pdo_lo,nekokabuotoko3,andrew_gogogo_,ohayotesuto,kazumax176,gifu_fujinoyu,himawari56757,otokulog_info,shiho_ns00,ayanon_v0u0v,kikutina8,shinomama__,day_trade_pro,t_e_r_u_1_2_,poiPottoNozomi,_hoshigaki_chan,sun_assets_lab,Umaane33,laletsu,hama_tora3,AskerBert,A38039891,paponyan_kabu,yutaro_osawa,920miso,noriyuki_0517,rmonsukikamo,taro_jiwa,yuyumi36,hwm7bq,ching__neng,zero_to_one_eng,teslamomy,showchan1129,money_sbest,EmbetsuMomochin,onigiri_finance,nyataromapo,obachanyo777,_donchanda4,tak06532,kaorutoblue,918_yoshi,ELGRANshuri,Gekko_Tenmondai,NTnakano,mochi_gohan55,tameo_money,aoisora_ema11,hana_kurashi_
[2026-08-10T00:49:55.907Z] recheck failed: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/check-followback.js mao_otk_tw cpaky1 sukesankoba fxmeitantei feldoman0504 STARPayment07 Kimama_FIRE hirouma888 gurisusan furunavi_PR kageyoshi_maki harunorikujyou new_mono_koto moyana75 pref_yamagata x1qnsd meta3d03 ebikaniaquarium AC_SP500 ATOMONE0909 30san shinsyu100par numazu_enbando shihomi8_02 shinjuku_dori tonoshotown kyoyasaga soba_boro is_official89 msakamoto1971 itsukachan0103 okamiler_pn so_n_07 S_InvestorHiro yamanobe_town nousei_furusato haiji_doctor Raykauof kanametajima Shinpoi_OTOKU chukenDr paykopayka paynomi tanaka100p pay_cashless mild7000 chibiusachi ourmoneybook showchan82 KumikoTNGC poruhei_ goriyama49676 TemebiNisiazabu nadekoko705 blushmarypetal yusa_nnnn sathunn ra_riri_rurere riri_nn81 appreciate_neo akimayume0130 rCXfRcspSq08XYV 7gook DawnR44687 Yuika5667585388 5NWu45ylRDg4xQI Rc9rbGEMcaBq16K SYuScN0QoFge3bi mn13148472 Yukiko642444 SEdetenbager soratobuchannel Yuuchan_iii 7muni7 yuppi93130629 Qr9S2Q7WpXUJPSk fOLZ1mBkDhMXsTn kitagawa1976101 junsan94470531 ONi2m nao73400941 masa497tan ZEROS_99 civic_55 SENTIA_666 otoshin2025 yuji1014s R701_tw Tokusan1968 dynghunj17546 kotone585078 nyanco93030543 mogu_mogu_104 kehanagasa29770 reiko454504 ycc106 hassy1217 health_aspect rakurun_blog pt4l_p th__shufu furunou_3nohe takahashininja Aibetu_kinoko prob_future KMomijinok47415 ITSOKALLOK uhsinseoul okasasa5 mayucosmelove ururunrun_2525 ukiukichan1202 konatsuamego hagirebiyori3 Zizi_nisa0316 pdo_lo nekokabuotoko3 andrew_gogogo_ ohayotesuto kazumax176 gifu_fujinoyu himawari56757 otokulog_info shiho_ns00 ayanon_v0u0v kikutina8 shinomama__ day_trade_pro t_e_r_u_1_2_ poiPottoNozomi _hoshigaki_chan sun_assets_lab Umaane33 laletsu hama_tora3 AskerBert A38039891 paponyan_kabu yutaro_osawa 920miso noriyuki_0517 rmonsukikamo taro_jiwa yuyumi36 hwm7bq ching__neng zero_to_one_eng teslamomy showchan1129 money_sbest EmbetsuMomochin onigiri_finance nyataromapo obachanyo777 _donchanda4 tak06532 kaorutoblue 918_yoshi ELGRANshuri Gekko_Tenmondai NTnakano mochi_gohan55 tameo_money aoisora_ema11 hana_kurashi_ — abort cleanup
```

## 4. 今日のフォロー

```
  [competitor-follower-follow.log]
    === end: 7/30 OK ===
    === end: 6/30 OK ===
  [hashtag-follow.log]
    === end: 1/4 OK ===
    === end: 2/7 OK ===
```

---

**何も触っていない。返信もアンフォローもフォローもしていない（$0）。**
