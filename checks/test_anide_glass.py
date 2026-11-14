"""Static contract checks for AniDE Quickshell bar and Hyprland screen-framing."""
import os
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
        for filename in (
            "shell.qml",
            "Colors.qml",
            "RoundCorner.qml",
            "LisaGlassIcon.qml",
            "CircleUtilButton.qml",
            "ClippedProgressBar.qml",
            "AniSubPanelFace.qml",
            "theme.json",
            "clock_widget.json",
        ):
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
            "component DesktopClockCanvas",
            "anisubPanelWindow",
            "AniSubPanelFace {",
            "anisubPanelOpen",
            "refreshAnisubFeed",
            "LisaGlassIcon {",
            "CircleUtilButton {",
            "ClippedProgressBar {",
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

        # The icon system lives in file-based components (immune to QML inline
        # component ordering quirks such as "X is not a type"); the remaining
        # inline components must be declared before first use.
        for file_type in (
            "LisaGlassIcon",
            "CircleUtilButton",
            "ClippedProgressBar",
            "AniSubPanelFace",
        ):
            self.assertNotIn(f"component {file_type}", shell_qml)
        decl = shell_qml.index("component DreamyMistCanvas")
        use = shell_qml.index("DreamyMistCanvas {")
        self.assertLess(
            decl,
            use,
            "DreamyMistCanvas is used before its inline component declaration",
        )

        restore_psv = (ROOT / "Scripts/restore_cfg.psv").read_text()
        self.assertIn(
            "S|${HOME}/.config/quickshell|shell.qml Colors.qml RoundCorner.qml LisaGlassIcon.qml CircleUtilButton.qml ClippedProgressBar.qml AniSubPanelFace.qml|hyprland",
            restore_psv,
        )
        self.assertIn("theme.json clock_widget.json|hyprland", restore_psv)
        self.assertIn("O|${HOME}/.local/share|quickshell|hyprland", restore_psv)

    def test_panel_search_is_on_the_panel_not_rofi(self):
        shell_qml = (QS_DIR / "shell.qml").read_text()
        face_qml = (QS_DIR / "AniSubPanelFace.qml").read_text()
        # the panel takes on-demand keyboard focus only (never Exclusive)
        self.assertIn("WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand", shell_qml)
        self.assertNotIn("WlrKeyboardFocus.Exclusive", shell_qml)
        # search runs the machine-readable movie subcommand, never a rofi menu
        self.assertIn('"rofi.movie", "feed-search", q', shell_qml)
        self.assertIn("function anisubPanelSearch(query)", shell_qml)
        self.assertIn("function anisubPanelSearchClear()", shell_qml)
        self.assertIn("signal searchSubmitted(string query)", face_qml)
        self.assertIn("signal searchCleared()", face_qml)
        self.assertIn("Keys.onEscapePressed", face_qml)
        self.assertIn("if (q.length < 2) return;", face_qml)
        # the face runs no process itself; it only emits signals
        self.assertNotIn("Process", face_qml)
        self.assertNotIn('"rofi', face_qml)
        self.assertNotIn("ctx.roundRect(", face_qml)
        # the panel never reaches the comic tool or the old desktop widgets
        self.assertNotIn("rofi.comic", shell_qml)
        self.assertNotIn("anisubComic", shell_qml)

    def test_panel_drops_from_the_top_bar_and_takes_the_bar_palette(self):
        shell_qml = (QS_DIR / "shell.qml").read_text()
        face_qml = (QS_DIR / "AniSubPanelFace.qml").read_text()
        # the card sits under the 38 px bar and slides down when it opens
        self.assertIn("property int anisubPanelTop: 46", shell_qml)
        self.assertIn("shellRoot.anisubPanelTop", shell_qml)
        self.assertIn("Behavior on y", shell_qml)
        self.assertIn("mask: Region {\n                item: anisubPanelFace", shell_qml)
        self.assertIn("modelData === Quickshell.screens[0]", shell_qml)
        # toggled over IPC (`qs ... ipc call anisub toggle`), bound to Win+Shift+M
        self.assertIn('target: "anisub"', shell_qml)
        self.assertIn("function toggle(): void", shell_qml)
        self.assertIn("function open(): void", shell_qml)
        self.assertIn("function close(): void", shell_qml)
        # the face follows the bar palette (no fixed colors besides fallbacks)
        self.assertIn("themePalette: theme", shell_qml)
        self.assertIn("themePalette.barBg", face_qml)
        self.assertIn("themePalette.mainFg", face_qml)
        self.assertIn("function paintCover(ctx, cv, img, src, w, h, r)", face_qml)
        self.assertIn("function nextResult()", face_qml)
        self.assertIn("text: \"Xem\"", face_qml)
        self.assertIn("ListView {", face_qml)
        self.assertIn("model: face.episodes", face_qml)
        self.assertNotIn("Repeater", face_qml.split("ListView {")[1].split("// ── Footer")[0])

    def test_wallpaper_widgets_are_gone(self):
        shell_qml = (QS_DIR / "shell.qml").read_text()
        for gone in ("anisubMovieW", "anisubComicW", "AniSubMovieFace", "AniSubWidgetFace",
                     "anisub_widgets.json", "saveAnisubWidgetsConfig", "clampAnisubW",
                     "applyAnisubWidgetsJson", "anisubMovieVisible"):
            self.assertNotIn(gone, shell_qml, gone)
        for gone_file in ("AniSubMovieFace.qml", "AniSubWidgetFace.qml", "anisub_widgets.json"):
            self.assertFalse((QS_DIR / gone_file).exists(), gone_file)
            self.assertFalse((ROOT / "Configs/.local/share/quickshell" / gone_file).exists(), gone_file)

    def test_win_shift_m_opens_the_panel_not_rofi(self):
        hypr = (ROOT / "Configs/.config/hypr/hyprland.lua").read_text()
        self.assertIn('hyde.config.modifiers.main .. " + SHIFT + M"', hypr)
        self.assertIn('exec_cmd("hyde-shell anisub_panel toggle")', hypr)
        self.assertNotIn("rofi.movie", hypr)
        script = ROOT / "Configs/.local/lib/hyde/anisub_panel.sh"
        self.assertTrue(script.is_file())
        self.assertTrue(os.access(script, os.X_OK))
        text = script.read_text()
        self.assertIn('ipc call anisub "$action"', text)
        self.assertNotIn("hyde-shell rofi", text)
        self.assertNotIn("exec rofi", text)
        proc = subprocess.run(["bash", str(script), "--help"], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("anisub_panel", proc.stdout)

    def test_bar_palette_is_the_wallpaper_green_and_visibly_synced(self):
        theme_data = json.loads((QS_DIR / "theme.json").read_text())
        # the bar is the image-18 green glass (not the old paper/cobalt palette)
        self.assertEqual(theme_data["barBg"], "#6f8f55")
        self.assertEqual(theme_data["mainFg"], "#fdfff7")
        # translucent bar so the wallpaper backdrop shows through the veil
        self.assertLess(theme_data["barOpacity"], 1.0)
        colors_qml = (QS_DIR / "Colors.qml").read_text()
        # sync takes the wallpaper tone itself: no faint 8-14% tint over cobalt
        self.assertNotIn("subtleTint", colors_qml)
        self.assertIn("function syncWallTone(r, g, b)", colors_qml)
        self.assertIn("barBg = t;", colors_qml)
        self.assertIn("function applyJson(raw)", colors_qml)
        shell_qml = (QS_DIR / "shell.qml").read_text()
        self.assertNotIn("subtleTint", shell_qml)
        self.assertIn("theme.syncWallTone(wc.r, wc.g, wc.b);", shell_qml)

    def test_quickshell_manifest_and_autostart(self):
        manifest = (ROOT / "Scripts/dots/quickshell.toml").read_text()
        self.assertIn('source_root = "Configs/.config/quickshell"', manifest)
        # every runtime QML type must be deployed to both launch locations
        for qml_file in (
            "shell.qml",
            "Colors.qml",
            "RoundCorner.qml",
            "LisaGlassIcon.qml",
            "CircleUtilButton.qml",
            "ClippedProgressBar.qml",
            "AniSubPanelFace.qml",
        ):
            self.assertGreaterEqual(manifest.count(f'"{qml_file}"'), 2, qml_file)

        core_group = (ROOT / "Scripts/dots-groups/core.toml").read_text()
        self.assertIn('"../dots/quickshell.toml"', core_group)
        self.assertNotIn('"../dots/waybar.toml"', core_group)

        variables_lua = (ROOT / "Configs/.local/share/hypr/lua/variables.lua").read_text()
        self.assertIn("quickshell.sh --watch", variables_lua)

        qs_script = ROOT / "Configs/.local/lib/hyde/quickshell.sh"
        self.assertTrue(qs_script.is_file())
        subprocess.run(["bash", "-n", str(qs_script)], check=True)

    def test_hyde_manifest_leaves_upstream_grimblast_ownership_alone(self):
        hyde_toml = (ROOT / "Scripts/dots/hyde.toml").read_text()
        # The [grimblast] unit owns ${HOME}/.local/lib/hyde/screenshot/grimblast;
        # if the hyde dot claims the same target, deploy dies with
        # "File conflict ... (owned by grimblast)".
        self.assertIn("[grimblast]", hyde_toml)
        self.assertIn('"hyde/screenshot/grimblast"', hyde_toml)
        lib_sync = hyde_toml.split('source_root = "Configs/.local/lib"', 1)[1]
        self.assertIn(
            'ignored_paths = [".*", "__pycache__", "hyde/screenshot/grimblast", "screenshot/grimblast"]',
            lib_sync.split("[[", 1)[0],
        )

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
