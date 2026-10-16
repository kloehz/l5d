---
name: godot-remote-interpolation
description: "Trigger: Godot remote interpolation, snapshot buffer, render cursor. Choose per-entity prediction or buffered presentation without hiding missing history."
license: Apache-2.0
metadata:
  author: kloehz
  version: "1.0"
---

## Activation Contract
Use when designing or reviewing networked visual motion for remote players or NPCs in Godot.

## Hard Rules
- Choose presentation per target/render pipeline: a locally controlled actor's owned input does not imply client ownership of its authoritative root; prediction/reconciliation remains distinct from remote/NPC buffered snapshots.
- Align aim and shot view time to the actual displayed target timeline used by combat. Do not force an ally's display timeline onto NPCs or local prediction. Interpolate a position and short yaw bracket; hold endpoints and do not extrapolate unless separately approved.
- Measure buffer delay from actual arrivals, ages, coalescing, and raw finite clock observations; never guess a universal delay.
- Reset on life/session/reconnect/settings/teleport changes. Keep cursor finite after reset and bound long frames.
- Do not mutate root physics, colliders, or input from presentation. Prefer a scene-first top-level visual node.
- Never mask missing-history/receiver failures with a fabricated fallback.

## Decision Gates
| Entity/state | Choice |
|---|---|
| Locally controlled actor / owned input | Choose narrow prediction or reconciliation while preserving server root authority. |
| Remote player or NPC | Buffer actual snapshots and render at measured historical time. |
| Missing bracket | Hold an actual endpoint; surface missing-history evidence. |

## Execution Steps
1. Identify simulation owner, rendered node, timestamp semantics, and reset events.
2. Measure arrivals and choose a bounded cursor/delay from evidence.
3. Interpolate only between valid samples; hold at either endpoint.
4. Test resets, nonfinite clocks, long frames, gaps, teleports, and simulation immutability.

## Output Contract
Return per-entity policy, clock and buffer evidence, reset/endpoint behavior, tests, and project-specific values clearly labeled non-universal.

## References
- [Interpolation boundaries and measured example](references/details.md)
