# 良い種から辿った、次の種の候補

**このレポートが作られた時刻: 2026-09-20 20:43:50 JST**

> x104 で**手元の候補プールは尽きた。** `influencers.json` は 7 件、
> `comment-state.json` の 58 件 は小さいアカウント中心で種に使えない。
>
> そこで**いちばん確かな信号から辿る。** `himawari56757`（返り率 26.0%）から
> フォローして**実際に返してくれた人**が、他に誰をフォローしているかを数える。

**辿る相手の名前は 1 件も出さない。** 出すのは集計後の候補と件数だけ。

## 1. 実行

```
  node --check: 通った
  rc=0 （**rc は証拠にならない。中身を見る**）

  経過 34 秒
  返してくれた人: 13 人 / **対象 6 人 → 読めた 6 人 / 読めなかった 0 人**

    候補                    何人が フォローしているか
    ----------------------------------------------------
    home                    6 人  ######
    explore                 6 人  ######
    notifications           6 人  ######
    shiratamatsuki          5 人  #####
    rough_dayonn            4 人  ####
    Bon6466                 4 人  ####
    MimesisJPN              4 人  ####
    kamukura_PR             4 人  ####
    game8jp                 4 人  ####
    GTUNE_NEXTGEAR          4 人  ####
    mouse_computer          4 人  ####
    _Liszt1                 3 人  ###
    Derby_impact            3 人  ###
    takeado_ado             3 人  ###
    TronDao_JPN             2 人  ##
    justinsuntron           2 人  ##
    Tcgshopchamake          2 人  ##
    db_legends_jp           2 人  ##
    dbfw_cardgameJP         2 人  ##
    StudioPrisma_JP         2 人  ##
    gbvs_official           2 人  ##
    turezuren7064           2 人  ##
    neru_rbcl               2 人  ##
    KatarisOfficial         2 人  ##
    animatetimes            2 人  ##
    atimes_goods            2 人  ##
    BookLive_BL             2 人  ##
    KOHACHI_yurie           2 人  ##
    drecs_jp                2 人  ##
    drecs_gl                2 人  ##
```

**複数人が共通してフォローしている先ほど、同じ層を抱えている可能性が高い。**
ただし**これは候補の入口であって、決定ではない。**
フォロワー数と中身を見てから選ぶ（規模では選ばないが、9 万 以下の帯から出ない）。

## 2. いまの 4 種（比較用）

```
    himawari56757  26.0%     haiji_doctor  20.8%
    okamiler_pn    18.2%     tokufree3     16.2%

    外した 3 つ: ukk_hx 4.2% / money_yossy 8.6% / POIKATSU_OTAKE 10.0%
    群で見ると 外した 3 つ 7.9% / 残した 4 つ 21.1%（2.7 倍）
```

## 3. 費用

**フォロー一覧を DOM で読むだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**種を足すのも $0。** `competitor-follower-follow` は DOM 操作のみ。
返信ループは `MAX_PICKS` 6 で **約 $0.95/月（推定）**。実測は明日 確かめる。
