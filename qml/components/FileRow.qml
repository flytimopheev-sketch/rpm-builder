import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  FileRow — строка источника в списке файлов: имя, путь, размер,
 *  выбор каталога установки и удаление.
 */
Rectangle {
    id: row

    property var entry: ({})         // {src,dst,human,isDir}
    property int rowIndex: 0

    signal removeRequested(int idx)
    signal destChanged(int idx, string dest)

    height: 66
    radius: Theme.radiusCtl
    color: hoverZone.containsMouse ? Theme.surface2 : Theme.surface
    border.color: Theme.hairline
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    // индикатор типа файла
    Rectangle {
        x: 12; y: 12
        width: 40; height: 42; radius: 9

        readonly property color tint: row.entry.isDir ? Theme.warning : Theme.info
        color: Qt.rgba(tint.r, tint.g, tint.b, Theme.isDark ? 0.18 : 0.13)

        Text {
            anchors.centerIn: parent
            text: row.entry.isDir ? "\u{1F5C2}" : ""
            visible: false                     // фонтомодзи не используем
        }

        // папка: прямоугольник с язычком; файл: лист со сгибом
        Item {
            anchors.centerIn: parent
            width: 20; height: 20
            visible: parent.visible !== false

            Rectangle {
                visible: row.entry.isDir === true
                x: 0; y: 3; width: 20; height: 14; radius: 3
                border.width: 1.6; border.color: parent.parent.parent.tint ?? Theme.info
                color: "transparent"
            }
            Rectangle {
                visible: row.entry.isDir === true
                x: 0; y: 1; width: 9; height: 4; radius: 2
                color: parent.parent.parent.tint ?? Theme.info
            }
            Rectangle {
                visible: row.entry.isDir === false
                x: 3; y: 0; width: 14; height: 19; radius: 3
                border.width: 1.6;
                border.color: (parent.parent.parent.tint ?? Theme.info)
                color: "transparent"
            }
            Rectangle {
                visible: row.entry.isDir === false
                x: 11; y: 0; width: 6; height: 6
                radius: 1
                color: row.entryColorFallback()
                       ? "transparent" : "transparent"
            }
        }
    }

    function entryColorFallback() { return false }

    ColumnLayout {
        x: 62; y: 10
        width: parent.width - 420
        spacing: 3

        Text {
            text: fileName(row.entry.src)
            font.family: Theme.uiFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
        RowLayout {
            spacing: 8
            Text {
                text: dirName(row.entry.src) + " • " +
                      (row.entry.human || "—")
                font.family: Theme.uiFamily
                font.pixelSize: 11
                color: Theme.textFaint
                elide: Text.ElideMiddle
                Layout.maximumWidth:
                    parent.parent.width - 10 < 220 ? 220 : parent.parent.width - 10
                Layout.fillWidth: true
            }
        }
    }

    Column {
        anchors.right: deleteBtn.left
        anchors.rightMargin: 12
        y: 10
        width: 250

        Text {
            text: qsTr("Каталог установки")
            font.family: Theme.uiFamily
            font.pixelSize: 10
            color: Theme.textFaint
        }
        AppComboBox {
            id: dstCombo
            width: parent.width
            height: 34
            editable: true
            model: Engine.destDirSuggestions()
            editText: row.entry.dst
            onActivated: (idx) => row.destChanged(row.rowIndex, editText)
            onAccepted: () => row.destChanged(row.rowIndex, editText)

            background: Rectangle {
                radius: 8
                color: Theme.field
                border.width: dstCombo.activeFocus ? 1.5 : 1
                border.color: dstCombo.activeFocus ? Theme.accent1 : Theme.hairline
            }

            contentItem: TextInput {
                text: dstCombo.editText
                font.family: Theme.monoFamily
                font.pixelSize: 11
                color: Theme.text
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
                rightPadding: 24
                selectByMouse: true
                onEditingFinished: row.destChanged(row.rowIndex, text)
            }
        }
    }

    Rectangle {
        id: deleteBtn
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 30; radius: 8
        color: delHover.containsMouse ? Theme.dangerSoft : "transparent"

        Text {
            anchors.centerIn: parent
            text: "\u2715"
            font.pixelSize: 11
            color: delHover.containsMouse ? Theme.danger : Theme.textDim
        }
        MouseArea {
            id: delHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.removeRequested(row.rowIndex)
        }
    }

    MouseArea {
        id: hoverZone
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    function fileName(p) {
        const parts = String(p).split("/");
        return parts[parts.length - 1];
    }
    function dirName(p) {
        const s = String(p);
        const i = s.lastIndexOf("/");
        if (i <= 0) return "/";
        return s.slice(0, Math.min(i, 46)) + (i > 46 ? "…" : "");
    }
}
