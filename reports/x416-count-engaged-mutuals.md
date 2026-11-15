# 「反応をくれた人」を数える（2026-11-03 23:50 JST・読むだけ・$0）

## 反応の記録の場所と読み方（コード）
```
49:const ONEWAY_IGNORE_ENGAGED = process.env.ONEWAY_IGNORE_ENGAGED !== "0";
53:const ENGAGED = path.join(WS, "data", "reply-followers.json");
85:function harvest(file) {
281:  const engaged = harvest(ENGAGED);
282:  const followedMap = harvest(FOLLOWED);
396:    if (engaged.has(k) && !(oneWayStage && ONEWAY_IGNORE_ENGAGED)) return "反応をくれた人";
424:    const rf = JSON.parse(fs.readFileSync(ENGAGED, "utf8"));
625:      const rf = JSON.parse(fs.readFileSync(ENGAGED, "utf8"));
function harvest(file) {
  const byHandle = new Map();
  let root;
  try { root = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { return byHandle; }
  const seen = new Set();
  const walk = (node, keyHint) => {
    if (!node || typeof node !== "object" || seen.has(node)) return;
    seen.add(node);
    if (Array.isArray(node)) { for (const v of node) walk(v, null); return; }
    const at = node.followed_at || node.at || node.created_at || node.followedAt;
    // **容器のキーを handle と見なさない。** 入れ子の {handles:{0:{...}}} で
    // "handles" を 1 件 数えてしまった（2026-09-27 のローカル検証で発見）。
    // **日付の有無では切らない**——日付が無い記録まで落ちて、守る側が弱くなる。
    // 中に子オブジェクトを持つものが容器、持たないものが記録、と見る。
    const isLeaf = !Object.values(node).some((v) => v && typeof v === "object");
    const h = node.handle || node.screen_name || node.username || (isLeaf ? keyHint : null);
    if (h && typeof h === "string" && /^[A-Za-z0-9_]{1,15}$/.test(h.replace(/^@/, ""))) {
      const k = h.replace(/^@/, "").toLowerCase();
      const prev = byHandle.get(k);
      if (!prev || (at && !prev.at)) byHandle.set(k, { at: at || (prev && prev.at) || null });
    }
    for (const [k, v] of Object.entries(node)) walk(v, typeof k === "string" ? k : null);
  };
```

## 数
```
ENGAGED の定義: ENGAGED = process.env.ONEWAY_IGNORE_ENGAGED !== "0"
読むファイル: (無し)
相互 406 件のうち 反応の記録あり 0 件 → 認証済み 0 ／ **未認証 0 **
未認証で反応の記録ありの、最後の反応: {"30日以内":0,"30〜90日":0,"90日より前":0,"日付なし":0}
```
