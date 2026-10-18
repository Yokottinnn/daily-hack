# 告知が落ちた理由・2 回目（2026-10-18 12:22:06 JST・読むだけ・$0）

## 1. ログの child_stdout / child_stderr

```
  step=thread-main-exec
  child_stdout={"ok":false,"step":"text-safety","error":"decode/validation failed","reason":"validation_failed_after_decode","details":{"ok":false,"reason":"too_long_weighted","details":{"weighted":2375,"limit":280,"chars":1325,"sample":"Amazonプライム感謝祭と、楽天市場の秋のお買い物マラソン。\n同じ1万円の買い物でも、ポイントが増える条件が正反対なの"}}}

  child_stderr=(空)
```

## 2. lib/text-safety.js の検査

```
       183 /Users/ny/.openclaw/workspace/scripts/lib/text-safety.js
6: *   validatePostText(text, opts) → { ok, reason, details }
7: *   decodeBase64Safe(b64)        → { ok, text, reason }
11: *   2. lone surrogate / invalid surrogate pair (UTF-16 整合性 NG)
28:  for (let i = 0; i < text.length; i++) {
31:      // high surrogate must be followed by low surrogate
32:      const next = i + 1 < text.length ? text.charCodeAt(i + 1) : 0;
36:      // low surrogate without high
44:  for (let i = 0; i < text.length; i++) {
49:    if (c < 0x20) return { found: true, codepoint: c, position: i };
51:    if (c >= 0x80 && c <= 0x9F) return { found: true, codepoint: c, position: i };
53:  return { found: false };
60:  for (let i = 0; i < text.length; ) {
86: * 上限 280 を超えると「ポストする」ボタンが aria-disabled のままになり、投稿できない。
93:  const withoutUrls = String(text).replace(/https?:\/\/\S+/g, "U".repeat(23));
105:  const maxWeighted = opts.maxWeighted ?? 280;
108:  if (text == null) return { ok: false, reason: "null_or_undefined" };
109:  if (typeof text !== "string") return { ok: false, reason: "not_a_string", details: typeof text };
110:  if (text.trim().length === 0) return { ok: false, reason: "empty_or_whitespace" };
111:  if (text.length < minLen) return { ok: false, reason: "too_short", details: text.length };
116:    return {
118:      reason: "too_long_weighted",
119:      details: { weighted, limit: maxWeighted, chars: text.length, sample: text.slice(0, 60) },
124:    return { ok: false, reason: "U+FFFD_replacement_char", details: text.slice(0, 80) };
127:    return { ok: false, reason: "lone_surrogate", details: text.slice(0, 80) };
131:    return { ok: false, reason: "illegal_control_char", details: ctrl };
135:    return { ok: false, reason: "low_printable_ratio", details: { ratio, threshold: printableRatioThreshold, sample: text.slice(0, 80) } };
138:  return { ok: true, ratio };
143: * If the decoded text fails validation, return { ok: false } so caller can abort BEFORE
151:    return { ok: false, reason: "base64_decode_threw", details: e.message };
154:  // Re-encode and compare lengths as a sanity check.
155:  const reEncoded = raw.toString("base64").replace(/=+$/, "");
156:  const cleanInput = b64.replace(/\s/g, "").replace(/=+$/, "");
158:    return { ok: false, reason: "base64_roundtrip_mismatch", details: { in_len: cleanInput.length, re_len: reEncoded.length } };
165:  if (reEncBytes.length !== raw.length || !reEncBytes.equals(raw)) {
166:    return { ok: false, reason: "utf8_decode_lossy", details: { src_bytes: raw.length, decoded_bytes: reEncBytes.length, sample: text.slice(0, 80) } };
170:  if (!v.ok) return { ok: false, reason: "validation_failed_after_decode", details: v };
172:  return { ok: true, text };
```

## 3. キューの [1/2] の本文を同じ検査に通す（送信しない）

```
  [1/2] 文字 1325 / weightedLength 2375 / ok=false reason=validation_failed_after_decode details={"ok":false,"reason":"too_long_weighted","details":{"weighted":2375,"limit":280,"chars":1325,"sample":"Amazonプライム感謝祭と、楽天市場の秋のお買い物マラソン。\n同じ1万円の買い物でも、ポイントが増える条件が正反対なの"}}
  [2/2] 文字 133 / weightedLength 131 / ok=true reason=- details=null
```

**投稿していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
