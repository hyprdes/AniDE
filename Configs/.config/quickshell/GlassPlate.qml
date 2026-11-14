// Liquid glass plate used by AniSubPanelFace: a light tint, a white top sheen
// and a thin bright rim, with a stronger tint while pressed (pressedLook).
// GPL-3.0-or-later; see CREDITS.md.
import QtQuick

Rectangle {
    id: plate
    property bool pressedLook: false
    radius: 22
    color: Qt.rgba(1, 1, 1, plate.pressedLook ? 0.30 : 0.16)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.42)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: plate.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.26) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.02) }
        }
    }
}
