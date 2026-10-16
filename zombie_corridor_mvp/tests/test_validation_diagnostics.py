"""Case-local raw logs must gate PASS, independently of process exit codes."""
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import run_validation


class ValidationDiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def owned(self, *texts):
        items = []
        for i, text in enumerate(texts):
            log = self.root / f"process-{i}.log"
            log.write_text(text)
            items.append((SimpleNamespace(returncode=0), log))
        return SimpleNamespace(items=items, check_logs=Mock())

    def test_clean_zero_exit_checks_existing_diagnostics(self):
        owned = self.owned("SERVER_READY\n", "CLIENT_READY\n")
        run_validation.check_case_logs(owned)
        owned.check_logs.assert_called_once_with()

    def test_native_warning_and_duplicate_print_block_zero_exit(self):
        text = ("WARNING: Reference tick 594 missing for #1 applying 608\n"
                "[WARN] Reference tick 594 missing for #1 applying 608\n")
        owned = self.owned("clean\n", text)
        with self.assertRaisesRegex(RuntimeError, "Reference tick 594 missing"):
            run_validation.check_case_logs(owned)
        self.assertEqual(owned.items[1][1].read_text(), text)

    def test_each_current_case_process_is_examined(self):
        for index in range(3):
            texts = ["clean\n"] * 3
            texts[index] = "[WARN] Reference tick 10 missing for #1 applying 24\n"
            with self.subTest(index=index):
                with self.assertRaises(RuntimeError):
                    run_validation.check_case_logs(self.owned(*texts))

    def test_historical_other_case_log_is_not_consulted(self):
        (self.root / "old-case.log").write_text("Reference tick 1 missing for #1 applying 2\n")
        run_validation.check_case_logs(self.owned("clean current case\n"))

    def test_expired_input_in_each_ordinary_process_blocks_zero_exit(self):
        messages = [
            'WARNING: [RedundantHistoryEncoder] Received data for 23, rejecting because older than 16 frames\n',
            '[WARN] Received data for 23, rejecting because older than 16 frames\n',
            'Received input snapshot for @23, rejecting because older than 16 frames\n',
        ]
        for message in messages:
            for index in range(3):
                with self.subTest(index=index, message=message):
                    texts = ['ordinary clean log\n'] * 3
                    texts[index] = message
                    owned = self.owned(*texts)
                    before = owned.items[index][1].read_bytes()
                    with self.assertRaisesRegex(RuntimeError, 'Expired rollback input'):
                        run_validation.check_case_logs(owned)
                    self.assertEqual(before, owned.items[index][1].read_bytes())

    def test_expired_input_from_other_case_is_not_consulted(self):
        (self.root / 'older-profile.log').write_text('Received data for 23, rejecting because older than 16 frames\n')
        run_validation.check_case_logs(self.owned('ordinary current case clean\n'))

    def test_existing_errors_are_not_waived(self):
        owned = self.owned("Received input snapshot for @1, rejecting because older than 16 frames\n")
        original = owned.items[0][1].read_bytes()
        owned.check_logs.side_effect = RuntimeError("existing diagnostic")
        with self.assertRaisesRegex(RuntimeError, "existing diagnostic"):
            run_validation.check_case_logs(owned)
        self.assertEqual(owned.items[0][1].read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
