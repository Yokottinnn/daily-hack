#!/usr/bin/env python3
"""Stop フック: 定期実行の話をしているのに、費用（1回・1日・1か月）を書かずに終わろうとしたら差し戻す。

CLAUDE.md 最上位ルール 2-B「反復作業は、必ずコストとセットで示す」は、文書と毎ターン注入があっても守られなかった。
2026-10-19、作戦室の毎日の更新を報告したとき費用を書かず、10/17 に週1→毎日へ変えたときも
費用を並べてダイアログで聞く手順を飛ばしていた。利用者に「重大なルール違反」と指摘された。

このターンで利用者に見える文章（本文と AskUserQuestion の問い・選択肢）に、定期実行を示す語があり、
かつ「1 回」「1 日」「1 か月（または月額）」の 3 つと金額（$ か 円）が揃っていなければ終了させない。

安全側の設計（enforce-dialog.py と同じ）:
  - 入力やトランスクリプトが読めない場合は素通しする
  - stop_hook_active が立っている再入時は素通しする（無限ループ防止）
"""

import json
import re
import sys

PASS = 0
BLOCK = 2

FENCED_CODE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE = re.compile(r"`[^`]*`")
QUOTE_LINE = re.compile(r"^\s*>.*$", re.MULTILINE)

# 定期実行・反復作業の話をしている合図
RECURRING = re.compile(
    r"毎日の更新|毎朝の更新|毎日更新|定期実行|定期的|ルーティン|毎日回|毎日 ?\d{1,2}:\d{2}|毎朝 ?\d{1,2}:\d{2}"
    r"|週 ?1 ?回|毎週|頻度|launchd|cron|スケジュール|自動で毎"
)

PER_RUN = re.compile(r"1\s*回")
PER_DAY = re.compile(r"1\s*日")
PER_MONTH = re.compile(r"1\s*か月|1\s*ヶ月|1\s*カ月|月額")
MONEY = re.compile(r"\$\s*\d|\d\s*円|\$0")

REMINDER = """CLAUDE.md 最上位ルール 2-B 違反: 定期実行・反復作業の話をしているのに、費用を書いていない。

利用者の指摘（2026-10-19）:「作戦室の更新をすることで追加のコストは発生しないんだよね？
そのコストの可否とそれを踏まえてやるかどうかの質問を私に選択式のダイアログで提示していないけどなぜ？
これは重大なルール違反なので、以降絶対に発生しないようにしてください」

同じメッセージの中に、1 回あたり・1 日あたり・1 か月あたりの費用を金額（$ か 円）で書くこと。
$0 なら $0 と書く。サブスクリプション枠で動くもの（このセッションの作業）は、その旨も添える。
始める・頻度を変える・量を増やすときは、費用を示したうえで、やるかどうかを AskUserQuestion で聞くこと。"""


def load_transcript(path):
    entries = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries


def content_blocks(entry):
    message = entry.get("message")
    if not isinstance(message, dict):
        return []
    content = message.get("content")
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    if isinstance(content, list):
        return [block for block in content if isinstance(block, dict)]
    return []


def is_real_user_message(entry):
    if entry.get("type") != "user":
        return False
    return any(block.get("type") == "text" for block in content_blocks(entry))


def current_turn(entries):
    for index in range(len(entries) - 1, -1, -1):
        if is_real_user_message(entries[index]):
            return entries[index + 1 :]
    return entries


def visible_text(turn):
    parts = []
    for entry in turn:
        if entry.get("type") != "assistant":
            continue
        for block in content_blocks(entry):
            if block.get("type") == "text":
                parts.append(block.get("text", ""))
            elif block.get("type") == "tool_use" and block.get("name") == "AskUserQuestion":
                for q in (block.get("input") or {}).get("questions", []) or []:
                    parts.append(q.get("question", ""))
                    for opt in q.get("options", []) or []:
                        parts.append(f"{opt.get('label', '')} {opt.get('description', '')}")
    text = "\n".join(parts)
    for pattern in (FENCED_CODE, INLINE_CODE, QUOTE_LINE):
        text = pattern.sub(" ", text)
    return text


def lacks_cost(text):
    if not RECURRING.search(text):
        return False
    return not (PER_RUN.search(text) and PER_DAY.search(text) and PER_MONTH.search(text) and MONEY.search(text))


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return PASS
    if payload.get("stop_hook_active"):
        return PASS
    path = payload.get("transcript_path")
    if not path:
        return PASS
    try:
        entries = load_transcript(path)
    except OSError:
        return PASS
    if lacks_cost(visible_text(current_turn(entries))):
        print(REMINDER, file=sys.stderr)
        return BLOCK
    return PASS


if __name__ == "__main__":
    sys.exit(main())
