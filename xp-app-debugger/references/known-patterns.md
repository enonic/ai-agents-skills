# Known Debug Patterns

Concise heuristics from past debug sessions. Max ~5 lines per entry. Prune when file exceeds ~30 entries.

---

## Serializer NPE on modify

**Symptom**: `ScriptValueTranslator.handleValue` throws NPE after `node.modify()`
**Cause**: Any null property in the returned object graph triggers it, not just the edited field. The serializer iterates the entire object.
**Fix**: Sanitize the entire returned object — strip nulls before returning from the editor function. Don't assume you know which property is null.
**Applies to**: XP 8+ (stricter null handling than XP 7)
