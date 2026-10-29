import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  StatCard — плитка статистики на обзоре.
 */
Rectangle {
    id: sc
    property string value: "—"
    property string label: ""
    property color tint: Theme.accent1
    property real valueSize: 21

    radius: Theme.radiusCard
    color: Theme.surface
    border.color: Theme.hairline
    border.width: 1

    Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            width: 34; height: 34; radius: 10
            color: Qt.rgba(sc.tint.r, sc.tint.g, sc.tint.b,
                           Theme.isDark ? 0.20 : 0.14)
            anchors.verticalCenter: parent.verticalCenter

            // символ: кружок + точка (универсальный маркер)
            Rectangle {
                anchors.centerIn: parent
                width: 9; height: 9; radius: 4.5
                color: sc.tint
            }
            Rectangle {
                anchors.centerIn: parent
                width: 15; height: 15; radius: 7.5
                color: "transparent"
                border.color: sc.tint
                border.width: 1.4
                opacity: 0.45
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                text: sc.value
                font.family: Theme.uiFamily
                font.pixelSize: sc.valueSize
                font.weight: Font.Bold
                color: Theme.text
            }
            Text {
                text: sc.label
                font.family: Theme.uiFamily
                font.pixelSize: 12
                color: Theme.textDim
            }
        }
    }
}
