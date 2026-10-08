"""Policy regressions; synthetic inputs only, no model/API requests."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).with_name("no-anthropic-api.sh")


class CreditPolicy(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fable-credit-policy-")
        self.addCleanup(self.temp.cleanup)
        self.flag = Path(self.temp.name) / "conserve-mode.json"

    def call(self, command="", *, low=False, event="PreToolUse", key="command"):
        if low:
            self.flag.write_text('{"minWeeklyPct":75}')
        return subprocess.run(
            ["bash", str(HOOK)],
            input=json.dumps({"hook_event_name": event, "tool_input": {key: command}}),
            text=True, capture_output=True,
            env={**os.environ, "LFOS_CONSERVE_FLAG": str(self.flag)},
            check=False,
        )

    def test_subscription_models_are_allowed_normally(self):
        for cmd in [
            "claude -p --model claude-fable-5-1 --effort xhigh",
            "env -u ANTHROPIC_BASE_URL claude -p --model='claude-fable-5-1'",
            "claude -p --model claude-opus-5",
            "claude --resume session-id",
        ]:
            with self.subTest(cmd=cmd):
                self.assertEqual(self.call(cmd).returncode, 0)

    def test_fable_and_unspecified_resumes_are_skipped_when_low(self):
        for cmd in [
            "claude -p --model claude-fable-5-1",
            "env -u ANTHROPIC_BASE_URL /usr/local/bin/claude -p --model='claude-fable-5-1[1m]'",
            "claude --resume session-id",
            "claude -p",
            "rg something README.md; claude -p --model fable",
            "true\nclaude -p --model fable",
            "bash -lc 'claude -p --model fable'",
            "env -u ANTHROPIC_BASE_URL zsh -c 'claude -p --model=claude-fable-5-1'",
            'runner=claude; "$runner" -p --model fable',
            'model=fable; claude -p --model "$model"',
            'task="claude -p --model fable"; bash -c "$task"',
            'eval "claude -p --model fable"',
            'bash -c \'"$1" -p --model "$2"\' _ claude fable',
            '"$(command -v claude)" -p --model fable',
            '"$(which claude)" -p --model fable',
            'runner="$(command -v claude)"; "$runner" -p --model fable',
        ]:
            with self.subTest(cmd=cmd):
                result = self.call(cmd, low=True, key="cmd")
                self.assertEqual(result.returncode, 2)
                self.assertIn("may approve design without Fable automatically", result.stderr)

    def test_explicit_other_models_and_local_inspection_are_unchanged(self):
        for cmd in [
            "claude -p --model claude-opus-5",
            "claude auth status",
            "claude --help",
            "rg fable ~/.claude/settings.json",
            'printf "%s" "claude -p --model fable"',
            "codex exec --model gpt-6-astra",
            "bash -lc 'claude auth status'",
            "bash -lc 'claude -p --model claude-opus-5'",
            'bash -c \'"$1" auth status\' _ claude',
        ]:
            with self.subTest(cmd=cmd):
                self.assertEqual(self.call(cmd, low=True).returncode, 0)

    def test_paid_api_guard_remains_active_in_both_modes(self):
        for low in [False, True]:
            for cmd in [
                "curl https://api.anthropic.com/v1/messages",
                "python -c 'from anthropic import Anthropic; Anthropic()'",
                "node -e 'require(\"@anthropic-ai/sdk\")'",
                "job --key $ANTHROPIC_API_KEY",
                "rg harmless file; curl https://api.anthropic.com/v1/messages",
            ]:
                with self.subTest(low=low, cmd=cmd):
                    result = self.call(cmd, low=low)
                    self.assertEqual(result.returncode, 2)
                    self.assertIn("Anthropic API", result.stderr)

    def test_product_key_and_sdk_installs_are_allowed(self):
        for cmd in [
            'curl -s https://api.anthropic.com/v1/models -H "x-api-key: $COMMONS_CLAUDE_API_KEY"',
            "set -a; . ~/.config/commons/claude-dev.env; set +a; ANTHROPIC_API_KEY=$COMMONS_CLAUDE_API_KEY node probe.mjs",
            "npm install @anthropic-ai/sdk@0.70.0",
            "cd api && env -u NODE_ENV npm install @anthropic-ai/sdk",
            "npm ls @anthropic-ai/sdk",
        ]:
            with self.subTest(cmd=cmd):
                self.assertEqual(self.call(cmd).returncode, 0)

    def test_box_key_and_non_install_sdk_use_stay_blocked(self):
        for cmd in [
            'curl https://api.anthropic.com/v1/messages -H "x-api-key: $ANTHROPIC_API_KEY"  # COMMONS_CLAUDE_API_KEY',
            "COMMONS_CLAUDE_API_KEY=x node -e 'process.env.ANTHROPIC_API_KEY'",
            "npm install @anthropic-ai/sdk && curl https://api.anthropic.com/v1/messages",
            "npx @anthropic-ai/claude-code",
            "npm ls; node -e 'new Anthropic()'",
        ]:
            with self.subTest(cmd=cmd):
                result = self.call(cmd)
                self.assertEqual(result.returncode, 2)
                self.assertIn("Anthropic API", result.stderr)

    def test_read_only_key_name_lookup_is_allowed(self):
        self.assertEqual(self.call("rg -l ANTHROPIC_API_KEY ~/.config", low=True).returncode, 0)

    def test_automatic_notice_is_narrow_and_low_credit_only(self):
        for event in ["SessionStart", "UserPromptSubmit"]:
            self.assertEqual(self.call(event=event).stdout, "")
        for event in ["SessionStart", "UserPromptSubmit"]:
            result = self.call(low=True, event=event)
            self.assertEqual(result.returncode, 0)
            self.assertIn("may approve design without Fable automatically", result.stdout)
            self.assertIn("Codex does not enter credit-saver mode", result.stdout)


if __name__ == "__main__":
    unittest.main()
