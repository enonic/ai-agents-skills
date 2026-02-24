# Known Debug Patterns

Concise heuristics from past debug sessions. Max ~5 lines per entry. Prune when file exceeds ~30 entries.

---

## Serializer NPE on modify

**Symptom**: `ScriptValueTranslator.handleValue` throws NPE after `node.modify()`
**Cause**: Any null property in the returned object graph triggers it, not just the edited field. The serializer iterates the entire object.
**Fix**: Sanitize the entire returned object — strip nulls before returning from the editor function. Don't assume you know which property is null.
**Applies to**: XP 8+ (stricter null handling than XP 7)

---

## Silent app — no log entries at all

**Symptom**: User reports "app doesn't load" or "I can't see it in logs". Grepping `server.log` for the app name returns zero results.
**Cause**: The app JAR was never deployed to the directory XP reads from. The deploy target path doesn't match `$XP_HOME/deploy/`.
**Fix**: Verify where the build tool places the JAR vs. where XP actually reads from. Check project deploy configuration and `$XP_HOME`.
**Key insight**: Actual app errors (bad code, version mismatch) always produce log entries. Complete absence means XP never saw the JAR.
