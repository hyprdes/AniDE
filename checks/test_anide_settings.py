"""Headless tests; real Wayland, Rofi and Hyprland integration still needs testing."""
import ast
import importlib.util
import os
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Configs/.local/lib/hyde/pygui/anide_settings.py"
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
try:
    from PyQt6 import QtCore, QtWidgets
except ImportError:
    QtCore = None
    QtWidgets = None


class PackagingTest(unittest.TestCase):
    def test_entrypoint_and_manifest(self):
        desktop = (ROOT / "Configs/.local/share/applications/anide-settings.desktop").read_text()
        self.assertIn("Exec=hyde-shell anide-settings", desktop)
        manifest = (ROOT / "Scripts/dots/hyde.toml").read_text()
        # Other launchers (anide-movie.desktop) share the same paths array.
        self.assertRegex(manifest, r'paths = \[[^\]]*"anide-settings\.desktop"[^\]]*\]')
        self.assertIn('target_root = "${XDG_DATA_HOME}/applications"', manifest)
        self.assertIn('paths = "hyde"', manifest)

    def test_safe_action_catalog_without_qt(self):
        tree = ast.parse(SCRIPT.read_text())
        declaration = next(node for node in tree.body if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "SECTIONS" for t in node.targets))
        sections = ast.literal_eval(declaration.value)
        for _, _, _, actions in sections:
            for _, _, command, dependencies in actions:
                self.assertIn(command[0], dependencies)
                self.assertNotIn(command[0], ("sh", "bash"))
                self.assertNotEqual(command[:2], ("hyde-shell", "animations"))

    def test_launcher_syntax(self):
        launcher = ROOT / "Configs/.local/lib/hyde/anide-settings.sh"
        subprocess.run(["bash", "-n", str(launcher)], check=True)


@unittest.skipIf(QtWidgets is None, "PyQt6 unavailable")
class SettingsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("anide_settings", SCRIPT)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def test_theme_colors_ignore_untrusted_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "theme.css"
            path.write_text('@define-color main-bg #123456;\n@define-color main-fg red;\n@define-color wb-act-bg #abc;\n@define-color evil #abcdef;')
            self.assertEqual(self.module.theme_colors(path), {"main-bg": "#123456", "wb-act-bg": "#abc"})
            self.assertEqual(self.module.theme_colors(path.parent / "missing"), {})

    def test_xdg_relative_path_falls_back(self):
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": "relative"}):
            self.assertEqual(self.module.xdg_config_home(), Path.home() / ".config")
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": "/tmp/example"}):
            self.assertEqual(self.module.xdg_config_home(), Path("/tmp/example"))

    def test_navigation_search_and_missing_dependencies(self):
        with mock.patch.object(self.module.shutil, "which", return_value=None):
            window = self.module.SettingsWindow()
            window.show()
            self.app.processEvents()
            self.assertEqual(window.stack.count(), len(self.module.SECTIONS))
            self.assertTrue(all(not button.isEnabled() for button in window.findChildren(QtWidgets.QPushButton) if button.text().startswith("Open")))
            window.search.setText("wallpaper")
            self.assertTrue(any(not card.isHidden() for card, text in window.cards if "wallpaper" in text))
            self.assertTrue(all(card.isHidden() for card, text in window.cards if "wallpaper" not in text))
            window.select_section(1)
            self.assertEqual(window.search.text(), "")
            self.assertEqual(window.stack.currentIndex(), 1)
            window.close()

    def test_image12_glass_design_contract(self):
        window = self.module.SettingsWindow()
        self.assertTrue(bool(window.windowFlags() & QtCore.Qt.WindowType.FramelessWindowHint))
        self.assertIsInstance(window.centralWidget(), self.module.RootPanel)
        self.assertEqual(window.hero.objectName(), "hero")
        self.assertTrue(window.toggle.isCheckable())
        self.assertTrue(window.toggle.isChecked())
        self.assertEqual(window.closeBtn.text(), "\u2715")
        self.assertEqual(window.titlePill.text(), self.module.SECTIONS[0][0])
        window.select_section(2)
        self.assertEqual(window.titlePill.text(), self.module.SECTIONS[2][0])
        self.assertEqual(window.subPill.text(), self.module.SECTIONS[2][2])
        nav_texts = [b.text() for b in window.findChildren(QtWidgets.QPushButton) if b.objectName() == "nav"]
        for title, icon, _subtitle, _actions in self.module.SECTIONS:
            self.assertIn(f"{icon}   {title}".replace("&", "&&"), nav_texts)
        window.close()

    def test_commands_are_fixed_argv(self):
        for _, _, _, actions in self.module.SECTIONS:
            for _, _, command, dependencies in actions:
                self.assertIsInstance(command, tuple)
                self.assertIn(command[0], dependencies)
                self.assertNotIn("sh", command[:1])
                self.assertNotIn("bash", command[:1])


if __name__ == "__main__":
    unittest.main()
