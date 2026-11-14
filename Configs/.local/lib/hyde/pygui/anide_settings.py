#!/usr/bin/env python3
"""AniDE Settings: a lightweight front door to the existing desktop tools.

UI follows the image-14 dashboard mockup: a bold white-framed dark window,
white pill top bar, left rail with the bottom dot, grey media tiles with
image glyphs and white "Open" pills, a skeleton-lines panel and a card
stack. Colors sync with the wallpaper through the HyDE wallbash palette
(~/.cache/hyde/wall.dcol, wallbash/shell-colors) and the wallpaper image.
Original implementation inspired by the settings UX of SekaiPop and
end-4/dots-hyprland. GPL-3.0-or-later; see CREDITS.md.
"""
import os
from pathlib import Path
import re
import shutil
import sys

from PyQt6 import QtCore, QtGui, QtWidgets

SECTIONS = (
    ("Widget", "\u25a6", "AniSub panel", (
        ("AniSub panel", "Win+Shift+M drops the AniSub panel under the top bar: search and play KKPhim movies without Rofi.", ("hyde-shell", "anisub_panel", "toggle"), ("hyde-shell", "curl", "jq", "mpv")),
    )),
    ("Appearance", "◈", "Make the desktop yours", (
        ("Curated themes", "Choose a theme and apply its Wallbash colors across your desktop.", ("hyde-shell", "app", "-t", "scope", "--", "theme.select.sh"), ("hyde-shell", "rofi")),
        ("Wallpaper", "Pick a wallpaper using the existing HyDE selector.", ("hyde-shell", "wallpaper", "--select", "--global"), ("hyde-shell", "rofi")),
        ("GTK appearance", "Change GTK themes, icons and fonts with nwg-look.", ("nwg-look",), ("nwg-look",)),
        ("Qt appearance", "Open the Qt 6 appearance tool.", ("qt6ct",), ("qt6ct",)),
    )),
    ("Bar & menus", "▤", "Shape your workspace", (
        ("Quickshell reload", "Reload the Quickshell top bar and refresh Wallbash colors.", ("hyde-shell", "quickshell", "--reload"), ("hyde-shell",)),
        ("Quickshell toggle", "Show or hide the Quickshell top bar.", ("hyde-shell", "quickshell", "--hide"), ("hyde-shell",)),
        ("Keyboard shortcuts", "See the current keybind hints.", ("hyde-shell", "keybinds_hint"), ("hyde-shell", "rofi")),
    )),
    ("Motion & effects", "✦", "Tune the atmosphere", (
        ("Workflows", "Choose a workflow preset for your session.", ("hyde-shell", "workflows", "--select"), ("hyde-shell", "rofi")),
        ("Shaders", "Choose a screen shader, or disable it in the selector.", ("hyde-shell", "shaders", "--select"), ("hyde-shell", "rofi")),
        ("Night light", "Toggle the existing Hyprsunset night-light control.", ("hyde-shell", "hyprsunset", "--toggle"), ("hyde-shell", "hyprctl")),
    )),
    ("Media", "▶", "Watch something tonight", (
        ("Movies (KKPhim)", "Search, browse and play movies from KKPhim without leaving Rofi.", ("hyde-shell", "rofi.movie"), ("hyde-shell", "rofi", "mpv", "curl", "jq")),
        ("Movie history", "Continue a movie you watched before, or clear the local history.", ("hyde-shell", "rofi.movie", "history"), ("hyde-shell", "rofi", "mpv")),
        ("Movie settings", "Pick the player, Rofi style, subtitle preference and cache options.", ("hyde-shell", "rofi.movie", "settings"), ("hyde-shell", "rofi")),
    )),
    ("System", "⚙", "Your desktop essentials", (
        ("Lock screen", "Choose an existing Hyprlock preset.", ("hyde-shell", "lockscreen", "--select"), ("hyde-shell", "rofi")),
        ("Vietnamese input", "Unikey is registered for you at login; change engines, Telex/VNI and the switch key here.", ("ibus-setup",), ("ibus-setup",)),
        ("Register Unikey again", "Add the Vietnamese engine back to IBus, for example after removing it or installing ibus-unikey later.", ("hyde-shell", "ibus-start", "--seed", "--force"), ("hyde-shell",)),
        ("Audio", "Open the system audio mixer.", ("pavucontrol",), ("pavucontrol",)),
        ("Network", "Open NetworkManager connection settings.", ("nm-connection-editor",), ("nm-connection-editor",)),
        ("Bluetooth", "Open Bluetooth Manager.", ("blueman-manager",), ("blueman-manager",)),
    )),
)


def theme_colors(path):
    """Read only simple hex colors; never execute or interpolate theme contents."""
    colors = {}
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return colors
    for name, value in re.findall(r"(?m)^\s*@define-color\s+(main-bg|main-fg|wb-act-bg|wb-act-fg)\s+(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})\s*;", text):
        colors[name] = value
    json_map = {"mainBg": "main-bg", "mainFg": "main-fg", "actBg": "wb-act-bg", "actFg": "wb-act-fg"}
    for key, value in re.findall(r'"(mainBg|mainFg|actBg|actFg)"\s*:\s*"(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})"', text):
        colors[json_map[key]] = value
    return colors


# ---------------------------------------------------------------------------
# image-14 dashboard design helpers (wallpaper-synced monochrome greys)
# ---------------------------------------------------------------------------

def blend_hex(base_hex, tint, amount):
    """Mix base_hex toward the tint color by amount (0..1)."""
    base = QtGui.QColor(base_hex)
    if tint is None:
        return base.name()
    out = QtGui.QColor(
        round(base.red() + (tint.red() - base.red()) * amount),
        round(base.green() + (tint.green() - base.green()) * amount),
        round(base.blue() + (tint.blue() - base.blue()) * amount),
    )
    return out.name()


def wallpaper_tint():
    """Dominant wallpaper color from the HyDE pipeline, or None.

    Sources, in order of trust: the wallbash palette HyDE regenerates on every
    wallpaper change (~/.cache/hyde/wall.dcol or wallbash/shell-colors - the
    colors that feed ./config/hyde's wallbash themes), the wallpaper image
    itself (wall.blur / wall.set), and the quickshell theme.json bar color.
    """
    candidates = []
    cache = Path(os.environ.get("XDG_CACHE_HOME", "") or Path.home() / ".cache") / "hyde"
    for name in ("wall.dcol", "wallbash/shell-colors"):
        try:
            text = (cache / name).read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        match = re.search(r"(?:dcol_pry1|wallbash_pry1)=[\"']?(#[0-9a-fA-F]{6})", text)
        if match:
            candidates.append(QtGui.QColor(match.group(1)))
    for name in ("wall.blur", "wall.set"):
        path = cache / name
        if path.exists() or path.is_symlink():
            pixmap = QtGui.QPixmap(os.path.realpath(path))
            if not pixmap.isNull():
                tiny = pixmap.scaled(1, 1, QtCore.Qt.AspectRatioMode.IgnoreAspectRatio,
                                     QtCore.Qt.TransformationMode.SmoothTransformation)
                candidates.append(tiny.toImage().pixelColor(0, 0))
    try:
        text = (Path(os.environ.get("XDG_CONFIG_HOME", "") or Path.home() / ".config")
                / "quickshell" / "theme.json").read_text(encoding="utf-8", errors="replace")
        match = re.search(r'"barBg"\s*:\s*"(#[0-9a-fA-F]{6})"', text)
        if match:
            candidates.append(QtGui.QColor(match.group(1)))
    except OSError:
        pass
    if not candidates:
        return None
    return QtGui.QColor(
        round(sum(c.red() for c in candidates) / len(candidates)),
        round(sum(c.green() for c in candidates) / len(candidates)),
        round(sum(c.blue() for c in candidates) / len(candidates)),
    )


def settings_palette():
    tint = wallpaper_tint()
    return {
        "frame": blend_hex("#f4f4f2", tint, 0.10),
        "bg": blend_hex("#2f2f2f", tint, 0.16),
        "card": blend_hex("#a9a9a9", tint, 0.18),
        "panel": blend_hex("#3b3b3b", tint, 0.16),
    }


def draw_image_glyph(painter, rect, color):
    """The mockup's image placeholder: rounded frame + sun + mountain."""
    painter.save()
    painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
    w, h = rect.width(), rect.height()
    cx, cy = rect.center().x(), rect.center().y()
    icon_w = w * 0.62
    icon_h = icon_w * 0.78
    frame = QtCore.QRectF(cx - icon_w / 2, cy - icon_h / 2, icon_w, icon_h)
    painter.setPen(QtGui.QPen(color, max(2.0, icon_w * 0.055)))
    painter.setBrush(QtCore.Qt.BrushStyle.NoBrush)
    painter.drawRoundedRect(frame, icon_w * 0.16, icon_w * 0.16)
    painter.setPen(QtCore.Qt.PenStyle.NoPen)
    painter.setBrush(color)
    painter.drawEllipse(QtCore.QRectF(frame.left() + icon_w * 0.17, frame.top() + icon_h * 0.14,
                                      icon_w * 0.17, icon_w * 0.17))
    mountain = QtGui.QPainterPath()
    mountain.moveTo(frame.left() + icon_w * 0.12, frame.bottom() - icon_h * 0.14)
    mountain.lineTo(frame.left() + icon_w * 0.42, frame.top() + icon_h * 0.40)
    mountain.lineTo(frame.left() + icon_w * 0.60, frame.top() + icon_h * 0.62)
    mountain.lineTo(frame.left() + icon_w * 0.72, frame.top() + icon_h * 0.48)
    mountain.lineTo(frame.right() - icon_w * 0.10, frame.bottom() - icon_h * 0.14)
    mountain.closeSubpath()
    painter.drawPath(mountain)
    painter.restore()


class GlyphLabel(QtWidgets.QWidget):
    """Image-placeholder glyph, the mockup's card icon."""

    def __init__(self, color, size=64, parent=None):
        super().__init__(parent)
        self._color = QtGui.QColor(color)
        self._size = size
        self.setFixedSize(size, size)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        draw_image_glyph(painter, QtCore.QRectF(self.rect()), self._color)


class RootPanel(QtWidgets.QWidget):
    """Bold white frame around the dark interior (image-14 signature)."""

    def __init__(self, parent=None, **kwargs):
        super().__init__(parent, **kwargs)
        self.frame_color = QtGui.QColor("#f4f4f2")
        self.bg_color = QtGui.QColor("#2f2f2f")

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        outer = QtCore.QRectF(self.rect()).adjusted(1, 1, -1, -1)
        painter.setPen(QtCore.Qt.PenStyle.NoPen)
        painter.setBrush(self.frame_color)
        painter.drawRoundedRect(outer, 30, 30)
        inner = outer.adjusted(7, 7, -7, -7)
        painter.setBrush(self.bg_color)
        painter.drawRoundedRect(inner, 24, 24)


class DragBar(QtWidgets.QWidget):
    """Header strip that drags the frameless window."""

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.MouseButton.LeftButton:
            handle = self.window().windowHandle()
            if handle is not None and hasattr(handle, "startSystemMove"):
                handle.startSystemMove()
        super().mousePressEvent(event)


class CardStack(QtWidgets.QWidget):
    """The stacked-cards widget from the mockup (decorative)."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(128, 112)
        self._layers = ("#9d9d9d", "#949494", "#8a8a8a")

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        offsets = ((22, 2), (11, 11), (0, 20))
        for (dx, dy), color in zip(offsets, self._layers):
            rect = QtCore.QRectF(dx, dy, 88, 88)
            painter.setPen(QtGui.QPen(QtGui.QColor(255, 255, 255, 30), 1))
            painter.setBrush(QtGui.QColor(color))
            painter.drawRoundedRect(rect, 14, 14)


class ActionTile(QtWidgets.QFrame):
    """Grey media tile: caption, image glyph, white Open pill (image-14)."""

    def __init__(self, caption, parent=None):
        super().__init__(parent)
        self.setObjectName("tile")
        self.setMinimumHeight(150)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(14, 12, 14, 12)
        layout.setSpacing(6)
        layout.addWidget(QtWidgets.QLabel(caption, objectName="tileCaption"),
                         0, QtCore.Qt.AlignmentFlag.AlignLeft)
        layout.addStretch()
        glyph_row = QtWidgets.QHBoxLayout()
        glyph_row.addStretch()
        glyph_row.addWidget(GlyphLabel("#3c3c3c", 62))
        glyph_row.addStretch()
        layout.addLayout(glyph_row)
        layout.addStretch()


class LinesPanel(QtWidgets.QFrame):
    """Dark skeleton-lines panel with the white dot (image-14)."""

    def __init__(self, subtitle, parent=None):
        super().__init__(parent)
        self.setObjectName("linesPanel")
        self.setMinimumHeight(136)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(18, 16, 18, 16)
        layout.setSpacing(8)
        top = QtWidgets.QHBoxLayout()
        top.addStretch()
        dot = QtWidgets.QLabel(objectName="panelDot")
        dot.setFixedSize(22, 22)
        top.addWidget(dot)
        layout.addLayout(top)
        for width in (190, 148, 96):
            bar = QtWidgets.QLabel(objectName="skeletonBar")
            bar.setFixedSize(width, 10)
            layout.addWidget(bar, 0, QtCore.Qt.AlignmentFlag.AlignLeft)
        layout.addStretch()
        label = QtWidgets.QLabel(subtitle, objectName="subtitle")
        label.setWordWrap(True)
        layout.addWidget(label)


def apply_theme(app):
    """Apply the image-14 dashboard styling (wallpaper-synced greys)."""
    pal = settings_palette()
    app.setStyleSheet(f"""
        QWidget#root {{ background: transparent; }}
        QWidget {{ color: #e9e9e9; font-size: 13px; }}
        QLabel#titlePill {{
            background: {pal["frame"]}; color: #2b2b2b; border-radius: 15px;
            padding: 5px 16px; font-weight: 700;
        }}
        QFrame#searchPill {{ background: {pal["frame"]}; border-radius: 15px; }}
        QLineEdit#searchEdit {{
            background: transparent; border: none; color: #2b2b2b;
            padding: 3px 12px; font-weight: 600;
        }}
        QPushButton#roundBtn {{
            background: {pal["frame"]}; border: none; border-radius: 16px;
            color: #2b2b2b; font-size: 13px; font-weight: 700;
        }}
        QPushButton#roundBtn:hover {{ background: #ffffff; }}
        QFrame#rail {{ background: {pal["panel"]}; border: none; border-radius: 26px; }}
        QPushButton#nav {{
            background: rgba(255, 255, 255, 18); color: #dddddd; border: none;
            border-radius: 12px; padding: 8px; font-size: 15px;
        }}
        QPushButton#nav:hover {{ background: rgba(255, 255, 255, 36); }}
        QPushButton#nav:checked {{ background: {pal["frame"]}; color: #2b2b2b; }}
        QLabel#railDot {{ background: {pal["frame"]}; border-radius: 18px; }}
        QFrame#tile {{ background: {pal["card"]}; border: none; border-radius: 16px; }}
        QFrame#rowsCard {{ background: {pal["card"]}; border: none; border-radius: 16px; }}
        QFrame#linesPanel {{ background: {pal["panel"]}; border: none; border-radius: 16px; }}
        QLabel#tileCaption {{ color: #262626; font-size: 11px; font-weight: 700; }}
        QLabel#heroPill {{
            background: #ffffff; color: #262626; border-radius: 12px;
            padding: 5px 14px; font-weight: 700;
        }}
        QLabel#panelDot {{ background: #f4f4f2; border-radius: 11px; }}
        QLabel#skeletonBar {{ background: #f0f0f0; border-radius: 5px; }}
        QLabel#subtitle {{ color: #b9b9b9; font-size: 12px; }}
        QLabel#rowTitle {{ color: #262626; font-size: 13px; font-weight: 700; }}
        QLabel#rowDesc {{ color: #454545; font-size: 11px; }}
        QLabel#status {{ color: #8f8f8f; font-size: 11px; }}
        QPushButton#open {{
            background: #ffffff; color: #262626; border: none;
            border-radius: 12px; padding: 6px 14px; font-weight: 700;
        }}
        QPushButton#open:hover {{ background: #e9e9e9; }}
        QPushButton#open:disabled {{ color: #9a9a9a; background: #d6d6d6; }}
        QPushButton#toggle {{
            background: {pal["frame"]}; color: #262626; border: none;
            border-radius: 11px; padding: 5px 16px; font-weight: 700; font-size: 11px;
        }}
        QPushButton#toggle:checked {{ background: #ffffff; color: #262626; }}
        QPushButton#toggle:hover {{ border: 1px solid rgba(38, 38, 38, 60); }}
        QScrollArea#pageScroll {{ border: none; background: transparent; }}
        QScrollArea {{ border: none; background: transparent; }}
        QWidget#page {{ background: transparent; }}
        QScrollBar:vertical {{ background: transparent; width: 8px; margin: 2px; }}
        QScrollBar::handle:vertical {{
            background: rgba(255, 255, 255, 60); border-radius: 4px; min-height: 26px;
        }}
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{ height: 0; }}
        QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{ background: transparent; }}
    """)


class SettingsWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("AniDE Settings")
        self.resize(980, 700)
        self.setMinimumSize(720, 500)
        self.setWindowFlags(self.windowFlags() | QtCore.Qt.WindowType.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.cards = []
        root = RootPanel(objectName="root")
        self.setCentralWidget(root)
        pal = settings_palette()
        root.frame_color = QtGui.QColor(pal["frame"])
        root.bg_color = QtGui.QColor(pal["bg"])
        shadow = QtWidgets.QGraphicsDropShadowEffect(root)
        shadow.setBlurRadius(44)
        shadow.setOffset(0, 14)
        shadow.setColor(QtGui.QColor(0, 0, 0, 160))
        root.setGraphicsEffect(shadow)
        outer = QtWidgets.QVBoxLayout(root)
        outer.setContentsMargins(30, 26, 30, 28)
        outer.setSpacing(14)

        # ── Top bar: section pill, search pill, star + close circles ──
        header = DragBar()
        header.setFixedHeight(40)
        header_row = QtWidgets.QHBoxLayout(header)
        header_row.setContentsMargins(0, 0, 0, 0)
        header_row.setSpacing(10)
        self.titlePill = QtWidgets.QLabel(SECTIONS[0][0], objectName="titlePill")
        header_row.addWidget(self.titlePill)
        header_row.addStretch()
        search_pill = QtWidgets.QFrame(objectName="searchPill")
        search_pill.setFixedSize(240, 32)
        search_row = QtWidgets.QHBoxLayout(search_pill)
        search_row.setContentsMargins(2, 2, 2, 2)
        self.search = QtWidgets.QLineEdit(objectName="searchEdit")
        self.search.setPlaceholderText("Search…")
        self.search.textChanged.connect(self.filter_cards)
        search_row.addWidget(self.search)
        header_row.addWidget(search_pill)
        self.starBtn = QtWidgets.QPushButton("★", objectName="roundBtn")
        self.starBtn.setFixedSize(32, 32)
        self.starBtn.setToolTip("Widgets")
        self.starBtn.clicked.connect(lambda: self.buttons.button(0).click())
        header_row.addWidget(self.starBtn)
        self.closeBtn = QtWidgets.QPushButton("\u2715", objectName="roundBtn")
        self.closeBtn.setFixedSize(32, 32)
        self.closeBtn.setToolTip("Close (Esc)")
        self.closeBtn.clicked.connect(self.close)
        header_row.addWidget(self.closeBtn)
        outer.addWidget(header)
        escape = QtGui.QShortcut(QtGui.QKeySequence("Esc"), self)
        escape.activated.connect(self.close)

        # ── Body: left rail (sections + bottom dot) + content stack ──
        body = QtWidgets.QHBoxLayout()
        body.setSpacing(14)
        rail = QtWidgets.QFrame(objectName="rail")
        rail.setFixedWidth(66)
        rail_layout = QtWidgets.QVBoxLayout(rail)
        rail_layout.setContentsMargins(10, 14, 10, 14)
        rail_layout.setSpacing(8)
        self.buttons = QtWidgets.QButtonGroup(self)
        self.buttons.setExclusive(True)
        self.stack = QtWidgets.QStackedWidget()
        for index, (title, icon, subtitle, actions) in enumerate(SECTIONS):
            button = QtWidgets.QPushButton(icon, objectName="nav")
            button.setCheckable(True)
            button.setFixedSize(46, 38)
            button.setToolTip(title)
            self.buttons.addButton(button, index)
            rail_layout.addWidget(button)
            self.stack.addWidget(self.make_page(title, subtitle, actions))
        self.buttons.idClicked.connect(self.select_section)
        self.buttons.button(0).setChecked(True)
        rail_layout.addStretch()
        rail_dot = QtWidgets.QLabel(objectName="railDot")
        rail_dot.setFixedSize(36, 36)
        rail_dot.setToolTip("AniDE")
        rail_layout.addWidget(rail_dot, 0, QtCore.Qt.AlignmentFlag.AlignHCenter)
        body.addWidget(rail)

        content = QtWidgets.QVBoxLayout()
        content.setSpacing(10)
        page_scroll = QtWidgets.QScrollArea(objectName="pageScroll")
        page_scroll.setWidgetResizable(True)
        page_scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        page_scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        page_scroll.setWidget(self.stack)
        content.addWidget(page_scroll, 1)
        self.status = QtWidgets.QLabel("Changes are made by the selected desktop tool.", objectName="status")
        self.status.setWordWrap(True)
        content.addWidget(self.status)
        body.addLayout(content, 1)
        outer.addLayout(body, 1)

    def make_page(self, title, subtitle, actions):
        page = QtWidgets.QWidget(objectName="page")
        layout = QtWidgets.QVBoxLayout(page)
        layout.setContentsMargins(2, 2, 2, 2)
        layout.setSpacing(12)

        # Row 1: media tiles for the first three actions
        tiles_row = QtWidgets.QHBoxLayout()
        tiles_row.setSpacing(12)
        for name, description, command, dependencies in actions[:3]:
            tile = ActionTile(name)
            open_button = self.make_open_button(name, command, dependencies)
            tile.layout().addWidget(open_button, 0, QtCore.Qt.AlignmentFlag.AlignLeft)
            tiles_row.addWidget(tile, 1)
            self.cards.append((tile, (name + " " + description).casefold()))
        layout.addLayout(tiles_row)

        # Row 2: hero card + skeleton panel + card stack
        hero_row = QtWidgets.QHBoxLayout()
        hero_row.setSpacing(12)
        hero = QtWidgets.QFrame(objectName="tile")
        hero.setMinimumHeight(200)
        hero_layout = QtWidgets.QVBoxLayout(hero)
        hero_layout.setContentsMargins(18, 16, 18, 16)
        hero_layout.addStretch()
        glyph_row = QtWidgets.QHBoxLayout()
        glyph_row.addStretch()
        glyph_row.addWidget(GlyphLabel("#3c3c3c", 110))
        glyph_row.addStretch()
        hero_layout.addLayout(glyph_row)
        hero_layout.addStretch()
        hero_layout.addWidget(QtWidgets.QLabel(title, objectName="heroPill"),
                              0, QtCore.Qt.AlignmentFlag.AlignLeft)
        hero_row.addWidget(hero, 3)
        right = QtWidgets.QVBoxLayout()
        right.setSpacing(12)
        panel = LinesPanel(subtitle)
        right.addWidget(panel, 1)
        right.addWidget(CardStack(), 0, QtCore.Qt.AlignmentFlag.AlignRight)
        hero_row.addLayout(right, 2)
        layout.addLayout(hero_row)

        # Row 3: remaining actions as compact rows with white Open pills
        rest = actions[3:]
        if rest:
            rows_card = QtWidgets.QFrame(objectName="rowsCard")
            rows_layout = QtWidgets.QVBoxLayout(rows_card)
            rows_layout.setContentsMargins(18, 12, 18, 12)
            rows_layout.setSpacing(8)
            for name, description, command, dependencies in rest:
                row = QtWidgets.QHBoxLayout()
                row.setSpacing(12)
                text = QtWidgets.QVBoxLayout()
                text.addWidget(QtWidgets.QLabel(name, objectName="rowTitle"))
                text.addWidget(QtWidgets.QLabel(description, objectName="rowDesc"))
                row.addLayout(text, 1)
                row.addWidget(self.make_open_button(name, command, dependencies))
                holder = QtWidgets.QWidget()
                holder.setLayout(row)
                rows_layout.addWidget(holder)
                self.cards.append((holder, (name + " " + description).casefold()))
            layout.addWidget(rows_card)

        layout.addStretch()
        return page

    def make_open_button(self, name, command, dependencies):
        button = QtWidgets.QPushButton("Open  \u2197", objectName="open")
        missing = [dep for dep in dependencies if not shutil.which(dep)]
        if missing:
            button.setEnabled(False)
            button.setToolTip("Missing: " + ", ".join(missing))
        else:
            button.clicked.connect(lambda checked=False, argv=command, label=name: self.launch(argv, label))
        return button

    def select_section(self, index):
        self.stack.setCurrentIndex(index)
        self.search.clear()
        self.titlePill.setText(SECTIONS[index][0])
        self.buttons.button(index).setChecked(True)

    def filter_cards(self, text):
        query = text.strip().casefold()
        for card, words in self.cards:
            card.setVisible(not query or query in words)

    def launch(self, command, label):
        started, _pid = QtCore.QProcess.startDetached(command[0], list(command[1:]))
        if started:
            self.status.setText(f"Opened {label}. The selected tool manages its own changes.")
        else:
            self.status.setText(f"Could not start {label}. Check that {command[0]} is installed.")


def main():
    app = QtWidgets.QApplication(sys.argv)
    app.setApplicationName("AniDE Settings")
    apply_theme(app)
    window = SettingsWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
