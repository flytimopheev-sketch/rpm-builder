import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  GradientButton — главная кнопка действия с градиентом индиго→фиолет.
 */
Button {
    id: btn
    implicitHeight: 44
    font.family: Theme.uiFamily
    font.pixelSize: 14
    font.weight: Font.DemiBold

    property real glow: hover.containsMouse ? 1.06 : 1.0
    Behavior on glow { NumberAnimation { duration: Theme.animFast } }

    contentItem: Text {
        text: btn.text
        font: btn.font
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: btn.enabled ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    background: Rectangle {
        radius: Theme.radiusCtl
        border.width: 1
        border.color: btn.enabled ? "#8B5CF6CC" : Theme.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: btn.enabled ? Qt.lighter(Theme.accent1, btn.glow)
                                   : (Theme.isDark ? "#3E4066" : "#C9CBDF")
            }
            GradientStop {
                position: 1.0
                color: btn.enabled ? Qt.lighter(Theme.accent2, btn.glow)
                                   : (Theme.isDark ? "#4A3866" : "#D6CCE8")
            }
        }

        // блик при наведении
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "white"
            opacity: hover.containsMouse && btn.enabled ? 0.09 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }
        // подсветка снизу
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: btn.enabled && !btn.pressed
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.18) }
            }
        }
    }

    scale: pressed ? 0.98 : (hover.containsMouse ? 1.015 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.NoButton
    }
}
