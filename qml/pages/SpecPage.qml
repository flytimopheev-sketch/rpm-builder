import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  SpecPage — живой предпросмотр генерируемого SPEC с действиями
 *  «Копировать» и «Сохранить…».
 */
Item {
    id: page
    clip: true

    readonly property var metaIssues:
        Engine.validationIssues.filter(i => i.level === "error" &&
                                         (i.page === "meta" || i.page === "files"))

    function refreshText() {
        previewArea.text = Engine.specText;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: qsTr("SPEC-файл")
                font.family: Theme.uiFamily
                font.pixelSize: 19
                font.weight: Font.Bold
                color: Theme.text
                Layout.fillWidth: true
            }

            // индикатор готовности
            Rectangle {
                visible: metaIssues.length === 0
                height: 26; radius: 13
                width: okLabel.implicitWidth + 30
                color: Theme.successSoft
                border.color: Qt.rgba(Theme.success.r, Theme.success.g,
                                      Theme.success.b, 0.4)
                Text {
                    id: okLabel
                    anchors.centerIn: parent
                    text: qsTr("готово к сборке")
                    color: Theme.isDark ? "#8AF0C5" : "#0B7A50"
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                }
            }
            Rectangle {
                visible: metaIssues.length > 0
                height: 26; radius: 13
                width: errLabel.implicitWidth + 30
                color: Theme.dangerSoft
                border.color: Qt.rgba(Theme.danger.r, Theme.danger.g,
                                      Theme.danger.b, 0.45)
                Text {
                    id: errLabel
                    anchors.centerIn: parent
                    text: qsTr("ошибок: %1").arg(metaIssues.length)
                    color: Theme.danger
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                }
            }

            FlatButton {
                text: qsTr("Копировать")
                onClicked: {
                    copyHelper.text = Engine.specText;
                    copyHelper.selectAll();
                    copyHelper.copy();
                    page.toastRef.show(qsTr("SPEC скопирован в буфер"), true);
                }
                Text { visible: false }   // placeholder to keep ids close
            }
            GradientButton {
                text: qsTr("Сохранить как…")
                implicitWidth: 168
                implicitHeight: 36
                onClicked: page.saveSpecAs()
            }
        }

        SectionCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: (Engine.name || "package") + ".spec"
            caption: qsTr("обновляется автоматически при правке формы")

            AppTextArea {
                id: previewArea
                x: 16; y: 44
                width: parent.width - 32
                height: parent.height - 60
                mono: true
                readOnly: true
                Component.onCompleted: page.refreshText()
            }
        }
    }

    // невидимый помощник копирования в буфер обмена
    TextEdit {
        id: copyHelper
        visible: false
        width: 0; height: 0
    }

    // ---- встроенный выбор (вместо системных диалогов) ----
    function saveSpecAs() {
        const t = toastRef;
        Window.window.pick(
            { mode: "saveFile", title: qsTr("Сохранить SPEC-файл"),
              defaultName: Engine.specFileName(),
              startDir: Engine.outputDir,
              filterExts: [".spec"],
              filterLabel: qsTr("SPEC файлы (*.spec)") },
            function(paths) {
                if (!paths || paths.length === 0) return;
                const ok = Engine.saveSpec(paths[0]);
                if (t) t.show(ok ? qsTr("Файл сохранён")
                                 : qsTr("Не удалось сохранить файл"), ok);
            });
    }

    // переподготовка текста при любом изменении модели проекта
    Connections {
        target: Engine
        function onProjectChanged() { page.refreshText() }
    }

    property var toastRef: null
}
