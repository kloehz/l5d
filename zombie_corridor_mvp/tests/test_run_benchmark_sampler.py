import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

SPEC = importlib.util.spec_from_file_location("run_benchmark", SCRIPTS / "run_benchmark.py")
if SPEC is None or SPEC.loader is None:
    raise ImportError("Cannot load the benchmark sampler test target")
run_benchmark = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(run_benchmark)


class FakeProcess:
    def __init__(self, polls, pid=4242):
        self._polls = list(polls)
        self.pid = pid

    def poll(self):
        if self._polls:
            return self._polls.pop(0)
        return None


def sleeper(_interval):
    return None


def clock(values):
    values = iter(values)
    return lambda: next(values)


def sampler(values):
    values = iter(values)

    def sample(_pid):
        value = next(values)
        if isinstance(value, BaseException):
            raise value
        return value

    return sample


class CollectOsSamplesUntilExitTests(unittest.TestCase):
    def test_live_zero_cpu_delta_emits_zero_percent_and_nonnegative_rss(self):
        process = FakeProcess([None, None, None, None, 0])
        samples = run_benchmark.collect_os_samples_until_exit(
            process,
            sample_fn=sampler([(10.0, 128.0), (10.0, 128.0)]),
            now_fn=clock([100.0, 101.0]),
            sleep_fn=sleeper,
            origin=99.0,
            interval=0.1,
        )
        self.assertEqual(samples, [{"elapsed_s": 2.0, "cpu_core_percent": 0.0, "rss_mb": 128.0}])

    def test_process_exits_during_sleep_emits_no_terminal_sample(self):
        process = FakeProcess([None, None, 0])
        read_sample = Mock(side_effect=sampler([(1.0, 64.0)]))
        sleep = Mock()
        samples = run_benchmark.collect_os_samples_until_exit(
            process,
            sample_fn=read_sample,
            now_fn=clock([10.0, 11.0]),
            sleep_fn=sleep,
            origin=10.0,
            interval=0.1,
        )
        self.assertEqual(samples, [])
        sleep.assert_called_once_with(0.1)
        self.assertEqual(read_sample.call_count, 1)

    def test_missing_pid_after_poll_race_is_dropped_when_process_exited(self):
        process = FakeProcess([None, None, None, 0])
        read_sample = Mock(side_effect=sampler([(1.0, 64.0), subprocess.CalledProcessError(1, ["ps"])]))
        samples = run_benchmark.collect_os_samples_until_exit(
            process,
            sample_fn=read_sample,
            now_fn=clock([10.0, 11.0]),
            sleep_fn=sleeper,
            origin=10.0,
            interval=0.1,
        )
        self.assertEqual(samples, [])
        self.assertEqual(read_sample.call_count, 2)

    def test_dead_zombie_counter_decrease_and_zero_rss_terminal_sample_is_dropped(self):
        process = FakeProcess([None, None, None, 0])
        read_sample = Mock(side_effect=sampler([(20.0, 100.0), (19.0, 0.0)]))
        samples = run_benchmark.collect_os_samples_until_exit(
            process,
            sample_fn=read_sample,
            now_fn=clock([10.0, 11.0]),
            sleep_fn=sleeper,
            origin=10.0,
            interval=0.1,
        )
        self.assertEqual(samples, [])
        self.assertEqual(read_sample.call_count, 2)

    def test_live_counter_decrease_raises_instead_of_clamping(self):
        process = FakeProcess([None, None, None])
        with self.assertRaisesRegex(ValueError, "CPU counter decreased"):
            run_benchmark.collect_os_samples_until_exit(
                process,
                sample_fn=sampler([(20.0, 100.0), (19.0, 100.0)]),
                now_fn=clock([10.0, 11.0]),
                sleep_fn=sleeper,
                origin=10.0,
                interval=0.1,
            )

    def test_live_bad_ps_parse_error_raises(self):
        process = FakeProcess([None, None])
        with self.assertRaisesRegex(ValueError, "bad ps parse"):
            run_benchmark.collect_os_samples_until_exit(
                process,
                sample_fn=sampler([(20.0, 100.0), ValueError("bad ps parse")]),
                now_fn=clock([10.0, 11.0]),
                sleep_fn=sleeper,
                origin=10.0,
                interval=0.1,
            )

    def test_genuine_positive_cpu_delta_produces_expected_percent_and_rss(self):
        process = FakeProcess([None, None, None, None, 0])
        samples = run_benchmark.collect_os_samples_until_exit(
            process,
            sample_fn=sampler([(5.0, 256.0), (5.25, 300.0)]),
            now_fn=clock([100.0, 100.5]),
            sleep_fn=sleeper,
            origin=99.5,
            interval=0.1,
        )
        self.assertEqual(len(samples), 1)
        self.assertEqual(samples[0]["elapsed_s"], 1.0)
        self.assertEqual(samples[0]["cpu_core_percent"], 50.0)
        self.assertEqual(samples[0]["rss_mb"], 300.0)

    def test_nonmonotonic_clock_delta_raises(self):
        process = FakeProcess([None, None])
        with self.assertRaisesRegex(ValueError, "clock did not advance"):
            run_benchmark.collect_os_samples_until_exit(
                process,
                sample_fn=sampler([(1.0, 64.0)]),
                now_fn=clock([10.0, 10.0]),
                sleep_fn=sleeper,
                origin=10.0,
                interval=0.1,
            )


if __name__ == "__main__":
    unittest.main()
