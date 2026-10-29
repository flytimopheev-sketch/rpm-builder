import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  MetaPage — карточка пакета: основные поля и описание.
 */
ScrollView {
    id: page
    clip: true
    contentWidth: availableWidth

    // мост навигации: задаётся в Main.qml
    property var goPage: null

    // ошибки валидации постранично
    readonly property var issues:
        Engine.validationIssues.filter(i => i.page === "meta")
    function fieldError(f) {
        return issues.some(i => i.level === "error" && i.field === f);
    }

    ColumnLayout {
        x: 26; y: 22
        width: page.width - 52
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: qsTr("Метаданные пакета")
                font.family: Theme.uiFamily
                font.pixelSize: 19
                font.weight: Font.Bold
                color: Theme.text
                Layout.fillWidth: true
            }
            Text {
                text: qsTr("обязательные поля отмечены")
                font.family: Theme.uiFamily
                font.pixelSize: 11
                color: Theme.textFaint
            }
            Rectangle {
                width: 6; height: 6; radius: 3
                color: Theme.danger
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                spacing: 16
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: (page.width - 52 - 16) * 0.54

                SectionCard {
                    Layout.fillWidth: true
                    implicitHeight: grid.implicitHeight + 74
                    title: qsTr("Основное")

                    GridLayout {
                        id: grid
                        x: 18; y: 46
                        width: parent.width - 36
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 13

                        AppTextField {
                            Layout.fillWidth: true
                            label: qsTr("Имя пакета")
                            showErrorDot: true
                            error: page.fieldError("name")
                            placeholder: "my-application"
                            text: Engine.name
                            onEdited: (v) => Engine.name = v
                        }
                        AppTextField {
                            Layout.fillWidth: true
                            label: qsTr("Версия")
                            showErrorDot: true
                            error: page.fieldError("version")
                            placeholder: "1.0.0"
                            text: Engine.version
                            onEdited: (v) => Engine.version = v
                        }
                        AppTextField {
                            Layout.fillWidth: true
                            label: qsTr("Релиз")
                            showErrorDot: true
                            error: page.fieldError("release")
                            placeholder: "1%{?dist}"
                            text: Engine.release
                            onEdited: (v) => Engine.release = v
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: qsTr("Архитектура")
                                font.family: Theme.uiFamily
                                font.pixelSize: 12
                                color: Theme.textDim
                            }
                            AppComboBox {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                model: Engine.archSuggestions()
                                editText: Engine.arch
                                editable: true
                                onActivated: (i) => {
                                    Engine.arch = editTextAt(i)
                                    editText = Qt.binding(() => Engine.arch)
                                }
                                onAccepted: () => {
                                    Engine.arch = editText
                                    editText = Qt.binding(() => Engine.arch)
                                }
                            }
                        }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    implicitHeight: licGrid.implicitHeight + 100
                    title: qsTr("Лицензия и ссылки")

                    GridLayout {
                        id: licGrid
                        x: 18; y: 46
                        width: parent.width - 36
                        columns: 1
                        rowSpacing: 13

                        RowLayout {
                            spacing: 14
                            Column {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 220
                                spacing: 6
                                Text {
                                    text: qsTr("Лицензия (SPDX)")
                                    font.family: Theme.uiFamily
                                    font.pixelSize: 12; color: Theme.textDim
                                }
                                AppComboBox {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    editable: true
                                    model: Engine.licenseSuggestions()
                                    editText: Engine.license
                                    onActivated: (i) => {
                                        Engine.license = editTextAt(i)
                                        editText = Qt.binding(() => Engine.license)
                                    }
                                    onAccepted: () => {
                                        Engine.license = editText
                                        editText = Qt.binding(() => Engine.license)
                                    }
                                }
                            }
                            AppTextField {
                                Layout.fillWidth: true
                                label: qsTr("Домашняя страница")
                                placeholder: "https://example.com/project"
                                text: Engine.url
                                onEdited: (v) => Engine.url = v
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: 16
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: (page.width - 52 - 16) * 0.46

                SectionCard {
                    Layout.fillWidth: true
                    implicitHeight: 196
                    title: qsTr("Краткое описание")
                    caption: {
                        const n = Engine.summary.length;
                        return n + "/80";
                    }

                    AppTextArea {
                        x: 16; y: 44
                        width: parent.width - 32
                        height: 122
                        label: ""
                        placeholder: qsTr("Одна строка — что это за программа")
                        text: Engine.summary
                        onTextChanged: if (!Engine || Engine.summary !== text)
                                           Engine.summary = text
                        error: page.fieldError("summary") ||
                               Engine.summary.length > 80
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    implicitHeight: 178
                    title: qsTr("Подробное описание")

                    AppTextArea {
                        x: 16; y: 44
                        width: parent.width - 32
                        height: 106
                        placeholder: qsTr("Для чего нужен пакет, особенности, примечания к установке…")
                        text: Engine.description
                        onTextChanged: if (!Engine ||
                                          Engine.description !== text)
                                           Engine.description = text
                        error: page.fieldError("description")
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    implicitHeight: 150
                    title: qsTr("Авторство")

                    GridLayout {
                        x: 18; y: 44
                        width: parent.width - 36
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 12

                        AppTextField {
                            Layout.fillWidth: true
                            label: qsTr("Сборщик (Packager)")
                            placeholder: "Ivanov Ivan <ivan@example.com>"
                            text: Engine.packager
                            onEdited: (v) => Engine.packager = v
                        }
                        AppTextField {
                            Layout.fillWidth: true
                            label: qsTr("Организация (Vendor)")
                            placeholder: "Example Inc."
                            text: Engine.vendor
                            onEdited: (v) => Engine.vendor = v
                        }
                    }
                }
            }
        }

        // ---- прямой переход к следующему разделу (не через сайдбар) ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: qsTr("Дальше — перетащить файлы пакета")
                font.family: Theme.uiFamily
                font.pixelSize: 12
                color: Theme.textFaint
            }
            GradientButton {
                text: qsTr("Далее: файлы пакета")
                implicitWidth: 210
                onClicked: if (page.goPage) page.goPage(2)
            }
        }

        Item { height: 20; Layout.fillWidth: true }
    }
}
