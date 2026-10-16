---
name: netfox-input-state-safety
description: "Trigger: Netfox input readiness, state publication, scheduler cadence. Gate outbound state on live peer, fresh provenance, and owned tick data."
license: Apache-2.0
metadata:
  author: kloehz
  version: "1.0"
---

## Activation Contract
Use when reviewing startup, reconnect, input history, state publication, or Netfox scheduler timing.

## Hard Rules
- Require the native peer to be registered and `STATE_CONNECTED`; an active pointer alone is insufficient. Never publish to a disconnecting peer.
- Bind readiness evidence to startup generation, peer, and fresh clock/RTT/jitter measurements with observed budgets.
- Gate publication/readiness only; do not stop recording, prediction, or history trimming.
- Require the exact non-null owned state at the target tick before encoding. Do not fabricate history, mutate private clocks, or use renderer nil fallbacks.
- Age ACK references per peer without shrinking required input history. Prove scheduler cadence from actual ticks, not presumed interval constants.

## Decision Gates
| Condition | Result |
|---|---|
| Peer pointer exists, native state not connected | Not ready; publish nothing. |
| Stale generation or measurement | Not ready; wait for fresh evidence. |
| Sparse input or missing owned tick | Do not encode fabricated state. |

## Execution Steps
1. Trace native peer lifecycle, generation, clock sample freshness, and input ownership.
2. Derive freshness/history budget from observed scheduler and network metrics.
3. Capture actual encoded bytes and clock provenance; treat metrics as context, not packet proof.
4. Test wrong peer state, reconnect, sparse/old packets, history, ACK aging, and next fresh publication.

## Output Contract
Return readiness proof, peer/generation/tick provenance, actual scheduler evidence, byte-level validation, and pinned-version caveats.

## References
- [Readiness and publication safety boundaries](references/details.md)
