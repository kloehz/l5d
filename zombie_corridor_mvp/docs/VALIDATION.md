# Validation evidence

## Current release: 4665229 (local acceptance)

**Status: PASS for local acceptance; release `4665229` is also deployed on the isolated cooperative service.** Source commit `46652293592683158a1bfadecd810bc842498cb1`; runtime source fingerprint `c8b36346a210e9d69a72a5d91638fd304f4101c9d8b8f537978a1113e59f5b14` (78 files). The pinned export ran once. All 15 artifacts (427,196,460 bytes) matched manifest SHA256 `f50fa31dc80aabea17a1e8e1110d021a279f5732201ae4e626db591e3c14414e` and checksum-list SHA256 `2df9e5ba67cf3ffbeee2413fa5a1858f1bf7b83659260de757a3634eec9c5a72`. The deployment evidence is bounded: one WAN profile's independent analysis passed 11 semantic gates, and a separate first normal-service two-client smoke passed. This does not establish arbitrary-source WAN behavior, general VPS capacity, or manual physical-input play.

A fresh separate full suite ran once: exit 0, no timeout, 907.94 seconds. The eight observed stages were invariants (0.55s), transport (8.96s), validation (157.74s), lifecycle (84.75s), Linux transport (62.44s), render (11.25s), GUI (13.47s), and benchmarks (568.66s). Canonical records are `logs/release-4665229-export-1/full-suite-receipt.json`, `full-suite-verified.json`, and `full-suite.log`; machine results are in `results/final-suite.json`, `validation.json`, `lifecycle.json`, `linux-transport.json`, `benchmark-summary.json`, and the current 78-file source record in `logs/release-4665229-export-1/verified.json`. `results/runtime-source-manifest.json` remains historical (`10b811…`); it does not identify this release.

The eight-stage suite establishes local acceptance of the frozen artifacts only; deployment and WAN observations are separate, bounded evidence summarized below. Neither evidence set establishes general VPS capacity, arbitrary-source public-WAN behavior, native physical keyboard/mouse interaction, or two-person manual play. No signed or published release is claimed.

### Runtime and lifecycle evidence

- All 15 frozen export artifacts matched the recorded hashes and byte counts. The macOS executable alone does not identify the PCK; use the paired PCK identity in the release receipt.
- Linux arm64 and amd64 ELF artifacts ran in local Docker and matched their frozen identities. Two macOS clients exited naturally after combat/respawn checks. Linux servers were copied while alive; the existing harness then force-removed its own UUID containers. **Do not claim natural server-container exit 0.** A read-only Docker check found no residual `zombie-transport` containers.
- Some live server JSONL captures end with a partial tick. Accepted counts use complete prefixes; do not claim all raw JSONL is parseable or that invalid live data was clamped.
- Current full-suite independent raw-log audit covered all eight adverse logs, including BOT logs and JSONL. It found zero ordinary errors, warnings, expired inputs, missing references, or leaks. Expected negative evidence remains: the malicious-position invariant warning and bind-conflict error. Cadence/dead-life rejections are business rejections, not stale-input warnings. The suite helper's escaped error-word-boundary regex was flawed; the independent raw-log audit bridged this candidate. No helper change, replay, or blanket waiver was made; the existing eight-stage gate passed.

### Benchmarks and manual boundaries

Each of eight scenarios had 60 measured server samples and 60 unique nearest-matched OS samples, after 10 seconds warmup; measured ticks were 1,800 except dormant20 at 1,802. Raw OS sample rows vary (69–70 for some cases). CPU/RSS samples were finite and nonnegative. Four-player/50-active on the local M5 measured p95/p99 tick 5.305/5.816ms, mean CPU 12.415% of one core and peak RSS 101.8125MiB. These local measurements are not VPS capacity estimates. Physical keyboard/mouse and two-person testing remain manual and outside automated proof.

## Reproduce the automated checks

From `zombie_corridor_mvp/`, first preserve existing `builds/`, `logs/` and `results/` with hash-verified copies. The scripts overwrite generated outputs; the recorded one-shot receipt helpers must not be replayed. Keep the pinned Godot4.7 binary/templates and Netfox1.35.3, and require a working existing Docker daemon for both Linux architectures.

```bash
# A new candidate only: regenerate all three matching exports.
bash scripts/export_builds.sh
# Check every builds/manifest.json entry and builds/SHA256SUMS first.
python3 scripts/run_final_suite.py
# Focused source regressions are additional to the eight-stage suite.
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/startup_input_budget.tscn
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/state_snapshot_admission.tscn
python3 -B -m unittest discover -s tests -p test_validation_diagnostics.py -v
python3 -B -m unittest discover -s tests -p test_run_benchmark_sampler.py -v
```

Exit0 or JSON PASS alone is insufficient: inspect the fresh case-local raw logs for ordinary errors, expired inputs and missing references, separating only the explicitly labeled negative fixtures. Recompute the runtime fingerprint and verify frozen artifact hashes before and after acceptance. Do not change clocks, history windows, SDKs or gates to make a failing run pass.

## Historical source and release evidence

These earlier records remain useful component evidence but are not interchangeable with the current frozen release:

- **3f3f80a** (`VPS-FIX-1`): disconnect-cleanup fix and its source checks; its separate historical export/full-suite acceptance does not describe current source.
- **44edbfc** (`VPS-FIX-3`): history-refresh source work. Its later `VPS-FIX-4` export/full-suite attempt had ordinary missing-reference diagnostics and is a preserved failure, not a current pass or waiver. Its original run log is `logs/vps-fix-4-final-suite-20261014-154321-069546.log` (the machine PASS was not strict raw-log acceptance).
- **006f1e6** (`VPS-FIX-5`): acknowledged-state reference guard. Historical 150ms/5% source-adverse runs had old-input events of ages 17–21; packet acceptance and cause were unresolved. Those events were not waived or retroactively erased.
- **4665229 / c8b363**: subsequent input/state admission work and the current local frozen-release pass documented above. The clean current suite does not establish a universal WAN/loss guarantee or deployment acceptance.

The earlier graphical `facing = null` failure remains unattributed. A state regression demonstrated a sparse-history-to-null-wire path and valid facing-state delivery after its guard, but the fresh GUI pass does not establish that earlier failure's cause. Preserve all failed probes, path incidents, fixture failures, and overrun receipts; observed RED/GREEN work did not activate Strict TDD.

## Deployment evidence and closeout

Release-specific artifact hashes, byte counts, stage details, and limitations are recorded in [`docs/releases/4665229.md`](releases/4665229.md). Current service identity, profile boundaries, local ignored evidence paths, and parent-only rollback boundary are in [`docs/DEPLOYMENT.md`](DEPLOYMENT.md). ODD task status and preservation/recovery history are in [`../../odd/tasks/vps-deployment.md`](../../odd/tasks/vps-deployment.md).

The current normal service is source `4665229`, PID `2425219`, ready epoch `570206795`, running the verified x86 ELF. UDP `27015` remains source-restricted. The normal unit has no metrics flag, so the normal smoke does not establish a directly observed normal roster-zero count; bounded cleanup comes from the separate canary profile. The canary's original CLI receipt remains FAIL even though independent analysis passed. No profile replay, general public ingress, arbitrary-source guarantee, or VPS-capacity claim is authorized. All 11 deployment tasks are complete; final documentation passed independent readback and is committed as `129c8bb6abd7ddb91a5abd6b8c1582874a04ba43`. Physical-input and real two-human checks remain manual.
