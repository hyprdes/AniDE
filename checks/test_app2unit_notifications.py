"""Check shipped and regenerated notification rules without a running desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DUNST = ROOT / "Configs/.config/dunst"
SCRIPT = ROOT / "Configs/.local/share/wallbash/scripts/dunst.sh"


def section(text, name):
    current = None
    values = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
        elif current == name and "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


class App2unitNotificationTest(unittest.TestCase):
    def assert_dunst_rule(self, text):
        self.assertGreater(text.rfind("[app2unit_error]"), text.rfind("[urgency_critical]"))
        self.assertEqual(section(text, "urgency_critical").get("timeout"), "0")
        rule = section(text, "app2unit_error")
        self.assertEqual(rule.get("appname"), '"^app2unit$"')
        self.assertEqual(rule.get("msg_urgency"), "critical")
        self.assertGreater(int(rule.get("timeout", "0")), 0)

    def test_shipped_dunst_rule(self):
        self.assert_dunst_rule((DUNST / "dunstrc").read_text())

    def test_generated_dunst_rule(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = root / "config"
            cache = root / "cache"
            data = root / "data"
            bin_dir = root / "bin"
            for path in (config / "dunst", cache / "wallbash", data / "icons", bin_dir):
                path.mkdir(parents=True)
            shutil.copy(DUNST / "dunst.conf", config / "dunst/dunst.conf")
            (cache / "wallbash/dunst.conf").write_text("")
            (bin_dir / "hyde-shell").write_text("get_hyprConf() { :; }\n")
            # No variables in the rule under test; this avoids needing gettext.
            (bin_dir / "envsubst").write_text("#!/bin/sh\ncat\n")
            for name in ("killall", "dunst"):
                (bin_dir / name).write_text("#!/bin/sh\nexit 0\n")
            for name in ("hyde-shell", "envsubst", "killall", "dunst"):
                (bin_dir / name).chmod(0o755)
            env = dict(os.environ, HOME=str(root), PATH=f"{bin_dir}:/usr/bin:/bin",
                       confDir=str(config), cacheDir=str(cache), XDG_DATA_HOME=str(data),
                       iconsDir=str(data / "icons"), WALLBASH_SCRIPTS=str(root))
            result = subprocess.run(["bash", str(SCRIPT)], env=env, text=True,
                                    capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_dunst_rule((config / "dunst/dunstrc").read_text())

    def test_swaync_rule_precedes_other_rules_and_keeps_critical_sticky(self):
        data = json.loads((ROOT / "Configs/.config/swaync/config.json").read_text())
        rules = data["notification-visibility"]
        self.assertEqual(next(iter(rules)), "app2unit-error")
        self.assertEqual(rules["app2unit-error"], {
            "state": "enabled", "app-name": "^app2unit$", "urgency": "Critical",
            "override-urgency": "normal",
        })
        self.assertGreater(data["timeout"], 0)
        self.assertEqual(data["timeout-critical"], 0)


if __name__ == "__main__":
    unittest.main()
