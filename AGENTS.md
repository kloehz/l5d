# Project agent routing

This repository's runnable game is `zombie_corridor_mvp/`; the root project is a placeholder. Keep project-local guidance scoped to this game. Do not treat this file as permission to change global skills/settings, clean files, run server/VPS operations, publish, or alter engine configuration.

## Engine and verification

- Observed lock and verified runner: Godot 4.7; Netfox 1.35.3; 30 Hz simulation; input history 16; GodotPhysics3D.
- Both root and nested `project.godot` declare Godot 4.8 features despite the 4.7 lock/runner. This is configuration drift requiring human review; do not silently edit engine configuration.
- Tests live under `zombie_corridor_mvp/tests/`; game scripts under `zombie_corridor_mvp/game/`. Check `.editorconfig`, `.gitattributes`, root/nested `.gitignore`, build and launch scripts before selecting a verification path.
- Use only observed, authorized commands. Runtime evidence does not imply WAN/human acceptance or authorize server changes.

## On-demand networking skills

Load a skill only when its trigger matches; do not load all skills by default.

| Trigger | Exact skill path |
|---|---|
| Netfox decoder writes, empty diffs, shared history, state provenance | `.pi/skills/netfox-state-provenance/SKILL.md` |
| Godot remote interpolation, snapshot buffer, render cursor | `.pi/skills/godot-remote-interpolation/SKILL.md` |
| Godot shot view time, lag compensation, rewind timeline | `.pi/skills/godot-shot-view-timeline/SKILL.md` |
| Netfox input readiness, publication, scheduler cadence | `.pi/skills/netfox-input-state-safety/SKILL.md` |
| Godot multiplayer graphical runtime and delay verification | `.pi/skills/godot-network-verification/SKILL.md` |

These project skills supplement—not replace—the generic Godot/Netfox guidance. References and project paths are examples; verify the target project's actual architecture and dependency version. Skills do not grant permissions or authorize cleanup, global changes, publication, or VPS actions.