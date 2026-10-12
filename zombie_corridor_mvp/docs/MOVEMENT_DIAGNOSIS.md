# Pinned ENet movement starvation diagnosis

## Retained failure, not a retry-based pass

The frozen candidate initially stopped at the two-client movement gate:
`logs/failed-frozen-transport.log` and `results/final-suite-failed-transport.json`.
No dependent acceptance or benchmark stages launched after that failure.

A bounded six-run **serial** source comparison preserved every log under
`logs/movement-diagnosis-default/0..5`; run3 failed, five passed. Its second client
predicted at most6.833m but finished with only4.833m accepted movement. The server
was ready and clock-synchronized; both loops continued around60Hz/30Hz. The client
recorded1.9665s connected process delta at its2.018s sample and483 process frames
at8.001s. No other game/proxy/benchmark processes were present. Unique random UDP
ports and scoped PIDs rule out overlapping prior sessions. This was not a harness
start/input-duration race or a main-loop stall.

In `logs/movement-diagnosis-default/3/transport-bot-1.jsonl`, actual ENet
`packetThrottleLimit` fell to1/32 at1.0086s with23ms RTT. The server's other peer
remained healthy. Unreliable movement/ping messages starved while reliable
lifecycle still worked. The client later recovered to32/32, after its movement
intent interval had ended.

## Proven pinned-source cause and narrow remedy

The [official Godot4.7 create_server implementation](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/modules/enet/enet_multiplayer_peer.cpp)
passes the derived channel count as the fifth `create_host_bound` argument. The
[official ENetConnection signature](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/modules/enet/enet_connection.h)
identifies that argument as **incoming bandwidth**, not maximum channels. The
[system-channel enum](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/modules/enet/enet_multiplayer_peer.h)
is2, so our requested16 channels became an unintended **18bytes/s** incoming
bandwidth advertisement. The host channel-limit argument was0 instead.

After successful bind and before connection polling, `NetSession.start_server`
now calls `peer.host.bandwidth_limit(0,0)` and `peer.host.channel_limit(18)`. These
restore unlimited transport bandwidth and16application+2system channels. The
[public wrapper](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/modules/enet/enet_connection.cpp)
uses ENet's normal host operations. **RTT-based congestion throttling remains
unchanged**; no peer throttle override, addon patch or reliable movement workaround
was introduced. Application snapshot budgets remain bounded independently.

## Controlled post-fix evidence

Six further serial runs used the unchanged distance/authority/clocks assertions,
plus stronger checks on **server-accepted** displacement and actual throttle limit.
All12 client connections passed: accepted displacement9.000–10.000m after2s input
at5m/s; every ready sample reported throttle_limit32. Raw logs are retained under
`logs/movement-diagnosis-fixed/0..5`; summary `results/movement-diagnosis-fixed.json`.
The older default comparison is preserved unchanged. No source runs remained alive.

Server raw samples additionally record each peer's actual RTT/throttle, readiness,
clock synchronization, latest submitted input tick and input age. Input-age
metadata stays **server-only** and is removed from public metrics; client intentions
are never broadcast to other clients. Bot reports record real process delta,
frames, poll calls, clock ticks and accepted poses separately from predicted poses.

The complete final frozen release suite and all eight final benchmarks are separate
proofs listed in `docs/VALIDATION.md`; this bounded diagnosis alone does not certify
remote network quality or VPS capacity.

## Distinct adaptive-baseline failure and bounded calibration

The later metric-corrected candidate failed four-player load with **limit32 but
actual throttle0**. This is distinct from the18B/s advertisement bug. Retained
frozen failure: `logs/failed-adaptive-throttle`, `results/failed-adaptive-throttle`.
No dependent workloads ran after the failed gate. A fresh read-only diagnosis
confirmed immediate client-to-server unreliable input starvation; its initial RTT
baseline trigger was not claimed proven until new public poll statistics existed.

`python3 scripts/diagnose_four_player.py --label default` reuses the existing
four-player active50 acceptance case, unchanged assertions, at most6 serial runs,
and stops on its first failure. It failed run0. Buffered public per-poll statistics
in `logs/adaptive-diagnosis-default/0/four_player-bot-1-poll.jsonl` show:

- LAST_RTT14ms /LAST_VARIANCE7ms, epoch235ms, interval5000ms;
- actual filtered RTT26ms and throttle24→0 between0.106s and0.139s;
- the same baseline/epoch persists through5.010s with throttle0;
- first rollover epoch5238ms increases baseline variance to11ms; recovery follows.

[Official ENet ACK handling](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/thirdparty/enet/protocol.c)
refreshes its baseline only at the configured interval and applies throttle per ACK.
The [native throttle algorithm](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/thirdparty/enet/peer.c)
compares individual ACK RTT against that baseline/variance. Individual raw ACK RTT
is not exposed by the public API: the exact triggering samples are inferred from
this source and measured transitions, not fabricated as directly measured values.
The baseline persistence, throttle collapse and sparse server input arrival are
direct measurements. Clock/readiness/input duration stayed normal.

The narrow calibration calls public `throttle_configure(100,2,2)` immediately on
connection, before bootstrap. Only baseline interval changes; **positive2/2
acceleration/deceleration and normal congestion-based drops remain enabled**.
No input-delay workaround, forced throttle32, reliable movement substitution or
assertion weakening is used. Tradeoff: faster adaptation to60Hz polling/bootstrap
RTT, but a shorter statistical window can react to transient jitter. Actual adverse
network acceptance remains a separate required gate, not assumed from this result.

`--label interval100` then passed all6 unchanged groups /24 real clients. Accepted
movement8.500–10.000m;46–64 baseline epochs over12s; observed minimum throttle2/32
proves adaptation was **not** disabled. Summary `results/adaptive-diagnosis-interval100.json`
and all raw traces are retained. Buffers cap8192 rows and flush at normal exit;
no per-poll file I/O. These extra traces are test-only and not enabled in benchmarks.
All final exports, acceptance and eight benchmarks use the calibrated source;
see `docs/VALIDATION.md` for their final identity and outcomes.
