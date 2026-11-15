// CircleUtilButton: @lisa.p.ng layered duo-tone glass icon button (image-10.png error-state icon set)
// plus a flat glyph skin for the frame layout (image-1.png), picked with `flat`.
// File-based component (not inline): immune to QML inline-component ordering quirks ("X is not a type").
import QtQuick

Item {
    id: utilBtn
    property string iconText: ""
    // Frame preset: point themePalette at the shell theme (Colors.qml) and the
    // button takes the frame's skin, colours and glyph font from it. Left null,
    // the stand-alone defaults below apply. Any of them can still be set per button.
    property var themePalette: null
    property color accentColor: themePalette ? themePalette.frameAccentA : "#e8449b"
    property bool glas: true
    property bool activeState: false
    property int iconVariant: 0
    property color iconPlateColor: themePalette ? themePalette.framePill : "#f2f1f7"
    property color iconInkColor: themePalette ? themePalette.frameInk : "#242739"
    property real iconArcStart: -210
    property real iconArcSweep: 90
    property real iconSparkX: 0.86
    property real iconSparkY: 0.14
    property real iconSparkSize: 0.11
    property real iconSparkRot: 0
    // Flat skin (frame layout, image-1): a thin glyph, either bare inside a white
    // pill (plate: false) or on its own white circle (plate: true).
    // flat: false keeps the layered glass icon above; with themePalette set, that
    // is what the frame uses when it follows the wallpaper.
    property bool flat: themePalette ? !themePalette.followWallpaper : false
    property bool plate: false
    property color flatPlateColor: themePalette ? themePalette.framePill : "#ffffff"
    property color flatHoverColor: themePalette ? themePalette.frameHover : "#e8e8e8"
    property string glyphFont: themePalette ? themePalette.frameGlyphFont : "JetBrainsMono Nerd Font"
    signal triggered()
    signal rightTriggered()

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: utilBtn.flat && (utilBtn.plate || utilBtn.activeState || utilMouse.containsMouse)
        color: utilBtn.activeState
            ? Qt.alpha(utilBtn.accentColor, 0.55)
            : (utilMouse.containsMouse ? utilBtn.flatHoverColor : utilBtn.flatPlateColor)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: utilBtn.flat
        text: utilBtn.iconText
        color: utilBtn.iconInkColor
        font.family: utilBtn.glyphFont
        font.pixelSize: Math.round(utilBtn.height * 0.54)
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !utilBtn.flat && utilBtn.activeState
        color: Qt.rgba(1.0, 0.31, 0.09, 0.16)
        border.width: 1
        border.color: Qt.rgba(1.0, 0.31, 0.09, 0.50)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !utilBtn.flat && !utilBtn.activeState && utilMouse.containsMouse
        color: Qt.rgba(0.15, 0.16, 0.24, 0.10)
    }

    LisaGlassIcon {
        anchors.centerIn: parent
        visible: !utilBtn.flat
        width: utilBtn.glas ? 22 : Math.round(parent.width * 0.8)
        height: width
        glyph: utilBtn.iconText
        glyphScale: 0.52
        accentColor: utilBtn.accentColor
        plateColor: utilBtn.iconPlateColor
        inkColor: utilBtn.iconInkColor
        variant: utilBtn.iconVariant
        arcStart: utilBtn.iconArcStart
        arcSweep: utilBtn.iconArcSweep
        sparkX: utilBtn.iconSparkX
        sparkY: utilBtn.iconSparkY
        sparkSize: utilBtn.iconSparkSize
        sparkRot: utilBtn.iconSparkRot
    }

    MouseArea {
        id: utilMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                utilBtn.rightTriggered();
            } else {
                utilBtn.triggered();
            }
        }
    }
}
