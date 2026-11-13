// CircleUtilButton: @lisa.p.ng layered duo-tone glass icon button (image-10.png error-state icon set)
// File-based component (not inline): immune to QML inline-component ordering quirks ("X is not a type").
import QtQuick

Item {
    id: utilBtn
    property string iconText: ""
    property color accentColor: "#ff4f18"
    property bool glas: true
    property bool activeState: false
    signal triggered()
    signal rightTriggered()

    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: utilBtn.activeState
        color: Qt.rgba(1.0, 0.31, 0.09, 0.22)
        border.width: 1
        border.color: Qt.rgba(1.0, 0.31, 0.09, 0.50)
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: !utilBtn.activeState && utilMouse.containsMouse
        color: Qt.rgba(0.41, 0.43, 0.90, 0.30)
    }

    LisaGlassIcon {
        anchors.centerIn: parent
        width: utilBtn.glas ? 26 : Math.round(parent.width * 0.8)
        height: width
        glyph: utilBtn.iconText
        glyphScale: 0.52
        accentColor: utilBtn.accentColor
        arcStart: -210
        arcSweep: 90
        sparkX: 0.86
        sparkY: 0.14
        sparkSize: 0
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
