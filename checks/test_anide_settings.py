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

    def test_image14_dashboard_design_contract(self):
        window = self.module.SettingsWindow()
        self.assertTrue(bool(window.windowFlags() & QtCore.Qt.WindowType.FramelessWindowHint))
        self.assertIsInstance(window.centralWidget(), self.module.RootPanel)
        self.assertEqual(window.closeBtn.text(), "\u2715")
        self.assertTrue(window.starBtn.text())
        self.assertEqual(window.titlePill.text(), self.module.SECTIONS[0][0])
        window.select_section(2)
        self.assertEqual(window.titlePill.text(), self.module.SECTIONS[2][0])
        self.assertEqual(window.search.text(), "")
        navs = [b for b in window.findChildren(QtWidgets.QPushButton) if b.objectName() == "nav"]
        self.assertEqual(len(navs), len(self.module.SECTIONS))
        stacks = window.findChildren(self.module.CardStack)
        self.assertGreaterEqual(len(stacks), len(self.module.SECTIONS))
        tiles = [t for t in window.findChildren(QtWidgets.QFrame) if t.objectName() == "tile"]
        self.assertTrue(tiles)
        window.close()

    def test_widget_section_and_comic_launcher(self):
        titles = [s[0] for s in self.module.SECTIONS]
        self.assertEqual(titles[0], "Widget")
        widget = self.module.SECTIONS[0][3]
        names = [a[0] for a in widget]
        self.assertEqual(names, ["AniSub (Movie)", "AniSub Comic"])
        movie, comic = widget
        self.assertEqual(movie[2], ("hyde-shell", "rofi.movie"))
        self.assertEqual(comic[2], ("hyde-shell", "rofi.comic"))
        launcher = ROOT / "Configs/.local/lib/hyde/rofi.comic.sh"
        self.assertTrue(launcher.is_file())
        subprocess.run(["bash", "-n", str(launcher)], check=True)
        text = launcher.read_text()
        self.assertIn("# @name: rofi.comic", text)
        self.assertIn("hyde-shell rofi.comic", text)
        self.assertIn("/tim-kiem?keyword=", text)
        self.assertIn("net.imgchapter.store", text)
        self.assertIn("chuong-", text)
        self.assertIn("truyen-", text)

    def test_wallpaper_widget_toggles_feed_and_page_scroll(self):
        import json

        window = self.module.SettingsWindow()
        self.assertTrue(window.movieToggle.isCheckable())
        self.assertTrue(window.comicToggle.isCheckable())
        page_scrolls = [
            s for s in window.findChildren(QtWidgets.QScrollArea)
            if s.objectName() == "pageScroll"
        ]
        self.assertEqual(len(page_scrolls), 1, "tall settings pages must scroll, not clip")

        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp}):
                self.module.write_widget_flags(True, False)
                data = json.loads((Path(tmp) / "quickshell" / "anisub_widgets.json").read_text())
                self.assertIs(data["movieVisible"], True)
                self.assertIs(data["comicVisible"], False)
                self.module.write_widget_flags(False, True)
                movie, comic, raw = self.module.read_widget_flags()
                self.assertFalse(movie)
                self.assertTrue(comic)
                self.assertIs(raw["movieVisible"], False)

        for script in ("rofi.comic.sh", "rofi.movie.sh"):
            path = ROOT / "Configs/.local/lib/hyde" / script
            subprocess.run(["bash", "-n", str(path)], check=True)
            text = path.read_text()
            self.assertIn("feed)", text)
            self.assertIn("Machine-readable wallpaper-widget feed", text)

    def test_commands_are_fixed_argv(self):
        for _, _, _, actions in self.module.SECTIONS:
            for _, _, command, dependencies in actions:
                self.assertIsInstance(command, tuple)
                self.assertIn(command[0], dependencies)
                self.assertNotIn("sh", command[:1])
                self.assertNotIn("bash", command[:1])


if __name__ == "__main__":
    unittest.main()
