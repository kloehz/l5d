---
name: godot-network-verification
description: "Trigger: Godot multiplayer runtime verification, graphical clients, delay testing. Prove real rendered behavior and preserve failure evidence."
license: Apache-2.0
metadata:
  author: kloehz
  version: "1.0"
---

## Activation Contract
Use when validating multiplayer behavior through real Godot clients, controlled network delay, exported builds, or delivery evidence.

## Hard Rules
- Match the runner to the question: focused unit/native checks for decoder or input contracts; actual two-graphical-client render/post-draw evidence for visible-motion acceptance. Do not turn every unit check into end-to-end GUI testing. Track authority, own input, and no-broadcast behavior in the appropriate runner.
- Prove movement over time/displacement, continuous motion, stationary behavior, and dead behavior. Do not let screenshot capture block measured intervals.
- Separate global frame pauses from network holds. Raw errors, warnings, and leaks override exit code zero except documented causal negatives.
- Use unique process groups, absolute CWD, timeouts, and macOS-compatible Python—not assumed GNU `timeout`.
- Preserve failure markers, receipts, partial output, and preimages; never rerun one-shot tests casually.
- Distinguish scene source from frozen EXE/PCK and compare source hashes. Never automate VPS/server changes absent explicit authorization.

## Decision Gates
| Result | Report |
|---|---|
| Local direct vs WAN | Separate measured evidence and human acceptance. |
| Exit zero with raw errors | Failure unless a causal negative exception is documented. |
| Same binary identity assumed | Verify EXE/PCK and source hashes individually. |

## Execution Steps
1. Define process ownership, CWD, timeout, evidence paths, and one-shot behavior.
2. Run the exact focused unit/native runner for logic contracts; for visible-motion acceptance, exercise two actual graphical clients and collect nonblocking render/runtime measurements.
3. Preserve raw warnings/errors and classify only proven causal exceptions.
4. Report local/WAN/human/capacity evidence separately; make no unsupported claims.

## Output Contract
Return exact commands and outcomes, preserved artifacts, source/runtime identity, limits, and separate human-acceptance status.

## References
- [Runtime evidence and safe runner boundaries](references/details.md)
