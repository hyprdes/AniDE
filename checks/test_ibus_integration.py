"""IBus integration tests with mocked binaries; no desktop session is required."""
from pathlib import Path
import stat
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENV_SCRIPT = ROOT / "Configs/.config/uwsm/env-hyprland.d/10-anide-input.sh"
START_SCRIPT = ROOT / "Configs/.local/lib/hyde/ibus-start.sh"

# A flat "schema|key=value" file stands in for the dconf database, carrying the
# schema defaults IBus itself ships, so an unset key reads the way it does on a
# fresh install.
GSETTINGS_MOCK = r"""#!/bin/sh
db="${MOCK_DB:?}"
cmd="$1"; shift
case "$cmd" in
    list-keys)
        case "$1" in
            org.freedesktop.ibus.general) printf 'preload-engines\nengines-order\nversion\n' ;;
            org.freedesktop.ibus.general.hotkey) printf 'triggers\ntrigger\n' ;;
            *) exit 1 ;;
        esac ;;
    get)
        value=$(grep -m1 "^$1|$2=" "$db" 2>/dev/null | cut -d= -f2-)
        if [ -z "$value" ]; then
            case "$1|$2" in
                "org.freedesktop.ibus.general|preload-engines") value="@as []" ;;
                "org.freedesktop.ibus.general|engines-order") value="@as []" ;;
                "org.freedesktop.ibus.general.hotkey|triggers") value="['<Super>space']" ;;
            esac
        fi
        printf '%s\n' "$value" ;;
    set)
        { grep -v "^$1|$2=" "$db" 2>/dev/null || true; printf '%s|%s=%s\n' "$1" "$2" "$3"; } > "$db.tmp"
        mv "$db.tmp" "$db" ;;
    *) exit 1 ;;
esac
"""

DCONF_MOCK = r"""#!/bin/sh
# Shares the store with the gsettings mock, keyed the same way, but prints
# nothing for a key nobody wrote -- which is how an unset key differs from one
# sitting at its schema default.
db="${MOCK_DB:?}"
key_from_path() {
    case "$1" in
        desktop/ibus/general/preload-engines) printf 'org.freedesktop.ibus.general|preload-engines' ;;
        desktop/ibus/general/engines-order) printf 'org.freedesktop.ibus.general|engines-order' ;;
        desktop/ibus/general/hotkey/triggers) printf 'org.freedesktop.ibus.general.hotkey|triggers' ;;
        *) printf 'unknown|%s' "$1" ;;
    esac
}
cmd="$1"; shift
key=$(key_from_path "${1#/}")
value="$2"
case "$cmd" in
    read)
        stored=$(grep -m1 "^$key=" "$db" 2>/dev/null | cut -d= -f2-)
        [ -n "$stored" ] && printf '%s\n' "$stored"
        exit 0 ;;
    write)
        { grep -v "^$key=" "$db" 2>/dev/null || true; printf '%s=%s\n' "$key" "$value"; } > "$db.tmp"
        mv "$db.tmp" "$db"
        exit 0 ;;
    *) exit 1 ;;
esac
"""

DAEMON_MOCK = """#!/bin/sh
printf '%s\\n' "$*" >> "${MOCK_LOG:?}"
"""

PGREP_MOCK = """#!/bin/sh
exit "${MOCK_FCITX:-1}"
"""

# $1=-a $2=AniDE $3=-i $4=icon $5=title $6=body
NOTIFY_MOCK = """#!/bin/sh
printf '%s|%s\\n' "$5" "$6" >> "${MOCK_LOG:?}"
"""

# The shape ibus-unikey really installs: the engine list is delegated to the
# engine binary, so a parser that only reads inline <engine> blocks finds
# nothing on a stock Arch system.
UNIKEY_DYNAMIC = """<?xml version="1.0" encoding="utf-8"?>
<component>
  <name>org.freedesktop.IBus.Unikey</name>
  <description>Unikey Component</description>
  <exec>{exec_dir}/ibus-engine-unikey --ibus</exec>
  <version>0.9.4</version>
  <license>GPL</license>
  <engines exec="{exec_dir}/ibus-engine-unikey --xml" />
</component>
"""

UNIKEY_DYNAMIC_RELATIVE = """<component>
  <name>org.freedesktop.IBus.Unikey</name>
  <engines exec="ibus-engine-unikey --xml" />
</component>
"""

UNIKEY_ENGINE_XML = """<engines>
  <engine>
    <name>Unikey</name>
    <longname>Unikey</longname>
    <language>vi</language>
    <license>GPLv3</license>
    <layout>*</layout>
    <rank>99</rank>
  </engine>
</engines>
"""

ENGINE_BINARY = """#!/bin/sh
case "$1" in
    --xml) cat "${MOCK_ENGINE_XML:?}" ;;
    *) exit 0 ;;
esac
"""

UNIKEY_STATIC = """<component>
  <name>org.freedesktop.IBus.Unikey</name>
  <engines>
    <engine>
      <name>Unikey</name>
      <language>vi</language>
      <longname>Unikey</longname>
    </engine>
  </engines>
</component>
"""

BAMBOO_STATIC = """<component>
  <name>org.freedesktop.IBus.Bamboo</name>
  <engines>
    <engine>
      <name>Bamboo</name>
      <language>vi</language>
    </engine>
  </engines>
</component>
"""


def write_executable(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


class IbusSandbox:
    """A throwaway session: settings backend, engine components, daemon, logs."""

    def __init__(self, root, *, gsettings=True, dconf=True, components="dynamic",
                 presets=(), relative_exec=False):
        self.root = Path(root)
        self.bin = self.root / "bin"
        self.data = self.root / "usr" / "share"
        self.libexec = self.root / "usr" / "lib" / "ibus"
        self.db = self.root / "db"
        self.log = self.root / "log"
        self.home = self.root / "home"
        self.engine_xml = self.root / "engine-unikey.xml"
        self.db.write_text("".join(line + "\n" for line in presets))
        self.log.write_text("")
        self.engine_xml.write_text(UNIKEY_ENGINE_XML)
        write_executable(self.bin / "ibus-daemon", DAEMON_MOCK)
        write_executable(self.bin / "pgrep", PGREP_MOCK)
        if gsettings:
            write_executable(self.bin / "gsettings", GSETTINGS_MOCK)
        if dconf:
            write_executable(self.bin / "dconf", DCONF_MOCK)
        self.components = self.data / "ibus" / "component"
        if components != "none":
            self.install(components, relative_exec=relative_exec)

    def install(self, kind, *, relative_exec=False):
        """Add an engine package, as pacman would, under the data directory."""
        self.components.mkdir(parents=True, exist_ok=True)
        if kind == "dynamic":
            write_executable(self.libexec / "ibus-engine-unikey", ENGINE_BINARY)
            text = (UNIKEY_DYNAMIC_RELATIVE if relative_exec
                    else UNIKEY_DYNAMIC.format(exec_dir=self.libexec))
            (self.components / "unikey.xml").write_text(text)
        elif kind == "static":
            (self.components / "unikey.xml").write_text(UNIKEY_STATIC)
        elif kind == "bamboo":
            (self.components / "bamboo.xml").write_text(BAMBOO_STATIC)
        else:
            raise ValueError(kind)

    def env(self, extra=None):
        env = {
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.home / ".local" / "state"),
            "XDG_DATA_DIRS": str(self.data),
            "MOCK_DB": str(self.db),
            "MOCK_LOG": str(self.log),
            "MOCK_ENGINE_XML": str(self.engine_xml),
        }
        env.update(extra or {})
        return env

    def run(self, args=(), **extra):
        return subprocess.run(
            ["bash", str(START_SCRIPT), *args],
            env=self.env(extra), text=True, capture_output=True, check=False,
        )

    def settings(self):
        return dict(line.split("=", 1) for line in self.db.read_text().splitlines() if line)

    def preload(self):
        return self.settings().get("org.freedesktop.ibus.general|preload-engines", "")

    def order(self):
        return self.settings().get("org.freedesktop.ibus.general|engines-order", "")

    def triggers(self):
        return self.settings().get("org.freedesktop.ibus.general.hotkey|triggers", "")

    def log_text(self):
        return self.log.read_text()

    def marker(self):
        path = self.home / ".local" / "state" / "hyde" / "ibus" / "vi-engine-seeded"
        return path.read_text() if path.exists() else ""

    def mark_seeded(self):
        path = self.home / ".local" / "state" / "hyde" / "ibus" / "vi-engine-seeded"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("engine=Unikey\n")


class IbusIntegrationTest(unittest.TestCase):
    def env_defaults(self, values):
        with tempfile.TemporaryDirectory() as tmp:
            daemon = Path(tmp) / "ibus-daemon"
            daemon.write_text("#!/bin/sh\nexit 0\n")
            daemon.chmod(0o755)
            env = {"PATH": tmp, "HOME": "/tmp"}
            env.update(values)
            code = '. "$1"; printf "%s|%s|%s" "${GTK_IM_MODULE-}" "${QT_IM_MODULE-}" "${XMODIFIERS-}"'
            return subprocess.check_output(["/bin/sh", "-c", code, "sh", str(ENV_SCRIPT)], env=env, text=True)

    def test_default_and_existing_input_method(self):
        self.assertEqual(self.env_defaults({}), "ibus|ibus|@im=ibus")
        self.assertEqual(self.env_defaults({"GTK_IM_MODULE": "fcitx"}), "fcitx||")
        self.assertEqual(self.env_defaults({"QT_IM_MODULE": "fcitx"}), "|fcitx|")
        self.assertEqual(self.env_defaults({"XMODIFIERS": "@im=fcitx"}), "||@im=fcitx")
        self.assertEqual(self.env_defaults({"ANIDE_INPUT_METHOD": "none"}), "||")
        self.assertEqual(self.env_defaults({"PATH": "/nonexistent"}), "||")
        self.assertEqual(self.env_defaults({"GTK_IM_MODULE": "ibus"}), "ibus|ibus|@im=ibus")

    def run_start(self, settings, running_fcitx=False):
        """The daemon start policy, on a machine that is already registered."""
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, components="none")
            sandbox.mark_seeded()
            env = dict(settings)
            if running_fcitx:
                env["MOCK_FCITX"] = "0"
            sandbox.run(**env)
            return sandbox.log_text()

    def test_daemon_no_replace_or_conflicts(self):
        self.assertEqual(self.run_start({}), "--daemonize --xim\n")
        self.assertEqual(self.run_start({"ANIDE_INPUT_METHOD": "none"}), "")
        self.assertEqual(self.run_start({"GTK_IM_MODULE": "fcitx"}), "")
        self.assertEqual(self.run_start({}, running_fcitx=True), "")

    def test_fresh_install_registers_unikey_and_starts_daemon(self):
        """The reported bug: a fresh install had no Vietnamese engine to switch to."""
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp)
            result = sandbox.run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Unikey']")
            self.assertIn("--daemonize --xim", sandbox.log_text())
            self.assertIn("engine=Unikey", sandbox.marker())
            self.assertIn("Vietnamese input ready", result.stdout)

    def test_dynamic_component_is_discovered(self):
        """ibus-unikey declares its engines through `<engines exec="... --xml"/>`."""
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, components="dynamic")
            sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Unikey']")

    def test_relative_component_exec_is_not_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, components="dynamic", relative_exec=True)
            result = sandbox.run()
            self.assertEqual(sandbox.preload(), "")
            self.assertEqual(sandbox.marker(), "")
            self.assertIn("no Vietnamese IBus engine found", result.stderr)
            self.assertIn("--daemonize --xim", sandbox.log_text())

    def test_static_component_and_other_engine(self):
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, components="static")
            sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Unikey']")
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, components="bamboo")
            sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Bamboo']")
            self.assertIn("engine=Bamboo", sandbox.marker())

    def test_user_engines_are_appended_to_not_replaced(self):
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, presets=(
                "org.freedesktop.ibus.general|preload-engines=['xkb:us::eng', 'xkb:fr::fra']",
                "org.freedesktop.ibus.general|engines-order=['xkb:fr::fra', 'xkb:us::eng']",
            ))
            sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'xkb:fr::fra', 'Unikey']")
            self.assertEqual(sandbox.order(), "['xkb:fr::fra', 'xkb:us::eng', 'Unikey']")

    def test_existing_vietnamese_engine_is_left_alone(self):
        """A user who already chose Bamboo does not get a second vi engine."""
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, components="bamboo", presets=(
                "org.freedesktop.ibus.general|preload-engines=['xkb:us::eng', 'Bamboo']",
            ))
            result = sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Bamboo']")
            self.assertIn("engine=Bamboo", sandbox.marker())
            self.assertIn("already registered", result.stdout)

    def test_marker_keeps_a_removed_engine_removed(self):
        """Registering happens once, so deleting Unikey in ibus-setup sticks."""
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp)
            sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Unikey']")
            # The user removes the engine; the marker is still there.
            sandbox.db.write_text("org.freedesktop.ibus.general|preload-engines=['xkb:us::eng']\n")
            sandbox.log.write_text("")
            sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng']")
            self.assertEqual(sandbox.log_text(), "--daemonize --xim\n")
            # ... and an explicit request puts it back.
            sandbox.run(["--seed", "--force"])
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Unikey']")

    def test_unclaimed_switch_key_becomes_control_space(self):
        """IBus now defaults to <Super>space, a chord the compositor may own."""
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp)
            sandbox.run()
            self.assertEqual(sandbox.triggers(), "['<Control>space']")

    def test_chosen_switch_key_is_kept(self):
        for chosen in ("['<Super>space']", "['<Shift>Shift_R']", "@as []"):
            with tempfile.TemporaryDirectory() as tmp:
                sandbox = IbusSandbox(tmp, presets=(
                    f"org.freedesktop.ibus.general.hotkey|triggers={chosen}",
                ))
                sandbox.run()
                self.assertEqual(sandbox.triggers(), chosen, "a written switch key was rewritten")

    def test_switch_key_without_dconf_only_fills_an_empty_one(self):
        """Without dconf there is no way to tell a default from a choice."""
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, dconf=False)
            sandbox.run()
            self.assertEqual(sandbox.triggers(), "", "the schema default was mistaken for a choice")

    def test_opt_out_and_conflicts_change_nothing(self):
        cases = {
            "ANIDE_INPUT_METHOD": ("none", ""),
            "GTK_IM_MODULE": ("fcitx", ""),
            "MOCK_FCITX": ("0", ""),
            # Skipping the engine is not skipping IBus.
            "ANIDE_IBUS_ENGINE": ("none", "--daemonize --xim\n"),
        }
        for key, (value, expected_log) in cases.items():
            with tempfile.TemporaryDirectory() as tmp:
                sandbox = IbusSandbox(tmp)
                result = sandbox.run(**{key: value})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(sandbox.db.read_text(), "", key)
                self.assertEqual(sandbox.marker(), "", key)
                self.assertEqual(sandbox.log_text(), expected_log, key)

    def test_dconf_fallback_and_missing_backend(self):
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, gsettings=False, dconf=True)
            sandbox.run()
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Unikey']")
            self.assertEqual(sandbox.triggers(), "['<Control>space']")
            self.assertEqual(sandbox.log_text(), "--daemonize --xim\n")
        with tempfile.TemporaryDirectory() as tmp:
            # No backend to write to: report it, start IBus anyway, and leave no
            # marker so the next login tries again.
            sandbox = IbusSandbox(tmp, gsettings=False, dconf=False)
            result = sandbox.run()
            self.assertIn("not registered", result.stderr)
            self.assertEqual(sandbox.marker(), "")
            self.assertEqual(sandbox.log_text(), "--daemonize --xim\n")

    def test_missing_engine_does_not_block_the_daemon(self):
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp, components="none")
            result = sandbox.run()
            self.assertIn("no Vietnamese IBus engine found", result.stderr)
            self.assertEqual(sandbox.preload(), "")
            self.assertEqual(sandbox.marker(), "")
            self.assertEqual(sandbox.log_text(), "--daemonize --xim\n")

    def test_seed_and_status_modes(self):
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp)
            result = sandbox.run(["--seed"])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(sandbox.log_text(), "")
            self.assertEqual(sandbox.preload(), "['xkb:us::eng', 'Unikey']")

            status = sandbox.run(["--status"])
            self.assertEqual(status.returncode, 0, status.stderr)
            for line in ("vi engines installed : Unikey",
                         "preload-engines      : xkb:us::eng Unikey",
                         "switch key           : <Control>space",
                         "registered by AniDE  : engine=Unikey"):
                self.assertIn(line, status.stdout)

            unknown = sandbox.run(["--nope"])
            self.assertEqual(unknown.returncode, 1)
            self.assertIn("Unknown option", unknown.stderr)
            self.assertIn("--status", unknown.stderr)

    def test_notification_reports_the_result(self):
        with tempfile.TemporaryDirectory() as tmp:
            sandbox = IbusSandbox(tmp)
            write_executable(sandbox.bin / "notify-send", NOTIFY_MOCK)
            sandbox.run()
            self.assertIn("Vietnamese input ready|Unikey was added to IBus.", sandbox.log_text())

    def test_package_and_session_wiring(self):
        deps = tomllib.loads((ROOT / "Scripts/dots/deps.toml").read_text())
        entry = deps["global"]["dependency"][0]
        self.assertIn("ibus", entry["pacman"])
        # Official repo package: it must not depend on an AUR helper being there.
        self.assertIn("ibus-unikey", entry["pacman"])
        for helper in ("yay", "paru"):
            self.assertIn("ibus-unikey", entry[helper])
        variables = (ROOT / "Configs/.local/share/hypr/lua/variables.lua").read_text()
        self.assertIn('hc.start.input_method = "hyde-shell ibus-start"', variables)
        self.assertIn('check_exec(hs.input_method)', (ROOT / "Configs/.local/share/hypr/lua/start_up.lua").read_text())
        self.assertIn('"ibus-start", "--seed", "--force"',
                      (ROOT / "Configs/.local/lib/hyde/pygui/anide_settings.py").read_text())
        # An install that runs inside a graphical session registers the engine
        # right away instead of waiting for the first Hyprland login.
        post_install = (ROOT / "Scripts/install_pst.sh").read_text()
        self.assertIn('ibus-start.sh" --seed', post_install)
        self.assertIn("DBUS_SESSION_BUS_ADDRESS", post_install)
        subprocess.run(["bash", "-n", str(START_SCRIPT)], check=True)
        subprocess.run(["sh", "-n", str(ENV_SCRIPT)], check=True)


if __name__ == "__main__":
    unittest.main()
