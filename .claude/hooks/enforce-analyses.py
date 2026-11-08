#!/usr/bin/env python3
"""Stop フック: 調査の結果を読んだのに、作戦室の分析レポートに入れずに終わろうとしたら差し戻す。

CLAUDE.md 最上位ルール 21（2026-10-31）と決定ログ 2026-11-08:
「調査・分析の結果は、その場の調査も含めて必ず作戦室の分析レポート（db の analyses）に 1 件入れる」。
2026-11-08、tweet2 が伸びている投稿 45 本の調査（x440）を読んで候補を作り、報告まで済ませたのに
analyses に入れていなかった。決まりは CLAUDE.md に書いてあったが、フックが無く、思い出さなければ素通りしていた。
利用者が「フックで止める」を選んだ。

判定（このターンの中だけを見る）:
  1. Mac の調査のレポート（`origin/ops/heartbeat:reports/...` を git show などで読んだもの）を読んだか
     - 調査とみなすのは、レポートの中身に「読むだけ」がある、またはファイル名に
       read / buzz / terms / research / survey / inventory / measure / diagnose / why が入っているもの
  2. 読んだあとに、ArtifactData で collection が analyses の書き込み（set / update / batch）をしたか
  1 があって 2 が無ければ差し戻す。

入れなくてよい理由があるときは、本文に「分析レポートに入れない理由:」と書けば通す
（例: 投稿の結果を確かめただけ・前に入れた調査の続き）。

安全側の設計（enforce-japanese.py と同じ）:
  - 入力やトランスクリプトが読めない場合は素通しする
  - stop_hook_active が立っている再入時は素通しする（無限ループ防止）
"""

import json
import re
import sys

PASS = 0
BLOCK = 2

REPORT_READ = re.compile(r"origin/ops/heartbeat:reports/([^\s'\"|;)]+)")
RESEARCH_NAME = re.compile(r"(read|buzz|terms|research|survey|inventory|measure|diagnose|why)", re.IGNORECASE)
ESCAPE = "分析レポートに入れない理由"

REMINDER = """CLAUDE.md 最上位ルール 21・決定ログ 2026-11-08 違反: 調査の結果を読んだのに、作戦室の分析レポートに入れていない。

利用者の指示（2026-11-08）:「こういったアドホックの調査情報は絶対に作戦室に格納して」
同じ日に、伸びている投稿 45 本の調査を入れ忘れて「書き足しているのになぜやっていないの」と指摘された。

ArtifactData(action="set", url="https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN", collection="analyses",
  doc_id="<YYYY-MM-DD>-<短い英字>", data={date, by, kind, title, question, summary, points, url}) で 1 件入れてから終えること。
入れなくてよいものなら、本文に「分析レポートに入れない理由: …」と書く。

このターンで読んだ調査のレポート:
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


def result_text(block):
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(part.get("text", "") for part in content if isinstance(part, dict))
    return ""


def writes_analyses(tool_input):
    if not isinstance(tool_input, dict):
        return False
    action = tool_input.get("action")
    if action in ("set", "update") and tool_input.get("collection") == "analyses":
        return True
    if action == "batch":
        for write in tool_input.get("writes") or []:
            if isinstance(write, dict) and write.get("collection") == "analyses" and write.get("op") in ("set", "update"):
                return True
    return False


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return PASS
    if payload.get("stop_hook_active"):
        return PASS
    path = payload.get("transcript_path")
    if not path:
        return PASS
    try:
        entries = load_transcript(path)
    except Exception:
        return PASS

    start = 0
    for index, entry in enumerate(entries):
        if is_real_user_message(entry):
            start = index
    turn = entries[start:]

    reads = {}  # tool_use_id -> [report names]
    results = {}
    order = []  # (position, kind, payload)
    escaped = False
    for position, entry in enumerate(turn):
        for block in content_blocks(entry):
            kind = block.get("type")
            if kind == "tool_use":
                name = block.get("name", "")
                tool_input = block.get("input") or {}
                if name == "Bash":
                    names = REPORT_READ.findall(str(tool_input.get("command", "")))
                    if names:
                        reads[block.get("id")] = names
                        order.append((position, "read", block.get("id")))
                if name.endswith("ArtifactData") and writes_analyses(tool_input):
                    order.append((position, "write", None))
            elif kind == "tool_result":
                results[block.get("tool_use_id")] = result_text(block)
            elif kind == "text" and entry.get("type") == "assistant" and ESCAPE in block.get("text", ""):
                escaped = True
    if escaped:
        return PASS

    first_research = None
    research_names = []
    for position, kind, tool_id in order:
        if kind != "read":
            continue
        names = reads.get(tool_id, [])
        text = results.get(tool_id, "")
        hit = [n for n in names if RESEARCH_NAME.search(n)]
        if hit or "読むだけ" in text:
            research_names.extend(hit or names)
            if first_research is None:
                first_research = position
    if first_research is None:
        return PASS
    if any(kind == "write" and position >= first_research for position, kind, _ in order):
        return PASS

    unique = list(dict.fromkeys(research_names))[:8]
    sys.stderr.write(REMINDER + "\n".join("- " + n for n in unique) + "\n")
    return BLOCK


if __name__ == "__main__":
    sys.exit(main())
