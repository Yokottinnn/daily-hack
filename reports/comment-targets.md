# 選別済み 58 件 を種の候補として見る

**このレポートが作られた時刻: 2026-09-20 16:53:06 JST**

> `influencers.json` は 7 件 しか無く候補プールが空だった（x96）。
> `comment-state.json` の **`targets` 58 件** が本来の候補プール。
> 返信経路は **21.9%（n=146）** で、**ここはジャンルの選別を通っている。**

**測るだけ。書き換えない。フォローしない。**

## 1. `targets` の中身（**構造から先に出す**）

```
  targets: 58 件

  --- 1 件目の実物（**フィールドを当て推量しない**）---
    {"handle":"yamixir","last_commented_at":"2026-05-10T09:14:59.639Z"}

  --- キーと件数 ---
    handle                     58 件
    last_commented_at          58 件
```

## 2. 58 件 の一覧（**分かっているフォロワー数を併記**）

```
    ハンドル                  フォロワー   備考
    ----------------------------------------------------------
    AEON_netsuper            225000   帯の外（大きすぎる）
    bicsim_official           92000   帯の外（大きすぎる）
    POIKATSU_OTAKE            91000   **いまの種**
    money_yossy               39000   **いまの種**
    yamixir                   （未取得）   
    1xQ12jhpZeUJBRD           （未取得）   
    SM_mandai                 （未取得）   
    adachi_city               （未取得）   
    Umaane33                  （未取得）   
    roomrakutentoku           （未取得）   
    poruhei_                  （未取得）   
    hekiwomattousu            （未取得）   
    konatsuamego              （未取得）   
    inami_furusato            （未取得）   
    koji55                    （未取得）   
    hayato_no_jikan           （未取得）   
    yumepolly                 （未取得）   
    ftax_support              （未取得）   
    bbPTEeUwD2BTas4           （未取得）   
    NISA_kansoku              （未取得）   
    mao_otk_tw                （未取得）   
    cpaky1                    （未取得）   
    sukesankoba               （未取得）   
    fxmeitantei               （未取得）   
    feldoman0504              （未取得）   
    STARPayment07             （未取得）   
    Kimama_FIRE               （未取得）   
    hirouma888                （未取得）   
    gurisusan                 （未取得）   
    furunavi_PR               （未取得）   
    kageyoshi_maki            （未取得）   
    harunorikujyou            （未取得）   
    pref_yamagata             （未取得）   
    x1qnsd                    （未取得）   
    heng_ji31590              （未取得）   
    meta3d03                  （未取得）   
    ebikaniaquarium           （未取得）   
    AC_SP500                  （未取得）   
    ATOMONE0909               （未取得）   
    30san                     （未取得）   
    shinsyu100par             （未取得）   
    F838F0203                 （未取得）   
    numazu_enbando            （未取得）   
    makubetsu_furu            （未取得）   
    shihomi8_02               （未取得）   
    shinjuku_dori             （未取得）   
    tonoshotown               （未取得）   
    agu_touseki               （未取得）   
    kyoyasaga                 （未取得）   
    soba_boro                 （未取得）   
    is_official89             （未取得）   
    msakamoto1971             （未取得）   
    nousei_furusato           （未取得）   
    kan826_ffa                （未取得）   
    n0326ao                   （未取得）   
    jikayolpgascar            （未取得）   
    otsukisama50              （未取得）   
    LR_investment             （未取得）   

    計 58 件 / **フォロワー数が未取得: 54 件**
```

**未取得が多ければ、次に DOM で数を取る必要がある**（それも $0）。
分かっているものだけで 3 つ 選べるなら、そこで決められる。

## 3. 返信で**何回 選ばれたか**（ジャンルの近さの代理指標）

```
     85 回  money_yossy
     43 回  POIKATSU_OTAKE
     30 回  fxmeitantei
     22 回  mao_otk_tw
     22 回  bicsim_official
     21 回  okamiler_pn
     15 回  1xQ12jhpZeUJBRD
     12 回  osusume999
     12 回  inami_furusato
     11 回  coupon_gorilla1
      9 回  sa51545199
      9 回  raspiM5stack
      9 回  haiji_doctor
      8 回  x1qnsd
      8 回  t_sh_30143
      8 回  rmonsukikamo
      8 回  HarrysShare
      8 回  Butokumaru_naro
      7 回  toshi00213591
      7 回  goriyama49676
      6 回  rakutenplay
      6 回  muisan1
      6 回  lecter_HL
      6 回  asd_doku
      6 回  SP500TARO500
```

**繰り返し選ばれている人は、picker のジャンル判定を何度も通っている。**
ただし**返信の相手として良いことと、種として良いことは別**なので、
これだけでは決めない。フォロワー数と合わせて見る。

## 3-B. 日ごとのフォロワー数が**別の口に残っていないか**

```
  /Users/ny/.openclaw/workspace/data/follower-snapshots
  ファイル数: 53 件

  --- 直近 20 件（日付と、中に入っている人数）---
    2026-07-25.json                 184 人
    2026-07-31.json                 187 人
    2026-08-01.json                 188 人
    2026-08-02.json                 192 人
    2026-08-06.json                 192 人
    2026-08-07.json                 195 人
    2026-08-08.json                 198 人
    2026-08-09.json                 206 人
    2026-08-21.json                 207 人
    2026-08-22.json                 206 人
    2026-08-23.json                 208 人
    2026-08-24.json                 210 人
    2026-08-25.json                 212 人
    2026-08-26.json                 211 人
    2026-08-27.json                 214 人
    2026-08-28.json                 214 人
    2026-08-29.json                 215 人
    2026-09-07.json                 224 人
    2026-09-08.json                 227 人
    2026-09-20.json                 264 人

  --- 9/09〜9/19 のファイルがあるか（**止まっていた期間**）---
    **1 件も無い。** 日ごとの数はこの期間 残っていない
```

**在れば日ごとの伸びが出せる。無ければ、いまの 264 が最初の再開点。**
その場合、日ごとの傾向は**明日以降の記録でしか出せない。**

## 4. 判断の材料（**同じ紙に残す**）

```
    いまの 7 種
      himawari56757   26.0%   残す
      haiji_doctor    20.8%   残す
      okamiler_pn     18.2%   残す
      tokufree3       16.2%   残す
      POIKATSU_OTAKE  10.0%   **外す**（フォロワー 90000）
      money_yossy      8.6%   **外す**（フォロワー 38000）
      ukk_hx           4.2%   **外す**

    群で見ると
      外す 3 つ  mature  89 件 →  7 人   7.9%
      残す 4 つ  mature 133 件 → 28 人  21.1%

    選ぶ基準
      ① 規模では選ばない（同規模で 4 倍 違う実例がある）
      ② ただし 9 万 以下（実証済みの帯）から出ない
      ③ ブランド公式より個人
```

## 5. 費用

**JSON とログを読むだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**差し替える場合も $0。** `competitor-follower-follow` は DOM 操作のみで
LLM を呼ばないため、**フォロー数を変えても API 費用は動かない。**
返信ループの実測は 1 回 $0.003 ／ 1 日 $0.021 ／ 1 か月 約 $0.63（別勘定・変わらない）。
