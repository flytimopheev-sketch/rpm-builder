import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  DepsPage — зависимости пакета чипами: Requires / BuildRequires / Provides.
 */
ScrollView {
    id: page
    clip: true
    contentWidth: availableWidth

    ColumnLayout {
        x: 26; y: 22
        width: page.width - 52
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: qsTr("Зависимости")
                font.family: Theme.uiFamily
                font.pixelSize: 19
                font.weight: Font.Bold
                color: Theme.text
                Layout.fillWidth: true
            }
            Text {
                text: qsTr("Enter или запятая — добавить, Backspace на пустом поле — удалить последний")
                font.family: Theme.uiFamily
                font.pixelSize: 11
                color: Theme.textFaint
            }
        }

        SectionCard {
            Layout.fillWidth: true
            implicitHeight: 152
            title: "Requires"
            caption: qsTr("runtime-зависимости пакета")

            Column {
                x: 16; y: 46
                width: parent.width - 32
                spacing: 8
                ChipInput {
                    width: parent.width
                    engineKey: "requires"
                    placeholder: "glibc  •  systemd >= 250  •  ffmpeg-libs"
                    Component.onCompleted: {}
                }
                Text {
                    text: qsTr("Пакеты, которые должны быть установлены в системе рядом с вашим")
                    font.family: Theme.uiFamily
                    font.pixelSize: 11
                    color: Theme.textFaint
                }
            }
        }

        SectionCard {
            Layout.fillWidth: true
            implicitHeight: 152
            title: "BuildRequires"
            caption: qsTr("инструменты сборки (для future-proof spec)")

            Column {
                x: 16; y: 46
                width: parent.width - 32
                spacing: 8
                ChipInput {
                    width: parent.width
                    engineKey: "buildRequires"
                    placeholder: "make  •  gcc  •  python3-devel"
                }
                Text {
                    text: qsTr("Обычно не требуется для простой упаковки готовых файлов")
                    font.family: Theme.uiFamily
                    font.pixelSize: 11
                    color: Theme.textFaint
                }
            }
        }

        SectionCard {
            Layout.fillWidth: true
            implicitHeight: 152
            title: "Provides"
            caption: qsTr("что объявляет пакет")

            Column {
                x: 16; y: 46
                width: parent.width - 32
                spacing: 8
                ChipInput {
                    width: parent.width
                    engineKey: "provides"
                    placeholder: "my-tool = 1.0.0"
                }
                Text {
                    text: qsTr("Виртуальные имена, которые пакет предоставляет другим пакетам")
                    font.family: Theme.uiFamily
                    font.pixelSize: 11
                    color: Theme.textFaint
                }
            }
        }

        Item { height: 20; Layout.fillWidth: true }
    }
}
