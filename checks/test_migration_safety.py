"""Migration and installer failure handling with temporary HOME and stubs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MigrationSafetyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.migrations = self.root / "migrations"
        self.migrations.mkdir()
        self.state = self.root / "state" / "applied"
        self.actions = self.root / "actions"
        self.env = dict(os.environ, HOME=str(self.home), ACTIONS=str(self.actions),
                        XDG_CACHE_HOME=str(self.root / "cache"), HYDE_LOG="test")
        self.harness = self.root / "run.sh"
        self.harness.write_text('''source "$1"
print_log() { printf '%s\\n' "$*"; }
run_pending_migrations "$2" "$3"
''')

    def migration(self, name, script):
        (self.migrations / name).write_text("#!/bin/sh\n" + script + "\n")

    def run_migrations(self, dry=0):
        return subprocess.run(["/bin/bash", str(self.harness), str(ROOT / "Scripts/global_fn.sh"),
                               str(self.migrations), str(self.state)],
                              env=dict(self.env, flg_DryRun=str(dry)),
                              text=True, capture_output=True, timeout=10)

    def test_test_mode_never_executes_or_creates_state(self):
        self.migration("v1.sh", 'echo dangerous >> "$ACTIONS"')
        result = self.run_migrations(dry=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Would check and run pending migrations", result.stdout)
        self.assertFalse(self.actions.exists())
        self.assertFalse(self.state.parent.exists())

    def test_failure_is_reported_and_only_successes_are_recorded(self):
        self.migration("v1.sh", 'echo one >> "$ACTIONS"')
        self.migration("v2.sh", 'echo failed >> "$ACTIONS"; exit 1')
        self.migration("v3.sh", 'echo three >> "$ACTIONS"')
        result = self.run_migrations()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.state.read_text().splitlines(), ["v1.sh", "v3.sh"])
        self.assertEqual(self.actions.read_text().splitlines(), ["one", "failed", "three"])
        self.migration("v2.sh", 'echo recovered >> "$ACTIONS"')
        result = self.run_migrations()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state.read_text().splitlines(), ["v1.sh", "v3.sh", "v2.sh"])
        self.assertEqual(self.actions.read_text().splitlines(), ["one", "failed", "three", "recovered"])

    def test_state_creation_failure_does_not_run_migration(self):
        self.migration("v1.sh", 'echo dangerous >> "$ACTIONS"')
        self.state.parent.write_text("not a directory")
        result = self.run_migrations()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.actions.exists())


class InstallerExitTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.scripts = self.root / "Scripts"
        self.scripts.mkdir()
        shutil.copy(ROOT / "Scripts/install.sh", self.scripts)
        (self.scripts / "global_fn.sh").write_text('''
print_log() { printf '%s\\n' "$*"; }
cacheDir="$HOME/cache"
''')
        (self.scripts / "hypr_autogen.sh").write_text(":\n")
        self.env = dict(os.environ, HOME=str(self.home))

    def child(self, name, code):
        path = self.scripts / name
        path.write_text(f"#!/bin/bash\n{code}\n")
        path.chmod(0o755)

    def run_installer(self, *args, input_text=""):
        return subprocess.run(["/bin/bash", str(self.scripts / "install.sh"), *args],
                              env=self.env, input=input_text, text=True, capture_output=True, timeout=10)

    def test_pre_install_failure_propagates_without_later_operations(self):
        self.child("install_pre.sh", "exit 13")
        result = self.run_installer("-p", "-s")
        self.assertEqual(result.returncode, 13)
        self.assertIn("Pre-install failed", result.stdout)

    def test_invalid_options_fail_and_help_succeeds(self):
        result = self.run_installer("--bad-option")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unknown option", result.stderr)
        self.assertEqual(self.run_installer("--help").returncode, 0)

    def test_restore_test_mode_does_not_run_migrations(self):
        functions = (ROOT / "Scripts/global_fn.sh").read_text().split("run_pending_migrations() {", 1)[1]
        with (self.scripts / "global_fn.sh").open("a") as script:
            script.write('''
cloneDir="$HOME"
setup_python_env() { return 0; }
nvidia_detect() { return 1; }
resolve_shell() { return 0; }
retire_autogenerated_hypr_config() { return 0; }
run_pending_migrations() {''' + functions)
        self.child("restore_thm.sh", "exit 0")
        migrations = self.scripts / "migrations"
        migrations.mkdir()
        (migrations / "v1.sh").write_text('echo dangerous > "$HOME/migration-ran"\n')
        self.env["TMPDIR"] = str(self.root)
        self.env["XDG_STATE_HOME"] = str(self.root / "state")
        result = self.run_installer("-r", "-t", input_text="y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Would check and run pending migrations", result.stdout)
        self.assertNotIn("Do you want to reboot", result.stdout)
        self.assertFalse((self.home / "migration-ran").exists())
        self.assertFalse((self.root / "state").exists())

    def test_test_services_never_offers_reboot(self):
        self.child("restore_svc.sh", "exit 0")
        result = self.run_installer("-s", "-t", input_text="y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Do you want to reboot", result.stdout)
        self.assertNotIn("Rebooting system", result.stdout)


if __name__ == "__main__":
    unittest.main()
