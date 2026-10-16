#!/usr/bin/env python3
"""Release failure-state and game-owned local action checks, never OS input injection."""
import argparse
import json
import os
import re
import time

from runtime import ROOT, Processes, port, rows
from source_identity import identity

results = []


def assert_no_native_channel_errors(owned):
    for _, log in owned.items:
        text = log.read_text()
        assert 'Unable to send packet on channel' not in text, f'{log}: native ENet channel send error'


def parse_pose(value):
    if isinstance(value, str):
        parts = value.strip('()').split(',')
        assert len(parts) == 3, value
        try:
            return [float(part.strip()) for part in parts]
        except ValueError as exc:
            raise AssertionError(('invalid pose', value)) from exc
    return value


def server_pose_distance(samples, peer):
    poses = []
    for sample in samples:
        for state in sample['player_states']:
            if state['peer'] == peer:
                poses.append(parse_pose(state['pose']))
    if not poses:
        return 0.0
    return max(abs(p[2] - -7.0) for p in poses)


def wait_for_sample(path, predicate, timeout=10):
    deadline = time.monotonic() + timeout
    last = []
    while time.monotonic() < deadline:
        if path.exists():
            last = [r for r in rows(path) if r['kind'] == 'sample']
            if last and predicate(last):
                return last
        time.sleep(0.05)
    raise AssertionError(('sample predicate timeout', path, last[-3:]))


def wait_for_rows(path, predicate=lambda rs: bool(rs), timeout=5):
    deadline = time.monotonic() + timeout
    last = []
    while time.monotonic() < deadline:
        if path.exists():
            last = rows(path)
            if last and predicate(last):
                return last
        time.sleep(0.05)
    raise AssertionError(('report predicate timeout', path, last[-3:]))


def wait_processes(processes, timeout=20):
    deadline = time.monotonic() + timeout
    pending = 999
    statuses = [pending] * len(processes)
    exit_times = [0.0] * len(processes)
    while time.monotonic() < deadline and any(status == pending for status in statuses):
        for index, proc in enumerate(processes):
            if statuses[index] == pending and proc.poll() is not None:
                statuses[index] = proc.returncode
                exit_times[index] = time.time()
        time.sleep(0.05)
    for index, proc in enumerate(processes):
        if statuses[index] == pending:
            proc.kill()
            statuses[index] = proc.wait(timeout=4)
            exit_times[index] = time.time()
    return statuses, exit_times


def real_two_bot_disconnect_reconnect(build):
    owned = Processes()
    pnum = port()
    first_report = ROOT / 'logs/lifecycle-disconnect-first.jsonl'
    survivor_report = ROOT / 'logs/lifecycle-disconnect-survivor.jsonl'
    late_report = ROOT / 'logs/lifecycle-disconnect-late.jsonl'
    try:
        metrics = ROOT / 'logs/lifecycle-disconnect-reconnect-server.jsonl'
        server, log = owned.start(
            'lifecycle-disconnect-reconnect-server',
            ['--server', '--port', pnum, '--scenario', 'play', '--metrics', metrics],
            build,
        )
        owned.wait_ready(server, log, 'SERVER_READY')
        first, first_log = owned.start(
            'lifecycle-disconnect-first',
            [
                '--bot', '--port', pnum, '--scenario', 'play', '--behavior', 'combat',
                '--duration', 6, '--report', first_report,
            ],
            build,
        )
        survivor_duration = 16.0
        survivor_started = time.time()
        survivor, survivor_log = owned.start(
            'lifecycle-disconnect-survivor',
            [
                '--bot', '--port', pnum, '--scenario', 'play', '--behavior', 'combat',
                '--duration', survivor_duration, '--report', survivor_report,
            ],
            build,
        )
        owned.wait_ready(first, first_log, 'CLIENT_READY')
        owned.wait_ready(survivor, survivor_log, 'CLIENT_READY')
        assert first.wait(timeout=14) == 0
        first_rows = rows(first_report)
        survivor_rows = rows(survivor_report)
        first_peer = first_rows[-1]['peer']
        survivor_peer = survivor_rows[-1]['peer']
        assert survivor_rows[-1]['ready']
        departure_elapsed = first_rows[-1]['elapsed_s']
        samples = wait_for_sample(
            metrics,
            lambda ss: any(
                s['elapsed_s'] >= departure_elapsed and
                all(p['peer'] != first_peer for p in s['player_states']) and
                any(p['peer'] == survivor_peer for p in s['player_states'])
                for s in ss
            ),
            8,
        )
        post_departure_survivor = [
            s for s in samples
            if s['elapsed_s'] >= departure_elapsed
            and all(p['peer'] != first_peer for p in s['player_states'])
            and any(p['peer'] == survivor_peer for p in s['player_states'])
        ]
        assert post_departure_survivor
        survivor_updates_before_late = rows(survivor_report)[-1]['updates']
        planned_common_close = survivor_started + survivor_duration
        late_duration = max(6.0, planned_common_close - time.time())
        late, late_log = owned.start(
            'lifecycle-disconnect-late',
            [
                '--bot', '--port', pnum, '--scenario', 'play', '--behavior', 'combat',
                '--duration', late_duration, '--report', late_report,
            ],
            build,
        )
        owned.wait_ready(late, late_log, 'CLIENT_READY')
        late_peer = wait_for_rows(late_report, lambda rs: rs[-1]['ready'], 5)[-1]['peer']
        samples = wait_for_sample(
            metrics,
            lambda ss: any(
                any(p['peer'] == survivor_peer and p['hp'] > 0 for p in s['player_states']) and
                any(p['peer'] == late_peer for p in s['player_states'])
                for s in ss
            ),
            10,
        )
        joined_with_survivor = [
            s for s in samples
            if any(p['peer'] == survivor_peer and p['hp'] > 0 for p in s['player_states'])
            and any(p['peer'] == late_peer for p in s['player_states'])
        ]
        assert joined_with_survivor
        samples = wait_for_sample(
            metrics,
            lambda ss: all(server_pose_distance(ss, peer) >= 6.0 for peer in (first_peer, survivor_peer, late_peer)),
            8,
        )
        close_statuses, close_times = wait_processes([survivor, late], 20)
        assert close_statuses == [0, 0], f'unexpected common-close statuses: {close_statuses}'
        close_skew_s = max(close_times) - min(close_times)
        assert close_skew_s <= 1.0, f'common close skew too large: {close_skew_s}'
        samples = wait_for_sample(metrics, lambda ss: ss[-1]['players'] == 0, 8)
        assert max(r['players'] for r in samples) >= 2
        peer_ids = {p['peer'] for r in samples for p in r['player_states']}
        assert {first_peer, survivor_peer, late_peer}.issubset(peer_ids)
        distances = {peer: server_pose_distance(samples, peer) for peer in (first_peer, survivor_peer, late_peer)}
        assert all(distance >= 6.0 for distance in distances.values()), distances
        survivor_post_updates = rows(survivor_report)[-1]['updates'] - survivor_updates_before_late
        assert survivor_post_updates > 0
        all_reports = rows(first_report) + rows(survivor_report) + rows(late_report)
        for report in all_reports:
            assert not report['control_input_broadcast']
            for owner, input_owner, peer, broadcast in report['state_owners']:
                assert owner == 1 and input_owner == peer and not broadcast
        owned.check_logs()
        assert_no_native_channel_errors(owned)
        results.append({
            'name': 'source_normal_play_disconnect_survivor_latejoin_zero_peers',
            'status': 'PASS',
            'build': build,
            'first_peer_absent_after_departure': True,
            'survivor_peer_present_after_departure': True,
            'survivor_ready': True,
            'survivor_updates_after_departure': survivor_post_updates,
            'late_peer_welcomed_while_survivor_alive': True,
            'server_accepted_motion_m': distances,
            'connected_peer_motion_gate_m': 6.0,
            'authority_root': 1,
            'input_authority_matches_peer': True,
            'input_broadcast': False,
            'common_close_epoch': planned_common_close,
            'common_close_skew_s': close_skew_s,
            'common_close_exit_statuses': close_statuses,
            'latejoin_peer_count': len(peer_ids),
            'final_server_players': samples[-1]['players'],
            'clean_native_channel_logs': True,
        })
    finally:
        owned.cleanup()


def protocol_reject_bind_and_cross_source_handshake(build):
    owned = Processes()
    pnum = port()
    try:
        server, log = owned.start(
            'lifecycle-server',
            ['--server', '--port', pnum, '--scenario', 'player', '--metrics', ROOT / 'logs/lifecycle-server.jsonl'],
            build,
        )
        owned.wait_ready(server, log, 'SERVER_READY')
        bot, bot_log = owned.start(
            'lifecycle-cross-source',
            ['--bot', '--port', pnum, '--scenario', 'player', '--duration', 5, '--report', ROOT / 'logs/lifecycle-cross-source.jsonl'],
            False,
        )
        owned.wait_ready(bot, bot_log, 'CLIENT_READY')
        assert bot.wait(timeout=10) == 0
        assert rows(ROOT / 'logs/lifecycle-cross-source.jsonl')[-1]['distance'] > 6
        bad, bad_log = owned.start('lifecycle-protocol-reject', ['--bot', '--port', pnum, '--reject-protocol-test'], build)
        assert bad.wait(timeout=15) == 2
        assert 'Protocol/map/build incompatible' in bad_log.read_text()
        collision, collision_log = owned.start('lifecycle-bind-conflict', ['--server', '--port', pnum], build)
        assert collision.wait(timeout=10) == 2
        assert 'UDP bind failed' in collision_log.read_text()
        owned.check_logs({collision_log: ["ERROR: Couldn't create an ENet host."]})
        assert_no_native_channel_errors(owned)
        results.append({'name': 'protocol_reject_bind_and_cross_source_handshake', 'status': 'PASS', 'build': build})
    finally:
        owned.cleanup()


def same_gui_client_reconnect(build):
    owned = Processes()
    pnum = port()
    try:
        metrics = ROOT / 'logs/lifecycle-same-client-server.jsonl'
        server, log = owned.start(
            'lifecycle-same-client-server',
            ['--server', '--port', pnum, '--scenario', 'player', '--metrics', metrics],
            build,
        )
        owned.wait_ready(server, log, 'SERVER_READY')
        gui, gui_log = owned.start(
            'lifecycle-same-client',
            ['--client', '--port', pnum, '--reconnect-action-test', '--duration', 10],
            build,
            True,
        )
        assert gui.wait(timeout=25) == 0
        text = gui_log.read_text()
        assert text.count('CLIENT_READY ') == 2 and text.count('RECONNECT_ACTION') == 1, text
        time.sleep(1)
        samples = [r for r in rows(metrics) if r['kind'] == 'sample']
        assert max(r['players'] for r in samples) == 1 and samples[-1]['players'] == 0
        peer_ids = {p['peer'] for r in samples for p in r['player_states']}
        assert len(peer_ids) == 2
        owned.check_logs()
        assert_no_native_channel_errors(owned)
        results.append({'name': 'same_GUI_client_reconnect_without_duplicate_callbacks', 'status': 'PASS', 'build': build, 'distinct_connections': len(peer_ids)})
    finally:
        owned.cleanup()


def exported_probar_local_action(build):
    owned = Processes()
    try:
        gui, log = owned.start(
            'lifecycle-local-action',
            ['--local-action-test', '--duration', 12, '--capture-frame', ROOT / 'results/local-action.png', '--capture-delay', 8],
            build,
            True,
        )
        owned.wait_ready(gui, log, 'LOCAL_CHILDREN')
        line = re.search(r'LOCAL_CHILDREN (\d+) (\d+) (\d+)', log.read_text())
        assert line
        child_pids = list(map(int, line.groups()[:2]))
        assert len(set(child_pids + [gui.pid])) == 3
        assert gui.wait(timeout=30) == 0
        text = log.read_text()
        assert text.count('CLIENT_READY ') == 2, text
        assert 'FRAME_CAPTURE 0' in text
        time.sleep(0.3)
        for pid in child_pids:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                continue
            raise AssertionError(('local action leaked child', pid))
        owned.check_logs()
        assert_no_native_channel_errors(owned)
        results.append({
            'name': 'exported_Probar_local_action',
            'status': 'PASS',
            'build': build,
            'child_pids_terminated': child_pids,
            'capture': 'results/local-action.png',
            'input_scope': 'test-only direct game action; not native keyboard/mouse',
        })
    finally:
        owned.cleanup()


def normal_play_waves_with_dormant_pack(build):
    owned = Processes()
    pnum = port()
    try:
        metrics = ROOT / 'logs/play-wave-server.jsonl'
        server, log = owned.start('play-wave-server', ['--server', '--port', pnum, '--scenario', 'play', '--metrics', metrics], build)
        owned.wait_ready(server, log, 'SERVER_READY')
        bots = []
        for i in range(2):
            bot, bot_log = owned.start(
                f'play-wave-bot-{i}',
                ['--bot', '--port', pnum, '--scenario', 'play', '--behavior', 'combat', '--duration', 35, '--report', ROOT / f'logs/play-wave-bot-{i}.jsonl'],
                build,
            )
            owned.wait_ready(bot, bot_log, 'CLIENT_READY')
            bots.append(bot)
        for bot in bots:
            assert bot.wait(timeout=45) == 0
        samples = [r for r in rows(metrics) if r['kind'] == 'sample']
        assert max(r['wave'] for r in samples) >= 2
        assert max(r['kills'] for r in samples) >= 6
        assert any(r['dormant_mobs'] >= 12 for r in samples)
        owned.check_logs()
        assert_no_native_channel_errors(owned)
        results.append({
            'name': 'normal_play_waves_with_dormant_pack',
            'status': 'PASS',
            'build': build,
            'max_wave': max(r['wave'] for r in samples),
            'kills': max(r['kills'] for r in samples),
        })
    finally:
        owned.cleanup()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-only', action='store_true', help='run lifecycle checks from pinned source instead of exported builds')
    args = parser.parse_args()
    build = not args.source_only
    protocol_reject_bind_and_cross_source_handshake(build)
    same_gui_client_reconnect(build)
    exported_probar_local_action(build)
    normal_play_waves_with_dormant_pack(build)
    real_two_bot_disconnect_reconnect(build)
    print(json.dumps(results, indent=2))
    (ROOT / 'results/lifecycle.json').write_text(json.dumps({
        'runtime_source_sha256': identity()['runtime_source_sha256'],
        'mode': 'source' if args.source_only else 'build',
        'checks': results,
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
