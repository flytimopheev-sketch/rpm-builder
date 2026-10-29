import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  FlatButton — нейтральная контурная кнопка.
 */
Button {
    id: btn
    implicitHeight: 36
    font.family: Theme.uiFamily
    font.pixelSize: 13
    font.weight: Font.Medium

    property string tone: "neutral"      // neutral | danger | success

    readonly property color fg:
        tone === "danger" ? Theme.danger :
        tone === "success" ? Theme.success : Theme.textDim
    readonly property color borderC:
        tone === "danger" ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.5) :
        tone === "success" ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.5) :
                             Theme.hairline

    contentItem: Text {
        text: btn.text
        font: btn.font
        color: btn.enabled ? btn.fg : Theme.textFaint
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 9
        color: hover.containsMouse && btn.enabled
               ? (btn.tone === "danger" ? Theme.dangerSoft
                  : btn.tone === "success" ? Theme.successSoft
                  : Theme.hairlineSoft)
               : "transparent"
        border.color: btn.borderC
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.NoButton
    }
}
