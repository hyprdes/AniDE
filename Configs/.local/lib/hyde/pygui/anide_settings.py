#!/usr/bin/env python3
"""AniDE Settings: a lightweight front door to the existing desktop tools.

UI follows the glass window mockup (image-12): a frameless dark glass panel
with a pill header, cascading sidebar buttons, a chamfered hero preview with
a toggle, and a chamfered profile card. Original implementation inspired by
the settings UX of SekaiPop and end-4/dots-hyprland. GPL-3.0-or-later; see
CREDITS.md.
"""
import getpass
import os
from pathlib import Path
import re
import shutil
import socket
import sys

from PyQt6 import QtCore, QtGui, QtWidgets

SECTIONS = (
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


def xdg_config_home():
    """Return the XDG config directory; ignore invalid relative XDG paths."""
    path = os.environ.get("XDG_CONFIG_HOME", "")
    return Path(path) if path and os.path.isabs(path) else Path.home() / ".config"


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
# image-12 glass design helpers
# ---------------------------------------------------------------------------

def chamfered_path(rect, radius, tl=0, tr=0, br=0, bl=0):
    """Rounded rect path with optional 45-degree chamfer cuts per corner."""
    x1, y1, x2, y2 = rect.left(), rect.top(), rect.right(), rect.bottom()
    path = QtGui.QPainterPath()
    path.moveTo(x1 + (tl or radius), y1)
    if tr:
        path.lineTo(x2 - tr, y1)
        path.lineTo(x2, y1 + tr)
    else:
        path.lineTo(x2 - radius, y1)
        path.arcTo(QtCore.QRectF(x2 - radius, y1, radius, radius), 90, -90)
    if br:
        path.lineTo(x2, y2 - br)
        path.lineTo(x2 - br, y2)
    else:
        path.lineTo(x2, y2 - radius)
        path.arcTo(QtCore.QRectF(x2 - radius, y2 - radius, radius, radius), 0, -90)
    if bl:
        path.lineTo(x1 + bl, y2)
        path.lineTo(x1, y2 - bl)
    else:
        path.lineTo(x1 + radius, y2)
        path.arcTo(QtCore.QRectF(x1, y2 - radius, radius, radius), 270, -90)
    if tl:
        path.lineTo(x1, y1 + tl)
        path.lineTo(x1 + tl, y1)
    else:
        path.lineTo(x1, y1 + radius)
        path.arcTo(QtCore.QRectF(x1, y1, radius, radius), 180, -90)
    path.closeSubpath()
    return path


def wallpaper_pixmap():
    """Best-effort wallpaper preview; returns None when nothing is readable."""
    cache = Path(os.environ.get("XDG_CACHE_HOME", "") or Path.home() / ".cache") / "hyde"
    candidates = []
    for name in ("wall.blur", "wall.set"):
        path = cache / name
        if path.exists() or path.is_symlink():
            candidates.append(os.path.realpath(path))
    try:
        text = (Path(os.environ.get("XDG_CONFIG_HOME", "") or Path.home() / ".config") / "quickshell" / "theme.json").read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        text = ""
    for value in re.findall(r'"wallBlurPath"\s*:\s*"([^"]+)"', text):
        candidates.append(value)
    for candidate in candidates:
        pixmap = QtGui.QPixmap(candidate)
        if not pixmap.isNull():
            return pixmap
    return None


def apply_theme(app):
    """Apply the dark glass styling from the image-12 mockup."""
    app.setStyleSheet("""
        QWidget#root { background: transparent; }
        QWidget { color: #e9e9e9; font-size: 13px; }
        QLabel#iconSquare {
            background: #d4d4d4; color: #262626; border-radius: 10px;
            font-size: 18px; font-weight: 700;
        }
        QLabel#titlePill {
            background: #d2d2d2; color: #232323; border-radius: 14px;
            padding: 5px 15px; font-weight: 700;
        }
        QLabel#subPill {
            background: #bfbfbf; color: #2c2c2c; border-radius: 14px;
            padding: 5px 13px; font-weight: 500;
        }
        QFrame#searchPill {
            background: rgba(18, 18, 18, 130);
            border: 1px solid rgba(255, 255, 255, 40); border-radius: 19px;
        }
        QLineEdit#searchEdit {
            background: transparent; border: none; color: #e9e9e9;
            padding: 4px 8px;
        }
        QPushButton#searchGo { background: #ffffff; border: none; border-radius: 13px; }
        QPushButton#searchGo:hover { background: #e6e6e6; }
        QPushButton#closeBtn {
            background: transparent; border: none; border-radius: 15px;
            color: #b9b9b9; font-size: 14px;
        }
        QPushButton#closeBtn:hover { background: rgba(255, 255, 255, 28); color: #ffffff; }
        QFrame#sidebar { background: transparent; border: none; }
        QPushButton#nav {
            background: rgba(208, 208, 208, 155); color: #262626; border: none;
            border-radius: 21px; padding: 11px 18px; text-align: left;
            font-weight: 600;
        }
        QPushButton#nav:hover { background: rgba(222, 222, 222, 195); }
        QPushButton#nav:checked { background: #e8e8e8; }
        QLabel#railDot { background: #8f8f8f; border-radius: 3px; }
        QLabel#profileName { color: #f4f4f4; font-size: 13px; font-weight: 700; }
        QLabel#profileLine { color: #9d9d9d; font-size: 11px; }
        QLabel#status { color: #8c8c8c; font-size: 11px; }
        QFrame#card {
            background: rgba(255, 255, 255, 16);
            border: 1px solid rgba(255, 255, 255, 36); border-radius: 14px;
        }
        QLabel#cardTitle { font-size: 14px; font-weight: 600; color: #f0f0f0; }
        QLabel#description { color: #a6a6a6; font-size: 12px; }
        QPushButton#open {
            background: rgba(255, 255, 255, 22);
            border: 1px solid rgba(255, 255, 255, 60); border-radius: 11px;
            padding: 7px 13px; color: #ececec;
        }
        QPushButton#open:hover { background: rgba(255, 255, 255, 42); border-color: #ffffff; }
        QPushButton#open:disabled { color: #777777; border-color: rgba(255, 255, 255, 28); }
        QScrollArea { border: none; background: transparent; }
        QWidget#page { background: transparent; }
        QScrollBar:vertical { background: transparent; width: 8px; margin: 2px; }
        QScrollBar::handle:vertical {
            background: rgba(255, 255, 255, 48); border-radius: 4px; min-height: 26px;
        }
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
        QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical { background: transparent; }
        QScrollBar:horizontal { background: transparent; height: 8px; margin: 2px; }
        QScrollBar::handle:horizontal {
            background: rgba(255, 255, 255, 48); border-radius: 4px; min-width: 26px;
        }
        QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal { width: 0; }
        QScrollBar::add-page:horizontal, QScrollBar::sub-page:horizontal { background: transparent; }
    """)


class ToggleSwitch(QtWidgets.QPushButton):
    """Pill toggle with a round knob, matching the mockup's bottom-left switch."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setCheckable(True)
        self.setChecked(True)  # image-12 shows the switch on (knob right)
        self.setFixedSize(64, 30)
        self.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        track = QtCore.QRectF(self.rect())
        painter.setPen(QtGui.QPen(QtGui.QColor(255, 255, 255, 46), 1))
        painter.setBrush(QtGui.QColor("#333333"))
        painter.drawRoundedRect(track, 15, 15)
        knob = 24
        margin = (self.height() - knob) / 2
        if self.isChecked():
            x = self.width() - knob - margin
            knob_color = QtGui.QColor("#ffffff")
        else:
            x = margin
            knob_color = QtGui.QColor("#9a9a9a")
        painter.setPen(QtCore.Qt.PenStyle.NoPen)
        painter.setBrush(knob_color)
        painter.drawEllipse(QtCore.QRectF(x, margin, knob, knob))


class DragBar(QtWidgets.QWidget):
    """Header strip that drags the frameless window."""

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.MouseButton.LeftButton:
            handle = self.window().windowHandle()
            if handle is not None and hasattr(handle, "startSystemMove"):
                handle.startSystemMove()
        super().mousePressEvent(event)


class HeroCard(QtWidgets.QWidget):
    """Chamfered wallpaper preview card with an image placeholder."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("hero")
        self.setMinimumHeight(210)
        self._pixmap = None
        self._overlay = None

    def set_pixmap(self, pixmap):
        self._pixmap = pixmap
        self.update()

    def set_overlay(self, widget):
        self._overlay = widget
        widget.setParent(self)
        self._place_overlay()

    def _place_overlay(self):
        if self._overlay is not None:
            self._overlay.move(22, self.height() - self._overlay.height() - 20)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._place_overlay()

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        path = chamfered_path(QtCore.QRectF(self.rect()).adjusted(1, 1, -1, -1), 18, tr=64)
        painter.setPen(QtGui.QPen(QtGui.QColor(255, 255, 255, 28), 1))
        if self._pixmap is not None and not self._pixmap.isNull():
            painter.setBrush(QtGui.QColor("#8b8b8b"))
            painter.drawPath(path)
            painter.save()
            painter.setClipPath(path)
            scaled = self._pixmap.scaled(
                self.size(),
                QtCore.Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                QtCore.Qt.TransformationMode.SmoothTransformation,
            )
            x = (self.width() - scaled.width()) // 2
            y = (self.height() - scaled.height()) // 2
            painter.setOpacity(0.82)
            painter.drawPixmap(x, y, scaled)
            painter.restore()
        else:
            painter.setBrush(QtGui.QColor("#8b8b8b"))
            painter.drawPath(path)
            self._draw_placeholder(painter)

    def _draw_placeholder(self, painter):
        icon_w, icon_h = 96, 76
        x = (self.width() - icon_w) / 2
        y = (self.height() - icon_h) / 2 - 6
        painter.setPen(QtGui.QPen(QtGui.QColor("#b4b4b4"), 6))
        painter.setBrush(QtCore.Qt.BrushStyle.NoBrush)
        painter.drawRoundedRect(QtCore.QRectF(x, y, icon_w, icon_h), 14, 14)
        painter.setPen(QtCore.Qt.PenStyle.NoPen)
        painter.setBrush(QtGui.QColor("#b4b4b4"))
        painter.drawEllipse(QtCore.QRectF(x + 24, y + 16, 15, 15))
        mountain = QtGui.QPainterPath()
        mountain.moveTo(x + 12, y + 62)
        mountain.lineTo(x + 42, y + 30)
        mountain.lineTo(x + 62, y + 50)
        mountain.lineTo(x + 72, y + 40)
        mountain.lineTo(x + 84, y + 62)
        mountain.closeSubpath()
        painter.drawPath(mountain)


class AvatarCircle(QtWidgets.QWidget):
    """White circle avatar with the user's initial."""

    def __init__(self, initial, parent=None):
        super().__init__(parent)
        self._initial = initial
        self.setFixedSize(56, 56)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        painter.setPen(QtCore.Qt.PenStyle.NoPen)
        painter.setBrush(QtGui.QColor("#ffffff"))
        painter.drawEllipse(self.rect().adjusted(1, 1, -1, -1))
        painter.setPen(QtGui.QColor("#2b2b2b"))
        font = painter.font()
        font.setBold(True)
        font.setPixelSize(22)
        painter.setFont(font)
        painter.drawText(self.rect(), QtCore.Qt.AlignmentFlag.AlignCenter, self._initial)


class ProfileCard(QtWidgets.QWidget):
    """Dark card with a chamfered top-left corner: avatar + identity lines."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumHeight(150)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(18, 18, 16, 16)
        layout.setSpacing(6)
        try:
            user = getpass.getuser()
        except Exception:
            user = "user"
        host = socket.gethostname() or "anide"
        avatar = AvatarCircle(user[:1].upper() or "A")
        layout.addWidget(avatar, 0, QtCore.Qt.AlignmentFlag.AlignLeft)
        layout.addSpacing(6)
        name = QtWidgets.QLabel(user, objectName="profileName")
        layout.addWidget(name)
        layout.addWidget(QtWidgets.QLabel(host, objectName="profileLine"))
        layout.addWidget(QtWidgets.QLabel("AniDE  ·  Hyprland", objectName="profileLine"))
        layout.addStretch()

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        path = chamfered_path(QtCore.QRectF(self.rect()).adjusted(1, 1, -1, -1), 16, tl=44)
        painter.setPen(QtGui.QPen(QtGui.QColor(255, 255, 255, 24), 1))
        painter.setBrush(QtGui.QColor("#3d3d3d"))
        painter.drawPath(path)


class RootPanel(QtWidgets.QWidget):
    """The dark glass window panel from the mockup."""

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        rect = QtCore.QRectF(self.rect()).adjusted(1, 1, -1, -1)
        gradient = QtGui.QLinearGradient(rect.topLeft(), rect.bottomLeft())
        gradient.setColorAt(0, QtGui.QColor("#343434"))
        gradient.setColorAt(1, QtGui.QColor("#292929"))
        painter.setPen(QtGui.QPen(QtGui.QColor(255, 255, 255, 26), 1))
        painter.setBrush(gradient)
        painter.drawRoundedRect(rect, 22, 22)


class SettingsWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("AniDE Settings")
        self.resize(960, 680)
        self.setMinimumSize(700, 480)
        self.setWindowFlags(self.windowFlags() | QtCore.Qt.WindowType.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.cards = []
        root = RootPanel(objectName="root")
        self.setCentralWidget(root)
        shadow = QtWidgets.QGraphicsDropShadowEffect(root)
        shadow.setBlurRadius(42)
        shadow.setOffset(0, 12)
        shadow.setColor(QtGui.QColor(0, 0, 0, 150))
        root.setGraphicsEffect(shadow)
        outer = QtWidgets.QVBoxLayout(root)
        outer.setContentsMargins(26, 22, 26, 24)
        outer.setSpacing(16)

        # ── Header: icon square, title pills, search pill, close ──
        header = DragBar()
        header.setFixedHeight(44)
        header_row = QtWidgets.QHBoxLayout(header)
        header_row.setContentsMargins(0, 0, 0, 0)
        header_row.setSpacing(10)
        icon_square = QtWidgets.QLabel("◈", objectName="iconSquare")
        icon_square.setFixedSize(40, 40)
        icon_square.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        header_row.addWidget(icon_square)
        self.titlePill = QtWidgets.QLabel(SECTIONS[0][0], objectName="titlePill")
        self.subPill = QtWidgets.QLabel(SECTIONS[0][2], objectName="subPill")
        header_row.addWidget(self.titlePill)
        header_row.addWidget(self.subPill)
        header_row.addStretch()
        search_pill = QtWidgets.QFrame(objectName="searchPill")
        search_pill.setFixedSize(260, 38)
        search_row = QtWidgets.QHBoxLayout(search_pill)
        search_row.setContentsMargins(4, 4, 5, 4)
        search_row.setSpacing(4)
        self.search = QtWidgets.QLineEdit(objectName="searchEdit")
        self.search.setPlaceholderText("Search this section…")
        self.search.textChanged.connect(self.filter_cards)
        search_row.addWidget(self.search)
        search_go = QtWidgets.QPushButton(objectName="searchGo")
        search_go.setFixedSize(26, 26)
        search_go.setCursor(QtCore.Qt.CursorShape.PointingHandCursor)
        search_go.setToolTip("Clear search")
        search_go.clicked.connect(self.search.clear)
        search_row.addWidget(search_go)
        header_row.addWidget(search_pill)
        self.closeBtn = QtWidgets.QPushButton("✕", objectName="closeBtn")
        self.closeBtn.setFixedSize(30, 30)
        self.closeBtn.setToolTip("Close (Esc)")
        self.closeBtn.clicked.connect(self.close)
        header_row.addWidget(self.closeBtn)
        outer.addWidget(header)
        escape = QtGui.QShortcut(QtGui.QKeySequence("Esc"), self)
        escape.activated.connect(self.close)

        # ── Body: sidebar, hero+cards, profile rail ──
        body = QtWidgets.QHBoxLayout()
        body.setSpacing(16)
        sidebar = QtWidgets.QFrame(objectName="sidebar")
        sidebar.setFixedWidth(230)
        nav = QtWidgets.QVBoxLayout(sidebar)
        nav.setContentsMargins(0, 8, 0, 0)
        nav.setSpacing(10)
        self.buttons = QtWidgets.QButtonGroup(self)
        self.buttons.setExclusive(True)
        self.stack = QtWidgets.QStackedWidget()
        for index, (title, icon, subtitle, actions) in enumerate(SECTIONS):
            button = QtWidgets.QPushButton(f"{icon}   {title}".replace("&", "&&"), objectName="nav")
            button.setCheckable(True)
            button.setFixedWidth(206 - index * 12)
            self.buttons.addButton(button, index)
            nav.addWidget(button)
            self.stack.addWidget(self.make_page(title, subtitle, actions))
        self.buttons.idClicked.connect(self.select_section)
        self.buttons.button(0).setChecked(True)
        nav.addStretch()
        body.addWidget(sidebar)

        center = QtWidgets.QVBoxLayout()
        center.setSpacing(12)
        self.hero = HeroCard()
        self.toggle = ToggleSwitch()
        self.toggle.setToolTip("Night light")
        self.toggle.clicked.connect(self.toggle_night_light)
        self.hero.set_overlay(self.toggle)
        wallpaper = wallpaper_pixmap()
        if wallpaper is not None:
            self.hero.set_pixmap(wallpaper)
        center.addWidget(self.hero, 2)
        center.addWidget(self.stack, 3)
        self.status = QtWidgets.QLabel("Changes are made by the selected desktop tool.", objectName="status")
        self.status.setWordWrap(True)
        center.addWidget(self.status)
        body.addLayout(center, 1)

        rail = QtWidgets.QVBoxLayout()
        rail.setSpacing(10)
        for _ in range(4):
            dot = QtWidgets.QLabel(objectName="railDot")
            dot.setFixedSize(10, 10)
            rail.addWidget(dot, 0, QtCore.Qt.AlignmentFlag.AlignLeft)
        rail.addStretch()
        rail.addWidget(ProfileCard())
        body.addLayout(rail)
        outer.addLayout(body, 1)

    def make_page(self, title, subtitle, actions):
        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        page = QtWidgets.QWidget(objectName="page")
        layout = QtWidgets.QVBoxLayout(page)
        layout.setContentsMargins(2, 4, 10, 4)
        layout.setSpacing(10)
        for name, description, command, dependencies in actions:
            card = QtWidgets.QFrame(objectName="card")
            row = QtWidgets.QHBoxLayout(card)
            row.setContentsMargins(16, 12, 16, 12)
            text = QtWidgets.QVBoxLayout()
            text.addWidget(QtWidgets.QLabel(name, objectName="cardTitle"))
            desc = QtWidgets.QLabel(description, objectName="description")
            desc.setWordWrap(True)
            text.addWidget(desc)
            row.addLayout(text, 1)
            button = QtWidgets.QPushButton("Open  ↗", objectName="open")
            missing = [dep for dep in dependencies if not shutil.which(dep)]
            if missing:
                button.setEnabled(False)
                button.setToolTip("Missing: " + ", ".join(missing))
                desc.setText(description + "\nMissing: " + ", ".join(missing))
            else:
                button.clicked.connect(lambda checked=False, argv=command, label=name: self.launch(argv, label))
            row.addWidget(button)
            layout.addWidget(card)
            self.cards.append((card, (name + " " + description).casefold()))
        layout.addStretch()
        scroll.setWidget(page)
        return scroll

    def select_section(self, index):
        self.stack.setCurrentIndex(index)
        self.search.clear()
        self.buttons.button(index).setChecked(True)
        self.titlePill.setText(SECTIONS[index][0])
        self.subPill.setText(SECTIONS[index][2])

    def filter_cards(self, text):
        query = text.strip().casefold()
        for card, words in self.cards:
            card.setVisible(not query or query in words)

    def toggle_night_light(self):
        self.launch(("hyde-shell", "hyprsunset", "--toggle"), "Night light")

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
