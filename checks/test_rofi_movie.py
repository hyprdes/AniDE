"""Static checks for hyde-shell rofi.movie; a live Rofi/mpv session is still required."""
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from urllib.parse import quote

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Configs/.local/lib/hyde/rofi.movie.sh"
FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures"


def run_bash(source, stdin="", env=None):
    process = subprocess.run(
        ["bash", "-c", source],
        input=stdin,
        capture_output=True,
        text=True,
        cwd=ROOT,
        env=env,
    )
    return process.returncode, process.stdout, process.stderr


class ScriptContractTest(unittest.TestCase):
    def test_syntax_and_shellcheck(self):
        status, _, err = run_bash(f"bash -n {SCRIPT}")
        self.assertEqual(status, 0, err)
        if shutil.which("shellcheck"):
            status, out, err = run_bash(f"shellcheck -x {SCRIPT}")
            self.assertEqual(status, 0, out + err)

    def test_metadata_header(self):
        header = "\n".join(SCRIPT.read_text().splitlines()[:50])
        self.assertIn("# @name: rofi.movie", header)
        self.assertIn("# @ver:", header)
        # hyde-shell completions only discover scripts that declare @name early.
        for line in SCRIPT.read_text().splitlines()[:50]:
            if line.startswith("# @name:"):
                self.assertEqual(line.split(":", 1)[1].strip(), "rofi.movie")
                break

    def test_help_documents_every_subcommand(self):
        _, out, _ = run_bash(f"bash {SCRIPT} -h")
        for command in ("search", "browse", "recent", "history", "play", "link", "open", "settings", "diagnose"):
            self.assertRegex(out, rf"\b{command}\b")

    def test_configuration_is_namespaced(self):
        text = SCRIPT.read_text()
        for key in ("PLAYER", "STYLE", "SCALE", "FONT", "SERVER_PREF", "POSTER", "LIMIT", "DETAIL_TTL"):
            self.assertIn(f"ROFI_MOVIE_{key}", text)
        # Only the XDG/HyDE path plumbing may be exported; settings stay local so
        # they never leak into other hyde-shell wrappers.
        exported = re.findall(r"(?m)^export ([A-Za-z_][A-Za-z0-9_]*)=", text)
        for name in exported:
            self.assertTrue(
                name.startswith(("XDG_", "HYDE_")),
                f"unexpected export {name}",
            )

    def test_no_unsafe_home_paths(self):
        text = SCRIPT.read_text()
        self.assertNotIn("/home/", text)
        self.assertNotIn("rm -rf /", text)


class FixtureParsingTest(unittest.TestCase):
    """jq fixtures copied from the live PhimAPI responses (v1 and legacy shape)."""

    def test_fixtures_are_valid_json(self):
        for path in FIXTURES.glob("*.json"):
            with path.open(encoding="utf-8") as handle:
                json.load(handle)

    def test_rows_are_pipe_safe(self):
        # Row fields are read back with awk -F'|', so names must never add pipes.
        status, out, err = run_bash(
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); movie_rows < {FIXTURES / 'legacy.json'}"
        )
        self.assertEqual(status, 0, err)
        rows = [line for line in out.splitlines() if line]
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(rows[0].split("|")), 5, rows[0])
        self.assertEqual(rows[0].split("|")[2], "phim-cu")

    def test_pagination_matches_both_api_shapes(self):
        source = (
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); "
            f"for f in {FIXTURES / 'category.json'} {FIXTURES / 'legacy.json'}; do "
            'jq -r "$MOVIE_JQ_TOTAL" <"$f" | tr "\\n" " "; '
            'jq -r "$MOVIE_JQ_PAGE" <"$f"; done'
        )
        status, out, err = run_bash(source)
        self.assertEqual(status, 0, err)
        self.assertEqual(out.split(), ["387", "1", "2", "1"])

    def test_empty_category_is_not_an_error(self):
        status, out, _ = run_bash(
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); movie_rows < {FIXTURES / 'empty.json'}"
        )
        self.assertEqual(status, 0)
        self.assertEqual(out.strip(), "")

    def test_servers_and_episodes(self):
        source = (
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); "
            f"json=$(cat {FIXTURES / 'detail.json'}); "
            'movie_servers <<<"$json"; echo ---; movie_episodes "$json" 0'
        )
        status, out, err = run_bash(source)
        self.assertEqual(status, 0, err)
        servers, episodes = out.split("---")
        self.assertIn("0|Vietsub|3", servers)
        self.assertEqual(len([line for line in episodes.splitlines() if line]), 3)
        for line in episodes.splitlines():
            if line:
                self.assertEqual(len(line.split("|")), 3, line)

    def test_server_preference_matching(self):
        source = (
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); "
            f"json=$(cat {FIXTURES / 'detail.json'}); "
            'for pref in auto vietsub thuyet-minh long-tieng; do '
            'printf "%s=" "$pref"; MOVIE_SERVER_PREF=$pref movie_pref_server "$json"; echo; done'
        )
        _, out, err = run_bash(source)
        chosen = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
        self.assertEqual(chosen["auto"], "0")
        self.assertEqual(chosen["vietsub"], "0")
        self.assertEqual(chosen["thuyet-minh"], "1")
        # No matching server falls back to the first one.
        self.assertEqual(chosen["long-tieng"], "0")

    def test_stream_url_prefers_m3u8(self):
        row = "Tập 1|https://cdn/index.m3u8|https://player/?url=x"
        source = (
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); "
            f"movie_stream_url {shlex.quote(row)}"
        )
        status, out, err = run_bash(source)
        self.assertEqual(status, 0, err)
        self.assertEqual(out.strip(), "https://cdn/index.m3u8")

    def test_stream_url_decodes_embed_parameter(self):
        # Some servers only expose the player wrapper; the m3u8 hides in ?url=.
        target = "https://s4.example.tv/x/index.m3u8?token=abc"
        row = f"Tập 1||https://player.example/?url={quote(target, safe='')}"
        source = (
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); "
            f"movie_stream_url {shlex.quote(row)}"
        )
        status, out, err = run_bash(source)
        self.assertEqual(status, 0, err)
        self.assertEqual(out.strip(), target)

    def test_stream_url_rejects_empty_row(self):
        source = f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); movie_stream_url 'Tập 1||'"
        status, _, _ = run_bash(source)
        self.assertEqual(status, 1)


class ConfigWiringTest(unittest.TestCase):
    def test_schema_and_keybind_are_wired(self):
        schema = (ROOT / "Configs/.local/share/hyde/schema/schema.toml").read_text()
        self.assertIn("[properties.rofi.properties.movie]", schema)
        for key in ("player", "style", "scale", "font", "server_pref", "poster", "site_url"):
            self.assertIn(f"[properties.rofi.properties.movie.properties.{key}]", schema)

        generated = (ROOT / "Configs/.local/share/hyde/schema/config.toml").read_text()
        self.assertIn("[rofi.movie]", generated)

        dispatcher = (ROOT / "Configs/.local/share/hypr/lua/hyde/dispatcher.lua").read_text()
        self.assertIn('"rofi.movie"', dispatcher)

        binds = (ROOT / "Configs/.local/share/hypr/lua/key_binds.lua").read_text()
        self.assertIn('MOD .. " + SHIFT + M"', binds)
        # MOD + CONTROL + M stays reserved for window mute.
        self.assertIn('MOD .. "+ CONTROL + M"', binds)

    def test_generated_config_hydrates_the_script(self):
        """[rofi.movie] keys must reach the script as ROFI_MOVIE_* (config.lua)."""
        import tomllib

        schema = tomllib.loads(
            (ROOT / "Configs/.local/share/hyde/schema/config.toml").read_text()
        )
        movie = schema["rofi"]["movie"]
        expected = {
            "player": "ROFI_MOVIE_PLAYER",
            "style": "ROFI_MOVIE_STYLE",
            "scale": "ROFI_MOVIE_SCALE",
            "font": "ROFI_MOVIE_FONT",
            "width": "ROFI_MOVIE_WIDTH",
            "server_pref": "ROFI_MOVIE_SERVER_PREF",
            "poster": "ROFI_MOVIE_POSTER",
            "limit": "ROFI_MOVIE_LIMIT",
            "detail_ttl": "ROFI_MOVIE_DETAIL_TTL",
            "site_url": "ROFI_MOVIE_SITE_URL",
            "api_url": "ROFI_MOVIE_API_URL",
            "cdn_url": "ROFI_MOVIE_CDN_URL",
        }
        self.assertEqual(set(movie), set(expected))
        for key, env in expected.items():
            self.assertEqual(f"ROFI_MOVIE_{key.upper()}", env)

    def test_settings_menu_persists_and_sanitises(self):
        """movie_set_config writes TOML literals; movie_setup_rofi sanitises input."""
        workdir = pathlib.Path(tempfile.mkdtemp())
        try:
            config = workdir / "hyde" / "config.toml"
            config.parent.mkdir()
            config.write_text('[rofi.movie]\nplayer = "vlc"\n\n[rofi.launch]\nstyle = "s1"\n')
            env = {**os.environ, "XDG_CONFIG_HOME": str(workdir)}
            source = (
                f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); "
                'movie_set_config limit 30; movie_set_config font "JetBrainsMono NF"'
            )
            process = subprocess.run(
                ["bash", "-c", source], capture_output=True, text=True, env=env, cwd=ROOT
            )
            self.assertEqual(process.returncode, 0, process.stderr)
            written = tomllib.loads(config.read_text())["rofi"]["movie"]
            self.assertEqual(written["limit"], 30)
            self.assertEqual(written["font"], "JetBrainsMono NF")
            # The untouched key and the following table survive the rewrite.
            self.assertEqual(written["player"], "vlc")
            self.assertEqual(tomllib.loads(config.read_text())["rofi"]["launch"]["style"], "s1")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    def test_invalid_settings_fall_back_to_defaults(self):
        env = {
            **os.environ,
            "ROFI_MOVIE_LIMIT": "999",
            "ROFI_MOVIE_DETAIL_TTL": "abc",
            "ROFI_MOVIE_SERVER_PREF": "bad|value",
            "ROFI_MOVIE_WIDTH": "",
        }
        source = (
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); "
            'printf "%s %s %s %s" "$MOVIE_LIMIT" "$MOVIE_DETAIL_TTL" '
            '"$MOVIE_SERVER_PREF" "$MOVIE_WIDTH"'
        )
        process = subprocess.run(
            ["bash", "-c", source], capture_output=True, text=True, env=env, cwd=ROOT
        )
        self.assertEqual(process.stdout.split(), ["24", "600", "auto", "46em"])


class RofiLegibilityTest(unittest.TestCase):
    """The -mesg line and the row text have to be drawn, not just passed in."""

    THEME = ROOT / "Configs/.local/share/hyde/rofi/themes/movie.rasi"

    def source_env(self, **extra):
        """Environment where SHARE_DIR resolves to the themes in this repo."""
        return {
            **os.environ,
            "XDG_DATA_HOME": str(ROOT / "Configs/.local/share"),
            **extra,
        }

    def sourced(self, body, **extra):
        return run_bash(
            f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); {body}",
            env=self.source_env(**extra),
        )

    def test_movie_theme_puts_message_in_mainbox(self):
        text = self.THEME.read_text()
        mainbox = re.search(r"mainbox\s*\{[^}]*\}", text, re.S)
        self.assertIsNotNone(mainbox)
        self.assertIn('"message"', mainbox.group(0))
        # Without an explicit colour rofi paints the summary dark-on-dark.
        self.assertRegex(text, r"message\s*\{[^}]*text-color:\s*@main-fg")
        self.assertRegex(text, r"textbox\s*\{[^}]*text-color:\s*inherit")
        self.assertRegex(text, r"element-text\s*\{[^}]*text-color:\s*inherit")
        # Posters are attached to the rows, so the layout must ask for icons.
        self.assertRegex(text, r"show-icons:\s*true")
        self.assertRegex(text, r"element-icon\s*\{[^}]*size:")

    def test_default_style_is_the_movie_theme(self):
        status, out, err = self.sourced(
            'movie_setup_rofi; printf "%s\\n%s\\n" "$MOVIE_ROFI_STYLE" "$MOVIE_ROFI_THEME"'
        )
        self.assertEqual(status, 0, err)
        style, theme = out.splitlines()[:2]
        self.assertEqual(style, "movie")
        # Resolved to a real path: rofi's own theme dir may not be linked yet.
        self.assertTrue(theme.endswith("/hyde/rofi/themes/movie.rasi"), theme)
        self.assertTrue(pathlib.Path(theme).is_file(), theme)
        schema = tomllib.loads(
            (ROOT / "Configs/.local/share/hyde/schema/schema.toml").read_text()
        )
        self.assertEqual(
            schema["properties"]["rofi"]["properties"]["movie"]["properties"]["style"][
                "default"
            ],
            "movie",
        )

    def test_message_is_injected_into_other_vertical_layouts(self):
        status, out, err = self.sourced(
            'movie_mesg_override "$XDG_DATA_HOME/hyde/rofi/themes/clipboard.rasi"'
        )
        self.assertEqual(status, 0, err)
        self.assertEqual(
            out.strip(), 'mainbox{children:[ "message" , "wallbox" , "listbox" ];}'
        )

    def test_horizontal_layouts_keep_their_own_children(self):
        # style_1 lays mainbox out horizontally; a message column there would
        # squeeze the list, so it must stay untouched.
        status, out, err = self.sourced(
            'movie_mesg_override "$XDG_DATA_HOME/hyde/rofi/themes/style_1.rasi"'
        )
        self.assertNotEqual(status, 0, out)
        self.assertEqual(out.strip(), "")

    def test_layouts_that_already_place_message_are_left_alone(self):
        """A second message widget makes rofi abort, so never inject one."""
        workdir = pathlib.Path(tempfile.mkdtemp())
        theme = workdir / "nested.rasi"
        theme.write_text(
            "mainbox {\n"
            "    orientation: vertical;\n"
            '    children: [ "listbox" ];\n'
            "}\n"
            "listbox {\n"
            '    children: [ "message", "listview" ];\n'
            "}\n"
        )
        try:
            status, out, err = self.sourced(
                f'movie_mesg_override "{theme}"'
            )
            self.assertNotEqual(status, 0, out)
            self.assertEqual(out.strip(), "")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    def test_movie_rofi_hands_the_overrides_to_rofi(self):
        """End to end: what movie_rofi actually puts on the rofi command line."""
        workdir = pathlib.Path(tempfile.mkdtemp())
        stub = workdir / "rofi"
        stub.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@"\n')
        stub.chmod(0o755)
        try:
            status, out, err = self.sourced(
                'printf "Ten phim|HD|slug|none|movie\\n" | '
                'movie_rofi -dmenu -p "🎬 Phim" -mesg "tóm tắt"',
                PATH=f"{workdir}{os.pathsep}{os.environ['PATH']}",
                ROFI_MOVIE_STYLE="clipboard",
            )
            self.assertEqual(status, 0, err)
            args = out.splitlines()
            self.assertIn(
                'mainbox{children:[ "message" , "wallbox" , "listbox" ];}', args
            )
            joined = " ".join(args)
            self.assertIn("show-icons: true;", joined)
            self.assertIn("textbox{", joined)
            self.assertIn("element-text{vertical-align:0.5;", joined)
            self.assertIn('inputbar{children:[ "prompt" , "entry" ];}', joined)
            self.assertTrue(
                any(arg.endswith("/clipboard.rasi") for arg in args), args
            )
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    def test_movie_pick_uses_literal_pipe_regex_separator(self):
        """Rofi treats -display-column-separator as a GLib PCRE regex: bare '|'
        splits between every UTF-8 character ('Đ\\tả'), whereas '[|]' splits on
        literal pipe characters."""
        workdir = pathlib.Path(tempfile.mkdtemp())
        stub = workdir / "rofi"
        stub.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@"\n')
        stub.chmod(0o755)
        try:
            status, out, err = self.sourced(
                'printf "Đảo Hải Tặc (1999)|Tập 1122 · HD · Vietsub|dao-hai-tac|none|series\\n" | '
                'movie_pick "🎬 Phim" "Mô tả" 10 -no-custom',
                PATH=f"{workdir}{os.pathsep}{os.environ['PATH']}",
            )
            self.assertEqual(status, 0, err)
            args = out.splitlines()
            sep_idx = args.index("-display-column-separator")
            self.assertEqual(args[sep_idx + 1], "[|]")
            col_idx = args.index("-display-columns")
            self.assertEqual(args[col_idx + 1], "1,2")

            # Verify caller-supplied -display-columns 1 replaces the default 1,2
            # (Rofi's find_arg_str reads the first occurrence on the CLI).
            status2, out2, err2 = self.sourced(
                'printf "Tập 1|https://cdn.example/1.m3u8|\\n" | '
                'movie_pick "🎬 Chọn tập" "1 tập" 12 -no-custom -display-columns 1',
                PATH=f"{workdir}{os.pathsep}{os.environ['PATH']}",
            )
            self.assertEqual(status2, 0, err2)
            args2 = out2.splitlines()
            col_indices = [i for i, a in enumerate(args2) if a == "-display-columns"]
            self.assertEqual(len(col_indices), 1, args2)
            self.assertEqual(args2[col_indices[0] + 1], "1")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    def test_movie_theme_has_no_broken_includes_or_unresolved_vars(self):
        text = self.THEME.read_text()
        self.assertNotIn("wallbash.rasi", text)
        self.assertNotIn("@dim-fg", text)

    def test_font_setting_is_sanitised_before_it_reaches_rofi(self):
        status, out, err = self.sourced(
            'movie_setup_rofi; printf "%s" "$MOVIE_FONT_OVERRIDE"',
            ROFI_MOVIE_FONT='"JetBrainsMono Nerd Font" 12',
        )
        self.assertEqual(status, 0, err)
        self.assertEqual(out, '* {font: "JetBrainsMono Nerd Font 10";}')

    def test_menus_carry_no_unrenderable_glyphs(self):
        # Regional-indicator flags and ZWJ sequences have no Linux font, so on
        # Rofi they show up as boxes instead of text.
        status, out, err = self.sourced("movie_countries; movie_genres")
        self.assertEqual(status, 0, err)
        lines = [line for line in out.splitlines() if line]
        self.assertTrue(lines)
        for line in lines:
            self.assertNotIn("\u200d", line, line)
            for char in line:
                self.assertFalse(
                    0x1F1E6 <= ord(char) <= 0x1F1FF, f"flag emoji in {line!r}"
                )


class AppFinderEntryTest(unittest.TestCase):
    """AniSub must be reachable from the SUPER+A application finder."""

    DESKTOP = ROOT / "Configs/.local/share/applications/anide-movie.desktop"

    def test_desktop_entry_starts_the_movie_menu(self):
        text = self.DESKTOP.read_text()
        self.assertIn("[Desktop Entry]", text)
        self.assertIn("Type=Application", text)
        self.assertIn("Exec=hyde-shell rofi.movie", text)
        # drun matches these fields, so the entry is findable in Vietnamese.
        self.assertRegex(text, r"(?im)^Name=.*AniSub")
        keywords = re.search(r"(?im)^Keywords=(.*)$", text).group(1)
        for needle in ("anisub", "phim", "movie", "kkphim"):
            self.assertIn(needle, keywords)
        if shutil.which("desktop-file-validate"):
            status, out, err = run_bash(f"desktop-file-validate {self.DESKTOP}")
            self.assertEqual(status, 0, out + err)

    def test_desktop_entry_is_part_of_the_install(self):
        dots = (ROOT / "Scripts/dots/hyde.toml").read_text()
        paths = [
            line
            for line in dots.splitlines()
            if "anide-settings.desktop" in line and "anide-movie.desktop" in line
        ]
        self.assertEqual(len(paths), 1, dots)
        self.assertRegex(paths[0], r'^paths = \[.*"anide-movie\.desktop".*\]$')

    def test_launcher_styles_replace_fourth_run_tab_with_anisub(self):
        themes_dir = ROOT / "Configs/.local/share/hyde/rofi/themes"
        for idx in (1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12):
            rasi = (themes_dir / f"style_{idx}.rasi").read_text()
            self.assertIn(
                '"drun,filebrowser,window,anisub:rofi.movie.sh --rofi-script"',
                rasi,
                f"style_{idx}.rasi must register anisub as the 4th mode",
            )
            self.assertRegex(
                rasi,
                r'display-anisub:\s*"',
                f"style_{idx}.rasi must set display-anisub icon",
            )

        # style_1.rasi (and side-panel styles 9, 11, 12) must isolate
        # icon-current-entry to the 4th tab (anisub) via [ "wallspacer",
        # "message", "icon-current-entry", "entry" ] with negative spacing so
        # Tabs 1-3 (drun, filebrowser, window, where message is disabled) push
        # icon-current-entry outside inputbar's clip box and leave the wallpaper
        # completely untouched, while Tab 4 (anisub, where \0message\x1f enables
        # message) places icon-current-entry at (0, 0) filling 100% of the panel.
        for idx in (1, 9, 11, 12):
            rasi = (themes_dir / f"style_{idx}.rasi").read_text()
            self.assertRegex(
                rasi,
                r'inputbar\s*\{[^}]*children:\s*\[\s*"wallspacer"\s*,\s*"message"\s*,\s*"icon-current-entry"\s*,\s*"entry"\s*\]',
                f"style_{idx}.rasi must use wallspacer+message+icon-current-entry in inputbar",
            )
            self.assertRegex(
                rasi,
                r"inputbar\s*\{[^}]*padding:\s*0em",
                f"style_{idx}.rasi must set 0em padding on inputbar for edge-to-edge poster",
            )
            self.assertRegex(
                rasi,
                r"entry\s*\{[^}]*enabled:\s*false",
                f"style_{idx}.rasi must keep entry hidden so Tabs 1-3 stay untouched",
            )
            self.assertRegex(
                rasi,
                r"icon-current-entry\s*\{[^}]*enabled:\s*true",
                f"style_{idx}.rasi must enable icon-current-entry for poster preview",
            )
        style_1 = (themes_dir / "style_1.rasi").read_text()
        self.assertRegex(
            style_1,
            r"icon-current-entry\s*\{[^}]*size:\s*33\.2em;",
            "style_1.rasi must size icon-current-entry to the full 33.2em panel width",
        )

    def test_rofi_script_mode_browses_searches_and_plays_in_tab(self):
        workdir = pathlib.Path(tempfile.mkdtemp())
        mpv_log = workdir / "mpv.log"
        mpv_stub = workdir / "mpv"
        mpv_stub.write_text(f'#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "{mpv_log}"\n')
        mpv_stub.chmod(0o755)
        mock_funcs = (
            f"movie_list_json() {{ cat {FIXTURES / 'category.json'}; }}; "
            f"movie_search_json() {{ cat {FIXTURES / 'search.json'}; }}; "
            f"movie_detail_json() {{ cat {FIXTURES / 'detail.json'}; }}; "
            "movie_prefetch_posters() { :; }; "
        )
        base_env = {
            **os.environ,
            "PATH": f"{workdir}{os.pathsep}{os.environ['PATH']}",
            "XDG_CONFIG_HOME": str(workdir / "config"),
            "XDG_STATE_HOME": str(workdir / "state"),
            "XDG_CACHE_HOME": str(workdir / "cache"),
            "ROFI_MOVIE_PLAYER": "mpv",
            "ROFI_MOVIE_POSTER": "false",
        }
        try:
            # 1. Initial call (ROFI_RETV=0) returns home menu immediately with
            #    no network calls, without overriding the mode-switcher icon,
            #    and with every row using entry="\t" + \x1fdisplay\x1f<label>
            #    (and no \x1fpermanent\x1ftrue) so typing any keyword in Rofi
            #    1.7.x yields filtered_lines == 0 and triggers ROFI_RETV=2 ($1).
            rc, out, err = run_bash(
                f"bash {SCRIPT} --rofi-script",
                env={**base_env, "ROFI_RETV": "0"},
            )
            self.assertEqual(rc, 0, err)
            self.assertNotIn("\0prompt\x1f", out)
            self.assertNotIn("\x1fpermanent\x1ftrue", out)
            self.assertIn(
                "\t\0info\x1flist|phim-moi-cap-nhat|1||\x1fdisplay\x1f🆕 Phim mới cập nhật",
                out,
            )
            self.assertIn(
                "\t\0info\x1fsearch_input\x1fdisplay\x1f🔎 Tìm phim (gõ tên phim rồi Enter)…",
                out,
            )

            # 1b. Clicking the search row with empty input opens the in-tab
            #     search prompt instead of spawning a separate Rofi window.
            rc, out, err = run_bash(
                f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); {mock_funcs} movie_script_mode $'\\t'",
                env={
                    **base_env,
                    "ROFI_RETV": "1",
                    "ROFI_INFO": "search_input",
                },
            )
            self.assertEqual(rc, 0, err)
            self.assertIn("\0data\x1fsearch_prompt\n", out)
            self.assertIn(
                "\t\0info\x1fsearch_input\x1fdisplay\x1f🔎 Gõ tên phim vào ô tìm kiếm rồi nhấn Enter…",
                out,
            )

            # 1c. Opening settings stays in-tab and persists changes to config.toml.
            rc, out, err = run_bash(
                f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); {mock_funcs} movie_script_mode $'\\t'",
                env={
                    **base_env,
                    "ROFI_RETV": "1",
                    "ROFI_INFO": "settings",
                },
            )
            self.assertEqual(rc, 0, err)
            self.assertIn("\0data\x1fsettings\n", out)
            self.assertIn(
                "\t\0info\x1fsettings_player\x1fdisplay\x1f▶ Trình phát video: mpv",
                out,
            )

            # 2. Selecting a category row (ROFI_RETV=1) lists movies in-tab.
            rc, out, err = run_bash(
                f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); {mock_funcs} movie_script_mode $'\\t'",
                env={
                    **base_env,
                    "ROFI_RETV": "1",
                    "ROFI_INFO": "list|phim-bo|1||",
                },
            )
            self.assertEqual(rc, 0, err)
            self.assertIn("\0data\x1flist|phim-bo|1||\n", out)
            self.assertIn("Gấp Ánh Trăng (2026)", out)
            self.assertIn("\0info\x1fmovie|gap-anh-trang|Gấp Ánh Trăng (2026)||", out)

            # 3. Typing a keyword and pressing Enter in Rofi 1.7.x / rofi-wayland
            #    invokes the script with ROFI_RETV=2 and $1=<typed keyword> (with
            #    no ROFI_INPUT or ROFI_INFO set), returning search results and
            #    full-bleed poster icons in-tab.
            poster_env = {**base_env, "ROFI_MOVIE_POSTER": "true"}
            poster_mock = (
                f"{mock_funcs} "
                "movie_poster_fetch() { local p; p=$(movie_poster_path \"$1\") && mkdir -p \"$(dirname \"$p\")\" && printf 'PNG' >\"$p\"; }; "
                "movie_prefetch_posters() { local u; while IFS= read -r u; do [[ $u == http* ]] && movie_poster_fetch \"$u\"; done < <(awk -F'|' '{print $4}' <<<\"$1\"); }; "
            )
            rc, out, err = run_bash(
                f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); {poster_mock} movie_script_mode naruto",
                env={
                    **poster_env,
                    "ROFI_RETV": "2",
                    "ROFI_DATA": "menu",
                },
            )
            self.assertEqual(rc, 0, err)
            self.assertIn("Naruto Shippuden (2007)", out)
            self.assertIn("\0info\x1fmovie|naruto-shippuden|Naruto Shippuden (2007)||", out)
            self.assertRegex(out, r"\x1ficon\x1f[^\n]*posters/[^\n]*-full\.png")

            # 4. Selecting a movie lists its episodes and servers in-tab and
            #    attaches the movie poster icon to episode rows so the left
            #    preview panel stays populated.
            rc, out, err = run_bash(
                f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); {poster_mock} movie_script_mode",
                env={
                    **poster_env,
                    "ROFI_RETV": "1",
                    "ROFI_INFO": "movie|naruto-shippuden|Naruto Shippuden (2007)||",
                    "ROFI_DATA": "search|naruto|1",
                },
            )
            self.assertEqual(rc, 0, err)
            self.assertIn("🎬 Tập 001 · Naruto Shippuden (2007) (Vietsub)", out)
            self.assertIn(
                "\0info\x1fplay|naruto-shippuden|Naruto Shippuden (2007)|0|Tập 001",
                out,
            )
            self.assertRegex(out, r"Tập 001[^\n]*\x1ficon\x1f[^\n]*posters/[^\n]*-full\.png")
            self.assertIn("🔉 Đổi nguồn: Thuyết Minh (1 tập)", out)

            # 5. Selecting an episode starts playback in the background and
            #    emits no rows so Rofi closes cleanly.
            rc, out, err = run_bash(
                f"source <(sed '/^main \"\\$@\"$/d' {SCRIPT}); {mock_funcs} movie_script_mode",
                env={
                    **base_env,
                    "ROFI_RETV": "1",
                    "ROFI_INFO": "play|naruto-shippuden|Naruto Shippuden (2007)|0|Tập 001",
                },
            )
            self.assertEqual(rc, 0, err)
            self.assertEqual(out, "")
            for _ in range(30):
                if mpv_log.is_file() and mpv_log.read_text().strip():
                    break
                import time
                time.sleep(0.05)
            self.assertTrue(mpv_log.is_file(), "mpv should have been launched")
            self.assertIn("tap001/index.m3u8", mpv_log.read_text())
        finally:
            shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
