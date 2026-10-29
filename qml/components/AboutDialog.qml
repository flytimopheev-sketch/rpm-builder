import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  AboutDialog — модальное окно «О программе»: версия, назначение,
 *  технологии, требования и лицензия.
 */
Popup {
    id: dlg

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: 480
    padding: 0

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animMid }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.animMid;
                          easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.animFast }
    }

    background: Rectangle {
        radius: Theme.radiusWin
        color: Theme.surface
        border.color: Theme.hairline
        border.width: 1

        // акцентное свечение сверху
        Rectangle {
            x: 40; y: -60; width: 300; height: 160; radius: 80
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                                                           Theme.accent1.b, 0.25) }
                GradientStop { position: 1; color: Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                                                           Theme.accent1.b, 0) }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ---------------- шапка ----------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            spacing: 10

            RowLayout {
                spacing: 14
                Layout.fillWidth: true

                AppIcon { Layout.preferredWidth: 52; Layout.preferredHeight: 52 }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: qsTr("RPM Builder")
                        font.family: Theme.uiFamily
                        font.pixelSize: 21
                        font.weight: Font.Bold
                        color: Theme.text
                    }
                    Text {
                        text: qsTr("визуальная сборка RPM-пакетов")
                        font.family: Theme.uiFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }

                Item { Layout.fillWidth: true }

                // бейдж версии
                Rectangle {
                    radius: 12
                    height: 24
                    width: verLbl.implicitWidth + 20
                    color: Theme.accentSoft
                    border.color: Theme.accent1
                    border.width: 1
                    Text {
                        id: verLbl
                        anchors.centerIn: parent
                        text: qsTr("версия %1").arg(Engine.appVersion)
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: Theme.accentText
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                wrapMode: Text.WordWrap
                text: qsTr("Конструктор RPM-пакетов: метаданные, файлы, зависимости, " +
                           "скрипты и SPEC-файл собираются в наглядной форме, а сборка " +
                           "запускается одной кнопкой — без ручного изучения rpmbuild.")
                font.family: Theme.uiFamily
                font.pixelSize: 12
                color: Theme.textDim
                lineHeight: 1.25
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.hairline }

        // ---------------- сведения ----------------
        GridLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            columns: 2
            columnSpacing: 16
            rowSpacing: 10

            component InfoRow: ColumnLayout {
                id: infoRow
                Layout.fillWidth: true
                spacing: 3
                required property string caption
                required property string value
                Text {
                    text: infoRow.caption
                    font.family: Theme.uiFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    color: Theme.textFaint
                }
                Text {
                    text: infoRow.value
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                    color: Theme.text
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            InfoRow { caption: qsTr("ИНТЕРФЕЙС");    value: qsTr("Qt 6.9 · QML, две темы оформления") }
            InfoRow { caption: qsTr("СБОРЩИК");      value: qsTr("rpmbuild (РЕД ОС: пакет rpm-build)") }
            InfoRow { caption: qsTr("СИСТЕМА");      value: qsTr("Linux x86_64, glibc не ниже 2.34") }
            InfoRow { caption: qsTr("ЛИЦЕНЗИЯ");     value: qsTr("MIT — свободное использование") }
            InfoRow { caption: qsTr("ШАБЛОНЫ");      value: qsTr("сохранение/загрузка проектов (*.rpmb.json)") }
            InfoRow { caption: qsTr("ПРОВЕРКА");     value: qsTr("запуск без окна: --selftest") }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.hairline }

        // ---------------- низ ----------------
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 18
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: qsTr("Сделано для РЕД ОС и других RPM-дистрибутивов")
                font.family: Theme.uiFamily
                font.pixelSize: 11
                color: Theme.textFaint
            }

            GradientButton {
                text: qsTr("Закрыть")
                onClicked: dlg.close()
            }
        }
    }
}
