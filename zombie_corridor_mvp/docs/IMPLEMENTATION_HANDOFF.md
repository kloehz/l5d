# Implementation handoff

## Delivery and ownership

Implemented in `zombie_corridor_mvp`; the original parent placeholder project was not overwritten. This is direct implementation, not SDD. No commit, push, PR, remote SSH lookup, firewall modification, auth/VPN change or shared-service mutation was performed.

For scene editing, start with [`docs/EDITING.md`](EDITING.md). That document is the compact scene-first map for authored surfaces; this handoff focuses on runtime ownership and measurement boundaries.

## Modules and clocks

| Module | Responsibility | Clock |
| --- | --- | --- |
| `game/net_session.gd` | explicit role CLI, handshake, RPC/lifecycle, accepted poses, committed cursor, metrics; player actor PackedScene instantiation with authority configured before add | 30 Hz Netfox; 60 FPS process/poll cap |
| `game/player.gd`, `player_input.gd`, `movement_sync.gd` | server-root/owner-input Netfox prediction and movement only; authored actor children preserve fixed capsule/camera composition and world-space visual interpolation | `_rollback_tick`; 16-tick history; stale input >11 ticks stops movement |
| `game/world.gd`, `geometry.gd`, `authored_box.gd` | authored static collision boxes, visual preview, analytic ray geometry and map hash from one scene source; unsupported box edits rejected | immutable world |
| `game/mob_world.gd` | mathematical records, chunk grid, union activity, AI, attack and wave state | active move 15 Hz / AI 5 Hz / activation 2 Hz; committed ticks only |
| `game/combat.gd` | bounded shot queue/cache, owner/life/session/time/finite/cadence validation, wall-first historic capsule hits | once per new committed tick, monotonic cadence |
| `game/publisher.gd`, `snapshot_codec.gd` | per-peer interest, ACKed baselines, absolute compact batches, heartbeat, reliable final states | publication 10 Hz; 65/80 m AOI hysteresis |
| `game/client_store.gd`, `presentation.gd`, `ui.gd` | revision/epoch/tombstone protection, buffered interpolation, authored presentation pool/tracers, menus/HUD/F3 | render only |
| `scripts/runtime.py` and launch/test tools | actual processes, readiness, scoped cleanup, assertions, OS measurements and lifecycle-aware CPU sampler | monotonic wall clocks |

The server has no camera, mesh, UI or cosmetic node instances. Bots explicitly select `--bot`; headless alone does not select server role. Linux dedicated exports carry `dedicated_server`. There are 16 ENet channels: pinned Netfox on channel 0, custom lifecycle 8, mob snapshots 9, combat 10 and diagnostics 11.

Pinned Godot 4.7 misroutes the requested server channel count into its host incoming bandwidth argument. After a successful bind, the application explicitly restores unlimited ENet host bandwidth and 18 total channels (16 application + 2 system), before accepting connections. RTT-based throttling remains enabled with a documented 100 ms baseline interval and positive 2/2 acceleration/deceleration, calibrated by a bounded public-statistics comparison. The application mob publication budget is unchanged. See `docs/MOVEMENT_DIAGNOSIS.md` for official source links and retained failing/passing evidence.

## Scene-first ownership

Fixed composition is authored in scenes where it can be inspected in the editor:

- `scenes/bootstrap.tscn`: base world and players anchors.
- `scenes/world_visuals.tscn`: client-only environment, sun and decorative strips.
- `scenes/corridor_geometry.tscn`: fixed physical boxes; the same box data drives collision, preview, analytic queries and map hash.
- `scenes/player_actor.tscn`: fixed player capsule/collision/camera children; runtime owns authority, prediction and state.
- `scenes/ui.tscn`: fixed menu/HUD/debug/feedback hierarchy and style; runtime owns values/signals.
- `scenes/mob_visual.tscn`: client-only zombie visual template; runtime owns population and HP/state.
- `scenes/presentation.tscn`: client-only root with eight authored tracer slots; runtime owns slot claims and expiry.
- `scenes/shot_tracer.tscn` and `scenes/resources/tracer_*`: shared tracer mesh/material resources.

Use `docs/EDITING.md` for exact edit points and constraints instead of duplicating a full scene guide here.

## Authority and rollback

Player `CharacterBody3D` root belongs to peer 1; its Input child belongs to the connection owner. Nonowning client actors never request input resimulation; they receive state only. Requests from predictors are clamped to retained history. All peers use identical paths and authority before synchronization. `enable_input_broadcast=false`; only local owners predict on clients, remote presentation never writes logical movement state.

Physics/network both run at 30 Hz and `NetworkTime.physics_factor` is applied around `move_and_slide`; measured factor is 1. The application commits every new tick once **after the entire rollback loop**, using the exact state history snapshot for each tick. It never uses final batch pose for every catch-up tick and never runs combat/mobs inside player replay. HP, lifecycle, kills, cooldowns, mobs and wave state are not rollback properties.

A retired life stops generating inputs/states, retains history and RPC paths for five seconds, then is cleaned on both roles together with its ACK bookkeeping. Actor-ready ACK gates server state transmission so a different ENet channel cannot race an uncreated node path.

## Combat and spatial state

Weapon range/rate/damage are loaded and bounded from the included configuration JSON. Config/map SHA256 values are checked during handshake; protocol and pinned engine/addon versions are tagged separately. Scheduler/clock defaults are pinned in source and `project.godot`, not dynamically reconfigured by arbitrary JSON keys.

Origin is accepted server pose + eye offset; clients cannot provide damage, victims, HP, poses or death outcomes. `session_epoch/life_id/shot_id` bind requests. Queue 64, per-peer pending 8, cache 128 and bounded future-ID window 64 prevent unbounded work. Accepted IDs resend cached ACKs without damage. Rejected/queued duplicates cannot commit twice. Cadence is server monotonic time; stale backlog is not replayed.

Ray/capsule queries select the nearest target before the nearest map AABB wall and within 35 m. A valid client's view timestamp is clamped to 250 ms rewind; active hitbox history keeps 500 ms. Complete bounded room candidates include old hitbox positions, not merely their current spatial cell. This reads mathematical history; it does not move physical bodies or resimulate AI. Friendly fire is absent. Respawn grants two seconds of server-owned melee protection.

Dormant records are absent from integration, targeting and navigation schedulers. Wake 45 m; sleep outside 60 m for 3 s; activation is the union of all living connections, with exact-distance checks after chunk queries. State/HP/ID/pose are preserved. No offline catch-up runs on wake. These decisions are independent of camera/frustum and per-peer replication. Mob movement uses corridor limits and a fixed baffle waypoint, not navigation agents or physics bodies.

Per-client ENTER is a complete reliable baseline, ACKed before unreliable updates; LEAVE retires only that visit. Reentry increments `interest_epoch`, not generation. Absolute batches use 28-byte records, centimeter signed positions, at most 30 records per packet, and a bounded per-peer mob budget. Updates include heartbeat poses even without changes; loss/partial batches never imply deletion. Dead IDs are not reused, and bounded tombstones plus reliable final lifecycle prevent revival.

## Measurement boundaries

Tick wall time spans Netfox movement/rollback loop work, amortized over new ticks in that loop, plus each tick's individual committed gameplay work. `rollback_ms` is **nested**, not a value to add to tick time. Idle waits, configured delta, render and OS sampling do not substitute for work duration. Subsystem numbers are actual instrumented calls, not assumed configured periods.

Tick work timing is captured before JSON construction/write; sample flush occurs outside the committed tick. Those logging and poll/receive costs remain part of measured process CPU, not the instrumented tick wall boundary. CPU is actual process CPU-time delta / monotonic wall interval; 100% = one core. RSS from `ps` is KiB converted to MiB.

The SCN-6 CPU sampler is lifecycle-aware: it checks process liveness after sleep and around `ps`, does not emit rows for unavailable/dead terminal reads, rejects live cumulative CPU regressions and preserves true zero CPU. The summarizer still rejects negative/nonfinite samples; it was not relaxed or clamped to pass.

`tx_bytes_s/rx_bytes_s` are var-to-bytes encoded custom application RPC argument payloads; these exclude Netfox/default-channel and Godot/ENet framing. Separate ENet host data counters and per-peer custom payload counters are also logged. Hz fields count process, physics, network, actual poll calls, publication cycles and individual packets separately.

## Reconnection and local launch

A connection-generation token guards suspended network-clock welcome continuations. Disconnect stops time synchronization, closes the peer, frees actor paths/visuals, clears HUD/ping/shot state and terminates only locally owned child PIDs. Local startup has a separate generation token and per-launch readiness file; cancellation removes that file and does not leave a suspended earlier launch controlling a later one.

The exported Probar local action and same-GUI-client reconnect have direct-game automation checks; they are not native keyboard/mouse input tests.

## Educational limitations

This is not a commercial anti-cheat or authenticated public service. Netfox's pinned transport validates property authority but is not promised hardened against arbitrary malformed addon wire packets. Application inputs/commands are bounded and validated. Committed combat does not retroactively undo a result when late movement inputs correct the past; that is an explicit consistency tradeoff. The one static baffle uses a fixed avoidance rule, not general-purpose navigation. Client extrapolation is conservative and never unbounded prediction of mobs.

No VPS architecture/resource/public-route assumption was made. Deployment and public UDP verification need an explicit authorized destination. Native physical input remains unautomated; game-owned Viewport input/camera checks and exported rendering were verified separately. Read `docs/VALIDATION.md` for current measured evidence.
