import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  Toast — всплывающее уведомление внизу окна.
 */
Rectangle {
    id: toast

    function show(message, ok) {
        msg = message;
        accent = ok === undefined ? Theme.accent1 : (ok ? Theme.success : Theme.danger);
        visibleTimer.restart();
        opacityTarget = 1;
    }

    property string msg: ""
    property color accent: Theme.accent1
    property real opacityTarget: 0

    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - height - 26
    width: Math.max(240, Math.min(460, msgText.implicitWidth + 56))
    height: 44
    radius: 12
    z: 1000

    opacity: opacityTarget
    scale: opacityTarget > 0 ? 1 : 0.92
    Behavior on opacity { NumberAnimation { duration: Theme.animMid } }
    Behavior on scale { NumberAnimation { duration: Theme.animMid; easing.type: Easing.OutCubic } }

    Timer {
        id: visibleTimer
        interval: 2600
        onTriggered: toast.opacityTarget = 0
    }

    border.width: 1
    border.color: toast.accent
    gradient: Gradient {
        GradientStop {
            position: 0
            color: Qt.rgba(toast.accent.r, toast.accent.g, toast.accent.b, 0.30)
        }
        GradientStop {
            position: 1
            color: Qt.rgba(toast.surfaceTint(), toast.surfaceTint(),
                           toast.surfaceTint(), 1)
        }
    }
    function surfaceTint() { return Theme.isDark ? 0.10 : 0.99 }

    Row {
        anchors.centerIn: parent
        spacing: 10
        Rectangle {
            width: 8; height: 8; radius: 4
            color: toast.accent
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: msgText
            text: toast.msg
            font.family: Theme.uiFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Theme.text
        }
    }
}
