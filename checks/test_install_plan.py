"""The preview must never reach installer helpers or modify the user's HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerPlanTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.scripts = self.root / "scripts"
        self.scripts.mkdir()
        for name in ("install.sh", "install_plan.sh"):
            shutil.copy2(ROOT / "Scripts" / name, self.scripts / name)
        # Sourcing either helper would produce a visible side effect and fail.
        for name in ("global_fn.sh", "hypr_autogen.sh"):
            (self.scripts / name).write_text('printf danger > "$HOME/helper-ran"\nexit 99\n')
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / "config"),
                        XDG_STATE_HOME=str(self.home / "state"), TMPDIR=str(self.home))

    def run_plan(self, *args):
        return subprocess.run(["/bin/bash", str(self.scripts / "install.sh"), *args],
                              env=self.env, text=True, capture_output=True, timeout=5)

    def assert_read_only(self):
        self.assertEqual(list(self.home.iterdir()), [])

    def test_default_plan_never_sources_helpers(self):
        result = self.run_plan("--plan")
        self.assertEqual(result.returncode, 0, result.stderr)
        for section in ("PRE:", "INSTALL:", "RESTORE:", "POST:", "SERVICES:"):
            self.assertIn(section, result.stdout)
        self.assertIn("not restoration of a backup", result.stdout)
        self.assert_read_only()

    def test_selected_options(self):
        result = self.run_plan("-r", "--plan", "-n", "-m")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("RESTORE:", result.stdout)
        self.assertNotIn("INSTALL:", result.stdout)
        self.assertNotIn("SERVICES:", result.stdout)
        self.assertIn("--no-nvidia", result.stdout)
        self.assertIn("--no-theme", result.stdout)
        self.assert_read_only()

    def test_pre_takes_precedence(self):
        result = self.run_plan("--plan", "-p", "-i", "-r", "-s")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("other requested operations will not run", result.stdout)
        self.assertNotIn("INSTALL:", result.stdout)
        self.assertNotIn("RESTORE:", result.stdout)
        self.assertNotIn("SERVICES:", result.stdout)
        self.assert_read_only()

    def test_unknown_or_combined_flags_fail_closed(self):
        for option in ("--bogus", "-irs", "-t", "--help"):
            with self.subTest(option=option):
                result = self.run_plan(option, "--plan")
                self.assertEqual(result.returncode, 2)
                self.assertIn("Unsupported option", result.stderr)
                self.assert_read_only()

    def test_service_only_and_modifiers(self):
        result = self.run_plan("--plan", "--services", "--shell")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SERVICES:", result.stdout)
        self.assertNotIn("PRE:", result.stdout)
        self.assertNotIn("RESTORE:", result.stdout)
        self.assert_read_only()


if __name__ == "__main__":
    unittest.main()
