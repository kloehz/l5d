# Shot and display timeline

Illustrative implementation: `zombie_corridor_mvp/game/combat.gd`. Its project example allows a 300 ms display delay, 450 ms rewind bound, and 500 ms history; these are bounded project choices, not global defaults. Include measured transit and server queue ages when evaluating the relationship between displayed target pose and adjudication.

Verify semantic mapping per replicated entity and apply conversion once. In this project, mob row `T` corresponds to `(T+1)/30`, while player state `T` is a tick boundary; other projects may differ. Keep the server authoritative and preserve retained-history, cadence, life/session, finite timestamp/direction, queue, ownership, and shot replay/cache guards.

Test actual accepted shots for target, life, and shot-cache identity. Record whether a client received a hit confirmation separately from when the server adjudicated it; rejected requests may have no confirmation. Equal overlapping capsules can make target identity geometrically ambiguous: preserve the existing rejection/gate and record unique geometry, tie bounds, raw historical poses, and ray distances. Never convert an ID mismatch into a silent pass.