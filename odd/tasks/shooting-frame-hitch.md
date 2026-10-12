# Shooting Frame Hitch

## Objective
Reduce transient per-shot client work by reusing tracer visuals, with a repeatable before/after measurement and behavior regressions.

## Problem and rationale
The user reports a brief FPS drop on every shot and confirms that FPS recover immediately. At the initial diagnosis, `zombie_corridor_mvp/game/presentation.gd` created a MeshInstance3D, ImmediateMesh, StandardMaterial3D and SceneTreeTimer per tracer. Predicted shots always spawn a tracer; confirmed hits may spawn another. Resource churn is a leading hypothesis, not a measured diagnosis of the user's rendered FPS.

## Authorization and scope
The user approved the proposed measurement, tracer-reuse correction and verification.
- Production: `zombie_corridor_mvp/game/presentation.gd` only.
- Focused harness: new `zombie_corridor_mvp/tests/tracers.gd`.
- Parent-owned progress: `odd/tasks/shooting-frame-hitch.md`.
- Preserve hitscan, shot signals, colors, endpoints, 75 ms visual lifetime and authoritative networking.
- Do not alter addons, project settings, server combat, exports or existing benchmark reports.
- Keep resource counts bounded, with no mesh/material/node/timer allocation on repeated shots after setup.
- Use the project's pinned Godot 4.7 runner, not the system Godot version.
- TDD configuration was not supplied or found; no strict TDD mode is inferred. Capture the baseline before the production change and add behavior/resource regressions.

## Tasks
- [x] ODD-1 — Add a focused tracer harness and capture the current repeated-shot baseline. Status: baseline verified; initially non-Git, source work-unit commit now pending explicit authorization.
- [x] ODD-2 — Reuse a bounded tracer pool and extend the harness with regression checks. Status: independently verified after scoped harness correction; source commit pending authorization.
- [x] ODD-3 — Independently verify behavior/resource bounds, compare measurements and record remaining live-FPS uncertainty. Status: verified; 188 tracer assertions and 43 invariants passed; live gameplay FPS remains unproven.
- [x] ODD-4 — Resolve the subagent Git/worktree launch blocker with explicit human authorization. Status: verified; registration and a read-only subagent launch succeeded after restart.
- [ ] ODD-5 — Obtain explicit authorization for the source work-unit commit. Status: pending; prior authorization covered only the empty initial commit.

## Acceptance and checks
1. The same benchmark scenario is run before and after the production change.
2. Repeated shots reuse a fixed resource set; no new tracer timer is created per shot.
3. Predicted and confirmed-hit tracers retain their endpoints, colors and short visibility lifetime.
4. Saturation stays bounded; expiration and subsequent reuse work; zero-length/vertical tracer handling remains safe.
5. Focused tracer regressions and existing game invariants pass.
6. Run a rendered harness if the local graphical environment supports it; separate tracer submission timing from actual client FPS and GPU frame timing.

## Runner and planned commands
Commands run from `zombie_corridor_mvp`.
- Engine: `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --version`
- Baseline: `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/tracers.gd -- --tracer-baseline`
- Regression: `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/tracers.gd`
- Invariants: `.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/invariants.tscn`
- Rendered baseline/comparison: the same tracer harness without `--headless`, when supported.

## Original evidence and limitations (historical)
- Read-only source exploration confirms per-shot tracer resource creation. No profiler evidence yet attributes the user's FPS hitch to it.
- At initial inspection neither folder was a Git checkout. A later fresh inspection finds a newly initialized root `.git`, branch `main`, no tracked files and no commits (unborn HEAD). The parent did not initialize it. Work-unit commits have not been created. Intended unit: `perf(rendering): reuse shot tracer resources` with its tests.
- Resuming the baseline worker was refused with `Select an existing worktree in the same Git clone as this session`. A fresh ODD-2 worker launch also failed during worktree registration with zero turns and zero tool calls. No native Agent fallback is exposed. Parent source comparison confirms `game/presentation.gd` remains byte-for-byte unchanged.
- The user explicitly authorized an empty initial commit. Executed `git commit --allow-empty --only -m "chore: initialize local project history"`; created `3b68027` on `main`. `git show --format= --stat HEAD` confirms it contains no files. All project files remain untracked; no source was staged or committed, no push occurred.
- Reattempted only explicit registration of the current existing Git worktree using `session_worktree_register`; it still returned `Select an existing worktree in the same Git clone as this session`. A resolvable HEAD did not restore this session's worktree registration. No further Git mutation or source-writing retry was made.
- Commit used Git's automatically inferred local identity; no global/local identity configuration was changed. The repository was not initialized by the parent.
- No connected Godot MCP editor session was available during investigation.
- Engram context/search/save fail with a local server ownership mismatch. Recovery mirror `odd/shooting-frame-hitch/tasks` is pending; the local document is the surviving progress record.
- ODD-1 added only `tests/tracers.gd`; production rendering remains unchanged. Engine verified: `4.7.stable.official.5b4e0cb0f`.
- Original headless baseline: 14 assertions passed; 120 sequential shots; submission p50/p95/max = 23/98/167 us; frame interval p50/p95/max = 16611/19303/20862 us.
- Original graphical baseline: 14 assertions passed; 120 sequential shots; submission p50/p95/max = 37/72/292 us; frame interval p50/p95/max = 16609/17370/126418 us.
- Original harness observed up to five visible tracer nodes, distinct meshes and distinct materials. Timings are harness submission/frame intervals, not measured gameplay FPS or GPU attribution.
- Graphical harness runs are supported on the local Mac. No user gameplay process was controlled.
- Godot cache changes may be incidental; no test UID was created by these runs.

## ODD-2 writer evidence
- Production now uses eight reusable MeshInstance3D slots, one shared ArrayMesh line and two shared unshaded materials. Slots expire via monotonic-time bookkeeping; saturation overwrites the earliest-expiring slot.
- Before this worker's production edit, the same 120-shot scenario passed 14 baseline assertions in both headless and graphical modes.
- Refreshed headless baseline: submission p50/p95/max 20/53/161 us; frame interval 16558/19907/20712 us; max visible meshes/materials 5/5.
- Refreshed graphical baseline: submission 39/63/234 us; frame interval 16606/17383/65003 us; max visible meshes/materials 6/6.
- Worker after-change headless run: 66 assertions passed; submission 10/21/40 us; frame interval 16419/22773/24100 us; visible meshes/materials 1/1.
- Worker after-change graphical run: 66 assertions passed; submission 10/20/29 us; frame interval 16631/18342/65026 us; visible meshes/materials 1/1.
- Worker invariants: 43 passed; netfox property-ownership warning reported. No baseline failure was established for this warning.
- Parent structural readback identified asynchronous helper calls without awaiting completion and synthetic expiry advancement in the harness; independent verifier must determine their effect on assertions and benchmark isolation. Confirmed-hit tests currently call the visual helper rather than a real own-actor hit signal.
- Active LSP probe of both changed GDScript files was unsupported: no configured LSP server. Zero diagnostics is not a clean LSP check; use actual pinned-engine runs.
- Native read-only ASSESS was unavailable (empty native output); returned plan treats risk as high and requires an independent verifier. RDD remains off; no native review is started.
- Exact introduced diff count is unavailable because worker did not preserve preimages. Production grew from 40 to 124 lines; current harness is 293 lines. Do not use empty Git HEAD as a behavioral baseline.

## Independent verification and bounded follow-up
- The independent verifier confirmed the production pool structure, bounded saturation, shared resources, colors, endpoint transforms, and absence of per-shot resource/timer constructors.
- All initial independent commands passed: 66 tracer assertions in headless and graphical modes, 43 invariants. Independent graphical submission p50/p95/max was 11/20/23 us; these figures are provisional because harness checks may overlap the benchmark.
- Required same-scope harness corrections: await asynchronous behavior/reuse/degenerate checks; prove natural frame-driven expiry without injected future timestamps; exercise confirmed-hit signal with an own actor; assert stable full-pool node/mesh/material identities across reuse.
- Existing NetSession source may be read to set up the real signal path, but only tests/tracers.gd is writable for this follow-up. No production scope expansion is authorized.

## Harness correction evidence
- Corrective writer edited tests/tracers.gd only: awaited all asynchronous helpers, removed synthetic expiry advancement, exercised the real own-actor confirmed-hit signal, and added full-pool node/mesh/material identity assertions.
- Corrected headless harness: exit 0, 188 assertions, no failures/stderr; submission p50/p95/max 10/30/49 us; frame interval 16274/23450/24770 us.
- Corrected graphical harness: exit 0, 188 assertions, no failures/stderr; submission 13/25/40 us; frame interval 16629/17903/18649 us.
- Invariants: exit 0, 43 passed; same netfox PropertySnapshot ownership warning. Pinned engine version check passed.
- Current source sizes: presentation.gd 124 lines, tests/tracers.gd 388 lines. The correction added 95 net lines; this is not an additions-plus-deletions diff count. Exact total introduced diff count remains unavailable.
- Final independent re-verification passed; no gameplay FPS/GPU claim is made.

## Final independent verification and parent spot check
- Independent verifier status: passed. All four harness findings closed with source readback and actual headless/graphical execution.
- Final independent headless harness: exit 0, 188 assertions, failures []; submission p50/p95/max 10/24/55 us; frame interval 15987/22703/24411 us.
- Final independent graphical harness: exit 0, 188 assertions, failures []; submission 11/20/36 us; frame interval 16627/18289/18628 us. Same 120-shot scenario.
- Final independent invariants: exit 0, 43 passed; netfox ownership warning remains. Pinned Godot version: 4.7.stable.official.5b4e0cb0f.
- Parent repeated the headless harness as the final spot check: exit 0, 188 assertions, failures []; submission 10/18/34 us; frame interval 16608/21336/24567 us; stderr empty.
- Verified resource set: eight persistent nodes, one shared mesh and two fixed materials. The predicted-only sequential measurement samples one visible material; confirmed-path identity assertions cover the second.
- Graphical submission p95 was 63 us before and 20 us in the final independent run (approximately 68% lower in this observed harness). Frame intervals are not a gameplay FPS/GPU diagnosis; timings vary by run.
- Failed/unavailable checks: active GDScript LSP unsupported, native ASSESS unavailable (handled with independent verification), Engram operations failed (full task mirror still pending). No strict TDD configured. No test command failures remain.
- Final Git readback: perf/shooting-frame-hitch branch; HEAD remains the authorized empty initial commit 3b68027; no staged source, source commit, push or PR.

## Recovery and delivery state
- Resumed from the surviving local task document; Engram context/search/review remain unavailable with a server ownership mismatch, so the full mirror is pending.
- Current-session `session_worktree_register` succeeded at the existing root. A foreground `gentle-ai-explore` completed successfully, confirming the prior launch incident is resolved.
- Read-only recovery initially confirmed no tracer pool had been implemented; ODD-2 worker has now implemented it. The Godot 4.7 runner exists. No applicable AGENTS.md or effective strict TDD setting was found.
- Feature branch: `perf/shooting-frame-hitch`, from empty initial commit `3b68027f3818ce1b037ecff41dc678bd6f397638`. No source has been staged or committed.
- Estimated new authored changes: 80–170 lines. Delivery strategy: ask-on-risk. No PR or push requested. The existing baseline harness is already untracked source, not a clean Git baseline.
- Source work-unit commits remain pending explicit authorization; the prior human Git grant covered only the empty initial commit. No approval to import all existing untracked game files is inferred.
- RDD remains off; no native review or consent will be started.

## Rollback boundary
Only `game/presentation.gd` tracer rendering and `tests/tracers.gd`; preserve all unrelated game behavior. No destructive Git operations are authorized.

## Next step
Have the user test repeated firing in a real rendered gameplay session to confirm whether the reported hitch remains; this was not automated or proven by the focused harness. Obtain explicit Git authorization before any source work-unit commit, without importing all unrelated untracked files by implication. Restore the Engram mirror when its provider is available. The approved optimization and focused verification are complete; source delivery and user gameplay FPS confirmation remain pending.
