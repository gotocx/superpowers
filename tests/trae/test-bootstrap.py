#!/usr/bin/env python3
"""Protocol tests only; these do not launch Trae or evaluate model behavior."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TraeBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.package = Path(self.temp.name) / 'package with spaces "quote"'
        (self.package / "hooks").mkdir(parents=True)
        self.skill = self.package / "skills/using-superpowers/SKILL.md"
        self.mapping = self.skill.parent / "references/trae-tools.md"
        self.mapping.parent.mkdir(parents=True)
        for name in ("session-start", "run-hook.cmd"):
            shutil.copy2(ROOT / "hooks" / name, self.package / "hooks" / name)
        self.skill.write_bytes((ROOT / "skills/using-superpowers/SKILL.md").read_bytes())
        self.mapping.write_bytes(
            (ROOT / "skills/using-superpowers/references/trae-tools.md").read_bytes()
        )
        self.env = os.environ.copy()
        for key in ("CURSOR_PLUGIN_ROOT", "CLAUDE_PLUGIN_ROOT", "COPILOT_CLI", "MUSE_PLUGIN_ROOT"):
            self.env.pop(key, None)

    def run_hook(self, *args, **kwargs):
        return subprocess.run(
            ["bash", str(self.package / "hooks/run-hook.cmd"), "session-start", *args],
            cwd=self.temp.name, env=self.env, capture_output=True, text=True,
            timeout=5, **kwargs,
        )

    def context(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        payload = json.loads(result.stdout)
        self.assertEqual(set(payload), {"hookSpecificOutput"})
        output = payload["hookSpecificOutput"]
        self.assertEqual(set(output), {"hookEventName", "additionalContext"})
        self.assertEqual(output["hookEventName"], "SessionStart")
        return output["additionalContext"]

    def test_full_live_skill_and_mapping_location(self):
        context = self.context(self.run_hook("--trae"))
        self.assertIn(self.skill.read_text().rstrip("\n"), context)
        self.assertIn(str(self.mapping), context)
        self.assertEqual(context.count("<EXTREMELY_IMPORTANT>"), 1)
        self.assertEqual(context.count("</EXTREMELY_IMPORTANT>"), 1)
        self.assertIn("already loaded", context)
        self.assertNotIn("For all other skills, use the 'Skill' tool", context)

    def test_trae_selection_wins_over_inherited_harness_variables(self):
        self.env.update(CURSOR_PLUGIN_ROOT="cursor", CLAUDE_PLUGIN_ROOT="claude",
                        COPILOT_CLI="1", MUSE_PLUGIN_ROOT="muse")
        self.context(self.run_hook("--trae"))

    def test_json_round_trip_quotes_backslashes_tabs_crlf_unicode(self):
        content = '---\r\nname: using-superpowers\r\n---\r\n"quoted" \\path\t中文\n'
        self.skill.write_bytes(content.encode())
        self.assertIn(content.rstrip("\n"), self.context(self.run_hook("--trae")))

    def test_each_new_invocation_bootstraps_without_persisted_state(self):
        first = self.context(self.run_hook("--trae"))
        second = self.context(self.run_hook("--trae"))
        self.assertEqual(first, second)
        self.assertEqual(list(self.package.glob(".trae*")), [])

    def test_next_invocation_reads_updated_skill(self):
        before = self.context(self.run_hook("--trae"))
        self.skill.write_text(self.skill.read_text() + "\nNEW_SKILL_MARKER\n")
        after = self.context(self.run_hook("--trae"))
        self.assertNotIn("NEW_SKILL_MARKER", before)
        self.assertIn("NEW_SKILL_MARKER", after)

    def test_missing_skill_or_mapping_does_not_emit_success_context(self):
        for path in (self.skill, self.mapping):
            original = path.read_bytes()
            path.unlink()
            result = self.run_hook("--trae")
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")
            self.assertIn("unreadable", result.stderr)
            path.write_bytes(original)

    def test_hook_does_not_wait_for_stdin_eof(self):
        process = subprocess.Popen(
            ["bash", str(self.package / "hooks/run-hook.cmd"), "session-start", "--trae"],
            env=self.env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        try:
            # Keep parent's write end open: waiting for EOF would deadlock here.
            self.assertEqual(process.wait(timeout=5), 0)
            payload = json.loads(process.stdout.read())
            self.assertEqual(payload["hookSpecificOutput"]["hookEventName"], "SessionStart")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            for pipe in (process.stdin, process.stdout, process.stderr):
                pipe.close()

    def test_documented_schema_and_reference_command(self):
        config = json.loads((ROOT / "hooks/hooks-trae.json").read_text())
        self.assertEqual(config["version"], 1)
        self.assertEqual(set(config["hooks"]), {"SessionStart"})
        groups = config["hooks"]["SessionStart"]
        self.assertEqual(len(groups), 1)
        self.assertEqual(set(groups[0]), {"hooks"})  # no Claude clear/compact matcher
        entries = groups[0]["hooks"]
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["type"], "command")
        self.assertGreater(entries[0]["timeout"], 0)
        result = subprocess.run(entries[0]["command"], shell=True, executable="/bin/bash",
                                cwd=self.package, env=self.env, capture_output=True,
                                text=True, timeout=5)
        self.context(result)

    def test_unselected_existing_output_contracts_are_preserved(self):
        for env_key, field in ((None, "additionalContext"),
                               ("CURSOR_PLUGIN_ROOT", "additional_context"),
                               ("CLAUDE_PLUGIN_ROOT", "hookSpecificOutput")):
            self.env.pop("CURSOR_PLUGIN_ROOT", None)
            self.env.pop("CLAUDE_PLUGIN_ROOT", None)
            if env_key:
                self.env[env_key] = "existing"
            result = self.run_hook()
            self.assertEqual(result.returncode, 0)
            self.assertEqual(set(json.loads(result.stdout)), {field})
            self.assertNotIn("trae-tools.md", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
