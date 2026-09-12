#!/bin/bash
# **エアウォレット招待キャンペーンの一次情報を取る。費用 $0（LLM を呼ばない）。**
#
# ## なぜ Mac に頼むのか
#
# クラウドセッションからは **egress proxy が 403 を返して公式ページに到達できない。**
#
#   point.recruit.co.jp → CONNECT tunnel failed, response 403
#   coin-plus.jp        → 同上
#   x.com               → 同上
#
# 検索スニペット経由では中身が取れたが、**数字が割れている。**
#
#   「両方に 500円」  ／ 別スニペットでは「両方に 300円」
#   「抽選 30名 に10万円」／ 別では「抽選 300名 に1万円」
#   付与「2026年9月下旬ごろ」／ 別では「10月頃」
#
# `airwallet202606` と `airwallet202608` の **別キャンペーンが混ざっている。**
# **X 投稿の 1 行目に置く数字なので、確定しないと書けない。**
#
# ## 取るもの（推測で埋めない）
#
#   - キャンペーン期間（開始日・**終了日**）
#   - 招待した人／された人が もらえる額
#   - 達成条件
#   - 特典の加算時期
#
# **見つからない項目は「記載なし」と書く。それらしい数字を置かない**（最上位ルール 11）。
#
# ## やらないこと
#
# **投稿しない。Chrome を触らない。LLM を呼ばない。ジョブをロード／アンロードしない。**
# curl で公開ページを読むだけ。
set -uo pipefail

OUT="${OPS_REPORT_DIR:-/tmp}/airwallet-campaign.md"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36'
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 公開ページのみ。秘密は扱わないが、念のため素通しの保険をかける
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }

# HTML → 素のテキスト。script/style を落としてからタグを剥がす
detag() {
  perl -0777 -pe 's{<(script|style|noscript)\b.*?</\1>}{}gis;
                   s{<br\s*/?>}{\n}gi; s{</(p|div|li|h[1-6]|tr|td|th)>}{\n}gi;
                   s{<[^>]+>}{}g;
                   s{&nbsp;}{ }g; s{&amp;}{&}g; s{&lt;}{<}g; s{&gt;}{>}g; s{&#39;}{'"'"'}g; s{&quot;}{"}g;' \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | grep -v '^$'
}

{
echo "# エアウォレット招待キャンペーンの一次情報"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> クラウド側は proxy が 403 で公式に届かない。**Mac から読むためのタスク。**"
echo "> 取れなかった項目は **「記載なし」** と書く。推測で埋めない（最上位ルール 11）。"

# ═══════════ 0. 外に出られるか ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
if curl -sS -o /dev/null -w '' --max-time 15 https://point.recruit.co.jp/ 2>/dev/null; then
  echo "  point.recruit.co.jp : 到達できる"
else
  echo "  point.recruit.co.jp : **到達できない**"
  echo
  echo "  Mac からも読めない。ネットワークか DNS を疑う。"
fi
echo '```'

# ═══════════ 1. 各ページを取る ═══════════
URLS="
https://point.recruit.co.jp/recruitid/doc/campaign/aw/airwallet202608_invitation/Aeg7a/
https://point.recruit.co.jp/recruitid/doc/campaign/aw/airwallet202606_invitation/
https://point.recruit.co.jp/recruitid/doc/campaign/
"

echo
echo "## 1. 各ページの実物"
echo
echo "**どれが「いま」のキャンペーンかは、期間の記載で判定する。**"

i=0
for u in $URLS; do
  [ -z "$u" ] && continue
  i=$((i + 1))
  f="$TMP/p$i.html"
  code=$(curl -sSL --max-time 30 -A "$UA" -o "$f" -w '%{http_code}' "$u" 2>/dev/null || echo 000)
  bytes=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
  echo
  echo "### ($i) $u"
  echo
  echo '```'
  echo "  HTTP $code / ${bytes:-0} bytes"
  if [ "$code" != "200" ] || [ "${bytes:-0}" -lt 500 ]; then
    echo "  **取れなかった。この URL からは判断しない。**"
    echo '```'
    continue
  fi

  detag < "$f" > "$TMP/p$i.txt" 2>/dev/null

  echo
  echo "  --- タイトル ---"
  grep -oE '<title>[^<]*' "$f" 2>/dev/null | sed 's/<title>//' | head -1 | sed 's/^/    /' | secrets

  echo
  echo "  --- 期間・金額・条件を含む行（そのまま） ---"
  grep -nE 'キャンペーン期間|対象期間|実施期間|202[0-9]年[0-9]+月[0-9]+日|[0-9,]+円|[0-9,]+ポイント|本人確認|リクルートID連携|加算|付与|エントリー|抽選|招待' \
    "$TMP/p$i.txt" 2>/dev/null | head -40 | cut -c1-300 | sed 's/^/    /' | secrets
  echo '```'
done

# ═══════════ 2. 招待リンクの飛び先 ═══════════
echo
echo "## 2. 保存済みの招待リンクの飛び先"
echo
echo "リポジトリの \`src/data/referrals.ts\` にある \`air-wallet\` の URL。"
echo "**コードそのものはここに出さない**（公開リポジトリに載るため）。"
echo
echo '```'
loc=$(curl -sS -o /dev/null --max-time 20 -A "$UA" -w '%{http_code} %{redirect_url}' \
      'https://coinplus.go.link/jH372' 2>/dev/null || echo "000 -")
echo "  HTTP/redirect: $(printf '%s' "$loc" | cut -c1-200 | secrets)"
echo '```'

# ═══════════ 3. まとめ ═══════════
echo
echo "## 3. この後やること"
echo
echo "上の (1)〜(3) で **期間の終了日と特典額が一意に決まったら**、"
echo "その数字だけを使って X 投稿の草案を書く。**割れていたら書かない。**"
echo
echo "判定できなかった場合は、アプリの \`設定/アカウント → 友だち招待\` 画面が"
echo "**一次情報として最も確実**（表示されている額と期限がそのまま今の条件）。"
} > "$OUT" 2>&1

echo "エアウォレット キャンペーン一次情報 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
