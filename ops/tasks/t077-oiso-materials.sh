#!/bin/bash
# **大磯プリンス記事のてこ入れ素材を確かめる。**
#
# t075 で「クロール済み - インデックス未登録」と分かった。記事を見ると、
# **X の実投稿 0 件・YouTube 0 件・写真カード 0 枚。** 一次の声が無い。
# `blog-article` スキルの「絶対に外さない 9 つ」の 8 番を満たしていない。
#
# ## なぜ Mac に投げるか
#
# クラウドセッションは `cdn.syndication.twimg.com` も `youtube.com` も
# **CONNECT 403 で塞がれている**（2026-09-14 に実測）。候補はクラウドの
# WebSearch で挙げたので、**実在と中身の確認だけ**をこちらでやる。
#
# ## やること
#
#   1. X 投稿 6 件を syndication API で引き、**本文・投稿者・日付**を出す
#   2. YouTube 5 本を oEmbed で引き、**タイトルと投稿者**を出す
#
# **JSON は python で読む**（`sed` で読まない・ops-task-runner ルール 5）。
# **`timeout` は使わない**（macOS に無い・ルール 14）。数十秒で終わる（ルール 15）。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t077-oiso-materials.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import contextlib, datetime as dt, json, socket, sys, urllib.error, urllib.parse, urllib.request

OUT = sys.argv[1]

TWEETS = [
    ("1940346162554486812", "Halohalo 旅行レジャー情報 / 大磯ロングビーチ 営業期間・宿泊者半額"),
    ("1227445236156313600", "さばお / デイユースでインフィニティプール・サウナ・温泉"),
    ("1814541069021028395", "SHO / サウナ 3 軒ハシゴ"),
    ("1305528886617227265", "Misa / 大磯プリンスホテルに宿泊"),
    ("934036817992499200",  "大磯ロングビーチ 公式 / THERMAL SPA S.WAVE 開業告知"),
    ("1859164371471183875", "大磯プリンスホテルボウリングセンター / 営業終了"),
]

VIDEOS = [
    ("_pajbI2NmeI", "4 種類のサウナと絶景インフィニティプール"),
    ("7lO8fT0GTtY", "完全版 ホテル紹介"),
    ("_z7JN_E4p0M", "コスパ最強 水着でサウナ＆テレワーク"),
    ("g9t_F28nsTM", "絶景サウナ 極上スパ体験"),
    ("AZMQIKdJDOQ", "THERMAL SPA S.WAVE ドローン動画（公式）"),
]

_ORIG = socket.getaddrinfo
def _v4(host, port, family=0, type=0, proto=0, flags=0):
    return _ORIG(host, port, socket.AF_INET, type, proto, flags)

@contextlib.contextmanager
def force_ipv4():
    socket.getaddrinfo = _v4
    try:
        yield
    finally:
        socket.getaddrinfo = _ORIG

def _unreachable(e):
    err = getattr(e, "reason", e)
    return isinstance(err, OSError) and err.errno in (-2, 65, 51, 113, 101)

def retry_ipv4(fn):
    try:
        return fn()
    except (urllib.error.URLError, OSError) as e:
        if not _unreachable(e):
            raise
        with force_ipv4():
            return fn()

UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}

def get(url):
    req = urllib.request.Request(url, headers=UA)
    return json.loads(urllib.request.urlopen(req, timeout=40).read())

L = ["# 大磯プリンス記事の素材（t077）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "## 1. X の実投稿", ""]

for tid, note in TWEETS:
    url = (f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a")
    L.append(f"### `{tid}` — {note}")
    L.append("")
    try:
        d = retry_ipv4(lambda u=url: get(u))
    except urllib.error.HTTPError as e:
        L += [f"❌ **取れなかった**: HTTP {e.code}（削除・非公開・ID 違いのいずれか）", ""]
        continue
    except Exception as e:
        L += [f"❌ **取れなかった**: {type(e).__name__}: {str(e)[:150]}", ""]
        continue
    # **JSON は構造を辿って読む。** sed で拾うと引用元の別人を掴む（ルール 5）
    user = d.get("user") or {}
    L += ["| 項目 | 値 |", "| --- | --- |",
          f"| 投稿者 | **{user.get('name','—')}**（@{user.get('screen_name','—')}） |",
          f"| 日時 | {d.get('created_at','—')} |",
          f"| いいね | {d.get('favorite_count','—')} |",
          f"| 写真 | {len((d.get('mediaDetails') or []))} 枚 |", "",
          "```", (d.get("text") or "").strip()[:500], "```", ""]

L += ["", "## 2. YouTube", ""]
for vid, note in VIDEOS:
    oe = ("https://www.youtube.com/oembed?format=json&url="
          + urllib.parse.quote(f"https://www.youtube.com/watch?v={vid}", safe=""))
    L.append(f"### `{vid}` — {note}")
    L.append("")
    try:
        d = retry_ipv4(lambda u=oe: get(u))
    except urllib.error.HTTPError as e:
        L += [f"❌ **取れなかった**: HTTP {e.code}（削除・非公開・埋め込み禁止のいずれか）", ""]
        continue
    except Exception as e:
        L += [f"❌ **取れなかった**: {type(e).__name__}: {str(e)[:150]}", ""]
        continue
    L += ["| 項目 | 値 |", "| --- | --- |",
          f"| タイトル | **{d.get('title','—')}** |",
          f"| チャンネル | {d.get('author_name','—')} |",
          f"| 埋め込み可 | {'はい' if d.get('html') else 'いいえ'} |", ""]

L += ["", "## 使い方", "",
      "- **タイトルが大磯プリンス以外なら使わない。** 2026-08-27 に 3 本 これで弾いた",
      "- **X は宣伝ではなく体験の投稿を選ぶ。** `#AD` が付くものは後回し",
      "- `❌` のものは記事に入れない。**組み立てた URL は必ず壊れる**", ""]

open(OUT, "w").write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
exit 0
