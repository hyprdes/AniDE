"""Static contract checks; a real GTK/Waybar session is still required."""
import ast
import glob
import json
import os
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
STYLE = ROOT / "Configs/.local/share/waybar/styles/anide-glass.css"


class GlassStyleTest(unittest.TestCase):
    def test_inherits_existing_styles_and_theme(self):
        css = STYLE.read_text()
        self.assertIn('@import "defaults.css";', css)
        for token in ("@main-bg", "@main-fg", "@wb-act-bg", "@wb-act-fg", "@wb-hvr-bg", "@wb-hvr-fg"):
            self.assertIn(token, css)
        self.assertNotIn('/home/', css)

    def test_style_is_in_existing_sync_tree(self):
        manifest = (ROOT / "Scripts/dots/waybar.toml").read_text()
        self.assertIn('source_root = "Configs/.local/share/waybar"', manifest)
        self.assertIn('"styles"', manifest)

    def test_layout_structure_and_no_unknown_groups(self):
        path = ROOT / "Configs/.local/share/waybar/layouts/anide-glass.jsonc"
        layout = json.loads(path.read_text())
        groups = set(layout["modules-left"] + layout["modules-center"] + layout["modules-right"])
        self.assertEqual(groups, {"group/pill#navigation", "group/pill#center", "group/pill#system"})
        for group in groups:
            self.assertTrue(layout[group]["modules"])
        self.assertEqual(layout["include"], ["$XDG_CONFIG_HOME/waybar/includes/includes.json"])
        self.assertEqual(layout["position"], "top")
        self.assertEqual(layout["margin-top"], 0)
        self.assertEqual(layout["margin-left"], 0)
        self.assertEqual(layout["margin-right"], 0)
        self.assertNotIn("/home/", path.read_text())

    def test_top_edge_flush_bar_and_hyprland_rounding(self):
        defaults_css = (ROOT / "Configs/.local/share/waybar/styles/defaults.css").read_text()
        self.assertIn("margin-top: 0px;", defaults_css)
        self.assertIn("margin-left: 0px;", defaults_css)
        self.assertIn("margin-right: 0px;", defaults_css)
        self.assertIn("background-color: @main-bg;", defaults_css)

        hypr_defaults = (ROOT / "Configs/.local/share/hypr/lua/defaults.lua").read_text()
        self.assertIn("rounding = 16", hypr_defaults)
        self.assertIn("border_size = 2", hypr_defaults)

        hyprland_lua = (ROOT / "Configs/.config/hypr/hyprland.lua").read_text()
        self.assertIn("rounding = 16", hyprland_lua)
        self.assertIn("border_size = 2", hyprland_lua)

    def test_quickshell_replaces_waybar_autostart(self):
        qs_dir = ROOT / "Configs/.config/quickshell"
        for filename in ("shell.qml", "Colors.qml", "RoundCorner.qml", "theme.json"):
            file_path = qs_dir / filename
            self.assertTrue(file_path.is_file(), f"missing {filename}")
            self.assertNotIn("/home/", file_path.read_text())

        theme_data = json.loads((qs_dir / "theme.json").read_text())
        self.assertEqual(theme_data["cornerRadius"], 16)

        variables_lua = (ROOT / "Configs/.local/share/hypr/lua/variables.lua").read_text()
        self.assertIn("quickshell.sh --watch", variables_lua)

        core_group = (ROOT / "Scripts/dots-groups/core.toml").read_text()
        self.assertIn('"../dots/quickshell.toml"', core_group)

    def test_layout_resolves_matching_style_and_user_override(self):
        # Exercise the production resolver without importing Waybar's desktop dependencies.
        source = (ROOT / "Configs/.local/lib/hyde/waybar.py").read_text()
        tree = ast.parse(source)
        function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "resolve_style_path")
        module = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
        class Logger:
            def debug(self, *args): pass
            def warning(self, *args): pass
        with tempfile.TemporaryDirectory() as tmp:
            user = pathlib.Path(tmp) / "user"
            user.mkdir()
            shared = STYLE.parent
            scope = {"os": os, "glob": glob, "STYLE_DIRS": [str(user), str(shared)], "logger": Logger()}
            exec(compile(module, "waybar.py", "exec"), scope)
            resolve = scope["resolve_style_path"]
            layout = str(ROOT / "Configs/.local/share/waybar/layouts/anide-glass.jsonc")
            self.assertEqual(resolve(layout), str(STYLE))
            override = user / "anide-glass.css"
            override.touch()
            self.assertEqual(resolve(layout), str(override))


if __name__ == "__main__":
    unittest.main()
