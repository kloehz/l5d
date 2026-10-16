# Editing the current game source

Open `zombie_corridor_mvp/project.godot` with the pinned Godot 4.7 editor in `zombie_corridor_mvp/.tools/godot-4.7/`. The outer repository `project.godot` is a placeholder; do not use it as the game project. Press F5 to run the current game project; the main scene remains `scenes/bootstrap.tscn`.

## Scene editing map

| Area | Edit here | Keep in mind |
| --- | --- | --- |
| Bootstrap composition | `scenes/bootstrap.tscn` | Owns the world and players anchors. Runtime code still starts networking and client-only presentation/UI. |
| World lighting | `scenes/world_visuals.tscn` | Environment, sun and decorative floor strips are visual-only. |
| Corridor geometry shape authoring | `scenes/corridor_geometry.tscn` | Change each collider `BoxShape3D.size` and node translation. `shape.size` is authoritative for collision, preview mesh, analytic queries and the map hash. Keep identity rotation/scale/basis, floor top at y=0 and the right-side baffle clearance intact. Restart the game after map edits so both roles compare the new hash. |
| Player actor | `scenes/player_actor.tscn` | Edit visible capsule and shoulder camera dimensions only. Runtime configures root/input authority before adding the actor, and the visual node keeps top-level/world-space interpolation for remote smoothing. Existing server hitbox, combat and movement rules remain code-owned. |
| UI | `scenes/ui.tscn` | Layout, labels, buttons, HUD/debug/feedback and style are authored here; button behavior and runtime values stay in `game/ui.gd`. Preserve existing copy unless a UI text change is explicitly requested. |
| Mob template | `scenes/mob_visual.tscn` | Visual zombie capsule/material template only. Server population, movement, attacks and HP state remain runtime code. |
| Presentation pool | `scenes/presentation.tscn` | Owns exactly eight direct `ShotTracer0`–`ShotTracer7` children. Do not add fallback tracer nodes in script. Dynamic mob population and tracer slot claiming remain runtime code. |
| Tracer resources | `scenes/shot_tracer.tscn`, `scenes/resources/tracer_*` | The pool shares one line mesh and two materials; runtime only claims slots, transforms them, sets expiry and swaps predicted/confirmed material. |

## Client mob rendering and aiming

Enemy visuals use a continuous render-frame display cursor, gently synchronized to public network time at 30 Hz and buffered by 300 ms (nine ticks). A stored mob row's tick denotes its historical pose at `(tick + 1) / 30`; the same displayed timestamp drives visual sampling and graphical shot rewind, with no second client-side delay. Camera targeting reads the mob's rendered foot pose; if no graphical presentation exists, existing headless/bot aim behavior remains.

Position and wrapped yaw share one authoritative history bracket. The client interpolates only between received samples and never extrapolates, fills, or modifies server history. If the buffered cursor falls outside available history, presentation holds the nearest endpoint; this is finite visible degradation, not predicted movement. The shared timing contract defines 30 Hz network ticks, a 300 ms interpolation delay, 450 ms maximum server rewind, and 500 ms mob history. The existing incoming shot validation, cadence, queue, session/life, protocol, and authority rules remain in force; the server clamps its historical hit query to the shared 450 ms bound. The cursor resets across session/reconnect changes, and removed visuals are discarded.

Focused local regression command (run from `zombie_corridor_mvp/`):

```sh
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/mob_presentation.gd
```

This deterministic synthetic fixture checks the client presentation path, not WAN behavior or a deployed build.

## Remote allied-player visuals

Remote allies interpolate copied, complete states captured at actual full/nonempty-diff decoder writes through a pinned Netfox 1.35.3 encoder-history view. The view aliases the synchronizer's existing storage; recorder writes bypass its receipt cache. Successful empty diffs therefore cannot invent received samples.

The client retains at most 24 accepted samples and renders position and shortest-path yaw from one bracket, delayed by 350 ms (10.5 network ticks). Final direct and 150 ms RTT/no-loss local runs measured a maximum newest decoder-write age of 307.485 ms, leaving more than one 30 Hz tick of margin. All four clients had 100% bracket coverage in the measured steady windows. This is bounded local evidence, not an arbitrary-WAN guarantee.

Outside available history, visuals hold the nearest endpoint without extrapolation. Configure, life, session, connection and receipt-generation changes reset playback; discontinuities do not blend across teleports. Local prediction, camera response and authoritative collision/root poses remain unchanged. Servers and bots do no cosmetic buffering.

Focused fixture command (from `zombie_corridor_mvp/`):

```sh
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/player_presentation.tscn
```

This checks receipt provenance, interpolation and player integration. Independent final checks passed 45 presentation assertions, 640 editable-scene assertions, 33 camera assertions, 53 enemy-presentation assertions and 43 invariants (with only the intentional ownership-negative warning). Separate two-client graphical runs passed direct and 150 ms RTT/no-loss checks; they do not replace human visual acceptance. Reopen the source client to load these changes; exported apps were not rebuilt and the VPS was not changed.

## Geometry constraints

`scenes/corridor_geometry.tscn` is the single source for fixed corridor boxes. Supported edits are translated, axis-aligned boxes with positive collider sizes. Unsupported geometry is rejected clearly instead of silently approximated: rotations, shear, non-unit scale, non-box shapes, disabled/extra/loose colliders, duplicate required roles, floor top not at y=0 and baffle clearance violations are not accepted. Resize by `BoxShape3D.size`, not transform scale.

The same authored boxes drive physical collision, visual preview, analytic ray/capsule queries and the map hash. Do not create an independent wall list in code or move preview meshes separately from their colliders.

## Running and exporting locally

```bash
# Source launcher; owns only the server/clients it starts
python3 scripts/run_local_demo.py --source

# Rebuild local macOS app and Linux dedicated-server packages
scripts/export_builds.sh
```

The embedded editor may leave window/layout cache files under `.godot/`; those are not gameplay settings. The game intentionally keeps the maximized window mode from `project.godot`.

Linux outputs are under `builds/linux-x86_64/` and `builds/linux-arm64/`; the local macOS app archive is under `builds/macos/`. Local source/export checks prove only the local bytes they inspect. The deployed 466 source and frozen exports remain unchanged; the revised source client has not been re-exported or accepted over WAN. See [DEPLOYMENT.md](DEPLOYMENT.md) for the deployment record and its evidence boundaries.
