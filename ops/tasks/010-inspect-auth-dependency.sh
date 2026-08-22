#!/bin/bash
# 「再認証しないといけない状態」を無くすために、まず依存関係を確定させる。
#
# Jordan の指示: **再認証が要る状態は絶対に嫌**。
#
# そのために答えを出すべき問いは 2 つ。
#   Q1. X 運用そのものは OAuth に依存しているのか？
#       依存していないなら、失効しても運用は止まらない。
#       （コストが Anthropic の従量で計上されている以上、
#         ジョブは API キーで動いている可能性が高いが、**確認していない**）
#   Q2. 依存しているなら、なぜ更新（refresh）に失敗するのか？
#       通常 OAuth の access token は自動更新される。
#       「could not be refreshed」が出たのは別の原因があるはず。
#
# **推測で答えを書かない。** 今日までに 3 回、実機を見ずに判断して外している。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
# トークンの値は一切出さず、「あるか無いか」と「期限」だけを出す。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/auth-dependency.md"
mask() { sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g'; }

{
echo "# 認証の依存関係（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
echo
echo "## Q1. X 運用のジョブは何で認証しているか"
echo
echo "### ジョブのスクリプトが API キーを読んでいるか（キー名のみ）"
for f in asuka-fill.js comment-warmup.js incoming-reply-watcher.js badge-followback.js; do
  S="$W/scripts/$f"
  [ -f "$S" ] || { echo "- $f: 存在しない"; continue; }
  keys="$(grep -oE 'process\.env\.[A-Z_]+' "$S" 2>/dev/null | sort -u | tr '\n' ' ')"
  cli="$(grep -cE '(spawn|exec|execSync).*(claude|anthropic)' "$S" 2>/dev/null || true)"
  sdk="$(grep -cE "require\(.@anthropic-ai|from ['\"]@anthropic-ai" "$S" 2>/dev/null || true)"
  echo "- $f: env=[${keys:-無し}] / claude CLI 起動=${cli}箇所 / SDK import=${sdk}箇所"
done

echo
echo "### plist が環境変数を渡しているか（キー名のみ・値は出さない）"
for P in "$HOME/Library/LaunchAgents"/ai.openclaw.*.plist; do
  [ -f "$P" ] || continue
  ks="$(plutil -extract EnvironmentVariables json "$P" 2>/dev/null \
        | grep -oE '"[A-Z_]+"[[:space:]]*:' | tr -d '":' | tr '\n' ' ')"
  [ -n "$ks" ] && echo "- $(basename "$P" .plist): ${ks}"
done

echo
echo "### OpenClaw の .env にどのキーが「入っているか」（値は出さない）"
for E in "$HOME/openclaw/config/.env" "$W/.env" "$HOME/.openclaw/.env"; do
  [ -f "$E" ] || continue
  echo "- $E:"
  grep -oE '^[A-Z_]+=' "$E" 2>/dev/null | tr -d '=' | sed 's/^/    /'
done

echo
echo "## Q2. Claude Code の OAuth はどこに、どう保存されているか"
echo
C="$HOME/.claude/.credentials.json"
if [ -f "$C" ]; then
  echo "- ファイル: あり（$C）"
  echo "- 権限: $(stat -f '%Sp %Su' "$C" 2>/dev/null || echo '不明')"
  echo "- 最終更新: $(date -r "$C" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '不明')"
  echo "- 含まれるキー: $(grep -oE '"[a-zA-Z]+"[[:space:]]*:' "$C" 2>/dev/null | tr -d '":' | sort -u | tr '\n' ' ')"
  echo "- refreshToken の有無: $(grep -qi 'refreshToken' "$C" && echo 'あり' || echo '**無し**')"
  echo "- expiresAt: $(grep -oE '"expiresAt"[[:space:]]*:[[:space:]]*[0-9]+' "$C" | grep -oE '[0-9]+' | head -1)"
else
  echo "- ファイル: 無し（Keychain に入っている可能性）"
fi
echo "- Keychain の項目: $(security find-generic-password -s 'Claude Code-credentials' 2>/dev/null >/dev/null && echo 'あり' || echo '見つからない')"

echo
echo "### 最終更新から見た自動更新の動き"
echo "credentials の mtime が数時間おきに動いていれば自動更新は効いている。"
echo "失効時刻の直前で止まっていれば、更新そのものが走っていない。"

echo
echo "## Q3. なぜ更新に失敗したのか（手がかり）"
echo
echo "### スリープ設定（寝ている間は更新が走らない）"
pmset -g 2>/dev/null | grep -E 'sleep|standby|hibernate|womp|powernap' | head -8

echo
echo "### 直近の再起動・スリープ履歴"
pmset -g log 2>/dev/null | grep -iE 'sleep|wake|shutdown' | tail -5 | cut -c1-110

echo
echo "### 認証まわりのエラー（ログ横断・直近10件）"
grep -rilE 'oauth|not logged in|could not be refreshed|401|unauthorized' "$W/logs" 2>/dev/null \
  | head -6 | while read -r L; do
  echo "#### $(basename "$L")  更新=$(date -r "$L" -u +%Y-%m-%dT%H:%MZ 2>/dev/null)"
  grep -hiE 'oauth|not logged in|could not be refreshed|401|unauthorized' "$L" 2>/dev/null \
    | tail -3 | mask | cut -c1-120
done

echo
echo "## Q4. rc-keeper は何をしているか"
echo
RK="$HOME/Library/LaunchAgents/com.dailyhack.rc-keeper.plist"
if [ -f "$RK" ]; then
  echo "- program: $(plutil -p "$RK" 2>/dev/null | awk '/ProgramArguments/,/\)/' \
      | grep -oE '"[^"]+"' | tr -d '"' | grep -v ProgramArguments | tr '\n' ' ' | cut -c1-200)"
  echo "- StartInterval: $(plutil -extract StartInterval raw "$RK" 2>/dev/null || echo '無し')"
else
  echo "- plist が見つからない"
fi
echo "- rc-keeper のログ末尾:"
for L in "$HOME"/Library/Logs/rc-keeper*.log "$W"/logs/rc-keeper*.log /tmp/rc-keeper*.log; do
  [ -f "$L" ] || continue
  echo "  ### $(basename "$L") 更新=$(date -r "$L" -u +%Y-%m-%dT%H:%MZ 2>/dev/null)"
  tail -3 "$L" 2>/dev/null | mask | cut -c1-110 | sed 's/^/  /'
done
} > "$OUT" 2>&1

echo "書き出した: $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
