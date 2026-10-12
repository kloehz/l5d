# Final validation evidence

## Current frozen candidate

The current local release candidate passed the full fail-fast suite. This is local source/export evidence only: it does not prove a VPS, a public Internet route, firewall rules, SSH access or native physical keyboard/mouse input.

| Identity | Value |
| --- | --- |
| Runtime source SHA256 | `dc00eece5d10abb957d02c242bf1452dcd0732cfc9e910a2dd3689f2f9feb006` |
| Runtime source manifest | `results/runtime-source-manifest.json` (`77` files) |
| Build manifest SHA256 | `2e226b5047ec6f864b55082aca6bad38631391547b54fd35b24eb060c3460e47` |
| Build artifacts | `builds/manifest.json` (`15` artifacts) and `builds/SHA256SUMS` (`15` matching entries) |
| Engine / addon | Godot `4.7.stable.official.5b4e0cb0f`; Netfox `1.35.3` |
| Host | Apple M5, macOS `26.5.1`, ARM64, 10 logical CPUs |
| Full-suite result | `results/final-suite.json`: `PASS`, 8 stages, 886.23 seconds |

The source manifest and build manifest are the stable references for exact file identities. Prefer those machine-readable reports over copied counts when auditing current bytes.

## Commands and verified outcomes

| Command/test | Verified result | Evidence |
| --- | --- | --- |
| pinned Godot `--headless --path . res://tests/invariants.tscn` | exit 0; invariant assertions passed; expected malicious-position warning only | `logs/invariants-final.log` |
| `python3 scripts/transport_smoke.py` | exit 0; real dedicated server plus two clients; predicted and accepted movement gates passed | `logs/transport-final-result.log` |
| `python3 scripts/run_validation.py --case all --build` | exit 0; all eight release validation groups passed | `results/validation.json`, `logs/validation-final-release.log` |
| `python3 scripts/run_lifecycle_checks.py` | exit 0; bind/handshake rejection, reconnect, exported Probar local and normal waves passed | `results/lifecycle.json`, `logs/lifecycle-final.log` |
| `python3 scripts/run_linux_transport.py` | exit 0; both actual Linux dedicated exports passed with macOS clients through local Docker | `results/linux-transport.json`, `logs/linux-transport-final.log` |
| `python3 scripts/capture_release_frames.py` | exit 0; exported gameplay/menu Viewport PNGs captured | `results/gameplay.png`, `results/menu.png`, `logs/render-final.log` |
| `python3 scripts/run_local_demo.py --duration 12` | exit 0; one dedicated server and two GUI clients became ready; owned session cleaned up | `logs/gui-final.log` |
| `python3 scripts/run_benchmark.py` | exit 0; all eight serial benchmark scenarios passed | `results/benchmark-summary.json`, `logs/benchmark-final-run.log` |

No engine/unit/full-suite rerun is implied by this document refresh. The table records already-observed reports.

## Real-transport authority, spatial and lifecycle proof

- `combat_authority` passed with 20 server kills, 80 server combat hits, 77 cached retries, deaths `[2, 1]` and respawns `[2, 1]` in `results/validation.json`.
- `dormant20` and `dormant100` passed with zero dormant movement, AI and navigation counters in the benchmark summaries and validation reports.
- `split_aoi` passed with 20 active and zero dormant records, two separated clients and retained per-peer snapshot evidence.
- `four_player` passed with four independent ENet clients and 50 active mobs.
- `results/lifecycle.json` passed all four groups: protocol rejection, same-GUI reconnect with two distinct peer IDs, exported Probar local child cleanup and normal play reaching wave 4 with 42 kills.

Current per-scenario details live in `results/validation.json`. Historical numeric values from earlier suites are retained only in the preserved failure directories and are not current evidence.

## Linux release transport

| Actual Linux dedicated release | Observed combat | Environment |
| --- | --- | --- |
| arm64 | 65 hits, 15 kills, deaths `[4, 4]`, respawns `[3, 3]` | local Docker `linux/arm64`, image `postgres:16`, UDP mapped only to `127.0.0.1` |
| x86_64 | 83 hits, 20 kills, deaths `[3, 3]`, respawns `[3, 3]` | local Docker `linux/amd64`, image `debian:bookworm-slim`, UDP mapped only to `127.0.0.1` |

This proves the exported Linux server binaries run locally under Docker. It does not prove a public VPS, host firewall, provider networking, VPN, authentication or deployment target.

## Controlled UDP adversity

| Configured RTT / loss / jitter | Measured median application RTT | Actual proxy loss | Confirmed gameplay |
| --- | ---: | ---: | --- |
| 100 ms / 2% / none | 119.2645 ms | 145/7361 dropped (1.970%) | 17 kills, 73 hits, deaths `[5, 4]`, respawns `[4, 4]`, snapshots `[4823, 4820]` |
| 150 ms / 5% / ±20 ms per leg | 167.424 ms | 373/7506 dropped (4.969%) | 14 kills, 63 hits, deaths `[5, 4]`, respawns `[4, 4]`, snapshots `[4821, 4598]` |

Proxy counters are retained in `results/adverse100-proxy.json` and `results/adverse150-proxy.json`; validation outcomes are in `results/validation.json`.

## Final eight benchmarks

All eight scenarios used the frozen source/build identities listed above. Each run used 10 seconds warmup, then 60 seconds observed, 1,800 measured ticks and 60 OS samples. CPU `100%` means one core. RSS is MiB. Application TX/RX are encoded custom RPC argument payload bytes and exclude Netfox/default-channel plus Godot/ENet framing.

| Scenario | Tick p50 / p95 / p99 ms | Rollback p95 ms | CPU mean, %1core | RSS peak MiB | Active / dormant mean | App TX / RX B/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A: 0 players / 0 mobs | 0.019 / 0.038 / 0.044 | 0.003 | 0.488 | 98.906 | 0.00 / 0.00 | 0.0 / 0.0 |
| B: 1 player / 0 mobs | 0.617 / 0.916 / 1.130 | 0.838 | 3.432 | 100.375 | 0.00 / 0.00 | 1508.3 / 31.0 |
| C: 1 player / 20 active | 0.757 / 1.325 / 1.655 | 0.892 | 3.753 | 99.594 | 20.00 / 0.00 | 7400.9 / 30.7 |
| D: 1 player / 20 dormant | 0.667 / 1.196 / 1.422 | 1.132 | 3.512 | 100.422 | 0.00 / 20.00 | 1516.1 / 30.7 |
| E: 1 player / 100 dormant | 0.659 / 0.828 / 0.991 | 0.770 | 3.502 | 100.859 | 0.00 / 100.00 | 1516.8 / 31.0 |
| F: 4 players / 50 active | 6.925 / 10.521 / 11.687 | 8.044 | 6.952 | 85.016 | 50.00 / 0.00 | 66964.0 / 123.9 |
| G: 2 players / split groups | 1.234 / 2.219 / 2.429 | 1.179 | 4.284 | 100.469 | 20.00 / 0.00 | 9606.0 / 62.0 |
| H: 2 players / 20 combat initially | 2.053 / 4.042 / 5.037 | 2.562 | 4.654 | 100.688 | 12.07 / 1.00 | 13418.1 / 862.2 |

All CPU/RSS values, including tails, are finite and nonnegative in the accepted summary. Local tick p95 stays below the 16.7 ms margin goal; that is not a capacity guarantee for a VPS.

### Effective clocks and real breakdowns

| Scenario | Network / physics / loop / poll Hz mean | Movement / mob move / AI / activation / interest / publication / encode / combat mean ms |
| --- | ---: | ---: |
| idle | 30.00 / 30.00 / 60.01 / 60.01 | 0.0000 / 0.0004 / 0.0003 / 0.0002 / 0.0000 / 0.0001 / 0.0000 / 0.0012 |
| player | 30.03 / 30.03 / 60.06 / 60.06 | 0.0254 / 0.0002 / 0.0003 / 0.0005 / 0.0004 / 0.0005 / 0.0000 / 0.0010 |
| active20 | 30.03 / 30.03 / 60.07 / 60.07 | 0.0251 / 0.0684 / 0.0027 / 0.0017 / 0.0013 / 0.1388 / 0.0067 / 0.0010 |
| dormant20 | 30.03 / 30.03 / 60.06 / 60.06 | 0.0275 / 0.0002 / 0.0004 / 0.0005 / 0.0004 / 0.0005 / 0.0000 / 0.0011 |
| dormant100 | 30.04 / 30.04 / 60.08 / 60.08 | 0.0319 / 0.0002 / 0.0004 / 0.0005 / 0.0004 / 0.0005 / 0.0000 / 0.0010 |
| active50 | 30.10 / 30.10 / 60.20 / 60.20 | 0.0702 / 0.1393 / 0.0085 / 0.0050 / 0.0078 / 0.9888 / 0.0463 / 0.0010 |
| split | 30.05 / 30.05 / 60.11 / 60.11 | 0.0417 / 0.0666 / 0.0034 / 0.0021 / 0.0016 / 0.2772 / 0.0066 / 0.0009 |
| combat | 30.06 / 30.04 / 60.08 / 60.08 | 0.0473 / 0.0509 / 0.0021 / 0.0021 / 0.0497 / 0.2516 / 0.0086 / 0.3197 |

Ticks measure actual network movement/rollback loop work amortized across new ticks plus the committed tick's gameplay. `movement_ms` is nested in rollback; encode serialization is nested in interest/publication/combat; do not add nested columns. Logging, polling and sample overhead are excluded from explicit tick wall boundaries but included in OS CPU.

## Preserved failures and narrow fixes

- The first benchmark attempt is historical only; retained logs and identities are not final evidence.
- A frozen-suite transport failure and movement diagnosis are retained in `logs/failed-frozen-transport.log`, `results/final-suite-failed-transport.json` and `docs/MOVEMENT_DIAGNOSIS.md`.
- The pre-metric-fix suite is historical and partial; final benchmarks above were rerun after the metric fix.
- The adaptive-throttle failure is historical and retained in `logs/failed-adaptive-throttle` and `results/failed-adaptive-throttle`.
- A later SCN-6 benchmark run failed because an OS CPU sample became negative after the server exit boundary. The accepted fix changed the sampler lifecycle only: it polls liveness after sleep and around `ps`, drops terminal unavailable/dead-counter rows, rejects live cumulative regressions and preserves true zero CPU. It did not clamp negative values or relax the finite/nonnegative summary guard. Eight deterministic sampler regression tests and the full suite rerun passed.
- The exact raw `ps` token for the negative sample was not logged. The exit/zombie explanation is a consistent hypothesis from the timing evidence, not a raw fact.

## External pending

Native physical keyboard/mouse interaction has not been automated. Current proof includes game-owned Viewport input/camera checks, exported rendered frames and prior human gameplay acceptance, but not OS-level native input. Remote deployment/public UDP verification still needs an explicit authorized destination. No historical host was contacted, no SSH command was run and no firewall, VPN, auth or service configuration was changed.
