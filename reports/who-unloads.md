# 誰がジョブを外しているか ＋ 終了コード 5 と 2

**このレポートが作られた時刻: 2026-09-20 01:38:47 JST**

> x86 で候補が 3 つ 消えた（disable されていない／plist 正常／置き場所も正しい）。
> **2 回 とも `ai.openclaw.*` だけが全滅し、`com.dailyhack.*` は無傷。**
> **2 回 とも tab-guard だけが生き残っている。**

**測るだけ。載せ直しの仕組みは、ここが分かってから入れる。**

## 1. `bootout` / `unload` を書いているスクリプト（**全部 洗う**）

```
  --- scripts/ で launchctl を外す操作を書いている箇所 ---
    ══ publish-hanabi-oneshot.sh（07-06 00:03）
      34:launchctl bootout gui/$(id -u)/ai.openclaw.publish-hanabi-oneshot 2>>$LOG || true
    ══ wave-freeze.sh（08-09 17:52）
      62:      if launchctl bootout "gui/$UID_VAL/$label" 2>/dev/null; then
    ══ tab-guard.js（09-13 01:41）
      69:    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
    ══ fire-watchdog.js（07-25 16:03）
      169:    `\n\n要対応: \`launchctl print gui/$(id -u)/<label>\` で event triggers 確認、欠けてたら \`launchctl bootout gui/$(id -u)/<label> && launchctl bootstrap gu
    ══ space-approved-posts.js（07-25 16:26）
      129:      execSync(`launchctl bootout gui/$(id -u)/${label}`, { stdio: "ignore" });
    ══ auto-reply.js（07-26 21:04）
      171:        require("child_process").execSync("launchctl bootout gui/501 ~/Library/LaunchAgents/ai.openclaw.comment-warmup.plist", { stdio: "ignore" });
    ══ daily-supervisor.sh（09-13 03:09）
      83:    launchctl bootout "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
      93:    launchctl bootout "gui/${UID_NUM}/$u" >/dev/null 2>&1 || true
    ══ emergency-stop-llm.sh（05-10 15:28）
      15:    launchctl unload "$PLIST" 2>/dev/null || true
    ══ publish-scheduled-entry.sh（07-11 18:47）
      33:  launchctl bootout gui/$(id -u)/${LABEL} 2>/dev/null
      89:launchctl bootout gui/$(id -u)/${LABEL} 2>/dev/null

  --- 見つからなければここは空。その場合は別の主体を疑う ---
```

## 2. tab-guard は何をしているか

```
  /Users/ny/.openclaw/workspace/scripts/tab-guard.js（138 行 / 2026-09-13 01:41）

  --- 止める・外す系の操作 ---
    3: * tab-guard.js — Jordan の Chrome が「丸ごと落とされる」異常だけを検知して自動化を止める。
    5: * 2026-08-09: 自動化が Chrome を pkill し、Jordan のウィンドウが全消滅する事故を起こした。
    8: * 一方、タブが1〜2枚減るのは Jordan 自身の通常操作でも起きる。それで cron を止めるのは
    9: * やり過ぎで無駄な停止を招く（2026-08-09 Jordan 指摘）。
    10: * → **通常運用ではあり得ない事象だけ**を止める条件にする:
    62:function haltAutomation(reason) {
    63:  log(`🚨 ${reason} → 自動化を全停止`);
    65:  // して Chrome の起動を塞ぎ、tab-guard 自身の halt 条件を永久に成立させ続けた
    66:  // （docs/self-healing-deadlock.md 条件 3）。halt と検知はそのまま残す。
    69:    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
    72:  try { execSync(`pkill -f 'workspace/scripts/.*\\.js' 2>/dev/null || true`, { shell: "/bin/bash" }); } catch {}
    73:  log("停止完了");
    83:    // UNREACHABLE_GUARD (2026-09-12): **CDP に繋がらないだけで全停止しない。**
    86:    // 止めてしまう。すると CDP は永久に戻らない（2026-09-08〜12 に 4 日 止まった）。
    89:      log("CDP unreachable が続いている（前回も false）。消滅とみなさず halt しない");
    92:    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
    93:    return { halted: true, reason: "chrome_process_gone" };
    106:    // **自動化そのものが自動化を止める**（2026-09-12 15:24 に実際に起きた）。
    113:    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
    114:    result.halted = true;

  --- ループの名前を列挙している箇所（対象を持っているか） ---
    69:    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
```

**tab-guard が `ai.openclaw.*` の名前を持っていて `bootout` を呼ぶなら、それが犯人。**
持っていなければ、**載せ直しの仕組みを入れても安全**という根拠になる。

## 3. tab-guard のログ（**外した記録が無いか**）

```
  tab-guard.log           20710080 bytes / 最終更新 2026-09-20 01:14
  tab-guard.out           14388301 bytes / 最終更新 2026-09-20 01:14
  tab-guard-err.log        2958020 bytes / 最終更新 2026-09-20 01:14

  --- 9/19〜9/20 の行（止まった前後） ---
    ══ tab-guard.log
      [2026-09-19T16:13:23.189Z] タブ 1 → 0 枚。元が少ないので破壊とみなさない
      [2026-09-19T16:13:33.269Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-19T16:13:33.297Z] タブ 1 → 0 枚。元が少ないので破壊とみなさない
      [2026-09-19T16:13:43.378Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-19T16:13:43.406Z] タブ 1 → 0 枚。元が少ないので破壊とみなさない
      [2026-09-19T16:13:53.483Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-19T16:13:53.532Z] タブ 1 → 0 枚。元が少ないので破壊とみなさない
      [2026-09-19T16:14:03.612Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-19T16:14:03.646Z] タブ 1 → 0 枚。元が少ないので破壊とみなさない
      [2026-09-19T16:14:13.886Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-19T16:14:13.939Z] タブ 1 → 0 枚。元が少ないので破壊とみなさない
      [2026-09-19T16:14:24.002Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）

  --- 外した・止めたと書いている行（全期間） ---
    🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    停止完了
    🚨 Jordan のタブが 14 → 1 枚（一括破壊） → 自動化を全停止
    停止完了
    🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
    停止完了
    🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    停止完了
    🚨 Jordan のタブが 24 → 1 枚（一括破壊） → 自動化を全停止
    停止完了
```

## 4. 終了コード 5 と 2 の中身

```
  --- comment-warmup（終了コード 5） ---
    ══ comment-warmup-err.log（最終更新 09-20 01:19）
          '[step] find-reply-textarea t=6234ms\n' +
          '[textarea] not via: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=12242ms\n' +
          '[textarea] not via: div[data-testid="tweetTextarea_0"] t=18247ms\n' +
          '[textarea] not via: div[role="textbox"][contenteditable="true"][aria-label*="ポスト"] t=24252ms\n' +
          '[textarea] not via: div[role="textbox"][contenteditable="true"] t=30255ms\n' +
          '[textarea] primary all failed, trying reply btn click t=30255ms\n' +
          '[textarea] no reply btn eith'
      }

    ══ comment-warmup.log（最終更新 09-20 01:24）
      [2026-09-20T01:17:26] enqueue: {"ok":true,"id":"comment-20260920-0117-0"}
      {"ok":true,"entry_id":"comment-20260920-0117-0","x_tweet_id":"2101344972452848045","url":"https://x.com/heng_ji31590/status/2101344972452848045","slack_report_ts":"silenced"}
      [2026-09-20T01:17:39]   follow @<伏せ>: skipped (already in reply-followers.json)
      [2026-09-20T01:17:39] --- processing #2/4 for @<伏せ> ---
      [2026-09-20T01:17:42]   → chosen template_id: unknown
      [2026-09-20T01:17:42] enqueue: {"ok":true,"id":"comment-20260920-0117-1"}
      [2026-09-20T01:21:38] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
      [2026-09-20T01:24:39] no candidates

  --- pipeline-heartbeat（終了コード 2） ---
    ══ pipeline-heartbeat.log（最終更新 09-20 01:20）
      [heartbeat] healed 1 issues, waiting 45s for effect...
      [heartbeat] digest: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789772463.197839","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789772463.197839","bot_id":"B0B2JT
      [heartbeat] actionable-alert: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789772463.657599","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789772463.657599","bot_id":"B0B2JT
      {"ok":true,"overall":"CRIT","results":[{"name":"login","level":"OK","detail":"logged_in","healable":false},{"name":"chrome_cdp","level":"OK","detail":"alive","healable":false},{"name":"
      [heartbeat] healed 1 issues, waiting 45s for effect...
      [heartbeat] digest: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789834827.353679","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789834827.353679","bot_id":"B0B2JT
      [heartbeat] actionable-alert: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789834827.732989","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789834827.732989","bot_id":"B0B2JT
      {"ok":true,"overall":"CRIT","results":[{"name":"login","level":"OK","detail":"logged_in","healable":false},{"name":"chrome_cdp","level":"OK","detail":"alive","healable":false},{"name":"

```

**終了コードは「最後に走ったときの結果」。** 載っているかとは別物。
毎回 落ちているなら、載っていても仕事をしていない。

## 5. 費用

**ソースとログを読むだけ。LLM を呼ばない。外しも載せもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

返信ループの実額は 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 $1.44
（`MAX_PICKS` は 4 のまま）。フォロー・アンフォロー系は $0（DOM 操作のみ）。
