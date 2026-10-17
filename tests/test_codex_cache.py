import importlib.util
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch
import contextlib
import io

SOURCE = Path(__file__).resolve().parents[1] / 'private_dot_claude/scripts/executable_codex-rate-limits.py'
spec = importlib.util.spec_from_file_location('codex_cache', SOURCE)
cache = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cache)


class CodexCacheTest(unittest.TestCase):
    def record(self, age=10, started=1000.25):
        return cache.observation(f'codex|basement|20|75|{age}|', 'basement', started)

    def test_preserves_transfer_and_residency_without_rejuvenation(self):
        record = self.record()
        self.assertEqual(cache.display(record, 'basement', 1003.5), 'codex|basement|20|75|15|')
        self.assertEqual(record['started_at'], 1000.25)

    def test_hidden_fraction_crossing_900_is_unknown(self):
        # Native observation age899.9 emits899; another0.2s must refuse.
        record = self.record(899)
        self.assertEqual(cache.display(record, 'basement', 1000.45), 'codex|basement|unknown|unknown||')
        self.assertEqual(cache.display(self.record(898), 'basement', 1000.45), 'codex|basement|20|75|900|')

    def test_future_malformed_mismatched_and_missing_cache_are_unknown(self):
        for record in [{}, {**self.record(), 'started_at': 1001}, {**self.record(), 'label': 'other'},
                       {**self.record(), 'age_bound': -1}, {**self.record(), 'five': '0'},
                       {**self.record(), 'weekly': 101}]:
            self.assertIn('|unknown|unknown||', cache.display(record, 'basement', 1000.5))

    def test_unknown_and_untrusted_wire_never_become_numbers(self):
        for line in ['codex|basement|unknown|unknown||', 'codex|other|0|0|0|',
                     'codex|basement|101|0|0|', 'codex|basement|0|0|-1|',
                     'codex|basement|0|0|0|\nprivate', 'codex|basement|0|0|9000|']:
            self.assertEqual(cache.observation(line, 'basement', 1000), {})

    def test_refresh_spacing_failure_invalidation_and_full_transfer_age(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'usage.json'
            now = [1000.25]
            calls = []
            def fetch(args):
                calls.append(args)
                now[0] += 0.2
                return 'codex|basement|20|75|899|'
            config = {'label': 'basement', 'argv': ['/fixture/openai-account', 'status']}
            cache.refresh(config, path, lambda: now[0], fetch)
            record = cache.load(path)
            self.assertEqual(record['started_at'], 1000.25)
            self.assertIn('|unknown|unknown||', cache.display(record, 'basement', now[0]))
            now[0] = 1060.24
            cache.refresh(config, path, lambda: now[0], fetch)
            self.assertEqual(len(calls), 1)
            now[0] = 1060.45
            cache.refresh(config, path, lambda: now[0], lambda args: None)
            self.assertNotIn('five', cache.load(path))
            self.assertEqual(cache.load(path)['last_attempt'], 1060.45)

    def test_changed_binding_never_reuses_old_account_cache(self):
        config = {'label': 'basement', 'argv': ['reader', '--expected-account-id', 'fixture-old']}
        record = {**self.record(), 'source_key': cache.source_key(config)}
        self.assertNotIn('unknown', cache.cached_display(config, record, 1000.5))
        changed = {**config, 'argv': ['reader', '--expected-account-id', 'fixture-new']}
        self.assertIn('|unknown|unknown||', cache.cached_display(changed, record, 1000.5))

    def test_default_main_does_not_launch_a_process(self):
        with tempfile.TemporaryDirectory() as root:
            with patch.dict(cache.os.environ, {'HOME': root}, clear=True), patch.object(cache.sys, 'argv', ['collector']), patch.object(cache.subprocess, 'Popen') as launch:
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    cache.main()
                self.assertEqual(output.getvalue(), 'codex|default|unknown|unknown||\n')
                launch.assert_not_called()

    def test_no_binding_configuration_means_no_process(self):
        self.assertIsNone(cache.command({}))
        self.assertIsNone(cache.command({'label': 'basement', 'argv': []}))

    def test_remote_transport_is_batch_bounded_and_quotes_arguments(self):
        command = cache.command({'label': 'basement', 'remote_host': 'basement',
                                 'argv': ['/fixture/reader', 'space argument', '$(never-execute)']})
        self.assertEqual(command[:8], ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', '-o', 'StrictHostKeyChecking=yes', 'basement'])
        self.assertIn("'$(never-execute)'", command[-1])
        self.assertIsNone(cache.command({'label': 'basement', 'remote_host': '-oProxyCommand=bad', 'argv': ['reader']}))


if __name__ == '__main__':
    unittest.main()
