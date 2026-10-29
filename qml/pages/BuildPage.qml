import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  BuildPage — конфигурация каталога вывода, запуск rpmbuild,
 *  живой журнал, индикатор выполнения и карточки артефактов.
 */
Item {
    id: page
    clip: true

    // журнал: список строк (стрим из C++ appendLog)
    ListModel { id: logModel }

    Connections {
        target: Engine
        function onAppendLog(chunk) {
            const lines = chunk.split("\n");
            for (const ln of lines)
                if (ln !== "" || true) logModel.append({ line: ln });
            autoscroll.restart();
            if (chunk.length === 0) {}
        }
        function onBuildFinished(ok) {
            if (Engine.lastBuildCancelled)
                page.toastRef.show(qsTr("Сборка отменена"), true);
            else if (ok)
                page.toastRef.show(qsTr("Сборка успешно завершена"), true);
            else
                page.toastRef.show(
                    qsTr("Сборка не удалась — разбор ошибок вверху"), false);
        }
    }

    Timer {
        id: autoscroll
        interval: 60
        onTriggered: logView.positionViewAtEnd()
    }

    readonly property bool blocked:
        Engine.validationIssues.some(i => i.level === "error")

    function logColor(ln) {
        if (/✗|error:|Error|FAILED|ошиб/i.test(ln)) return Theme.danger;
        if (/warning:|Внимание:|^!!/i.test(ln)) return Theme.warning;
        if (/✔|Готово|Writing|Wrote/.test(ln)) return Theme.success;
        if (/^\[\d\/6\]/.test(ln)) return Theme.accentText;
        return Theme.textDim;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: qsTr("Сборка")
                font.family: Theme.uiFamily
                font.pixelSize: 19
                font.weight: Font.Bold
                color: Theme.text
                Layout.fillWidth: true
            }
            Text {
                text: Engine.rpmbuildPath !== ""
                      ? qsTr("rpmbuild найден")
                      : qsTr("rpmbuild не установлен!")
                color: Engine.rpmbuildPath !== "" ? Theme.success : Theme.danger
                font.family: Theme.uiFamily
                font.pixelSize: 12
            }
        }

        // ------------------- конфигурация -------------------
        SectionCard {
            Layout.fillWidth: true
            implicitHeight: 118
            title: qsTr("Каталог результатов")

            RowLayout {
                x: 16; y: 46
                width: parent.width - 32
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 9
                    color: Theme.field
                    border.color: Theme.hairline
                    border.width: 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12; width: parent.width - 24
                        text: Engine.outputDir
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.monoFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }

                FlatButton {
                    text: qsTr("Изменить…")
                    onClicked: page.pickOutputDir()
                }
                FlatButton {
                    text: qsTr("Открыть папку")
                    visible: page.lastArtsLen() > 0 || Engine.totalBuilds > 0
                    onClicked:
                        Engine.openInFileManager(Engine.outputDir)
                }
            }
        }

        // ------------------- действие и статус -------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            GradientButton {
                id: buildBtn
                text: Engine.building ? qsTr("Идёт сборка…")
                                      : qsTr("Собрать пакет")
                implicitHeight: 48
                Layout.preferredWidth: 210
                enabled: !Engine.building && Engine.rpmbuildPath !== ""
                onClicked: {
                    logModel.clear();
                    Engine.startBuild();
                }
            }

            FlatButton {
                text: qsTr("Отменить")
                tone: "danger"
                visible: Engine.building
                onClicked: Engine.cancelBuild()
            }

            // кольцевой индикатор + таймер
            Item {
                visible: Engine.building
                width: 26; height: 26
                Layout.alignment: Qt.AlignVCenter

                RotationAnimation on rotation {
                    running: Engine.building
                    from: 0; to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Theme.accentText;
                        ctx.lineWidth = 2.6;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(width/2, height/2, width/2 - 3,
                                -Math.PI/2, Math.PI * 0.75);
                        ctx.stroke();
                    }
                }
                Text {
                    anchors.left: parent.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 сек").arg(Engine.elapsedSec)
                    font.family: Theme.monoFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }
            }

            Item { Layout.fillWidth: true }

            // сводка по текущим ошибкам валидации
            Rectangle {
                visible: page.blocked
                width: blockLbl.implicitWidth + 34
                height: 34
                radius: 17
                color: Theme.warningSoft
                border.color: Qt.rgba(Theme.warning.r, Theme.warning.g,
                                      Theme.warning.b, 0.5)

                Text {
                    id: blockLbl
                    anchors.centerIn: parent
                    text: qsTr("Исправьте ошибки формы перед сборкой")
                    color: Theme.isDark ? "#FFE9A6" : "#7A5B00"
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                }
            }

            property real dummy: 0
        }

        // ------------------- rpmbuild не установлен -------------------
        SectionCard {
            Layout.fillWidth: true
            visible: Engine.rpmbuildPath === ""
            title: qsTr("rpmbuild не найден — сборка невозможна")
            implicitHeight: 236

            ColumnLayout {
                x: 16; y: 44
                width: parent.width - 32
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: qsTr("rpmbuild — утилита, которая собирает .rpm. "
                               + "Установите пакет с ней одной командой:")
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    text: "РЕД ОС / МСВС / РЕД АДМ:  sudo dnf install rpm-build"
                    font.family: Theme.monoFamily
                    font.pixelSize: 12
                    color: Theme.danger
                }
                Text {
                    Layout.fillWidth: true
                    text: "Astra / Debian / Ubuntu:  sudo apt install rpm"
                    font.family: Theme.monoFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("После установки нажмите «Проверить снова» — "
                               + "перезапускать приложение не нужно.")
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
                FlatButton {
                    text: qsTr("Проверить снова")
                    onClicked: Engine.recheckRpmbuild()
                }
            }
        }

        // ------------------- почему сборка заблокирована -------------------
        SectionCard {
            Layout.fillWidth: true
            visible: page.blocked
            title: qsTr("Почему сборка не запускается")
            implicitHeight: Math.max(
                168,
                104 + Engine.validationIssues.filter(
                          i => i.level === "error").length * 26)

            ColumnLayout {
                x: 16; y: 44
                width: parent.width - 32
                spacing: 4

                Repeater {
                    model: Engine.validationIssues.filter(
                               i => i.level === "error")

                    delegate: Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "✗ " + modelData.message
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: Theme.danger
                        wrapMode: Text.WrapAnywhere
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: qsTr("Исправьте пункты выше на вкладках «Обзор» "
                               + "(название, версия, описание) и «Файлы "
                               + "пакета» — сборка станет доступна.")
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ------------------- артефакты после успеха -------------------
        RowLayout {
            Layout.fillWidth: true
            visible: Engine.lastArtifacts.length > 0
            spacing: 10

            Repeater {
                model: Engine.lastArtifacts

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    height: 64
                    radius: Theme.radiusCtl
                    color: Theme.surface
                    border.color: Qt.rgba(Theme.success.r, Theme.success.g,
                                          Theme.success.b, 0.45)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 12

                        Rectangle {
                            width: 34; height: 34; radius: 9
                            color: Theme.successSoft
                            Rectangle {
                                anchors.centerIn: parent
                                width: 4; height: 12; radius: 2
                                color: Theme.success
                            }
                            Rectangle {
                                x: 9; y: 18
                                width: 16; height: 3; radius: 1.5
                                color: Theme.success
                                rotation: 45
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            Text {
                                text: fileNameOf(modelData.path)
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.text
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.human + qsTr(" • нажмите, чтобы открыть папку")
                                font.family: Theme.uiFamily
                                font.pixelSize: 10
                                color: Theme.textFaint
                            }
                        }

                        MouseArea {
                            Layout.preferredWidth: 120
                            Layout.fillHeight: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked:
                                Engine.openInFileManager(modelData.path)
                        }
                    }
                }
            }

            function lastArtsLen_dmy() {}
        }

        // ------------------- разбор ошибок сборки -------------------
        SectionCard {
            Layout.fillWidth: true
            visible: !Engine.building && Engine.lastBuildCancelled
            title: qsTr("Сборка была отменена")

            Text {
                x: 16; y: 44
                width: parent.width - 32
                text: qsTr("Процесс rpmbuild был остановлен по вашей команде. "
                           + "Черновик проекта сохранён — можно поправить "
                           + "настройки и собрать пакет заново.")
                font.family: Theme.uiFamily
                font.pixelSize: 12
                color: Theme.textDim
                wrapMode: Text.WordWrap
            }
        }

        SectionCard {
            id: errCard
            Layout.fillWidth: true
            visible: !Engine.building && !Engine.lastBuildCancelled
                     && Engine.lastBuildErrors.length > 0
            title: qsTr("Почему сборка не удалась")
            implicitHeight: Math.min(300,
                74 + Engine.lastBuildErrors.length * 24 + errHint.implicitHeight + 26)

            function hintFor(errors) {
                const all = errors.join("\n").toLowerCase();
                if (all.indexOf("no such file") >= 0
                        || all.indexOf("file not found") >= 0
                        || all.indexOf("нет такого файла") >= 0)
                    return qsTr("Файл не найден: проверьте пути на вкладке «Файлы пакета» и каталог установки у каждого файла.");
                if (all.indexOf("installed (but unpackaged") >= 0)
                    return qsTr("Есть файлы, не внесённые в %files: задайте правильный «каталог установки» на вкладке «Файлы пакета».");
                if (all.indexOf("failed build dependencies") >= 0)
                    return qsTr("Не хватает пакетов для сборки: установите их (dnf install …) или уберите лишние BuildRequires.");
                if (all.indexOf("cannot stat") >= 0
                        || all.indexOf("permission denied") >= 0
                        || all.indexOf("отказано в доступе") >= 0)
                    return qsTr("Ошибка доступа в скриптах %install/%files: проверьте пути и права на каталог результатов.");
                if (all.indexOf("file must begin") >= 0
                        || all.indexOf("bad file") >= 0)
                    return qsTr("Некорректный путь в %files: пути должны начинаться с «/» и лежать внутри buildroot.");
                if (all.indexOf("directory not found") >= 0)
                    return qsTr("Каталог не найден: проверьте «Каталог установки» у файлов.");
                return qsTr("Смотрите выделенные строки ниже и полный журнал — обычно причина в первых строках после «error:».");
            }

            ColumnLayout {
                x: 16; y: 44
                width: parent.width - 32
                spacing: 4

                Repeater {
                    model: Engine.lastBuildErrors
                    delegate: Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: Theme.danger
                        wrapMode: Text.WrapAnywhere
                    }
                }

                Text {
                    id: errHint
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: qsTr("Подсказка: ")
                          + errCard.hintFor(Engine.lastBuildErrors)
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ------------------- журнал -------------------
        SectionCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: qsTr("Журнал сборки")

            Item {
                x: 16; y: 44
                width: parent.width - 32
                height: parent.height - 60

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Theme.consoleBg
                    border.color: Theme.hairline
                    border.width: 1
                }

                ListView {
                    id: logView
                    anchors.fill: parent
                    anchors.margins: 10
                    model: logModel
                    clip: true
                    spacing: 1
                    flickDeceleration: 8000

                    delegate: Text {
                        required property string line
                        width: logView.width
                        text: line.replace(/\t/g, "    ") || " "
                        font.family: Theme.monoFamily
                        font.pixelSize: 11
                        color: page.logColor(line)
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                    }
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 5
                            radius: 2.5
                            color: Theme.hairline
                        }
                    }
                }
            }
        }
    }

    function fileNameOf(p) {
        const s = String(p);
        const i = s.lastIndexOf("/");
        return i >= 0 ? s.slice(i + 1) : s;
    }
    function lastArtsLen() { return Engine.lastArtifacts.length }

    // ---- встроенный выбор каталога результатов ----
    function pickOutputDir() {
        Window.window.pick(
            { mode: "folder", title: qsTr("Каталог для готовых .rpm"),
              startDir: Engine.outputDir },
            function(paths) {
                if (paths && paths.length > 0)
                    Engine.outputDir = paths[0];
            });
    }

    property var toastRef: null
}
