"""Regression tests for legacy installer paths, isolated from system commands."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerSafetyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.scripts = self.root / "Scripts"
        self.scripts.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands"
        self.env = dict(os.environ, HOME=str(self.home), USER="anide_test_unique_avatar",
                        CLONE_DIR=str(self.root), PATH=f"{self.bin}:/usr/bin:/bin",
                        COMMAND_LOG=str(self.log), HYDE_LOG="test")
        (self.scripts / "global_fn.sh").write_text('''
set -e
cloneDir="$CLONE_DIR"
print_log() { printf '%s\\n' "$*"; }
pkg_installed() { case "$1" in sddm|dolphin|xdg-utils|dummy) return 0;; *) return 1;; esac; }
pacmanCmd="$CLONE_DIR/bin/package-install"
''')

    def executable(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def run_script(self, *args, dry=1):
        return subprocess.run(["/bin/bash", *map(str, args)], env=dict(self.env, flg_DryRun=str(dry)),
                              input="1\n", text=True, capture_output=True, timeout=10)

    def test_post_install_guards_avatar_and_file_association(self):
        shutil.copy(ROOT / "Scripts/install_pst.sh", self.scripts)
        (self.scripts / "restore_shl.sh").write_text('#!/bin/bash\nexit 0\n')
        (self.scripts / "restore_shl.sh").chmod(0o755)
        avatar = self.root / "Source/misc" / f'{self.env["USER"]}.face.icon'
        avatar.parent.mkdir(parents=True)
        avatar.write_text("avatar")
        self.executable("sudo", 'echo "sudo $*" >> "$COMMAND_LOG"')
        self.executable("xdg-mime", 'echo "xdg-mime $*" >> "$COMMAND_LOG"; echo current.desktop')
        dry = self.run_script(self.scripts / "install_pst.sh")
        self.assertEqual(dry.returncode, 0, dry.stderr)
        self.assertFalse(self.log.exists(), self.log.read_text() if self.log.exists() else "")
        self.assertIn("Would set avatar", dry.stdout)
        self.assertIn("Would set Dolphin", dry.stdout)
        self.assertIn("Would configure sddm", dry.stdout)
        live = self.run_script(self.scripts / "install_pst.sh", dry=0)
        self.assertEqual(live.returncode, 0, live.stderr)
        calls = self.log.read_text()
        self.assertIn("xdg-mime default org.kde.dolphin.desktop inode/directory", calls)
        self.assertIn(f"sudo cp {avatar} /usr/share/sddm/faces/", calls)

    def test_preserve_mode_dry_run_never_copies_missing_files(self):
        # Test the real deploy_psv function in isolation; no legacy hooks run.
        script = (ROOT / "Scripts/restore_cfg.sh").read_text().split("\nensure_hyq() {", 1)[0]
        functions = self.root / "functions.sh"
        functions.write_text(script)
        dest = self.home / ".config/example"
        dest.mkdir(parents=True)
        (dest / "kept").write_text("user")
        source = self.root / "Configs/.config/example"
        source.mkdir(parents=True)
        (source / "kept").write_text("default")
        (source / "new").write_text("new")
        manifest = self.root / "test.psv"
        manifest.write_text("P|${HOME}/.config|example|dummy\n")
        harness = self.root / "harness.sh"
        harness.write_text('''source "$1"
print_log() { printf '%s\\n' "$*"; }
pkg_installed() { return 0; }
CfgLst="$2"; CfgDir="$3"; BkpDir="$4"; USE_RSYNC=0
deploy_psv "$CfgLst"
''')
        backup = self.root / "backup"
        dry = self.run_script(harness, functions, manifest, self.root / "Configs", backup)
        self.assertEqual(dry.returncode, 0, dry.stderr)
        self.assertEqual((dest / "kept").read_text(), "user")
        self.assertFalse((dest / "new").exists())
        self.assertFalse(backup.exists())
        self.assertIn("Would back up and populate", dry.stdout)
        live = self.run_script(harness, functions, manifest, self.root / "Configs", backup, dry=0)
        self.assertEqual(live.returncode, 0, live.stderr)
        self.assertEqual((dest / "kept").read_text(), "user")
        self.assertEqual((dest / "new").read_text(), "new")
        self.assertEqual((backup / ".config/example/kept").read_text(), "user")

    def test_restore_dry_run_does_not_execute_hooks_or_create_config(self):
        shutil.copy(ROOT / "Scripts/restore_cfg.sh", self.scripts)
        config = self.root / "Configs"
        config.mkdir()
        manifest = self.root / "empty.psv"
        manifest.write_text("# empty\n")
        self.executable("hyq", 'exit 1')
        for name in ("package-install", "uv", "hyde-shell", "sudo"):
            self.executable(name, 'echo "unexpected $0 $*" >> "$COMMAND_LOG"; exit 1')
        result = self.run_script(self.scripts / "restore_cfg.sh", manifest, config)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / ".config").exists())
        self.assertFalse(self.log.exists())
        self.assertIn("Would check uv", result.stdout)

    def test_manifest_preflight_rejects_injection_and_traversal_before_writes(self):
        shutil.copy(ROOT / "Scripts/restore_cfg.sh", self.scripts)
        config = self.root / "Configs"
        (config / ".config").mkdir(parents=True)
        (config / ".config" / "safe").write_text("default")
        marker = self.root / "injected"
        for extension, good, bad_rows in (
            ("psv", "P|${HOME}/.config|safe|dummy", [
                f"P|${{HOME}}/$(touch {marker})|safe|dummy",
                "P|${HOME}/../escape|safe|dummy",
                "P|${HOME}/.config|../../escape|dummy",
                f"   P|${{HOME}}/$(touch {marker})|safe|dummy",
                "P|/tmp|safe|dummy",
            ]),
            ("lst", "N|Y|${HOME}/.config|safe|dummy", [
                f"N|Y|${{HOME}}/$(touch {marker})|safe|dummy",
                "N|Y|${HOME}/../escape|safe|dummy",
                "N|Y|${HOME}/.config|../../escape|dummy",
            ]),
        ):
            manifest = self.root / f"bad.{extension}"
            for bad in bad_rows:
                with self.subTest(row=bad):
                    manifest.write_text(good + "\n" + bad + "\n")
                    result = self.run_script(self.scripts / "restore_cfg.sh", manifest, config, dry=0)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("aborting before deployment", result.stderr)
                    self.assertFalse(marker.exists())
                    self.assertFalse((self.home / ".config").exists())

    def test_bundled_manifests_validate_and_spaces_in_home_work(self):
        script = (ROOT / "Scripts/restore_cfg.sh").read_text().split("\nensure_hyq() {", 1)[0]
        functions = self.root / "functions.sh"
        functions.write_text(script)
        harness = self.root / "validate.sh"
        harness.write_text('''source "$1"
validate_manifest "$2" psv || exit 1
validate_manifest "$3" lst || exit 1
manifest_path '${HOME}/.config/Code - OSS/User' || exit 1
printf '%s\\n' "$pth"
''')
        spaced_home = self.root / "home with spaces"
        spaced_home.mkdir()
        self.env["HOME"] = str(spaced_home)
        result = self.run_script(harness, functions, ROOT / "Scripts/restore_cfg.psv", ROOT / "Scripts/restore_cfg.lst")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), f"{spaced_home}/.config/Code - OSS/User")

    def test_no_nvidia_skips_systemd_boot_detection(self):
        shutil.copy(ROOT / "Scripts/install_pre.sh", self.scripts)
        with (self.scripts / "global_fn.sh").open("a") as script:
            script.write('''
setup_python_env() { return 0; }
pkg_installed() { [ "$1" = systemd ]; }
nvidia_detect() { return 0; }
prompt_timer() { PROMPT_INPUT=n; }
''')
        self.executable("bootctl", 'echo bootctl >> "$COMMAND_LOG"; echo "Product: other"')
        self.env["flg_Nvidia"] = "0"
        result = self.run_script(self.scripts / "install_pre.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())
        self.env["flg_Nvidia"] = "1"
        result = self.run_script(self.scripts / "install_pre.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("bootctl", self.log.read_text())

    def test_missing_hyq_does_not_install_in_dry_run(self):
        shutil.copy(ROOT / "Scripts/restore_cfg.sh", self.scripts)
        config = self.root / "Configs"
        config.mkdir()
        manifest = self.root / "empty.psv"
        manifest.write_text("# empty\n")
        self.executable("package-install", 'echo called >> "$COMMAND_LOG"; exit 1')
        result = self.run_script(self.scripts / "restore_cfg.sh", manifest, config)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())
        self.assertIn("hyq unavailable", result.stdout)


if __name__ == "__main__":
    unittest.main()
