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
| MOB-3 | Replace prediction with buffered interpolation and matching bounded server rewind | VERIFIED LOCALLY; COMMIT PENDING | Native53/641/33/43; actual direct/delayed movement;18/18 displayed/server hit identity matches. |
| MOB-4 | Export, update only the cooperative service with rollback, verify and document | PENDING | Existing live/frozen466 release remains unchanged until guarded candidate promotion. |

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

Commit only the verified source/tests/docs and ledger on this branch. Preserve existing15 export artifacts before one pinned export and bind the new runtime/ELF/PCK identities. Current source is not frozen466/c8. Do not modify historical release466 acceptance documents.

Fresh parent-owned VPS inspection must bind actual current release/process/unit/isolation/listener/source-restricted firewall and neighboring identities. Promote only a new immutable cooperative release under the original normal unit; retain466 and3f3 for rollback. No old one-shot replay, blind retry, cleanup, or unknown-state overwrite. Verify the new candidate, preserve all failures, then document actual results and pending human visual confirmation.

Previous full ledger is preserved at `logs/enemy-motion-smoothing/mob3-bookkeeping/before-source-closure.md`. Historical MOB-1 evidence remains under `logs/enemy-motion-smoothing/{writer-1,writer-2,independent-1,independent-2,parent-spot-1}/`.
