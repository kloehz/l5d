# VPS deployment status

**Release `46652293592683158a1bfadecd810bc842498cb1` is running on the existing isolated cooperative service.** Independent analysis passed all 11 semantic gates from one four-client WAN profile, and a separate first normal-service two-client smoke passed. This is bounded evidence, not a guarantee of arbitrary-source WAN behavior, universal VPS capacity, physical-input play, or signed publication. UDP `27015` remains source-restricted; no general public ingress was opened.

See [release evidence](releases/4665229.md) for the profile boundaries and exact local evidence index. Ignored recovery receipts and raw captures remain local; they are not downloaded or published receipts, signed authority, or tracked evidence.

## Live service identity

| Field | Observed value |
| --- | --- |
| Source | `46652293592683158a1bfadecd810bc842498cb1` |
| Runtime fingerprint | `c8b36346a210e9d69a72a5d91638fd304f4101c9d8b8f537978a1113e59f5b14` (78 files) |
| Normal-service x86 ELF | `eca1a8047d9101e3d8d4da8f4af6f214f43b366f9f32017659af3b72365ece9b` |
| Normal process | PID `2425219`, ready epoch `570206795`, Job 0 |
| Runtime identity and limits | Non-root UID/GID `63324`; `DynamicUser`; 512 MiB memory, half-core CPU, 64 tasks |
| Base unit | `18de4e8ac53738f4e5a9ffb1743b162794a3844f0eaeb0d11431b0fd527bcce2` (unchanged) |
| Service policy | `Restart=on-failure`; unlimited lifetime; no drop-in; no metrics or run-ID flags |
| Network boundary | UDP `27015` retains its original source-restricted rule and firewall bytes |
| Retained rollback release | `3f3f80aadaebcd1cb4115db9c1397ef1cfede6de`; prior ELF `4c934b7974678dca11c39943d52aef997cf85bdfcf5f0b5307e4b025052c6e8f` |

Neighboring processes, unit hashes, and firewall bytes were unchanged. No account, global security, unrelated service, source, vendor, history, clock, or protocol changes were made. The earlier PIDs `1211296` and `2280633` are historical and are not the current process.

## What the WAN evidence establishes

The original four-client CLI receipt remains **FAIL** because its analyzer had a string/Path defect. The profile itself was run once; its immutable raw evidence was retained, and rollback was explicit. Independent analysis, separate from that CLI, passed all 11 semantic gates after 23 fixtures. The profile observed same-life movement, combat and survival, respawn, late join, same-process reconnect, root authority, peer-owned input, no input broadcast, natural client exits, and bounded cleanup. Cleanup's conservative worst-case was 3.236061 seconds. Five unbound initial metadata rows were excluded; malformed or regressed complete records fail. This does not establish synchronized clocks or universal WAN behavior.

After normal-service preflight and activation of the existing immutable release, the first normal CLI attempt failed before spawning clients because it read the wrong cursor field; its receipt is preserved and no profile ran. A corrected, predecessor-bound first profile then passed once with two clients over 12 seconds. Both exited naturally, reported distinct peers and advancing updates, and shared the new normal run identity. PID, ELF, unit policy, firewall, and neighbors remained stable. The normal service has no metrics flag, so this smoke does not prove a directly observed normal roster count of zero. The separate canary supplies the bounded cleanup evidence.

Physical keyboard/mouse use and real two-human play remain manual. Operator-source bots do not prove arbitrary WAN sources, general VPS capacity, or signed publishing. No push, pull request, merge, or publication is claimed.

## Deployment and rollback boundary

The service already exists. `scripts/deploy_vps.py` is an **initial installer** that refuses existing targets; it is not an updater. Do not rerun it, replay the canary or normal first-profile helpers, or remove preserved markers. No firewall opening is needed or authorized.

Rollback is parent-only. The fixed read-only `recovery/normal_release.py` inspection produces a nonce-scoped fingerprint. Only an explicit restore using that exact freshly returned fingerprint may proceed; it rechecks the settled Job 0, current process, base unit, firewall, and neighbors, and is limited to this service and its owned release link. It is not a blind replay. Do not execute recovery or administrative commands from this document.

Local ignored evidence is under `logs/vps-deployment/release-4665229-attempt-6/`: independent analysis at `recovery/analysis-independent-v4.json`, immutable capture under `recovery/evidence/`, and normal preflight, activation, and first-smoke receipts under `recovery/normal-v3/`. The failed original canary and zero-client normal attempt remain preserved at their original paths. Raw operator/client addresses are intentionally omitted from tracked documentation.