# Allied player interpolation

**Implemented and locally verified.** Remote allies now render from actual received position/yaw samples on a buffered timeline instead of exponentially chasing the latest replicated root. Human visual acceptance remains pending.

## Authorization and boundaries

User approved the plan and implementation, then explicitly requested completion after the interrupted attempt. Scope is client presentation only. Preserve server authority, root/collision poses, local prediction/reconciliation, camera/input, authored capsules, network/physics rates and existing history16.

Original local work branch: `fix/enemy-motion-smoothing` at `66d8a938b3144a48e51874728c04724c244339cd`, preserved intact. Implementation initially remained uncommitted. The user later authorized publication and chose a clean branch without historical operator addresses. Verified source is now recorded as `9e78c1a0771cddd0e74cb930d0d721994889b51b` on `feat/networking-skills-clean`, parent public main5013ec9. No VPS/restart, export, vendor/protocol change, personal/global configuration change, force-push, PR or merge. Unrelated generated results and personal profiles remain local. Publication evidence and policy live in `odd/tasks/networking-skills-and-publish.md`.

## Completed work

| ID | Outcome | Evidence |
| --- | --- | --- |
| ALLY-0 | [x] Repair execution and isolate the fixture lifecycle | Node-backed fixture loads after project autoloads. Detached filter cleanup and balanced synchronizer teardown eliminate actual leaks/disconnect errors. Early failures remain preserved. |
| ALLY-1 | [x] Measure real player presentation and receipt delivery | Baseline-3 and final corrected-2 direct/150 ms RTT observations; receipt provenance corrected to decoder writes. Final maximum newest decoder-write age307.485 ms;350 ms buffer leaves more than one30 Hz tick margin. Earlier history-key/counter-based recommendations are superseded. |
| ALLY-2 | [x] Implement remote-only buffered visual playback with focused tests/docs | `received_player_states.gd`, `remote_player_visual.gd`, `movement_sync.gd`, `player.gd`; focused scene/test, updated editable-scene fixture and `docs/EDITING.md`. Final45 presentation assertions pass. |
| ALLY-3 | [x] Independently verify native regressions and real graphical clients | Native45/640/33/53/43; corrected-2 four clients100% steady bracket coverage, raw-clean natural exits,289 protected inputs unchanged. Parent spot check45 pass. |

## Final design

### Capture only actual decoder writes

Netfox1.35.3 `_states` includes local recorder-held snapshots. Its latest-state counter also advances after an empty diff, even though that diff writes no snapshot. Neither history-key existence nor counter advancement proves an authoritative pose was received.

The application-owned `ReceivedPlayerStates` view aliases the **same** dictionary as the synchronizer's normal history. After normal `process_settings()`, only remote-client full/diff encoder history references are pointed at this view. Its overridden `set_snapshot` performs the unchanged shared write, then copies a complete finite position/facing/tick into a constant-space receipt cache. Recorder writes still target the original buffer and bypass the cache; empty diffs cause no write and invent no sample. Reset/settings generations replace the view. The vendor, RPCs, wire schema, authoritative history writes and simulation are unchanged.

Focused regression explicitly exercises actual full/nonempty-diff encoder application, the empty-diff/recorder-held-key trap, shared-storage aliasing, copy isolation, malformed/stale samples and cache reset. Private encoder-history references are pinned Netfox1.35.3 coupling, not a portable public API.

### Interpolate remote presentation only

The helper retains at most24 copied states and samples position and shortest-path yaw from one bracket. A monotonic render-frame cursor gently follows public network tick/fraction minus10.5 ticks (350 ms). It never extrapolates, fills missing ticks, changes private clocks or mutates the player root.

Outside history, presentation holds the nearest endpoint. Configure, owner/life, epoch, connection and receipt-generation changes reset playback. Implausible displacement resets the trajectory without blending through a teleport; its cursor is also reinitialized safely. Long render steps are bounded. Local visual/camera response stays immediate; headless/server roles allocate no remote visual playback history.

The updated editable-scene fixture tests this contract instead of requiring the obsolete exponential lerp. No legacy production fallback was introduced to satisfy old synthetic data.

## Final verification

All engine commands use pinned Godot4.7 from the absolute game directory. Strict TDD and RDD are off: ordinary failures/passes are not configured RED/GREEN or native review approval.

### Native checks

| Command suffix | Result |
| --- | --- |
| `res://tests/player_presentation.tscn` | 45 assertions, exit0, no ordinary diagnostics |
| `-s res://tests/editable_scenes.gd` | 640 assertions, exit0 |
| `-s res://tests/third_person.gd` | 33 assertions, exit0; headless capture is unsupported |
| `-s res://tests/mob_presentation.gd` | 53 assertions, exit0 |
| `res://tests/invariants.tscn` | 43 invariants, exit0; only intentional ownership-negative warning |

Evidence: `logs/allied-player-interpolation/independent-final-2/`. The verifier's initial warning matcher rejected the preauthorized negative-test warning; the original matcher receipt remains unchanged. Parent read both stdout and engine logs and confirmed the exact traceback `PropertySnapshot.sanitize -> tests/invariants.gd:128`, where sender2 is deliberately denied authority1's position. The conditional graphical phase then proceeded without replaying native commands.

Parent spot: `parent-spot-1/receipt.json`, PID30916,45 assertions/raw clean/natural0 and8 targeted inputs unchanged. After final checks only documentation and a timing comment were normalized; no behavior changed. Scoped `git diff --check` passed.

### Real graphical checks

Fresh `corrected-2/run.py` and `analyze.py` ran once each; analysis status `ANALYZED_PENDING_HUMAN_VISUAL_ACCEPTANCE`, no errors. No screenshots or synthetic movement/state/clock writes. Each case used an owned natural22-second server and two14-second graphical clients with ordinary movement/turn/stop intentions.

| Case/client | Steady frames with matching draw | Bracket coverage | Actual rendered speed CV | Baseline visual CV |
| --- | ---: | ---: | ---: | ---: |
| Direct/0 | 758 | 100% | .0667 | .1013 |
| Direct/1 | 756 | 100% | .0626 | 1.5319 |
|150 ms RTT/0 | 692 | 100% | .0700 | .2038 |
|150 ms RTT/1 | 691 | 100% | .0685 | 1.5326 |

Position/yaw errors against the actual helper cursor bracket stay below1e-6 m/2.2e-7 rad; all poses finite. Qualifying constant-motion windows last1.8-1.83 seconds and cover9.0-9.17 m. Sample cap24, root authority1, Input authority equal to each actor owner and no broadcasting all passed. Distinct peers share their owned server run/epoch. Speed comparisons match case and observer role across separate runs, not peer IDs; they are descriptive, not synchronized A/B or a universal frame-rate claim.

Direct server/client PIDs29920/29921/29922; delayed30013/30018/30019 all natural0. Owned proxy30017 exited0 after expected SIGTERM, two endpoints, zero drops/jitter/loss. No ordinary errors/warnings/leaks;289 protected source/build/results inputs unchanged.

Newest decoder-write age maxima:299.855/307.485 ms direct,269.552/274.276 ms delayed. These final write-proven observations support350 ms; they supersede provisional counter-derived ages.

## Preserved failures and limitations

- Baseline-1 keys mixed local held copies: its delivery ages and100 ms recommendation are invalid. Raw frame/draw/process/authority facts remain valid.
- Baseline-2 was prepared but never run and must not be launched as-is. Its stale adapter dependency, frozen24-sample array and receipt-name collision remain documented in the archived task file.
- Baseline-3 analyzer failed a frame-field mismatch. Offline schema-v2 analysis is separate; original FAIL/raw remain. Some receipt interpretation was superseded by the final decoder-write hook.
- Corrected-1 remains FAIL: direct client1 had77.87% coverage after false discontinuity resets; the latest-counter adapter was unsafe for empty diffs. No threshold increase or bad-window exclusion masked it.
- SceneTree dependency/compiler failures, fixture leaks/disconnect errors, timeout wrappers, failed attempts and unrerun intermediate edits remain under their original evidence namespaces.
- Writer implementation-* evidence was written under repository-root `logs/` outside the delegated game/logs surfaces. It is preserved, not retroactively authorized. Independent final checks use the correct game path. A later test preimage was not saved; this gap is not represented as complete preservation.
- ASSESS returned unassessable/native empty output; independent high-risk verification was used. No native review authority or delivery approval is claimed.
- Active LSP probing returned unsupported for all6 GDScript paths: no server configured, not clean evidence. Native parser/runtime checks are separate.
- No new WAN, exported-app, Linux-runtime, full-suite or capacity profile was run. Human physical-input/two-human visual acceptance remains pending. The existing cooperative VPS was not touched.

## Rollback and next action

Rollback removes this feature's remote Visual branch/helper/view and associated tests/docs without reverting local movement, camera, enemy timing or vendor behavior. Leave unrelated dirty files and all evidence intact.

Reopen the **source client**, not the old exported app, and judge an ally walking, turning, stopping and reappearing. From repository root:

```sh
bash zombie_corridor_mvp/scripts/run_client.sh --connect <COOP_HOST> --port 27015
```

Server is already running. Do not restart it or silently launch further profiles while waiting for human feedback.
