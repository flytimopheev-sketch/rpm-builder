import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  FilesPage — управление файлами пакета: drag&drop, выбор вручную,
 *  каталог установки для каждого источника.
 */
Item {
    id: page
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: qsTr("Файлы пакета")
                font.family: Theme.uiFamily
                font.pixelSize: 19
                font.weight: Font.Bold
                color: Theme.text
                Layout.fillWidth: true
            }

            FlatButton {
                text: qsTr("Очистить всё")
                tone: "danger"
                visible: Engine.fileList.length > 0
                onClicked: {
                    Engine.clearFiles();
                    toastRef.show(qsTr("Список файлов очищен"));
                }
            }
            FlatButton {
                text: qsTr("Добавить папку…")
                onClicked: page.pickFolder()
            }
            GradientButton {
                text: qsTr("Добавить файлы…")
                implicitWidth: 168
                implicitHeight: 36
                onClicked: page.pickFiles()
            }
        }

        DropFilesArea {
            id: dropZone
            Layout.fillWidth: true
            height: Engine.fileList.length === 0 ? 190 : 130

            onPathsDropped: (list) => {
                Engine.addFiles(list);
                toastRef.show(
                    qsTr("Добавлено файлов: %1")
                        .arg(Engine.fileList.length), true);
            }
            onClickedEmpty: page.pickFiles()
        }

        // контейнер списка
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusCard
            color: "transparent"
            border.width: 0
            visible: Engine.fileList.length > 0

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: parent.width < 200 ? 200 : parent.width
                    spacing: 8

                    Repeater {
                        model: Engine.fileList

                        delegate: FileRow {
                            Layout.fillWidth: true
                            entry: modelData
                            rowIndex: index
                            onRemoveRequested: (idx) => Engine.removeFile(idx)
                            onDestChanged: (idx, dest) => Engine.setFileDest(idx, dest)
                        }
                    }
                }
            }
        }

        // подсказка снизу, когда файлов нет
        Text {
            visible: Engine.fileList.length === 0
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            text: qsTr("Каталоги установки определяются автоматически по типу файла — всегда можно поправить вручную")
            font.family: Theme.uiFamily
            font.pixelSize: 12
            color: Theme.textFaint
        }

        Item { Layout.fillHeight: true; visible: Engine.fileList.length > 0 }

        property var toastRef: page.toastRef   // прокидываем ссылку на toast
    }

    // ---- встроенный выбор (вместо системных диалогов) ----
    function pickFiles() {
        const t = toastRef;
        Window.window.pick(
            { mode: "openFiles", title: qsTr("Выберите файлы пакета") },
            function(paths) {
                if (!paths || paths.length === 0) return;
                Engine.addFiles(paths);
                if (t) t.show(qsTr("Добавлено файлов: %1")
                                  .arg(Engine.fileList.length), true);
            });
    }

    function pickFolder() {
        const t = toastRef;
        Window.window.pick(
            { mode: "folder", title: qsTr("Выберите папку с файлами пакета"),
              startDir: Engine.homeDir() },
            function(paths) {
                if (!paths || paths.length === 0) return;
                Engine.addDirectory(paths[0]);
                if (t) t.show(qsTr("Добавлено файлов: %1")
                                  .arg(Engine.fileList.length), true);
            });
    }

    property var toastRef: null
}
