"""Static contract checks for AniDE Quickshell bar and Hyprland screen-framing."""
import json
import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
QS_DIR = ROOT / "Configs/.config/quickshell"


class QuickshellBarTest(unittest.TestCase):
    def test_waybar_configs_are_removed(self):
        self.assertFalse((ROOT / "Configs/.config/waybar").exists())
        self.assertFalse((ROOT / "Configs/.local/share/waybar").exists())
        self.assertFalse((ROOT / "Scripts/dots/waybar.toml").exists())
        self.assertFalse((ROOT / "Configs/.local/share/wallbash/theme/waybar.dcol").exists())

    def test_quickshell_files_and_wallbash_theme(self):
        for filename in ("shell.qml", "Colors.qml", "RoundCorner.qml", "theme.json", "clock_widget.json"):
            file_path = QS_DIR / filename
            share_path = ROOT / "Configs/.local/share/quickshell" / filename
            self.assertTrue(file_path.is_file(), f"missing {filename}")
            self.assertTrue(share_path.is_file(), f"missing share copy {filename}")
            self.assertNotIn("/home/", file_path.read_text())
            self.assertEqual(file_path.read_text(), share_path.read_text())

        colors_qml = (QS_DIR / "Colors.qml").read_text()
        self.assertNotIn("Behavior on barBg", colors_qml)
        self.assertNotIn("property color onErrorColor", colors_qml)
        self.assertNotIn("property color onSecondaryContainer", colors_qml)

        theme_data = json.loads((QS_DIR / "theme.json").read_text())
        for key in (
            "preset",
            "barBg",
            "mainBg",
            "surfaceBg",
            "layer2Bg",
            "mainFg",
            "subFg",
            "actBg",
            "glowColor",
            "glowSecondary",
            "accentSecondary",
            "onSecondaryContainer",
            "actFg",
            "barOpacity",
            "pillOpacity",
            "cornerRadius",
        ):
            self.assertIn(key, theme_data)
        self.assertEqual(theme_data["preset"], "end4-tonal-spot")
        self.assertEqual(theme_data["cornerRadius"], 23)

        for dcol_rel in (
            "Configs/.local/share/wallbash/always/quickshell.dcol",
            "Configs/.local/share/wallbash/theme/quickshell.dcol",
        ):
            dcol_text = (ROOT / dcol_rel).read_text()
            self.assertIn("<wallbash_pry1>", dcol_text)
            self.assertIn("<wallbash_2xa8>", dcol_text)

        shell_qml = (QS_DIR / "shell.qml").read_text()
        for corner in ('"top-left"', '"top-right"', '"bottom-left"', '"bottom-right"'):
            self.assertIn(corner, shell_qml)
        for end4_component in (
            "function cssRgba",
            "function iconForClass",
            "swapUsage",
            "component DreamyMistCanvas",
            "component BarGroup",
            "component CircularResourceRing",
            "component CircleUtilButton",
            "component DesktopClockCanvas",
            "component LisaGlassIcon",
            "component ClippedProgressBar",
            "leftCenterGroup",
            "middleCenterGroup",
            "rightCenterGroup",
            "activeIndicator",
            "caffeineBtn",
            "desktopClockWindow",
            "clockCustomizerPopup",
            "RoundCorner",
            "leftSidebarBtn",
            "rightStatusPill",
            "activeWinClass",
            "activeWinTitle",
            "middleSection",
        ):
            self.assertIn(end4_component, shell_qml)
        self.assertNotIn("WlrLayershell.namespace", shell_qml)
        self.assertNotIn("parent.parent.", shell_qml)
        self.assertNotIn("WheelHandler", shell_qml)

        restore_psv = (ROOT / "Scripts/restore_cfg.psv").read_text()
        self.assertIn("S|${HOME}/.config/quickshell|shell.qml Colors.qml RoundCorner.qml|hyprland", restore_psv)
        self.assertIn("O|${HOME}/.local/share|quickshell|hyprland", restore_psv)

    def test_quickshell_manifest_and_autostart(self):
        manifest = (ROOT / "Scripts/dots/quickshell.toml").read_text()
        self.assertIn('source_root = "Configs/.config/quickshell"', manifest)

        core_group = (ROOT / "Scripts/dots-groups/core.toml").read_text()
        self.assertIn('"../dots/quickshell.toml"', core_group)
        self.assertNotIn('"../dots/waybar.toml"', core_group)

        variables_lua = (ROOT / "Configs/.local/share/hypr/lua/variables.lua").read_text()
        self.assertIn("quickshell.sh --watch", variables_lua)

        qs_script = ROOT / "Configs/.local/lib/hyde/quickshell.sh"
        self.assertTrue(qs_script.is_file())
        subprocess.run(["bash", "-n", str(qs_script)], check=True)

    def test_hyprland_rounding_and_border(self):
        hypr_defaults = (ROOT / "Configs/.local/share/hypr/lua/defaults.lua").read_text()
        self.assertIn("rounding = 16", hypr_defaults)
        self.assertIn("border_size = 2", hypr_defaults)

        hyprland_lua = (ROOT / "Configs/.config/hypr/hyprland.lua").read_text()
        self.assertIn("rounding = 16", hyprland_lua)
        self.assertIn("border_size = 2", hyprland_lua)

    def test_screenshot_and_grimblast_scripts(self):
        grimblast_main = ROOT / "Configs/.local/lib/hyde/grimblast"
        grimblast_sub = ROOT / "Configs/.local/lib/hyde/screenshot/grimblast"
        screenshot_sh = ROOT / "Configs/.local/lib/hyde/screenshot.sh"
        self.assertTrue(grimblast_main.is_file())
        self.assertTrue(grimblast_sub.is_file())
        self.assertEqual(grimblast_main.read_text(), grimblast_sub.read_text())
        for script in (grimblast_main, grimblast_sub, screenshot_sh):
            subprocess.run(["bash", "-n", str(script)], check=True)



if __name__ == "__main__":
    unittest.main()
