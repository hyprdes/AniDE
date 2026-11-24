"""Regression tests for the missing Quickshell bar ("mất thanh bar").

Covers the startup lifecycle in Configs/.local/lib/hyde/quickshell.sh:
the bar is launched from Hyprland's `hyprland.start` event via app2unit,
so a start that races the Wayland socket, or a Quickshell that exits at
once, used to vanish with no trace. start_qs now waits for the socket,
verifies the process stayed up, retries once, and logs every outcome.
"""
import os
import pathlib
import shutil
import socket
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
QS_SH = ROOT / "Configs/.local/lib/hyde/quickshell.sh"


class QuickshellManifestTest(unittest.TestCase):
    def test_root_dots_manifest_deploys_quickshell_not_waybar(self):
        # dots.toml is the example/full manifest; it still listed the deleted
        # waybar.toml and omitted quickshell.toml, so a deploy from it left
        # ~/.config/quickshell empty and the bar never started.
        dots = (ROOT / "dots.toml").read_text()
        self.assertIn('"Scripts/dots/quickshell.toml"', dots)
        self.assertNotIn("waybar.toml", dots)
        self.assertTrue((ROOT / "Scripts/dots/quickshell.toml").is_file())
        self.assertFalse((ROOT / "Scripts/dots/waybar.toml").exists())


class QuickshellScriptContractTest(unittest.TestCase):
    def test_start_waits_verifies_and_reports(self):
        text = QS_SH.read_text()
        subprocess.run(["bash", "-n", str(QS_SH)], check=True)
        # Wayland readiness: hyprland.start can fire before the socket exists.
        self.assertIn("wait_for_wayland()", text)
        self.assertIn('[[ -S "${sock}" ]]', text)
        # Launch verification + one retry instead of a silent disappearance.
        self.assertIn("pid_alive()", text)
        self.assertIn("for attempt in 1 2", text)
        self.assertIn("exited immediately", text)
        # Outcomes are logged; a missing binary is a failure, not success.
        self.assertIn("qs_log()", text)
        self.assertIn("start failed: quickshell binary not found on PATH", text)
        self.assertIn("Quickshell failed to stay up", text)
        # Detached launch survives the script / systemd scope exit.
        self.assertIn("setsid nohup", text)


class QuickshellStartFunctionalTest(unittest.TestCase):
    """Run quickshell.sh --watch against fake quickshell binaries."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="qs-bar-test-")
        self.addCleanup(shutil.rmtree, self.tmp, True)
        tmp = pathlib.Path(self.tmp)
        self.bin_dir = tmp / "bin"
        self.run_dir = tmp / "run"
        for d in (tmp / "home", tmp / "config", tmp / "data", tmp / "cache",
                  self.bin_dir, self.run_dir):
            d.mkdir(parents=True, exist_ok=True)
        # Minimal share source so ensure_config has something to copy.
        share = tmp / "data" / "quickshell"
        share.mkdir(parents=True, exist_ok=True)
        (share / "shell.qml").write_text("import Quickshell\nShellRoot {}\n")
        self.env = {
            "HOME": str(tmp / "home"),
            "XDG_CONFIG_HOME": str(tmp / "config"),
            "XDG_DATA_HOME": str(tmp / "data"),
            "XDG_CACHE_HOME": str(tmp / "cache"),
            "XDG_RUNTIME_DIR": str(self.run_dir),
            "PATH": f"{self.bin_dir}:/usr/bin:/bin",
        }
        self.env.pop("WAYLAND_DISPLAY", None)
        self.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)

    def _make_wayland_socket(self):
        self.env["WAYLAND_DISPLAY"] = "wayland-test-0"
        sock_path = self.run_dir / "wayland-test-0"
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.bind(str(sock_path))
        # The socket file keeps its type after close; wait_for_wayland only
        # checks for a socket at the path.
        srv.close()
        self.assertTrue(sock_path.exists())

    def _write_fake(self, body):
        fake = self.bin_dir / "quickshell"
        fake.write_text("#!/bin/bash\n" + body)
        fake.chmod(0o755)

    def _run_watch(self):
        return subprocess.run(
            ["bash", str(QS_SH), "--watch"],
            capture_output=True, text=True, env=self.env, timeout=30,
        )

    def _log(self):
        log = self.run_dir / "quickshell.log"
        return log.read_text() if log.exists() else ""

    def test_missing_binary_fails_loudly(self):
        proc = self._run_watch()
        self.assertNotEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("not found on PATH", proc.stderr)
        self.assertIn("not found on PATH", self._log())

    def test_crashing_binary_is_retried_and_logged(self):
        self._make_wayland_socket()
        self._write_fake('echo "fake crash" >&2\nexit 3\n')
        proc = self._run_watch()
        self.assertNotEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("failed to stay up", proc.stderr)
        log = self._log()
        self.assertIn("attempt 1", log)
        self.assertIn("attempt 2", log)
        self.assertIn("exited immediately", log)

    def test_healthy_binary_starts_and_stays(self):
        self._make_wayland_socket()
        self._write_fake('echo "args: $*" >> "$HOME/fake_qs_args.log"\nexec sleep 30\n')
        self.addCleanup(lambda: subprocess.run(
            ["pkill", "-f", "sleep 30"], capture_output=True))
        proc = self._run_watch()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("started quickshell", self._log())
        args_log = pathlib.Path(self.env["HOME"]) / "fake_qs_args.log"
        self.assertTrue(args_log.exists())
        self.assertIn(f"-p {self.env['XDG_CONFIG_HOME']}/quickshell",
                      args_log.read_text())


if __name__ == "__main__":
    unittest.main()
