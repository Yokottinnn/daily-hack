# 種の候補を既存のログから拾う

**このレポートが作られた時刻: 2026-09-20 16:30:17 JST**

> x96 で候補プールが空だと分かった。`influencers.json` は **7 件 ちょうど**で、
> いま使っている 7 種と同じ。**差し替える先が手元に無い。**
>
> **規模では選ばない。** okamiler_pn 18.2%（平均 7757）と ukk_hx 4.2%（平均 6993）は
> ほぼ同じ規模で 4 倍 違う。効いているのは**ジャンルの近さ**。

**測るだけ。書き換えない。フォローしない。**

## 1. `hashtag-follow` が「**大きすぎる**」と弾いたアカウント

**フォロー相手としては大きすぎるが、種としてはその大きさが要る。**
自分たちのハッシュタグから出てきているので、ジャンルも近い。

```
  ログ: 1929 行 / 2026-09-20 10:20

  --- 上限超えで弾かれたもの（**フォロワー数の多い順**）---
      7075000  711SEJ
      1335000  donki_donki
       833000  Yomiuri_Online
       362000  rakutenbooks
       342000  RakutenPay_App
       298000  tsuruhaofficial
       276000  sundrugofficial
       254000  Seiyu_Japan
       250000  news_mynavi_jp
       242000  KanalocoLocal
       225000  AEON_netsuper
       179000  jwave813fm
       121000  AvispaF
       105000  Lemino_official
       103000  rchannel_japan
       101000  rakutenplay
        92000  bicsim_official
        90000  POIKATSU_OTAKE
        43000  nilax_buffet
        38000  money_yossy
        29000  TDB_PR
        20000  kazurakudesu
        19000  ashikaga_city
        11000  otaru_aobato
        11000  Gian_Support

  --- 下限割れで弾かれたもの（**種には使えない。参考**）---
    小さすぎ: 4

  --- ジャンル違いで弾かれたもの（**種にもしない**）---
      6 回  fjztUtNR5JaO8mO
      5 回  osusume999
      2 回  yoshii07300831
      2 回  GinzaKawaii
      2 回  AztZxSR1BZkaU6f
      1 回  akabane_pman
```

**50000 を大きく超えているものほど、種としての母数が大きい。**
ただし**大きすぎる公式アカウントはフォロワーの質がばらける**ので、
10 万 前後 までを優先する（26.0% の himawari56757 がその帯の外なら、この前提は外れる）。

## 2. `comment-orchestrator` が返信先に選んだ投稿の主

返信経路は **21.9%（n=146）** で競合の平均より高い。
**そこで選ばれている人はジャンルが合っている証拠がある。**

```
  --- comment-state.json の構造 ---
    rollout_started_at       "2026-04-25T06:19:20.061Z"
    targets                  配列 58 件
    daily_counts             オブジェクト 11 キー
    hourly_counts            オブジェクト 34 キー
    recent_negative_signals  配列 0 件
    paused                   false
    pause_reason             null

  --- ログに出ている「選んだ相手」の頻度（上位 20）---
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
```

**複数回 選ばれている人は、こちらの狙う層と重なっている。**
その人自身のフォロワーが多ければ、種の候補になる。

## 3. いまの 7 種（**入れ替え先を決めるための基準**）

```
    種                  返り率   判定
    ------------------------------------------------
    himawari56757        26.0%   **残す**
    haiji_doctor         20.8%   **残す**
    okamiler_pn          18.2%   **残す**
    tokufree3            16.2%   **残す**
    POIKATSU_OTAKE       10.0%   入れ替え候補
    money_yossy           8.6%   入れ替え候補
    ukk_hx                4.2%   入れ替え候補

    外す 3 つ の群  mature  89 件 →  7 人   **7.9%**
    残す 4 つ の群  mature 133 件 → 28 人   **21.1%**
```

**群で見れば 2.7 倍 の差があり、n も足りている。** 差し替えの根拠はここ。

## 4. 費用

**ログと JSON を読むだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**差し替える場合も $0。** `competitor-follower-follow` は DOM 操作のみで
LLM を呼ばないため、**フォロー数を変えても API 費用は動かない。**
返信ループの実測は 1 回 $0.003 ／ 1 日 $0.021 ／ 1 か月 約 $0.63（別勘定）。
