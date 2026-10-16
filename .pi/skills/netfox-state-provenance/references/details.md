# Netfox received-state provenance

Use the repository's `zombie_corridor_mvp/game/received_player_states.gd` as an illustrative app-level cache, not a portable Netfox API. Its buffer aliases an underlying dictionary; that fact does not establish that every recorder or decoder updates it. Verify the exact pinned dependency and trace full-snapshot and diff application to the actual write site.

## Evidence matrix

| Path | Evidence required |
|---|---|
| Full state | Observe decoder applying complete properties to the shared history. |
| Nonempty diff | Observe changed properties actually written. |
| Empty diff | Ensure success/latest tick is not mistaken for a new pose. |
| Recorder/held copy | Show whether it stores references, duplicates, or bypasses the shared map. |
| Cache/generation | Require complete finite pose fields; verify copies and stale generation rejection. |

Test alias identity, generation changes, copied results, missing/invalid fields, and stale values. Do not replace history buffers, alter wire encoding, infer freshness from a recorder callback, or assume private Netfox coupling is stable across versions. A project may use a different receive API; adapt by tracing its concrete decoder, not by transplanting these paths.