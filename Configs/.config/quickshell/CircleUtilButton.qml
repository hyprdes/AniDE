// CircleUtilButton: @lisa.p.ng layered duo-tone glass icon button (image-10.png error-state icon set)
// File-based component (not inline): immune to QML inline-component ordering quirks ("X is not a type").
import QtQuick

Item {
    id: utilBtn
    property string iconText: ""
    property color accentColor: "#ff4f18"
    property bool glas: true
    property bool activeState: false
    property int iconVariant: 0
    property color iconPlateColor: "#f2f1f7"
    property color iconInkColor: "#242739"
    property real iconArcStart: -210
    property real iconArcSweep: 90
    property real iconSparkX: 0.86
    property real iconSparkY: 0.14
    property real iconSparkSize: 0.11
    property real iconSparkRot: 0
    signal triggered()
    signal rightTriggered()

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: utilBtn.activeState
        color: Qt.rgba(1.0, 0.31, 0.09, 0.16)
        border.width: 1
        border.color: Qt.rgba(1.0, 0.31, 0.09, 0.50)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !utilBtn.activeState && utilMouse.containsMouse
        color: Qt.rgba(0.15, 0.16, 0.24, 0.10)
    }

    LisaGlassIcon {
        anchors.centerIn: parent
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
