import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  TitleBar — кастомная строка заголовка безрамочного окна:
 *  перетаскивание, двойной клик = максимизация, кнопка «О программе»,
 *  переключатель темы и кнопки окна (свернуть/развернуть/закрыть),
 *  жёстко прижатые к ПРАВОМУ ВЕРХНЕМУ углу (привязки, не Layout).
 */
Rectangle {
    id: bar

    required property var win
    signal aboutClicked()

    color: "transparent"
    height: Theme.titleBarH

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWin
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(Theme.accent1.r, Theme.accent1.g, Theme.accent1.b,
                               Theme.isDark ? 0.10 : 0.07)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(Theme.accent1.r, Theme.accent1.g, Theme.accent1.b, 0)
            }
        }
    }

    function toggleMaximize() {
        if (bar.win.visibility === Window.Maximized)
            bar.win.showNormal()
        else
            bar.win.showMaximized()
    }

    // вся площадь — зона перетаскивания (кнопки выше и перехватывают клики)
    MouseArea {
        anchors.fill: parent
        onPressed: () => {
            if (!rightCluster.childHovered)
                bar.win.startSystemMove()
        }
        onDoubleClicked: () => bar.toggleMaximize()
    }

    // ------------------- левая часть: логотип и название -------------------
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        AppIcon { width: 30; height: 30; anchors.verticalCenter: parent.verticalCenter }

        Column {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: qsTr("RPM Builder")
                font.family: Theme.uiFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: 0.2
                color: Theme.text
            }
            Text {
                text: qsTr("визуальная сборка RPM-пакетов")
                font.family: Theme.uiFamily
                font.pixelSize: 11
                color: Theme.textFaint
            }
        }
    }

    component WinButton: Rectangle {
        id: wb
        property string glyph: ""
        property bool isClose: false
        signal activate()

        readonly property bool hovered: hoverZone.containsMouse

        width: 34; height: 26; radius: 8
        border.width: 0
        color: wb.isClose
               ? (hoverZone.containsMouse ? "#E81123" : "transparent")
               : (hoverZone.containsMouse ? Theme.hairlineSoft : "transparent")

        Behavior on color { ColorAnimation { duration: 90 } }

        Text {
            anchors.centerIn: parent
            text: wb.glyph
            font.pixelSize: 11
            font.family: Theme.uiFamily
            color: (wb.isClose && hoverZone.containsMouse) ? "#FFFFFF" : Theme.textDim
        }

        MouseArea {
            id: hoverZone
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wb.activate()
        }
    }

    // ------------- правая часть: прижата к правому верхнему углу -------------
    Row {
        id: rightCluster
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        readonly property bool childHovered:
            aboutBtn.hovered || themePill.containsMouse
            || minWn.hovered || maxWn.hovered || closeWn.hovered

        // ------------------- кнопка «О программе» -------------------
        Rectangle {
            id: aboutBtn
            readonly property bool hovered: aboutHover.containsMouse
            width: aboutLbl.implicitWidth + 24
            height: 26; radius: 13
            color: aboutHover.containsMouse ? Theme.accentSoft : Theme.field
            border.color: aboutHover.containsMouse ? Theme.accent1 : Theme.hairline
            border.width: 1

            Behavior on color { ColorAnimation { duration: 90 } }
            Behavior on border.color { ColorAnimation { duration: 90 } }

            Text {
                id: aboutLbl
                anchors.centerIn: parent
                text: qsTr("О программе")
                font.family: Theme.uiFamily
                font.pixelSize: 11
                color: aboutBtn.hovered ? Theme.accentText : Theme.textDim
            }

            MouseArea {
                id: aboutHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.aboutClicked()
            }
        }

        // ------------------- переключатель темы -------------------
        Rectangle {
            id: themePill
            readonly property bool containsMouse: pillMouse.containsMouse
            width: 58; height: 26; radius: 13
            color: Theme.field
            border.color: Theme.hairline
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            Rectangle {
                x: Theme.isDark ? 31 : 3
                y: 3
                width: 20; height: 20; radius: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: "#8B8FF5" }
                    GradientStop { position: 1; color: Theme.isDark ? "#6D28D9" : "#C084FC" }
                }
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            // «солнце» справа (видно в светлой теме, когда ручка слева)
            Rectangle {
                x: 39; y: 9; width: 8; height: 8; radius: 4
                color: "#EAB308"
                visible: !Theme.isDark
            }
            // «луна» слева (видна в тёмной теме, когда ручка справа)
            Item {
                x: 9; y: 9; width: 9; height: 9
                visible: Theme.isDark
                Rectangle { width: 9; height: 9; radius: 4.5; color: "#FDE68A" }
                Rectangle { x: 3; y: -1; width: 8; height: 8; radius: 4;
                            color: themePill.color }
            }

            MouseArea {
                id: pillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Engine.darkTheme = !Engine.darkTheme
            }
        }

        Rectangle { width: 1; height: 22; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }

        // ------------------- кнопки окна -------------------
        Row {
            id: btnRow
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            WinButton {
                id: minWn
                glyph: "\u2500"                 // —
                onActivate: win.showMinimized()
            }
            WinButton {
                id: maxWn
                glyph: "\u25A1"                 // □
                onActivate: bar.toggleMaximize()
            }
            WinButton {
                id: closeWn
                glyph: "\u2715"                 // ✕
                isClose: true
                onActivate: Qt.quit()
            }
        }
    }
}
