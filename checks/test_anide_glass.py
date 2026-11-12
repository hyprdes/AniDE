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
        for filename in ("shell.qml", "Colors.qml", "RoundCorner.qml", "theme.json"):
            file_path = QS_DIR / filename
            self.assertTrue(file_path.is_file(), f"missing {filename}")
            self.assertNotIn("/home/", file_path.read_text())

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
        self.assertEqual(theme_data["preset"], "wallbash-glass")
        self.assertLessEqual(theme_data["barOpacity"], 0.35)
        self.assertLessEqual(theme_data["pillOpacity"], 0.55)
        self.assertEqual(theme_data["cornerRadius"], 24)

        for dcol_rel in (
            "Configs/.local/share/wallbash/always/quickshell.dcol",
            "Configs/.local/share/wallbash/theme/quickshell.dcol",
        ):
            dcol_text = (ROOT / dcol_rel).read_text()
            self.assertIn("<wallbash_pry1>", dcol_text)
            self.assertIn("<wallbash_3xa7>", dcol_text)

        shell_qml = (QS_DIR / "shell.qml").read_text()
        for corner in ('"top-left"', '"top-right"', '"bottom-left"', '"bottom-right"'):
            self.assertIn(corner, shell_qml)
        for end4_component in (
            "function cssRgba",
            "wallBlurUrl",
            "component DreamyMistCanvas",
            "component BarGroup",
            "component CircularResourceRing",
            "component CircleUtilButton",
            "leftCenterGroup",
            "middleCenterGroup",
            "rightCenterGroup",
            "activeIndicator",
            "RoundCorner",
        ):
            self.assertIn(end4_component, shell_qml)

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


if __name__ == "__main__":
    unittest.main()
