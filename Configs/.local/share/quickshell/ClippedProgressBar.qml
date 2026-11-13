// ClippedProgressBar: OneUI 7 style clipped capsule progress bar
// File-based component (not inline): immune to QML inline-component ordering quirks ("X is not a type").
import QtQuick

Item {
    id: progressRoot
    property real value: 0.0
    property color fill: "#ff4f18"
    property color trackColor: Qt.rgba(0.55, 0.58, 0.91, 0.18)

    implicitWidth: 42
    implicitHeight: 12

    Rectangle {
        id: clipTrack
        anchors.fill: parent
        radius: height / 2
        color: progressRoot.trackColor
    }
    Rectangle {
        id: clipFill
        radius: height / 2
        color: progressRoot.fill
        height: parent.height
        width: Math.max(height, parent.width * Math.min(1, Math.max(0, progressRoot.value)))
        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        Rectangle {
            width: clipFill.width - clipFill.height * 0.8
            height: 1.5
            radius: 1
            color: "#2effffff"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: clipFill.height * 0.5
            anchors.topMargin: 2
        }
    }
    Text {
        anchors.centerIn: parent
        text: Math.round(progressRoot.value * 100).toString() + "%"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 8
        font.bold: true
        color: "#ffffff"
    }
}
