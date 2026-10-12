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

Linux outputs are under `builds/linux-x86_64/` and `builds/linux-arm64/`; the local macOS app archive is under `builds/macos/`. Local source/export checks are proof of local bytes only. They are not VPS/public-internet proof, and this project has no authorized remote host.
