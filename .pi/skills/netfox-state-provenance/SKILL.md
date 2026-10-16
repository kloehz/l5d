---
name: netfox-state-provenance
description: "Trigger: Netfox state provenance, decoder writes, empty diffs, shared history. Distinguish real receive updates from recorder activity and stale samples."
license: Apache-2.0
metadata:
  author: kloehz
  version: "1.0"
---

## Activation Contract
Use when diagnosing received-state freshness, decoder writes, recorder history, tick advancement, or cached poses in a Netfox project.

## Hard Rules
- Separate actual decoder writes from recorder-held copies and empty-diff success; advancing a latest tick does not prove pose data changed.
- Treat shared-history aliasing as valid only when the exact full/diff encoder path writes the shared dictionary. Recorder paths may bypass it.
- Keep vendor wire format and simulation behavior unchanged. Do not replace histories or blindly patch vendor code.
- Netfox 1.35.3 coupling is private and version-specific. Verify the target version and implementation before relying on it.

## Decision Gates
| Observation | Verify |
|---|---|
| Tick advances | Was a nonempty decoded property written? |
| History contains a pose | Is it a fresh copied complete finite pose, or retained data? |
| Shared map changes | Did the encoder path alias and write this exact map? |

## Execution Steps
1. Trace the target version's actual decoder and encoder full/diff writes.
2. Distinguish recorder/cached paths and mark generation/session ownership.
3. Test actual full writes, nonempty and empty diffs, alias identity, generation changes, cache copies, and stale values.
4. Report which observations prove a receive update; do not infer freshness from counters alone.

## Output Contract
Return version/path evidence, the write-vs-record distinction, freshness and generation behavior, focused tests, and unresolved private-API risk.

## References
- [Implementation boundaries and test matrix](references/details.md)
