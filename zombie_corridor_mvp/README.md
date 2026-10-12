# Corridor 99 — native cooperative prototype

A complete over-the-shoulder cooperative capsule survival game for **1–4 players**, with one separate ENet dedicated server. Godot **4.7 stable**, GDScript, Compatibility renderer and Netfox **1.35.3**. No external art, accounts, relay or listen-server player.

## Play now

Run the current source from the game project directory:

```bash
cd zombie_corridor_mvp
python3 scripts/run_local_demo.py --source
```

The launcher starts **one headless server and two independent source GUI clients**, waits for real readiness, chooses a free local UDP port and prints the endpoint. Ctrl-C stops only its owned processes. Closing both clients stops the server. `logs/local-session.json` exists only while this launcher session is alive.

Alternatively, open `zombie_corridor_mvp/builds/macos/Zombie Corridor MVP.app` and press **Probar local**. This starts a separate dedicated process, connects the current window and opens a second client. **Conectar** accepts an IP/DNS and UDP port; it does not host a game.

**Controls:** WASD moves relative to the over-the-shoulder facing; captured mouse turns the player/camera and tilts aim; hold left mouse to fire; Escape releases/recaptures mouse and opens the menu; F3 toggles server-vs-local diagnostics. Four confirmed 25-damage hits kill a 100-HP zombie. Zombies attack, players die and automatically respawn after three seconds with two seconds of server-owned protection. Surviving groups and new waves remain server-owned.

Weapon range/rate/damage are loaded from `config/default-config.json`; rebuild both roles after changing them. Clock/history defaults remain pinned in `project.godot` and scheduler constants. The handshake compares actual map/config SHA256 values.

Automation covers game-owned Viewport input/camera checks and exported rendered frames (`results/gameplay.png`, `results/menu.png`). Native physical keyboard/mouse input has not been automated. Prior human gameplay acceptance covered the source game feel; current release evidence is the machine-readable validation suite, not an OS desktop-lock claim.

## Source and builds

- Open `zombie_corridor_mvp/project.godot` with the pinned engine under `zombie_corridor_mvp/.tools`. The outer repository `project.godot` is a placeholder and is not the game project.
- F5 starts `scenes/bootstrap.tscn` and preserves the maximized window setting from `project.godot`.
- See **[`docs/EDITING.md`](docs/EDITING.md)** for the scene editing table covering bootstrap composition, world lighting, corridor geometry, player actor, UI, mob template, presentation pool and tracer resources.
- `scenes/presentation.tscn` owns exactly eight direct `ShotTracer0`–`ShotTracer7` children. `game/presentation.gd` binds those authored slots, shared mesh, predicted/confirmed materials and expiry state; dynamic mob instances, tracer slot claims and runtime expiry remain code-owned.
- Visual edits to mob/player dimensions do not change weapon, combat, networking or existing server hitbox rules. Runtime movement/combat/network/population state intentionally remains in code.
- `builds/macos/Zombie Corridor MVP.app`: universal macOS client; the same executable supports explicit `--headless -- --server` and network test-bot modes.
- `builds/linux-x86_64/zombie-server` and `builds/linux-arm64/zombie-server`: actual dedicated release exports with embedded packs, plus compressed Linux packages.
- `builds/manifest.json` and `builds/SHA256SUMS`: build identities/checksums.
- `dependencies.lock.json`: official engine, template and addon versions/hashes.

```bash
# Source launcher instead of the release build
python3 scripts/run_local_demo.py --source
# Explicit standalone roles, default port 27015
scripts/run_server.sh --port 27015
scripts/run_client.sh --connect 127.0.0.1 --port 27015
# Recreate the local macOS app archive and Linux dedicated-server packages
scripts/export_builds.sh
```

## Verification and measurement

```bash
# Focused editable scene/world composition harness
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/editable_scenes.gd
# Focused third-person camera/input/aim harness
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/third_person.gd
# Focused geometry/protocol/authority/dormancy invariants
.tools/godot-4.7/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/invariants.tscn
# First-stage real two-client movement test
python3 scripts/transport_smoke.py
# Complete acceptance against actual macOS release binaries
python3 scripts/run_validation.py --build
# Full fail-fast verification + eight serial benchmarks (~15 min)
python3 scripts/run_final_suite.py
# Same-client reconnect, Probar local, normal waves, explicit failure states
python3 scripts/run_lifecycle_checks.py
# Actual Linux release servers with two macOS ENet clients (local Docker required)
python3 scripts/run_linux_transport.py
# Eight serial scenarios, 10s warmup + 60s observed each (~9m20s)
python3 scripts/run_benchmark.py
```

All acceptance scripts exit nonzero on a failed assertion. No global `killall`, background test farms or offline fake players are used. A controlled local UDP proxy imposes delay/loss/jitter on isolated test ports and records actual forwarding and loss. Bots record independently measured RTT and authoritative confirmations.

See **[`docs/VALIDATION.md`](docs/VALIDATION.md)**, **`results/validation.json`**, **`results/benchmark.md`**, **`results/final-suite.json`** and **[`docs/IMPLEMENTATION_HANDOFF.md`](docs/IMPLEMENTATION_HANDOFF.md)** for exact evidence, measurement boundaries and limitations. CPU **100% means one core**; RSS is MiB. Application payload and ENet counters are separately labeled. Local source/export results do **not** certify a VPS or any public Internet endpoint.

## Remote deployment

There is **no project-authorized SSH destination**. No unrelated host was contacted. Both architectures and a safe explicit-target deploy tool are provided:

```bash
python3 scripts/deploy_vps.py --host YOUR_AUTHORIZED_HOST --user GAME_USER \
  --directory /opt/corridor99-new --service corridor99-new --arch arm64 --port 27015
```

The directory must be new and writable by that user. Select the server architecture from the remote `uname -m` result, not a guess. The tool checks it before upload and refuses existing paths/services. `--install-service` explicitly opts into installing this **new** systemd unit with sudo. It never changes firewall/provider rules, users, unrelated services, SSH configuration, auth or VPN configuration. Public UDP handshake/gameplay must still be tested after deployment; localhost is not public-online verification.
