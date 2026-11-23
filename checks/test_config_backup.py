"""Configuration backups are opt-in and limited to regular HOME files."""
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "Scripts/config_backup.py"


class ConfigBackupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.archive = self.root / "backup"
        self.env = dict(os.environ, HOME=str(self.home))
        self.file = self.home / ".config/app/settings"
        self.file.parent.mkdir(parents=True)
        self.file.write_text("original\n")
        self.file.chmod(0o640)

    def run_tool(self, *args):
        return subprocess.run(["python3", str(SCRIPT), *map(str, args)], env=self.env,
                              text=True, capture_output=True, timeout=10)

    def create(self, *paths):
        result = self.run_tool("create", self.archive, *(paths or (".config/app/settings",)))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_preview_conflict_and_explicit_restore(self):
        self.create()
        self.assertEqual(stat.S_IMODE(self.archive.stat().st_mode), 0o700)
        self.file.write_text("changed\n")
        preview = self.run_tool("restore", self.archive)
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn("REPLACE '.config/app/settings'", preview.stdout)
        self.assertEqual(self.file.read_text(), "changed\n")
        refused = self.run_tool("restore", self.archive, "--apply")
        self.assertNotEqual(refused.returncode, 0)
        self.assertEqual(self.file.read_text(), "changed\n")
        restored = self.run_tool("restore", self.archive, "--apply", "--overwrite")
        self.assertEqual(restored.returncode, 0, restored.stderr)
        self.assertEqual(self.file.read_text(), "original\n")
        self.assertEqual(stat.S_IMODE(self.file.stat().st_mode), 0o640)

    def test_missing_file_restores_without_overwrite(self):
        self.create()
        self.file.unlink()
        self.file.parent.rmdir()
        result = self.run_tool("restore", self.archive, "--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.file.read_text(), "original\n")

    def test_preflight_hash_failure_changes_nothing(self):
        second = self.home / "another"
        second.write_text("second")
        self.create(".config/app/settings", "another")
        self.file.write_text("user data")
        second.write_text("user data 2")
        (self.archive / "files/00000001").write_text("corrupt")
        result = self.run_tool("restore", self.archive, "--apply", "--overwrite")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Integrity check failed", result.stderr)
        self.assertEqual(self.file.read_text(), "user data")
        self.assertEqual(second.read_text(), "user data 2")

    def test_refuses_paths_and_symlink_components(self):
        for value in ("../outside", "/etc/passwd", ".config//app/settings", ".config/./app/settings"):
            with self.subTest(value=value):
                self.assertNotEqual(self.run_tool("create", self.archive, value).returncode, 0)
                self.assertFalse(self.archive.exists())
        (self.home / "link").symlink_to(self.file.parent, target_is_directory=True)
        self.assertNotEqual(self.run_tool("create", self.archive, "link/settings").returncode, 0)
        self.assertFalse(self.archive.exists())
        self.create()
        self.file.unlink()
        self.file.symlink_to(self.root / "outside")
        result = self.run_tool("restore", self.archive, "--apply", "--overwrite")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.file.is_symlink())
        self.assertFalse((self.root / "outside").exists())

    def test_manifest_traversal_and_blob_links_rejected(self):
        self.create()
        manifest = self.archive / "manifest.json"
        document = json.loads(manifest.read_text())
        document["files"][0]["path"] = "../outside"
        manifest.write_text(json.dumps(document))
        result = self.run_tool("restore", self.archive, "--apply", "--overwrite")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.file.read_text(), "original\n")
        document["files"][0]["path"] = ".config/app/settings"
        manifest.write_text(json.dumps(document))
        blob = self.archive / "files/00000000"
        blob.unlink()
        blob.symlink_to(self.file)
        self.assertNotEqual(self.run_tool("restore", self.archive).returncode, 0)

    def test_existing_archive_and_duplicate_paths_are_rejected(self):
        result = self.run_tool("create", self.archive, ".config/app/settings", ".config/app/settings")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.archive.exists())
        self.create()
        before = hashlib.sha256((self.archive / "manifest.json").read_bytes()).hexdigest()
        self.assertNotEqual(self.run_tool("create", self.archive, ".config/app/settings").returncode, 0)
        self.assertEqual(before, hashlib.sha256((self.archive / "manifest.json").read_bytes()).hexdigest())

    def test_restore_rejects_archive_target_overlap(self):
        self.create()
        manifest = self.archive / "manifest.json"
        document = json.loads(manifest.read_text())
        # Simulate placing an archive inside HOME and naming its own manifest.
        inside_home = self.home / "archive"
        self.archive.rename(inside_home)
        document["files"][0]["path"] = "archive/manifest.json"
        (inside_home / "manifest.json").write_text(json.dumps(document))
        result = self.run_tool("restore", inside_home, "--apply", "--overwrite")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("overlaps", result.stderr)


if __name__ == "__main__":
    unittest.main()
