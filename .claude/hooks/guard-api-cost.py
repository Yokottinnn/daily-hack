#!/usr/bin/env python3
"""PreToolUse フック: API 課金が発生しうるコマンドの実行を止める。

CLAUDE.md の最上位ルール 2「API 課金が発生する操作は必ず事前確認」を強制する。
文書に書くだけでは守られない前例があるため、実行の直前で機械的に止める。

止めるのは Console 経由で費用が発生しうる呼び出しだけ。Claude のサブスクリプション
枠内で動く対話そのものは対象外で、通常の開発コマンドも一切妨げない。

安全側の設計:
  - 入力が読めない場合は素通しする（作業を壊さない）。
  - grep や cat などの読み取り専用コマンドは、課金キーの名前を含んでいても通す。
    調査のために設定を覗く行為まで止めると、確認作業そのものができなくなる。
"""

import json
import re
import shlex
import sys

ALLOW = 0
BLOCK = 2

# 課金が発生する呼び出しの目印。エンドポイント・APIキー・課金CLI。
BILLABLE = [
    (r"api\.anthropic\.com", "Anthropic API エンドポイント"),
    (r"api\.openai\.com", "OpenAI API エンドポイント"),
    (r"generativelanguage\.googleapis\.com", "Google Generative Language API"),
    (r"aiplatform\.googleapis\.com", "Google Vertex AI"),
    (r"bedrock[-.]runtime", "Amazon Bedrock"),
    (r"api\.mistral\.ai", "Mistral API"),
    (r"api\.cohere\.(ai|com)", "Cohere API"),
    (r"\bANTHROPIC_API_KEY\b", "Anthropic APIキー"),
    (r"\bCLAUDE_API_KEY\b", "Claude APIキー"),
    (r"\bANTHROPIC_AUTH_TOKEN\b", "Anthropic 認証トークン"),
    (r"\bOPENAI_API_KEY\b", "OpenAI APIキー"),
    (r"\b(GEMINI|GOOGLE)_API_KEY\b", "Google APIキー"),
    (r"\bant\s+(messages|beta:)", "Anthropic CLI の課金エンドポイント呼び出し"),
    (r"\bopenai\s+api\b", "OpenAI CLI"),
]

# 中身を読むだけのコマンド。課金キーの名前を含んでも実行はしないので通す。
READ_ONLY = {
    "grep", "rg", "cat", "head", "tail", "less", "more", "ls", "find", "wc",
    "git", "jq", "diff", "stat", "file", "env", "printenv", "which", "type",
    "echo", "printf", "awk", "sed", "sort", "uniq", "tr", "cut", "basename",
    "dirname", "realpath", "test", "true", "false",
}

# パイプや連結の区切り。区切りごとに「実行するコマンド」を見る。
SPLIT = re.compile(r"\|\||&&|\||;|\n")

NOTICE = """CLAUDE.md 最上位ルール 2 違反: API 課金が発生しうるコマンドを実行しようとしている。

検出: {reason}
対象: {segment}

Console 経由で費用が発生しうる操作は、リサーチ・検証・動作確認であっても
着手前に利用者へ確認すること。確認なしに実行しない。

次のいずれかを行うこと。
1. AskUserQuestion のダイアログで、何にいくらかかる見込みかを説明して許可を得る。
2. 課金の発生しない方法（既存の記録を読む、ドキュメントを参照する）に切り替える。

なお Claude Code / Cowork の対話そのものはプラン利用であり、このルールの対象外。"""


def leading_command(segment):
    """区切りの中で実際に実行されるコマンド名を返す。環境変数代入は読み飛ばす。"""
    try:
        tokens = shlex.split(segment)
    except ValueError:
        return None  # クォートが閉じていない等。判定できないので不明扱い。
    for token in tokens:
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", token):
            continue  # FOO=bar cmd の形
        return token.rsplit("/", 1)[-1]
    return None


def find_violation(command):
    for segment in SPLIT.split(command):
        segment = segment.strip()
        if not segment:
            continue
        for pattern, reason in BILLABLE:
            if not re.search(pattern, segment):
                continue
            if leading_command(segment) in READ_ONLY:
                break  # 読み取りだけ。この区切りは問題なし
            return reason, segment
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return ALLOW

    if payload.get("tool_name") != "Bash":
        return ALLOW

    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return ALLOW

    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip():
        return ALLOW

    found = find_violation(command)
    if found:
        reason, segment = found
        print(NOTICE.format(reason=reason, segment=segment.strip()), file=sys.stderr)
        return BLOCK

    return ALLOW


if __name__ == "__main__":
    sys.exit(main())
