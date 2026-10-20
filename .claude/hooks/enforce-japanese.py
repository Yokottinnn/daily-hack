#!/usr/bin/env python3
"""Stop フック: 利用者向けの本文を英語で書いて終わろうとしたら差し戻す。

CLAUDE.md 最上位ルール 22「利用者への本文・報告・ダイアログは必ず日本語」は、
文書に書き、毎ターン注入（dialog-rule-reminder.sh）までしても守られなかった。
2026-10-18、注入を入れた直後のターンで、記事の報告を英語で書いて指摘された。

このターンで利用者に見える文章（本文のテキストと AskUserQuestion の問い・選択肢）を
すべて集め、英字が多く日本語がほとんど無いものが 1 つでもあれば差し戻す。

判定の前に取り除くもの（英語でよい部分）:
  - コードブロック・インラインコード・URL・引用行
  - パスや識別子（英数字と記号だけの語）は英字として数えるが、短い文は判定しない

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
URL = re.compile(r"https?://\S+")
QUOTE_LINE = re.compile(r"^\s*>.*$", re.MULTILINE)
JAPANESE = re.compile(r"[぀-ヿ㐀-䶿一-鿿ｦ-ﾟ]")
LATIN = re.compile(r"[A-Za-z]")

# 英字がこれ未満の短い文は判定しない（「OK」「PR #1100」などで誤検知しない）
MIN_LATIN = 40
# 日本語の文字が、日本語＋英字のうちこの割合未満なら「英語の文章」とみなす
MIN_JAPANESE_RATIO = 0.25

REMINDER = """CLAUDE.md 最上位ルール 22 違反: 利用者に見える文章を英語で書いている。

利用者の指示（2026-10-18）:「日本語で返信して。何度も言うけど、英語も理解は出来るが
使うのに翻訳するのが面倒なので。これは全てのセッションにおいて必ずルール化して徹底してください」

本文・報告（「こういうことをしました」）・AskUserQuestion の問いと選択肢は、必ず日本語で書き直すこと。
英語のままでよいのは、コード・コマンド・URL・ファイル名・ログの引用だけ。

該当した文章の冒頭:
"""


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


def visible_texts(turn):
    """このターンで利用者に見える文章を集める。"""
    texts = []
    for entry in turn:
        if entry.get("type") != "assistant":
            continue
        for block in content_blocks(entry):
            if block.get("type") == "text":
                texts.append(block.get("text", ""))
            elif block.get("type") == "tool_use" and block.get("name") == "AskUserQuestion":
                for q in (block.get("input") or {}).get("questions", []) or []:
                    texts.append(q.get("question", ""))
                    for opt in q.get("options", []) or []:
                        texts.append(f"{opt.get('label', '')} {opt.get('description', '')}")
    return texts


def is_english(text):
    for pattern in (FENCED_CODE, INLINE_CODE, URL, QUOTE_LINE):
        text = pattern.sub(" ", text)
    latin = len(LATIN.findall(text))
    if latin < MIN_LATIN:
        return False
    japanese = len(JAPANESE.findall(text))
    return japanese / (japanese + latin) < MIN_JAPANESE_RATIO


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

    hits = [t for t in visible_texts(current_turn(entries)) if is_english(t)]
    if hits:
        print(REMINDER + hits[0].strip()[:200], file=sys.stderr)
        return BLOCK
    return PASS


if __name__ == "__main__":
    sys.exit(main())
