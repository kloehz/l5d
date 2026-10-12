# Third-Person Camera and Mouse Aim

## Objective
Replace the local first-person view with an over-the-shoulder third-person camera, make captured mouse movement reliably rotate the view/aim, and preserve authoritative shooting and the verified tracer pool.

## Problem and rationale
The user reports mouse motion does not orient the aim and explicitly requests third person rather than first person. Read-only mapping found mouse look in CorridorUI._unhandled_input behind a fullscreen Control with default mouse filtering. GUI event consumption is a strong hypothesis, not a reproduced runtime diagnosis. The current local camera is at player head height, the local body is hidden, and control_look drives view, movement frame, rollback facing and shot direction.

## Accepted behavior
The user selected "Sobre el hombro (Recommended)" through the camera-choice UI:
- Camera behind and to one side of the visible local player.
- Captured mouse movement controls camera yaw/pitch and player facing.
- WASD remains camera/facing-relative; no free-orbit movement model.
- The HUD crosshair remains centered; the camera view and shot targeting follow mouse look.
- Menu/unfocused/released-mouse input must not rotate the view unintentionally.
- Camera obstruction handling prevents ordinary wall clipping.
- Shot origin remains the authoritative player's head; camera-center targeting may determine only the client direction, never the authoritative origin.
- Server wall/hit validation remains authoritative, including cases where the camera can see a target but the player's shot is obstructed.

## Authorization and scope
The user explicitly requested third person and approved the over-the-shoulder behavior. Authorized source surfaces:
- zombie_corridor_mvp/game/ui.gd
- zombie_corridor_mvp/game/player.gd
- zombie_corridor_mvp/game/net_session.gd (only narrow camera-center direction integration if needed)
- zombie_corridor_mvp/tests/third_person.gd (new focused harness)
- zombie_corridor_mvp/README.md (only update current camera/control/testing description)
Parent-owned progress: odd/tasks/third-person-camera.md.

Non-goals: free orbit, art/animation polish, new weapon rules, server combat authority changes, rollback/input schemas, project settings, addons, launcher changes, exports, benchmark reports, network rearchitecture. Do not edit presentation.gd or tests/tracers.gd; preserve the existing eight-slot pool and its verified regressions.

## Tasks
- [x] TPC-1 — Map mouse, camera, movement and authoritative aim; resolve the camera model. Status: verified by read-only mapping and explicit user choice; no source commit.
- [x] TPC-2 — Implement reliable captured mouse input, shoulder camera, obstruction handling and aligned aiming with focused regressions and minimal current-use docs. Status: independently verified after nearby-mob convergence correction; source commit pending explicit authorization.
- [x] TPC-3 — Independently verify focused input/camera/aim checks, graphical execution, tracer/invariant regressions and a bounded source-mode multiplayer launch. Status: verified; 29 headless/35 graphical camera assertions, 43 invariants, 188 tracer assertions and owned source-mode demo passed.
- [ ] TPC-4 — Confirm camera feel in user gameplay and obtain explicit source work-unit commit authorization. Status: pending; no source staging/commit authorization.

## Acceptance checks
1. Mouse motion delivered through the actual viewport input path changes yaw/pitch only during captured, ready gameplay; HUD controls cannot swallow gameplay look.
2. Escape/menu capture and ready-state gating still work; no duplicate rotation from two callbacks.
3. Local player body is visible, camera starts behind/to one side, yaw/pitch move the view consistently with control_look, and other players retain their camera ownership/interpolation.
4. Wall obstruction reduces the camera distance safely and clears when moving away; finite transforms at allowed pitch extremes.
5. The centered aiming ray converges from the player-head shot origin, without moving shot authority to the camera or allowing camera-peeking shots through walls.
6. Existing authoritative request schema, origin, normalization/range validation and rollback movement are preserved.
7. New focused harness, 43 existing invariants and 188 tracer assertions pass. Graphical harness/source-launch limitations are reported honestly.
8. README tells the user to run current source rather than stale exported apps. Manual camera feel is a separate human acceptance step, not simulated proof.

## Test configuration and exact runner
Strict TDD is not established: no effective setting was found during recovery; test presence does not enable it. Use ordinary focused regressions and observe the current mouse failure before correction when feasible, without inventing RED evidence.
Pinned engine: zombie_corridor_mvp/.tools/godot-4.7/Godot.app/Contents/MacOS/Godot, 4.7.stable.official.5b4e0cb0f.

Commands from zombie_corridor_mvp:
- .tools/godot-4.7/Godot.app/Contents/MacOS/Godot --version
- .tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/third_person.gd
- .tools/godot-4.7/Godot.app/Contents/MacOS/Godot --path . -s res://tests/third_person.gd
- .tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/invariants.tscn
- .tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/tracers.gd
- python3 scripts/run_local_demo.py --source --duration 5
Graphical runs may launch only their own short-lived harness/client windows. Never control/kill the user's existing gameplay process. The demo chooses a free local UDP port and cleans only its owned processes. Report any unavailable GUI/capture coverage; a direct handler call alone does not prove real GUI event routing.

## Evidence and implementation boundaries
- Map: ui.gd input/capture, player_input.gd gathering, player.gd local presentation and rollback facing, net_session.gd shot direction, combat.gd authoritative head-origin trace.
- Product choice: over-the-shoulder with aim-turn, not free orbit.
- Snapshot/branch: feat/third-person-camera, from empty initial commit 3b68027f3818ce1b037ecff41dc678bd6f397638. All project source and the prior tracer correction are untracked; preserve their pre-existing bytes outside this feature scope.
- Work-unit commit candidate after authorization: feat(camera): add over-the-shoulder aiming. The earlier human Git grant covered only the empty initial commit, not source import or source commits. No commit, push, PR or export is requested.
- Forecast: approximately 220–380 authored changed lines including focused tests and docs; advisory, not a reason to omit tests or code-golf. Delivery strategy: ask-on-risk; no delivery slice prepared yet.
- Capture narrow source preimages before editing because empty Git HEAD is not a behavioral baseline. Report additions plus deletions, not just net line count.
- RDD is off; do not start native review. After writer handoff, use read-only native ASSESS and follow its returned verification plan; unavailable assessment is high risk.
- Active GDScript LSP was unsupported in prior feature; engine checks are required.
- Engram context/search/save fail with a local ownership mismatch; full mirror odd/third-person-camera/tasks is pending. Local task document is authoritative surviving progress, not a successful memory persistence claim.

## TPC-2 writer evidence and verification routing
- Worker edited the five authorized surfaces. Mouse look now uses _input and HUD root ignores mouse filtering. Local body is visible, a shoulder offset replaces head-camera view and the floating first-person gun was removed. Camera obstruction uses a physics ray and margin; player camera aim converges from head toward camera-center wall/range target. NetSession preserves no-camera/bot fallback.
- Worker reports all commands exit 0: engine 4.7.stable.official.5b4e0cb0f; third-person harness 23 headless assertions (capture_supported false), 29 graphical assertions (capture_supported true); invariants 43; tracers 188, capacity eight.
- Worker source-mode local demo ran after confirming no existing session marker, printed PLAYABLE_LOCAL and exited cleanly. No existing user process was controlled.
- Worker claims current routing issue observed before final fix but has not supplied the exact prior-run failure output; do not call this a demonstrated baseline or strict TDD RED.
- Active LSP probe unsupported for all four changed GDScript paths (no configured server). Native read-only ASSESS unavailable, returning unassessable/high-risk fallback with independentVerifier true. RDD remains off.
- Worker preserved hashes/line counts rather than reporting an exact preimage diff; authored churn remains unquantified. Empty HEAD is not the behavior baseline.
- Parent readback requests independent scrutiny of near-mob parallax: camera_aim_direction currently chooses wall_distance or max range, not a nearest client-visible mob target. Determine actual candidate-caused misses with geometry evidence rather than accepting matching helper formulas as end-to-end proof.
- Parent readback notes player.gd replaced typed input/rb and direct autoload references with dynamic loads/lookups; verifier must check that this is needed and does not change rollback/server behavior. No authority/protocol edits are authorized.

## Independent verification finding and bounded correction
- First independent pass: partial. All engine/source-launch commands passed with 23 headless and 29 graphical camera assertions, 43 invariants, 188 tracer assertions; graphical viewport capture routing is verified. Source demo launched only owned processes after confirming no session marker.
- Concrete defect at player.gd camera_aim_direction: camera-center target uses walls/range only. With actual shoulder/head offsets and shared zombie capsule dimensions, a close camera-centered mob is hit by the camera ray at 4.5968888761923825 m but the resulting head ray misses (INF). This is candidate-caused parallax, not a server-authority defect.
- Bounded correction: use the nearest client-visible mob capsule intersection along the camera-center ray when nearer than the wall/range target, reusing CorridorGeometry.ray_capsule and NetSession.store.records. Continue sending only a normalized direction from the head; server still owns origin, history, walls and final damage.
- Corrective edit surfaces are player.gd and tests/third_person.gd only. Add an independently meaningful nearby-camera-centered-mob head-ray hit regression, nearest-target ordering and wall precedence/fallback checks. No server, rollback, tracer, network protocol or launcher edits.
- Existing camera point-ray margin behavior is adequate for the tested rear-wall case; side/corner swept-frustum clearance was not proven and no concrete blocker was found. Manual camera feel remains pending.

## Nearby-mob correction evidence
- Corrective writer edited player.gd and tests/third_person.gd only. Camera-center targeting now uses the closest finite positive live client mob capsule hit before wall/range, then sends a normalized head-origin direction. Dead/invalid rows and degenerate/backward targets are ignored/fall back; there is no aim assist for off-ray bodies.
- Ordinary pre-fix regression observed exit 1 with nearby-mob head-origin convergence and nearest-target failures on wall-only aiming. Initial test draft enum-reference compile errors were corrected; strict TDD was not activated and no final compilation failures remain in writer evidence.
- Added meaningful camera-ray versus head-ray capsule-intersection oracle, nearest ordering, wall precedence, invalid/dead fallback and store restoration checks.
- Corrective writer final exits all 0: 29 headless camera assertions (capture unsupported), 35 graphical (capture supported), 43 invariants, 188 tracers, source-mode local demo with no previous marker. Netfox invariant warning remains.
- Exact correction diff from literal preimages: player.gd +23/-3; tests/third_person.gd +66/-0; 92 authored diff lines. Initial feature diff remains unquantified; do not substitute full files versus empty HEAD.
- Read-only ASSESS still unavailable and requires independent verification; no native review/consent was started.

## Final verification and closeout
- Independent final status: passed. Near-mob miss is closed with an independent camera-hit/head-hit capsule oracle. Nearest live target, wall precedence, invalid/dead fallback and store restoration passed.
- All final independent commands exit 0: pinned Godot 4.7 version; camera harness 29 headless assertions (capture_supported false), 35 graphical (capture_supported true); invariants 43; tracers 188/capacity eight; five-second source-mode two-client demo after confirming no existing session marker.
- Parent headless camera-harness spot check: exit 0, 29 assertions, failures []; no stderr. Git confirms feat/third-person-camera at empty initial HEAD 3b68027, no staged source or source commits.
- Graphical viewport input routing, capture/ready/menu gates, Escape/F3, local visible body, remote camera ownership, rear-wall clamp/recovery and pitch-finite cases verified. Server combat authority/schema untouched; bots/no-camera fallback preserved.
- Failed checks resolved during implementation: close-mob convergence and nearest-target regression intentionally failed before correction; test draft enum compile errors fixed before final verification. No required final engine check failed.
- Remaining limits: headless cannot prove captured mouse (graphical did); side/corner/frustum swept camera clearance is not exhaustive; subjective camera feel and actual human mouse play remain user acceptance. LSP unsupported, native ASSESS unavailable (independent fallback completed), Engram mirror/save/summary unavailable.
- Netfox malicious snapshot ownership warning persists in invariants; failures array is empty. No builds reexported, source staged/committed, pushes or PRs.

## Rollback boundary
Only current camera/input/aim integration, the new focused third_person.gd harness and minimal README description. Preserve movement authority, combat, all existing game data, and prior tracer optimization. No destructive Git rollback is authorized.

## Next step
User stops/restarts their owned old source demo (Ctrl-C in its terminal) and runs python3 scripts/run_local_demo.py --source from zombie_corridor_mvp. Confirm real mouse yaw/pitch, centered reticle aiming at nearby zombies, shoulder-camera feel and wall/corner behavior. Adjust only on observed feedback within authorized scope. TPC-4 stays pending until manual acceptance and explicit source commit authorization; existing .app exports are still stale. Restore full Engram mirror when available.
