---
name: godot-shot-view-timeline
description: "Trigger: Godot lag compensation, shot view time, rewind timeline. Align firing with displayed state and preserve authoritative bounded adjudication."
license: Apache-2.0
metadata:
  author: kloehz
  version: "1.0"
---

## Activation Contract
Use when implementing or reviewing networked firing, hit validation, rewind, or display-time alignment in Godot.

## Hard Rules
- Derive shot view time from the same actual display cursor used by rendered feet, camera aim, and target presentation.
- Verify the target's tick rate and semantics explicitly; apply any `(tick+1)/rate` conversion exactly once where required. A 30 Hz mapping is only a project-specific example, not a universal rate.
- Keep server-authoritative rewind bounded by retained history and cadence/life/session/finite/queue guards.
- Include transit and queue delay in evidence; distinguish received-hit confirmation from adjudication time. Rejected shots need not receive confirmation.
- For overlapping equal capsules, preserve existing gating and report unique geometry/tie bounds; do not silently pass ID mismatch.

## Decision Gates
| Evidence | Action |
|---|---|
| Display and shot clocks differ | Fix shared timestamp source before tuning rewind. |
| Historical target is ambiguous | Preserve gate; capture raw poses and ray distances. |
| Retry uses cached shot | Verify owner, life/session, and shot-cache identity. |

## Execution Steps
1. Trace displayed cursor through fire request, transit, queue, and server adjudication.
2. Verify tick mapping and clamp against retained history.
3. Preserve authoritative cadence, ownership, life/session, finite-input, queue, and replay checks.
4. Test real accepted shots, target and cache identity, confirmation timing, and ambiguous geometry.

## Output Contract
Return the timeline mapping, bounded authority checks, actual runtime evidence, ambiguity handling, and project measurements marked non-universal.

## References
- [Shot timeline, guardrails, and evidence](references/details.md)
