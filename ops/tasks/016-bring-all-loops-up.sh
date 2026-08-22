#!/bin/bash
# **4 つのループを全部 稼働状態にする。** 今日中が必須。
#
#   ① 会話の継続       auto-thread-chainifier
#   ② フォロー返し     badge-followback              （稼働中）
#   ③ アンフォロー     unfollow 系
#   ④ 能動フォロー     competitor-follower-follow / hashtag-follow
#
# 前提として分かっていること（014 の実測）:
#   - ④ の plist は Label も ProgramArguments も無く壊れている
#     → `.bak.20260615-v6-tactic`（7/05〜7/07 に動いていた頃）から復元する
#   - 両スクリプトとも LLM を呼ばない（SDK 0 / CLI 0）→ 追加費用 $0
#   - 18800 への CDP 接続が応答しない
#     → ただし 2026-08-09 に `*.bak18800` が一括作成されており、
#       **その日にポートを変えた可能性がある。18800 を決め打ちしない。**
#       実際に待ち受けているポートを探して、そこを叩く。
#
# **壊れたまま上書きしない。** 触る前に必ず退避する。
# **当て推量で plist を作らない。** 作る場合は、動いている兄弟 plist を
# テンプレートにして Label と対象スクリプトだけ差し替える。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/all-loops.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"

# 値だけ伏せる。キー名・パス・ポートは残す（診断に要る）
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

valid() {
  [ -f "$1" ] || return 1
  plutil -extract Label raw "$1" >/dev/null 2>&1 || return 1
  plutil -extract ProgramArguments json "$1" >/dev/null 2>&1 || return 1
  return 0
}

loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$1"; }

# plist を正常化して bootstrap する。戻り値: 0=載った
bring_up() {
  lbl="$1"
  CUR="$LA/$lbl.plist"
  if loaded "$lbl"; then echo "  - $lbl: 既にロード済み"; return 0; fi

  if ! valid "$CUR"; then
    echo "  - $lbl: 現行 plist が正常でない（Label/ProgramArguments が読めない）"
    BEST=""
    for B in $(ls -t "$LA/$lbl.plist."* 2>/dev/null); do
      valid "$B" && { BEST="$B"; break; }
    done
    if [ -z "$BEST" ]; then
      echo "  - $lbl: **正常なバックアップが無い。当て推量で作らないので飛ばす**"
      return 1
    fi
    [ -f "$CUR" ] && cp "$CUR" "$CUR.broken.$STAMP" 2>/dev/null
    cp "$BEST" "$CUR" || { echo "  - $lbl: 復元に失敗"; return 1; }
    echo "  - $lbl: $(basename "$BEST") から復元した"
  fi

  launchctl bootstrap "gui/$UID_N" "$CUR" >/dev/null 2>&1
  if loaded "$lbl"; then
    echo "  - $lbl: **ロード成功** / 起動=$(plutil -extract StartCalendarInterval json "$CUR" 2>/dev/null | cut -c1-100 || echo '')$(plutil -extract StartInterval raw "$CUR" 2>/dev/null | sed 's/^/interval=/' || true)"
    return 0
  fi
  echo "  - $lbl: **ロード失敗**"
  launchctl bootstrap "gui/$UID_N" "$CUR" 2>&1 | mask | head -2 | sed 's/^/      /'
  return 1
}

{
echo "# 4 ループの立ち上げ（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"

# ---------------------------------------------------------------- CDP
echo
echo "## 0. Chrome CDP の実際の待ち受けポートを探す"
echo
echo "2026-08-09 に \`*.bak18800\` が一括作成されている＝**その日にポートを変えた疑い。**"
echo "18800 を決め打ちせず、実際に開いているポートを探す。"
echo
CDP_PORT=""
# scripts が既定値として持っているポート
echo "### スクリプトが持つ既定ポート"
grep -rhoE 'localhost:[0-9]{4,5}|127\.0\.0\.1:[0-9]{4,5}' "$W/scripts"/*.js 2>/dev/null \
  | grep -oE '[0-9]{4,5}$' | sort | uniq -c | sort -rn | head -8
echo
echo "### 実際に待ち受けているポート（Chrome 系）"
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -iE 'chrome|Google' \
  | awk '{print $1, $9}' | sort -u | head -10 | mask
echo
echo "### /json/version に応答するポート"
for p in $(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -iE 'chrome|Google' \
           | grep -oE ':[0-9]{4,5}' | tr -d ':' | sort -u) 18800 9222 9223; do
  if curl -fsS --noproxy '*' --max-time 3 "http://127.0.0.1:$p/json/version" >/dev/null 2>&1; then
    echo "- **$p → 応答あり**"
    [ -z "$CDP_PORT" ] && CDP_PORT="$p"
  fi
done
[ -z "$CDP_PORT" ] && echo "- **どのポートも応答しない。**"

echo
echo "### chrome-cdp ジョブ"
for B in "$LA"/ai.openclaw.chrome-cdp.plist*; do
  [ -f "$B" ] || continue
  v="壊れている"; valid "$B" && v="正常"
  echo "- $(basename "$B") 更新=$(date -r "$B" '+%m-%d %H:%M' 2>/dev/null) → $v"
done
if ! loaded ai.openclaw.chrome-cdp; then
  echo "- launchctl: **未ロード** → 立ち上げる"
  bring_up ai.openclaw.chrome-cdp
else
  echo "- launchctl: ロード済み"
fi

# ---------------------------------------------------------------- ①
echo
echo "## ① 会話の継続（返信への返信）"
bring_up ai.openclaw.auto-thread-chainifier

# ---------------------------------------------------------------- ②
echo
echo "## ② フォロー返し"
bring_up ai.openclaw.badge-followback

# ---------------------------------------------------------------- ③
echo
echo "## ③ アンフォロー"
echo
echo "### unfollow 系の plist をすべて見る"
UF_FOUND=0
for P in "$LA"/*unfollow*.plist; do
  [ -f "$P" ] || continue
  lbl="$(basename "$P" .plist)"
  v="壊れている"; valid "$P" && v="正常"
  echo "- $lbl 更新=$(date -r "$P" '+%m-%d %H:%M' 2>/dev/null) → $v / launchctl=$(loaded "$lbl" && echo あり || echo なし)"
  UF_FOUND=1
done
[ "$UF_FOUND" = "0" ] && echo "（unfollow を名前に含む .plist が 1 つも無い）"
echo
for P in "$LA"/*unfollow*.plist; do
  [ -f "$P" ] || continue
  bring_up "$(basename "$P" .plist)"
done

# ---------------------------------------------------------------- ④
echo
echo "## ④ 能動フォロー"
bring_up ai.openclaw.competitor-follower-follow
bring_up ai.openclaw.hashtag-follow

# ---------------------------------------------------------------- 検証
echo
echo "## 最終確認（自己申告ではなく launchctl の実体）"
echo
printf '%-45s %s\n' "ジョブ" "状態"
for lbl in ai.openclaw.auto-thread-chainifier \
           ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow \
           ai.openclaw.hashtag-follow \
           ai.openclaw.chrome-cdp; do
  printf '%-45s %s\n' "$lbl" "$(loaded "$lbl" && echo '稼働' || echo '**未ロード**')"
done
for P in "$LA"/*unfollow*.plist; do
  [ -f "$P" ] || continue
  lbl="$(basename "$P" .plist)"
  printf '%-45s %s\n' "$lbl" "$(loaded "$lbl" && echo '稼働' || echo '**未ロード**')"
done

echo
echo "## ai.openclaw のジョブ一覧（現在）"
launchctl list 2>/dev/null | awk '{print $3}' | grep '^ai\.openclaw\.' | sort | mask
} > "$OUT" 2>&1

# heartbeat の 300 字に、判断に効く行だけ出す
up=0; down=""
for lbl in ai.openclaw.auto-thread-chainifier ai.openclaw.badge-followback \
           ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl"; then
    up=$((up + 1))
  else
    down="$down ${lbl#ai.openclaw.}"
  fi
done
uf="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -c 'unfollow' || true)"
echo "主要4件のうち稼働=${up}/4${down:+ / 未ロード:$down} / unfollow系=${uf}件 / $(basename "$OUT")"
