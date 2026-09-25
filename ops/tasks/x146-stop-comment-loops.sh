#!/bin/bash
# **返信ループを止める。利用者の指示（2026-09-25）。費用 $0。**
#
# ## なぜ
#
# `x145` が一次情報で特定した。`2103379894306750770` は `comment-warmup` の産物で、
# **2 つ 同時に壊れている。**
#
#   本文  「シも今年は結局満額いったわ😉」  ← **「アタ」が落ちている**（一人称の頭）
#   親    （なし）                          ← **返信のつもりが単独の投稿になった**
#
# 重みは 28/280。**長さで切られたのではない。**
# `published_via: "auto-reply-no-approval"` なので承認も通っていない。
#
# **調べている間も出続ける。** だから先に止める。
#
# ## 止め方（**一覧から消すのではなく plist をリネームする**）
#
# `ops-heartbeat` が 30 分ごとに `ops/data/autoload-jobs.txt` のジョブを
# **`bootstrap` し直す。** 一覧から消すだけだと `unloaded` の警報が鳴り続け、
# `bootout` しただけだと **30 分後に戻ってくる。**
#
#   → **plist を `.disabled` にリネームする。** `.plist` で終わらないものは対象外になる
#
# ## rc=0 を証拠にしない（最上位ルール 13）
#
# `launchctl bootout` の rc も、`launchctl list | grep` が空なことも証拠にならない。
# **`launchctl print gui/<uid>/<ラベル>` が「通らなくなったこと」で確かめる。**
#
# ## やらないこと
#
# **投稿を消さない**（別タスク。利用者の判断を待つ）。
# **他のループを止めない**（フォロー系・監視系はそのまま）。**LLM も呼ばない（$0）。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/stop-comment-loops.md"

# 止める対象。**返信を出す 2 本だけ。**
TARGETS="ai.openclaw.comment-warmup ai.openclaw.comment-orchestrator"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

{
echo "# 返信ループを止める（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿は消していない。** 消すかどうかは利用者が決める。"
echo "> フォロー系・監視系のループは触っていない。"

echo
echo "## 1. 止める前の状態"
echo
echo '```'
for lb in $TARGETS; do
  if launchctl print "gui/$UID_N/$lb" >/dev/null 2>&1; then
    st="$(launchctl print "gui/$UID_N/$lb" 2>/dev/null | grep -E '^\s+(state|runs|last exit code) ' | tr -s ' ' | tr '\n' ' ')"
    printf '  %-38s **載っている**  %s\n' "$lb" "$st"
  else
    printf '  %-38s 載っていない\n' "$lb"
  fi
done
echo '```'
echo
echo "plist の在りか:"
echo
echo '```'
for lb in $TARGETS; do
  p="$LA/$lb.plist"
  if [ -f "$p" ]; then
    printf '  %-46s あり (%s bytes)\n' "$(basename "$p")" "$(wc -c < "$p" | tr -d ' ')"
  else
    printf '  %-46s **無い**\n' "$(basename "$p")"
    ls -1 "$LA" 2>/dev/null | grep -i "$(printf '%s' "$lb" | sed 's/^ai\.openclaw\.//')" | sed 's/^/    候補: /'
  fi
done
echo '```'

echo
echo "## 2. 止める（\`bootout\` → plist を \`.disabled\` にリネーム）"
echo
echo '```'
for lb in $TARGETS; do
  p="$LA/$lb.plist"
  echo "  ===== $lb ====="
  if [ ! -f "$p" ]; then
    echo "    plist が無いので何もしない"
    continue
  fi
  bo="$(launchctl bootout "gui/$UID_N/$lb" 2>&1)"
  printf '    bootout rc=%s  %s\n' "$?" "$(printf '%s' "$bo" | head -1)"
  mv "$p" "$p.disabled" 2>/dev/null
  if [ -f "$p.disabled" ] && [ ! -f "$p" ]; then
    echo "    リネーム: $(basename "$p") -> $(basename "$p").disabled"
  else
    echo "    **リネームできなかった。30 分後に載せ直される。**"
  fi
done
echo '```'

echo
echo "## 3. 止まったことの証拠（**rc ではなく \`print\` で見る**）"
echo
echo "**\`print\` が通らなくなっていれば止まっている。** 通るなら止まっていない。"
echo
echo '```'
ngc=0
for lb in $TARGETS; do
  if launchctl print "gui/$UID_N/$lb" >/dev/null 2>&1; then
    printf '  %-38s **まだ載っている（止まっていない）**\n' "$lb"
    ngc=$((ngc + 1))
  else
    printf '  %-38s 止まった（print が通らない）\n' "$lb"
  fi
done
printf '  ---\n  止まっていないもの: %s 件\n' "$ngc"
echo '```'
echo
echo "載せ直しの対象から外れたか（**\`.plist\` で終わらなければ対象外**）:"
echo
echo '```'
for lb in $TARGETS; do
  printf '  %-46s %s\n' "$lb.plist" "$( [ -f "$LA/$lb.plist" ] && echo '**まだ在る（載せ直される）**' || echo '無い（対象外になった）' )"
  printf '  %-46s %s\n' "$lb.plist.disabled" "$( [ -f "$LA/$lb.plist.disabled" ] && echo 'あり' || echo '-' )"
done
echo '```'

echo
echo "## 4. 触っていないもの"
echo
echo "**返信を出すループは、もう 1 本 ある。** 今回は指示の範囲外なので触っていない。"
echo
echo '```'
for lb in ai.openclaw.incoming-reply-watcher ai.openclaw.badge-followback ai.openclaw.reply-followback-check; do
  if launchctl print "gui/$UID_N/$lb" >/dev/null 2>&1; then
    printf '  %-42s 載ったまま\n' "$lb"
  else
    printf '  %-42s （載っていない）\n' "$lb"
  fi
done
echo '```'
echo
echo "> \`incoming-reply-watcher\` は**自分宛の返信に返す**ループ。同じ不具合を踏みうる。"
echo "> **止めるかどうかは利用者の判断。**"

echo
echo "## 5. 戻すとき"
echo
echo '```bash'
for lb in $TARGETS; do
  echo "  mv \"$LA/$lb.plist.disabled\" \"$LA/$lb.plist\""
  echo "  launchctl bootstrap gui/$UID_N \"$LA/$lb.plist\""
  echo "  launchctl print gui/$UID_N/$lb     # ← **これが通れば戻っている**"
done
echo '```'
echo
echo "**\`bootstrap\` の 2 回目は rc=5 になる。** それは「もう載っている」印で、失敗ではない。"

echo
echo "## 6. 費用"
echo
echo "**このタスク自体は launchd を触るだけで LLM を呼ばない（\$0）。**"
echo "止めたことで**減る**額は次のとおり（\`docs/recurring-job-costs.md\` の実測から）。"
echo
echo "| | 止める前（実測） | 止めた後 |"
echo "| --- | --- | --- |"
echo "| 1 回あたり | 約 \$0.0048 | **\$0** |"
echo "| 1 日あたり | **\$0.081** | **\$0** |"
echo "| 1 か月あたり | **約 \$2.43** | **\$0** |"
echo
echo "> 出典は 2026-09-21 の \`pipeline-heartbeat\` 自己計測（\`cost_24h_usd \$0.081\`）。"
echo "> **これは comment 系ループぶん。** 記事リフレッシュ（約 \$1.33/月・実測）は別で、止めていない。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '止まっていないもの: 0 件' "$OUT" 2>/dev/null; then
  echo "返信ループ 2 本を止めた（print で確認済み） / $(basename "$OUT")"
else
  echo "**止まっていないものが残っている。レポートを確認すること** / $(basename "$OUT")"
fi
