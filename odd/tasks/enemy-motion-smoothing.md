# Enemy motion smoothing

## Current authorization and scope

The user reports tick-like enemy movement in the source client against the VPS. After a client-only attempt exposed visual/hit disagreement, the user explicitly selected **"Completar cliente y servidor (Recomendado)"**: correct interpolation and authoritative compensation, verify both, and update only `game99-coop.service`.

Branch: `fix/enemy-motion-smoothing`, based on `6d5a275b13b8efd936403280f825815f56ce9002`. Local work-unit commits and a new isolated deployment are authorized. No push, PR, merge, firewall change, neighboring-service/account/security change, global configuration change, or broad staging. Preserve personal `.pi`, unrelated dirty generated outputs, all failed evidence, and retained rollback releases.

Preserve 30 Hz network/physics, 15 Hz mob movement, 10 Hz snapshots, rollback history16, capsule/geometry/gameplay/weapon properties, eight tracers, camera behavior, wire schemas, server authority and peer-owned Input. The sole newly authorized server policy is bounded hit rewind. No vendor/private-clock mutation, invented authoritative history, relaxed diagnostics, or replay of completed historical WAN/canary/normal one-shots.

## Work units

| ID | Work | Status | Evidence |
| --- | --- | --- | --- |
| MOB-1 | Fractional position/yaw sampling and fixture coverage | LOCAL UNIT DONE; USER SYMPTOM REMAINED | `191445227c9f01ee4decce065e20761498a6b6c0`; ledger closure `4993c117b6c5a1ffaadf1598ffae59918f7d659e`. Synthetic success did not establish actual smoothness. |
| MOB-2 | Measure starvation; test client-only bounded prediction and aim alignment | SUPERSEDED; ALIGNMENT FAILED | Motion improved, but four of19 isolated hits selected another authoritative target. Prediction/correction approach was not committed or accepted. |
| MOB-3 | Replace prediction with buffered interpolation and matching bounded server rewind | DONE | Commit `66d8a938b3144a48e51874728c04724c244339cd`; native53/641/33/43; actual direct/delayed movement;18/18 displayed/server hit identity matches. |
| MOB-4 | Export, update only the cooperative service with rollback, verify and document | IN PROGRESS; ACCEPTANCE BLOCKED | Live66d8a93/PID3088396/epoch1635698347. Export, activation, poststate and journal passed. Both new WAN analyses remain FAIL; global frame stalls and an overlapping-target identity tie require resolution. Human acceptance pending. |

## Execution and acceptance contract

Strict TDD and RDD are off (recovered session configuration). Ordinary regressions are not RED/GREEN evidence. Project-local writer and separate verifier use the configured Luna/high profile; no profile/global edits. Native ASSESS returned empty output, so the candidate used independent high-risk fallback, not native approval. GDScript LSP has no configured server; native parsing/runtime checks are evidence, not an LSP-clean claim.

Run only exact delegated commands, bounded attempts/timeouts and newly owned process groups. Read raw diagnostics even when exit0 or assertion JSON claims success. The only accepted warning is the causally identified unauthorized-position negative test in `tests/invariants.gd:128`; ordinary warnings/errors/leaks block. Parent owns Git and SSH/admin operations. Verification must leave protected source/build/results unchanged.

Focused command, from the absolute game directory:

```text
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/mob_presentation.gd
```

Independent regressions also execute `tests/editable_scenes.gd`, `tests/third_person.gd` and `tests/invariants.tscn` through the pinned engine. Real graphical checks use production bootstrap, public clocks, mesh transforms and post-draw callbacks—not a fake-clock-only acceptance.

## Measured cause

Initial integer-tick presentation and direct yaw stepping were fixed by MOB-1, but the user still observed pauses around0.2 seconds. Real observations showed fractional clock progress near60 FPS; the remaining problem was snapshot starvation.

Baseline: `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/game99-mob-observation-_bbrwx5o/`. Local direct and150 ms configured RTT, zero loss/jitter. Steady analysis excludes bootstrap/first ready second, dormant/attacking states and requires contiguous active windows of at least1.5 seconds with at least2 m authoritative displacement. All20 mobs qualified.

For mob20, delayed target exceeded newest history in91.2% of365 frames. Visual-motion gaps: median82.70 ms, maximum133.48 ms;56 gaps at least65 ms, all ending at new revisions. Latest-sample ages: median151.24 ms, p95217.88 ms, maximum251.20 ms. Movement/publication timestamps alternate2/4-tick gaps. A100 ms buffer could not cover this measured delivery history.

Shot coupling mattered: row tickT denotes pose at(T+1)/30. Existing shots independently used a100 ms offset; camera targeting used raw rather than rendered positions; server rewind was capped at250 ms including transit/queueing.

## Rejected MOB-2 approach and preserved failures

MOB-2 introduced a continuous bounded display cursor,150 ms capped visual extrapolation, bounded correction offsets, rendered-foot targeting and shared shot time. It preserved authority, but prediction was insufficient for the required hit agreement.

- `logs/enemy-motion-smoothing/mob2-writer-{1,2,3}/`: parse/expectation failures; parent found capped-horizon snapback; later camera fixture parse failure. All retained.
- `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/game99-mob-corrected-b5ojoepq/`: final native40/641/33/43 and real motion passed. Delayed movement median16.625/max50.995 ms, no gaps at least65 ms, but raw-history underflow remained frequent. Failed first native evidence remains in `native/`, passing checks in `native-v2/`.
- One continued verifier stalled with zero turns/tools and no new marker. A fresh verifier actually ran the checks; no configuration workaround.
- `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/game99-mob-shots-aeby5077/`:43 submitted/adjudicated;34 accepted/confirmed,9 cadence rejections,33 hits and one accepted miss (shot12/displayed target10). Its analyzer wrongly required every submission to be confirmed and stopped early. This failure and the unexplained miss remain; no fabricated PASS.
- `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/game99-mob-isolated-shots-8apu_j22/`: separate400 ms ordinary-click intentions, without changing weapon cadence.19 accepted hits, but four target mismatches: shots3 (render4/server5),6 (10/5),8 (15/10),10 (20/10). Selected visual/historical pose differences0.126–0.172 m. Timestamps matched; age169.552–203.144 ms, median186.460, no250 ms clamp. Raw logs clean, processes0,281 protected records unchanged. Strict target-parity gate failed.

The user then authorized client+server completion. No further profiles were run on the superseded prediction candidate.

## Accepted local MOB-3 design and evidence

A shared pure `game/mob_timing.gd` defines300 ms interpolation,450 ms maximum server rewind and the unchanged500 ms mob history at30 Hz. Presentation retains a continuous, bounded cursor synchronized to public time, but **does not extrapolate or maintain packet-correction offsets**. It samples position/yaw from the same authoritative bracket; outside history, it holds an endpoint. Aim uses the actual rendered foot; graphical shots use the displayed time once. Server cadence/queue/session/life/finite/protocol rules remain unchanged; actual historical hit queries use the450 ms clamp.

Tests retain history integrity, endpoint/yaw/duplicate-tick behavior, authored visuals/tracers, cursor bounds/session reset, camera/wall precedence and clean teardown. New coverage checks timing order/boundaries and the real committed-combat path.

Authoring failures remain under `logs/enemy-motion-smoothing/mob3-writer-1/`: three allowed focused attempts printed47 zero-failure assertions but had runtime/fixture errors, including a typed mock-publisher mismatch. The final real-publisher edit was not self-rerun. Independent first native then ran50 assertions with three combat-hit failures: synthetic origin was inside the authored **front boundary**, not the baffle. Geometry correctly blocked the ray; no production fix was needed.

`mob3-writer-2/` preserves the fixture preimage and two clean53-assertion runs. Fixture now uses player(-1.5,0,-7), historical mob(-1.5,0,-10), current off-axis mob(100,0,-10), explicit clear-wall/ray preconditions and an old250 ms counterfactual miss. Actual450 ms at/below/above checks remain.

Independent evidence:
- `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/game99-mob3-buffered-ibdpomsr/native-v2/`: focused53, editable641, camera33, invariants43; all exit0, only the expected ownership-negative warning. Original `native/` failure retained.
- Same directory, `direct/` and `delay150-no-loss/`:715 frame observations and715 post-draw records each; all owned processes0, ordinary logs clean,282 protected records unchanged. Proxy1714 packets forwarded, zero dropped.
- Mob20 fully bracketed: direct359 frames/5.97 seconds, delayed367 frames/6.10 seconds. Movement gaps median/max16.697/19.648 ms direct;16.750/18.602 ms delayed. No after-history samples or movement holds at least65 ms in these selected active windows. Overall frame maxima113/116 ms include startup; do not claim every frame stayed below20 ms.
- `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/game99-mob3-shots-o5cjjdys/`: fresh150 ms RTT isolated-shot profile,18 submitted/adjudicated/confirmed/accepted hits,18/18 displayed-ray/server target matches; no misses/rejections/clamps. Actual view age386.651–403.591 ms, median386.882: every shot exercises the newly authorized bound above250 ms and within450 ms. Proxy1789 packets forwarded, zero drops; logs clean, processes0,282 protected records unchanged.

These are controlled local results, not arbitrary WAN, capacity, physical-input, two-human, or human visual acceptance. Prior prediction failures remain separate. No source edits followed final checks except this ledger.

## Next: isolated release

Source work unit committed locally as `66d8a938b3144a48e51874728c04724c244339cd` (`fix(net): align buffered enemy visuals with bounded rewind`),11 files,+319/-53. Only named source/tests/docs/ledger paths were staged; index empty afterward. Auto-detected identity warning was left untouched, without configuration change or amend. Preserve existing15 export artifacts before one pinned export and bind the new runtime/ELF/PCK identities. Current source is not frozen466/c8. Do not modify historical release466 acceptance documents.

Fresh parent-owned VPS inspection must bind actual current release/process/unit/isolation/listener/source-restricted firewall and neighboring identities. Promote only a new immutable cooperative release under the original normal unit; retain466 and3f3 for rollback. No old one-shot replay, blind retry, cleanup, or unknown-state overwrite. Verify the new candidate, preserve all failures, then document actual results and pending human visual confirmation.

Previous full ledger is preserved at `logs/enemy-motion-smoothing/mob3-bookkeeping/before-source-closure.md`. Historical MOB-1 evidence remains under `logs/enemy-motion-smoothing/{writer-1,writer-2,independent-1,independent-2,parent-spot-1}/`.


### MOB-4 checkpoint

One export passed in16.363 seconds:15 artifacts,427223589 bytes; runtime `783ab196ad89bb3db19cb51fba5249e046d3541248daba91dc37fc47c6b09d9e`,80 files. All522 protected body/proof records unchanged; both import/export logs clean. The98 verified preimages retain old466 artifacts at `/var/folders/kq/sw184q4x2vz7vp4dcxhk4hg40000gn/T/game99-release66d8-export-preimages-rd3neuj6`. Three genuine UIDs appeared for mob timing, visual sampler and focused test. Manifest `d1d00d29160c9aa56d794c9a4f6273c748ef7997f3611a8e05da4da10c908748`; x86 ELF `a0bde597a5e312fe51fdec3d2edc5a9f3f0dd5e88c9c56b432c8de53dda56ae8`; macOS PCK `3222acbf6514caaf0eb222a4a45baa407fd112e7378ad6e24ff5dc2b16d0ff15`. Export evidence: `logs/enemy-motion-smoothing/release-66d8a93-export-1/`.

Operational helper evidence is in `release-66d8a93-deployment-1/` under the same feature logs. Offline review caught root calculation, export-receipt field, restore-after-PASS, discarded failure output, reusable inspect, plan binding and runtime enumeration defects before SSH. Initial scaffold tests were not validation. Parent-prose neighbor PID transcription was corrected from the original plan: authenticated Game99 PID754488, not99754488. Final independent23 pure tests passed after Python3.9 timeout-output compatibility and UUID test-receipt fixes. Earlier failures and code snapshots remain; exact immediate helper/test preimages before repair1 were not captured, and `repair-1/PREIMAGE-INDEX.md` records that gap. Repair2 full preimages are preserved. No configured TDD evidence is claimed.

Parent then ran native preflight, stage and activate once each: all PASS. Fresh old baseline was466/PID2425219/epoch570206795; staging published a new immutable candidate without service changes. Activation switched only owned current and restarted only the cooperative service. New live PID3088396, epoch1635698347, Job0, pinned new ELF. Original base unit18de4, normal command, Restart=on-failure, unlimited lifetime, no drop-in/metrics flags, DynamicUser63324, resource/sandbox/state policies, source-restricted raw firewall3f52, listener, Noray PID1893481 and Game99 PID754488 unchanged. Old466 and3f3 releases and owned upload directory remain. Exact startup cursor is preserved in activation before/after records. No rollback was needed.

### WAN outcomes: acceptance remains open

The fresh `release-66d8a93-wan-1/` profile actually ran once after a clean native parse-only check. Parent preserved and corrected pre-execution observer syntax/type/deferred-scene defects; the writer also corrected metadata/authority and fail-fast contracts. Three owned clients ran across the two new profiles below, never a local server/proxy or historical one-shot replay.

**WAN1:** source GUI PID63142/peer616555788, 711 frames and711 draws;19 submitted/confirmed hits with19/19 displayed-ray target matches. The sequential frozen executable/PCK client PID63303/peer1679974869 had8 bound-ready reports, updates5->181, valid authority/Input ownership and no broadcasting. Both observed native run729184; the source observed epoch1635698347. Both exited naturally0 with clean raw logs;285 protected files unchanged. RTT samples median66.686/p9592.967/max100.166 ms.

Original WAN1 analysis remains **FAIL**. It detected one76.807 ms movement interval for each of six qualifying mobs. Independent readback shows a single global render stall: consecutive frames154->155, no intervening draws, all six poses advanced and targets remained bracketed. It was not six independent snapshot-wait pauses. The analyzer additionally had an inverted `fail(bool(misses))` predicate, falsely rejecting an empty miss list; original code/result and all raw evidence remain intact.

**One capture-free control:** `release-66d8a93-wan-frame-control-1/`, source GUI only, same observer bytes and window requests; no exported-client replay or server change.708 frames/draws,8 qualifying mobs, natural0, clean raw logs and285 unchanged protected files. Epoch1635698347/run729184 remained bound. Its corrected miss predicate did not waive any motion/identity gate. Analysis remains **FAIL**:
- Global frame intervals72.817/87.102/93.937 ms show screenshot capture was not necessary for the stalls; their cause remains unproved.
- Long4.134698/4.068050-second visual intervals for mobs25/26 span player death and respawn. Frames361/365 retain ticks264396/264398 until609/tick264522; player dies425 and respawns606. ACTIVE state plus total window displacement does not establish continuous authoritative motion through that interior interval. Client records do not reveal whether the server was stationary or moving unobserved; no arbitrary exclusion or retroactive PASS.
-13 submitted/confirmed hits,12/13 strict ID matches, no confirmed misses. Life2/shot4 selects rendered25 but server26. Read-only geometry reconstruction shows25/26/27 have **exactly coincident rendered feet**(0.8,0,-3.07) and identical ray entry1.099126 m. The observer chooses25 by array-order tie-break; no unique visible target is established. Confirmed endpoint is on the submitted ray (perpendicular residual0.00000053 m),1.874 mm before the client capsule entry. Centimetre encoding can shift coordinates up to5 mm per component, but quantization, raw server history, origin, cache replay and rewind causality are not determined from this capture. Do not claim a uniquely wrong visible enemy or silently convert strict FAIL into PASS.

No further runtime profiles, game edits, exports or restarts followed these results. The user selected **"Probarla vos ahora (Recomendado)"**: pause automated work and evaluate the current matching client against the already-running candidate. Await feedback on periodic enemy movement, aiming and death/respawn; do not make further game/service changes while the user tests. This selection does not close acceptance or waive the retained failures. Existing server logs contain no per-shot/historical-pose trace; missing authoritative evidence cannot be recovered by inventing it.

### Postrun isolation and journal

Fresh parent read-only inspections `inspect-20df4daafadfecdf1a1df50d.json` (after WAN1) and `inspect-6df7deb234a285ac98f2d11d.json` (after the control), under deployment `.state/`, both passed: same66/PID3088396/epoch1635698347/Job0, ELF, normal unit, sandbox/limits, source-restricted firewall and neighboring identities. Candidate66 remains live under evaluation; no restore was performed.

One `.state/journal.json` capture passed, using the canonical activation-before cursor through the fresh postrun END. Eight normal stop/start/readiness entries were read completely; no engine warnings/errors/leaks. The END equals the startup-ready cursor because no subsequent entries exist, not because the startup boundary was substituted. This is service/journal health, not gameplay approval, capacity, queue-age or roster-zero evidence.

MOB-4 and human visual acceptance remain open. No new66 full-suite/Linux runtime/benchmark acceptance was run; historical466 results remain historical. Genuine export UIDs and post-source ledger changes remain pending scoped bookkeeping; no completed-release documentation or acceptance commit is claimed.

## Later publication authorization
The user subsequently requested publishing the existing work and selected a clean publication snapshot after learning that four old local commits contained an operational host address. The original local branch/history remains intact. Sanitized final source and genuine resource UIDs are included in clean publication source commit `9e78c1a0771cddd0e74cb930d0d721994889b51b` on `feat/networking-skills-clean`, without those old feature-branch parents. This records publication, not a new deployment or a retroactive PASS for earlier WAN failures. See `odd/tasks/networking-skills-and-publish.md` for the current delivery decision and checks.
