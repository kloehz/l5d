# Editable Godot Scenes

## Objective and authorization
The user explicitly requested analysis/listing of code-built scenes and then implementation replacing as much fixed construction as practical with editor-editable scenes/resources. Preserve existing gameplay and the current over-the-shoulder camera/tracer work. Technical artifacts follow the existing English convention.

## Initial findings and rationale
The actual game lives in `zombie_corridor_mvp/`; the outer `project.godot` is a placeholder. At the initial audit, production had only `scenes/bootstrap.tscn` with empty World/Players anchors. Six construction groups are candidates: bootstrap composition, world, UI/HUD, player actor, mob visuals, tracer visuals/resources. Network/session orchestration, combat, movement, actor/mob population and tracer lifecycle remain runtime code. `CorridorGeometry.WALLS` drives authoritative analytic queries; editing physical walls independently would cause disagreement and is not acceptable.

## Scope and constraints
- Fixed node hierarchy, visuals/materials and reusable templates belong in `.tscn`/`.tres`; scripts bind behavior/state.
- Preserve launch order, dedicated-server/bot visual exclusion, authority/rollback contracts, input routing, camera aiming and the eight-slot tracer pool.
- The first slice changes only world visual authoring/composition; collisions/analytic geometry remain unchanged until their own task.
- Preserve all pre-existing untracked source. Git HEAD is an empty history anchor, not a behavioral baseline. Capture literal narrow preimages before writes.
- User now explicitly authorizes completing all remaining scene-first work and final local delivery, including refreshing local exports and integrated acceptance. No source staging/commits/push/PR, remote deployment, unrelated settings/addon changes or destructive Git operations authorized. Preserve previous builds/results before replacing them. Source work-unit commits remain pending explicit authorization.
- User positively accepted current gameplay and clarified this is scene authoring, not new textures/models/animation. Preserve current feel and maximized window setting.
- RDD is off; do not start native review. Use read-only ASSESS after writers; unavailable assessment requires independent verification.
- Strict TDD is not established by effective configuration. Use ordinary focused regressions and the pinned engine, not inferred strict TDD.
- Single writer, foreground subagents. A task's approximately 400 authored changed lines is advisory only; preserve clarity/tests.

## Tasks
- [x] SCN-1 — Author the fixed world visuals and base world composition as editable scenes, preserving geometry and role behavior; add regression evidence and minimal editing guidance. Status: independently verified; human visual acceptance/source commit pending authorization.
- [x] SCN-2 — Move menu/HUD hierarchy and styling to an editable UI scene, retaining input/status/event binding. Status: independently verified after harness timing correction; human visual acceptance/source commit pending authorization.
- [x] SCN-3 — Move fixed player children/visuals/camera to a reusable actor scene and instantiate it dynamically with unchanged authority/rollback/lifecycle. Status: independently verified after world-space visual correction; source commit pending explicit authorization.
- [x] SCN-4 — Author reusable mob/tracer visual templates/resources while retaining dynamic population and the bounded eight-slot tracer pool. Status: independently verified; source commit pending explicit authorization.
- [x] SCN-5 — Make authored level collision/visual geometry the shared source for physics and analytic server queries, with parity tests; do not duplicate independently editable wall data. Status: independently verified after validation/hash corrections; source commit pending authorization.
- [x] SCN-6 — Verify integrated headless/graphical gameplay, refresh local macOS/Linux exports and complete release/system acceptance/benchmarks; document all edit points and external limitations. Status: independently verified complete locally; all eight final stages pass and documentation matches current reports. Source commits and public deployment remain unauthorized.

## SCN-1 allowed source surfaces
- `zombie_corridor_mvp/game/world.gd`
- `zombie_corridor_mvp/game/bootstrap.gd`
- `zombie_corridor_mvp/scenes/bootstrap.tscn`
- `zombie_corridor_mvp/scenes/world.tscn` (new)
- `zombie_corridor_mvp/scenes/world_visuals.tscn` (new)
- `zombie_corridor_mvp/tests/editable_scenes.gd` (new)
- `zombie_corridor_mvp/README.md` (only current scene-editing/testing guidance)
Parent owns this task file. No other source surfaces are authorized in this slice.

## SCN-2 allowed source surfaces
- `zombie_corridor_mvp/game/ui.gd`
- `zombie_corridor_mvp/game/bootstrap.gd` (client-only UI scene instantiation only)
- `zombie_corridor_mvp/scenes/ui.tscn` (new)
- `zombie_corridor_mvp/tests/editable_scenes.gd` (extend UI behavior coverage)
- `zombie_corridor_mvp/tests/third_person.gd` (instantiate authored UI instead of CorridorUI.new only)
- `zombie_corridor_mvp/README.md` (narrow UI editing pointers)
Existing mixed-language button copy must be preserved; this is not a copy/redesign task. Use the authored UI scene for runtime and tests, not a duplicate code-built fallback. Behavior includes real button signal wiring, capture/input routing, ready/menu/background/HUD/debug/feedback state, and preserved IP/port defaults. Keep scene-authored geometry/style editable without runtime overwrites.

## Acceptance and checks
SCN-1: world and client-only fixed visuals are visible/editable in scenes; no procedural environment/light/strip construction; bootstrap references the world PackedScene without duplicate creation. Client lighting/fog/colors/strip dimensions and placements match the existing implementation. Dedicated server and bots retain collision bodies but no active client-only visual/environment/light nodes. Collision geometry/layers/masks and analytic walls are unchanged. Existing bootstrap launch order is preserved; any authored-role initialization change must be proved with a real-role harness.
Later tasks: editor-authored hierarchy survives runtime initialization, UI ignores gameplay mouse appropriately, actor ownership/rollback/aim unchanged, pool capacity/reuse unchanged, shared authored geometry parity proven.

Commands from `zombie_corridor_mvp/` (pinned runner):
- `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/editable_scenes.gd`
- `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/invariants.tscn`
- `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/third_person.gd`
- `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/tracers.gd`
- `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --path . -s res://tests/editable_scenes.gd`
- `python3 scripts/run_local_demo.py --source --duration 5` (only when no existing live session would be disturbed; launch/clean only owned processes)
Report unavailable GUI coverage honestly. Existing Netfox malicious-snapshot ownership warning is known from prior invariant runs; verify failures/output, not just exit status.

## Recovery and evidence
- Working branch at exploration: `feat/third-person-camera`, HEAD `3b68027f3818ce1b037ecff41dc678bd6f397638`. Implementation branch: `feat/editable-scenes`; no source staged or committed.
- Pre-existing camera/tracer feature documents remain untouched; manual camera feel and their source commits are still pending.
- Engram initialization fails with a server ownership mismatch. Full recovery mirror `odd/editable-scenes/tasks` is pending; local document is surviving progress, not a claim of successful memory persistence.
- Rollback boundary for SCN-1: world visual extraction/base composition, new focused scene harness and narrow README guidance; restore literal preimages rather than empty HEAD. Preserve collisions, camera, combat, UI, net session and tracer code.

## SCN-1 evidence
- New `world.tscn` and `world_visuals.tscn` compose authored environment, sun, floor/wall meshes and 17 strips; bootstrap embeds one world. `world.gd` retains collision construction only and removes visuals for server/bot. Roles initialize in NetSession before main-scene readiness/launch.
- Literal preimages: `/tmp/scn1-preimages.6hro3Q`; source churn +455/-47 including tests and scenes. This exceeds the advisory planning heuristic because the cohesive extraction includes explicit scene data and behavior tests; no minification or test omission.
- Writer (gpt-5.5 medium): focused scene harness 227 assertions headless/graphical, invariants 43, camera 29 headless, tracers 188/capacity 8; all exit 0/failures []. Writer initially skipped demo conservatively because an editor was open.
- Independent verifier read launcher ownership/marker behavior and proved idle editor does not conflict. Five-second source demo passed: dedicated SERVER_READY plus two CLIENT_READY peers, exit 0. It controlled only owned processes, not the user's editor.
- Independent repeated checks all exit 0: 227 scene assertions headless/graphical, 43 invariants, 29 camera, 188 tracer. No candidate-caused defects found. Parent focused scene spot check exit 0, 227 assertions/failures [].
- Active LSP probe unsupported for all three changed GDScript paths; native ASSESS empty output -> unassessable/high-risk, independent verification completed. Existing Netfox warning persisted without invariant failures. No strict TDD claim/native review/source commit/export.
- Human aesthetic acceptance remains pending. Wall meshes are editable but non-authoritative: do not move/resize them independently until SCN-5 supplies one geometry source.

## SCN-2 backup boundary
The worker initially stopped before edits because its repository-relative write surfaces did not include an external preimage directory. User explicitly selected approval of `/tmp/scn2-preimages-game-99-coop/` through the three-choice prompt. Parent created that new directory (refusing overwrite) and captured literal preimages for all five existing allowed source files plus a manifest recording the new UI scene's absence. Worker consumes this backup read-only; its source surfaces remain unchanged.

## SCN-2 implementation and verification finding
- Writer moved fixed UI hierarchy/style into `scenes/ui.tscn`, bound named nodes in `ui.gd`, switched client-only bootstrap instantiation and existing camera harness setup to the authored scene, extended scene tests and README.
- Literal comparison to approved parent preimages: +505/-107 across the six allowed surfaces. No source staging/commits/exports.
- Writer reports all seven checks pass (345 scene assertions headless, 347 graphical, invariants 43, camera 29/35, tracers 188, source demo). Independent verification contradicted the graphical scene-harness result: exit 1 with two captured viewport mouse yaw/pitch failures at tests/editable_scenes.gd:391-396. This observed failure supersedes a passing claim.
- Independent remaining checks passed: scene 345 headless, invariants 43 with known warning, camera 29 headless/35 graphical with capture supported, tracer 188/capacity 8, source demo one server/two clients and clean marker cleanup. No separate production defect proven yet; scene harness determinism versus actual routing must be diagnosed, not assumed.
- Active LSP unsupported for all four changed script paths; native ASSESS again unavailable -> independent verification required. SCN-2 remains unchecked until correction/new proof.

## SCN-2 correction and final evidence
- Read-only diagnosis observed 2/3 graphical scene runs passing and 1/3 failing only yaw/pitch; graphical third-person comparison passed. Difference: new harness injected immediately after mouse capture while the existing camera harness waited a frame. OS focus/cursor warp is a hypothesis, not proved as the cause.
- Corrective writer changed only `tests/editable_scenes.gd`: wait one frame after capture, measure baseline after transition, inject via real `root.push_input` and assert exact wrap/clamp yaw/pitch synchronously before the next frame admits unrelated motion. Released-mouse/debug/Escape/readiness checks remain active; no production change, direct handler substitution or broad tolerance weakening.
- Correction-start literal preimage: `/tmp/scn2-preimages-game-99-coop/correction-1/zombie_corridor_mvp/tests/editable_scenes.gd`; correction +23/-6. Worker initially encountered a Variant-inference parse error, fixed with explicit Vector2 annotations before final runs. Do not hide this resolved failed draft check or the original independent graphical failure.
- Corrective writer final results: 345 scene assertions headless, five sequential graphical runs each 347 assertions, graphical camera 35/capture supported; all exit 0/failures [].
- Final independent results: 345 scene assertions headless; three sequential graphical runs each 347; camera 35 graphical/capture supported; invariants 43; tracers 188/capacity eight; all exit 0/failures []. Known Netfox warning persists. Prior real two-client source demo remains valid because production did not change after it.
- Parent final scene-harness spot check: exit 0, 345 assertions/failures []. Final Git status: feat/editable-scenes, HEAD remains initial 3b68027, no staged source or source commits.
- Current editor entry points: `scenes/bootstrap.tscn` for base composition, `scenes/world.tscn`/`scenes/world_visuals.tscn` for static visual scene, `scenes/ui.tscn` for fixed UI layout/style/copy. Dynamic status/feedback/HUD values still correctly bind from runtime state.
- Limits: full GUI-click network side effects of local/connect/disconnect/quit are source-inspected/signal-bound rather than end-to-end clicked in tests; human aesthetic/camera-feel acceptance pending. LSP unsupported, native risk assessment unavailable (independent fallback completed), Engram mirror unavailable. No source commit/export/push/PR/native review performed.
- SCN-2 rollback: restore five existing source preimages from the approved directory and remove only the new ui.tscn; this preserves SCN-1. Never use empty HEAD as a source rollback.

## Final-completion scope and mapping
User requested completion end-to-end, not another partial handoff. Execute SCN-3, SCN-4, SCN-5, SCN-6 sequentially with a single writer and observed checks. Parent captures literal scoped source preimages and previous builds/results outside the overwrite path; workers consume those read-only rather than acquiring outside-repository write authority.

SCN-3 surfaces: `game/player.gd`, `game/net_session.gd` (actor PackedScene instantiation only), new `scenes/player_actor.tscn`, `tests/editable_scenes.gd`, `tests/third_person.gd`, `tests/tracers.gd`, `README.md`, all under `zombie_corridor_mvp/`. Instantiate actor and configure root/input authority and MovementSync settings before add_child/ready. Preserve shoulder aim/obstruction/movement/retirement/respawn.
SCN-4: `game/presentation.gd`, new `scenes/mob_visual.tscn`, `scenes/shot_tracer.tscn`, scene-local `.tres` materials, `tests/editable_scenes.gd`, `tests/tracers.gd`, `README.md`. Mob material must be per-instance; tracer mesh and two materials deliberately shared within eight slots.
SCN-5: decouple pure authored level geometry from world script to avoid geometry -> world scene -> world -> geometry cycle. Read normalized collision boxes to derive analytic walls/hash and visual bounds from the same source. Unsupported rotated/sheared/non-box inputs must fail clearly rather than silently approximate; no general OBB gameplay expansion requested.
SCN-6: retain old exports/results, run focused source/graphical checks, then `scripts/export_builds.sh`, refresh `results/runtime-source-manifest.json`, run `python3 scripts/run_final_suite.py`. Suite includes release validation/lifecycle, source/build compatibility, local Linux Docker transport, rendered frames, demo and eight serial benchmarks. Existing wall time approximately 15 minutes; report actual environmental failures, never label localhost/Docker as VPS proof. New runtime resources live under scenes so source identity includes them, or explicitly extend manifest coverage if necessary.

## SCN-3 initial evidence and correction
- Writer extracted player_actor.tscn and switched NetSession actor creation/configure-before-add. Churn +327/-64; camera/input/authority/collision tests and real source demo passed. Counts: scene446/448, camera31/37, invariants43, tracers188.
- Independent readback proved a candidate-caused remote smoothing defect: Visual is now actor child, so actor position delta is inherited before global-position lerp. For visual P and actor A->B the new formula adds an unwanted (1-alpha)*(B-A) snap term. Existing camera assertions miss this; preserve world-space/top-level-equivalent presentation and add an actor-jump regression.
- Scene harness emits new3ObjectDB/1resource exit warnings; no warnings in camera/tracer/invariants/demo runtime. Treat as unresolved test-exit issue, not pre-existing or proved production. Correct cleanup within own harness, never edit Netfox addon.
- Source demo server/two clients ready with no RPC/error/resource logs. Native ASSESS unavailable, independent verifier caught regression despite passing counts. Keep SCN-3 unchecked until correction proof.

## SCN-3 correction closure
- Authored Visual is top-level/world-space while remaining actor child; initialization and local follow write world coordinates. New actor-jump oracle proves remote prior world pose does not inherit actor delta, exact exponential interpolation follows and logical pose is untouched. Camera data/ownership preserved.
- Corrective churn +52/-15. Off-tree Netfox visibility-filter cleanup and reversible NetworkTime sync lifecycle in harness closed3ObjectDB/1resource warnings; no addon edits.
- Independent final: scene456headless/458graphical, camera31headless/37graphical, invariants43, tracers188/capacity8, real server/twoclients source demo all passed. No resource/parse/RPC path errors. One client emitted Netfox DiffHistoryEncoder missing reference tick109 applying124; causality unproven, retained for final-suite review. Known invariant malicious-snapshot warning remains intentional.

## SCN-4 closure
- Mob/tracer templates and shared serialized twovertex line/two materials are authored under scenes; mob material local_to_scene plus per-instance duplication isolates albedo. Runtime population/AOI/8slot pool lifetime/transform ownership unchanged.
- Churn +177/-21; temporary authorized resource-generator test entrypoint removed. One draft compile failure fixed before final checks.
- Independent scene519headless/521graphical, tracers344 including bounded mesh/material identities, camera31headless, invariants43 and source demo5sec all passed. No resource/parse/RPC errors; prior one-off Netfox diff warning not reproduced. Parent tracer spot check exit0/assertions344/failures[] completed.

## SCN-5 accepted implementation boundary
A dependency-free `corridor_geometry.tscn` authors StaticBody3D/CollisionShape3D(BoxShape3D) and mesh children. New @tool authored_box script derives visual BoxMesh size from the collider's sole authoritative size and updates on resource changes; no world/geometry/NetSession dependency. Geometry class extracts normalized records from this pure scene, avoiding preload cycle. World instances these authored physical nodes directly and strips client meshes for server/bot, not collision bodies. Decorative world_visuals retains environment/sun/strips only.

Current scope is an axis-aligned rectangular corridor on y0: finite translations/positive collider sizes supported; rotations/shear/nonunit transform scale/nonbox shapes/missing or duplicate required roles/floor top !=0 rejected with pure validation errors and fail real startup before networking. Resize by shape.size, not transform.scale. Derived floor/boundary records supply existing constrain bounds, baffle records supply the existing narrow right-side detour (no arbitrary navigation). Protocol map hash includes normalized physical records and remains stable under child ordering.

SCN-5 exact source surfaces under zombie_corridor_mvp: game/{geometry,world,net_session,mob_world,authored_box}.gd; scenes/{world,world_visuals,corridor_geometry}.tscn; tests/{editable_scenes,invariants,third_person}.gd; README.md. New authored_box.gd UID is an allowed incidental generated companion. Mutated-wall regressions must prove actual authored physical/visual/query/hash coupling using isolated scene-local shape resources and restore shared geometry/state afterward.

## SCN-5 initial evidence and correction
- Authored physical scene, tool-derived meshes, cached analytic records/hash, map gate and derived mob detour implemented. Source churn +357/-86 plus249new lines. Writer+independent defaultmap checks all passed: scene553headless/555graphical, invariants43, camera31/37, tracers344, source demo and TRANSPORT_PASS2clients/5m/s/30Hz/~60Hzpoll.
- Independent identified supported-edit safety defects despite defaultpass: world/ancestor transforms omitted from extraction; untagged StaticBody/disabled collider ignored; AuthoredBox.ready normalizes authored layer/mask beforevalidation; hash roundsvalues4decimals whilephysicsunrounded; shape replacement lacks editorrebinding. Parent additionally requires identitypreviewtransform so visualtranslation cannot silentlydesync.
- Correct only geometry.gd/world.gd/authored_box.gd and own scene harness: account/reject unsupported ancestor placement, reject all unaccountedphysical/disabled/shapebypasses, preserveauthoredlayer/mask forvalidation, exactcanonicalfloatidentity, editor-only shape replacement rebinding (noruntimepoll), boundaryclearance/floorcoverage guards for existingrectangularsupport.
- Verifier accidentally invoked one initial relativebinary fromoutercwd: exit127/no runner; separately diagnosed parentstate confirms runneronlyinnergame, no writes/Gitmutation. All8requiredchecks subsequently ran at correctinnerroot; this is not a gameplayfailure or baseline.
- First corrective child timed out after reading4inputs, before writes. Parent independently compared all4authorizedfiles byte-for-byte with correction preimages: unchanged; terminal task state timed_out, branch unchanged. Relaunch a fresh narrow correction, not an unknown partially edited tree. No runtime extension/package repair is authorized or needed for source completion.

## SCN-5 correction closure
- Three files corrected: geometry.gd +90/-23, authored_box.gd +15/-2, scene harness +104/-0; world.gd correction unchanged. Ancestor translations are included; unsupported basis/top_level placements/untagged or extra/disabled/loose/duplicate collision shapes/polygons and translated preview meshes rejected. Layer/mask authored values preserved for validator. Exact canonical float bytes distinguish sub1e-4 physical edits; no rounded identity collision. Editor-only shape identity monitoring rebinds resources without runtime polling, invalidcache clears and floor/freecorridor clearance validated.
- Independent final all8checks pass: scene578headless/580graphical, camera31/37, invariants43, tracers344, source demo and TRANSPORT_PASS. No new resource/RPC/parser errors; known intentional invariant warning only. SCN-5 now closed with supported-box-edit negative coverage.

## SCN-6 final-delivery boundary
Finish the last fixed composition: new scenes/presentation.tscn owns client presentation root and eight authored shot_tracer scene slots; presentation.gd binds slots instead of constructing fixed pool nodes, bootstrap instantiates presentation scene and tests use that production scene. Dynamic mob count/lifetime and pool claiming stay code. Preserve all8slot/resource/finite transform regressions. Source surfaces: game/{bootstrap,presentation}.gd, new scenes/presentation.tscn, tests/{editable_scenes,tracers}.gd, README.md, new docs/EDITING.md. Project.godot may only receive unavoidable export-engine metadata normalization; preserve all gameplay/window settings. Export outputs under builds, generated logs/results are authorized; no remote deployment/install/source commit.

Parent preserves old407MB builds/results and exact source preimages before final writes. Writer source self-checks/exports first; independent verifier owns expensive full frozen release suite so it is executed once on final bytes, not two15minute benchmark runs. No source edits after verification freeze; docs/progress can report observed results without changing runtime identity. Full suite exact command `python3 scripts/run_final_suite.py` with long foreground timeout includes8serial stages (source invariants/transport, release validation/lifecycle, DockerLinuxtransport, renderedframes, gui demo, benchmarks). Unavailable Docker/tooling remains a real blocker, not a skipped success. No publicendpoint/VPS claim.

## SCN-6 source/export subunit
- Final presentation.tscn authors root and8directShotTracer0..7 scenes. Runtime binds pool/sharedmesh/twomaterials, no fixednode allocation; bootstrapinstantiates client-onlyPackedScene. Mobcounts remain dynamic. Tests useproductionpresentation scene; README anddocs/EDITING.md listeveryeditpoint/shapeconstraints/sourcevsbuild/localonlyproof.
- Source churn +235/-41; initial PackedScene autoload-name compile errors resolved with root-node binding before final checks. Final writer: scene641headless/643graphical, tracers344, camera31/37, invariants43 all exit0/failures[].
- Exports refreshed successfully: macOSapp/zip, Linuxx86_64/arm64binaries/tarpackages. Import log has no Script/Parse/Error markers. project.godot byte-identical to preimage, maximized mode2 retained. Real exportedserver+twoclient demo5sec passed.
- Final runtime source identity `dc00eece5d10abb957d02c242bf1452dcd0732cfc9e910a2dd3689f2f9feb006`,77files includingpresentation.tscn; recorded runtime-source-manifest refreshed. Oldbuilds/results preserved in SCN6previous-delivery backup. NativeASSESSunavailable, independent final acceptance next; sourcefiles mustremain frozen.

## SCN-6 full-suite finding
- Independent focused final scene641headless/643graphical, tracers344, camera37graphical pass. All77runtimeentries/15buildartifacts/15SHA256SUMS entries matchactualbytes, mode2retained, screenshots show current capsulecorridor/shouldercamera/menuHUD.
- Frozen runtime dc00eece... and buildmanifest `2e226b5047ec6f864b55082aca6bad38631391547b54fd35b24eb060c3460e47`. Fullsuite884.61s: invariants0, transport0, releaseallvalidation0(155.95s), lifecycle0(66.59s), LinuxDocker0(62.18s), render0, gui0; benchmark stageexit1(565.75s).
- All8benchmark gameplayprofiles printed BENCHMARK_PASS, but summarizer correctly rejected logs/benchmark-idle.jsonl:2171 CPU=-47.501425042750995. Rawgame row hasnoCPU; offendingOSsample elapsed70.468257833, RSS0; precedingOSsample69.4788CPUpositive. Do not use stale summary ascurrentacceptedbenchmark or ignoreoutside-windowinvalidrows.
- Readonlydiagnosis traced run_benchmark.py pollsserver BEFOREsleep then samplespsAFTERsleep without recheckingalive. LastsampledecreasingcumulativeTIME isconsistent with exit/zombie race; rawps tokennotlogged so exacttokenunproven. Fix harnessonly: repollafter sleep/beforeandafterps, do not emit unavailable/deadcounter rows, livecumulativeregressionraises, trueunchangedCPUvalidzero. Neverclampnegativeorrelaxsummarizer'sfinite/nonnegativeguard.
- Narrowcorrection surfaces: scripts/run_benchmark.py and new tests/test_run_benchmark_sampler.py. These are excludedfromruntimeidentity/exportpack, so exportedgamebytes remainfinal; no reexportneeded. Preservefailedsuite/logs asdiagnosticevidence, then deterministicunitregression and freshfullsuite.

## SCN-6 benchmark correction
- run_benchmark.py now exposes lifecycle-aware collect_os_samples_until_exit; checks alive aftersleep andafterps, drops unavailableterminalreads, rejects livecounterregression andnonmonotonicclock, preserves truezeroCPU. Importmain guard enables isolatedtests. Summarizer/schema/window/game/exportsource remain unchanged.
- Added8deterministic tests; writer unittest/py_compile pass and runtime dc00eece... / buildmanifest2e226b... unchanged. Parent readback strengthened3fakepollsequences plus callcounts so missingPID/zombie/sleep races actually execute their targetbranches, and switched dynamic testmoduleloading to resolve Python import/style diagnostics. Final updatedtests awaiting independentrun.
- Correction preimage/failedreports/logs preserved under scn6-benchmark-correction within backup root; no source/exportbyte rewrite and no reexport. Independent final suite rerun next.

## SCN-6 final acceptance
- Independent corrected sampler audit, eight deterministic Python tests and py_compile passed. Fresh `python3 scripts/run_final_suite.py` exited 0: all eight stages passed in 886.23 seconds (14m46s), including release validation, lifecycle, both Linux Docker architectures, rendered frames, real GUI demo and all eight serial benchmarks.
- Runtime SHA256 remains `dc00eece5d10abb957d02c242bf1452dcd0732cfc9e910a2dd3689f2f9feb006` (77 verified entries). Build manifest SHA256 remains `2e226b5047ec6f864b55082aca6bad38631391547b54fd35b24eb060c3460e47` (15 verified artifacts and 15 SHA256SUMS matches). No runtime/export changes after freeze.
- Each benchmark has 1,800 measured ticks and 60 samples after 10 seconds warmup / 60 seconds observed. All CPU/RSS values including tails are finite and nonnegative. Local Apple M5/10 logical CPUs: 50 active mobs/four clients tick p95/p99 10.521/11.687 ms, CPU mean 6.952% of one core, RSS peak 85.016 MiB. No VPS-capacity inference.
- Expected malicious-position invariant warning only; no new fatal/RPC/resource-leak/DiffHistory error in final logs. Graphical scene/camera tests inject viewport events; native physical keyboard/mouse interaction remains manual, not automated. Public VPS remains unauthorized and unverified.
- Final documentation refresh and independent readback passed for README.md, docs/EDITING.md, docs/VALIDATION.md and docs/IMPLEMENTATION_HANDOFF.md. All eight benchmark rows and subsystem/clock breakdowns, combat/lifecycle/Linux/proxy values, references and hashes match current reports. Runtime/build checksums still match after documentation-only edits. `logs/local-session.json` is absent. Preimages preserved in `final-docs` under the backup root.
- Parent active Python LSP probe: new sampler tests clean; benchmark script has 11 auxiliary findings, not primary syntax/type errors. AST baseline comparison proves all 13 assertion nodes unchanged: seven flagged tuple-message assertions have non-tuple tests and are false positives; three conversion flags are unchanged deliberate fail-fast parsing; wildcard import is unchanged style debt. No new candidate-caused diagnostic. GDScript LSP unsupported, native ASSESS unavailable (independent verification completed), markdownlint unavailable (manual/document crosschecks completed). Strict TDD and RDD are off, not silently claimed.

## Delivery and next step
All six authorized scene-migration tasks are complete locally. Play current source with `cd zombie_corridor_mvp && python3 scripts/run_local_demo.py --source`, or open the refreshed macOS app and choose Probar local. Edit points and geometry constraints are in docs/EDITING.md; current evidence and manual/public limits are in docs/VALIDATION.md. No new art or gameplay redesign was introduced.

Public VPS deployment/native physical-input acceptance are not automated local proof and remain external decisions; no SSH destination was authorized. Engram mirror remains unavailable due provider ownership mismatch; this local task document carries recoverable state. No source staging/commit/push/PR was performed; branch remains feat/editable-scenes, HEAD 3b68027. There is no source commit identity to record without explicit authorization. Literal source preimages and previous exports/results are preserved under `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/editable-scenes-final-psc4wg0x` (earlier SCN-1/2 preimages retain their separately recorded paths).
