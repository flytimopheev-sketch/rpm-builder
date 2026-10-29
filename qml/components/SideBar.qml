import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore
import RpmBuilder

/*
 *  SideBar — панель навигации со списком разделов и блоком статистики.
 */
Rectangle {
    id: sidebar
    objectName: "sideBar"

    property int currentPage: 0

    color: "transparent"
    width: Theme.sidebarW

    readonly property var sections: [
        { icon: "overview", label: qsTr("Обзор") },
        { icon: "meta",     label: qsTr("Метаданные") },
        { icon: "files",    label: qsTr("Файлы пакета") },
        { icon: "deps",     label: qsTr("Зависимости") },
        { icon: "scripts",  label: qsTr("Скрипты") },
        { icon: "spec",     label: qsTr("SPEC-файл") },
        { icon: "build",    label: qsTr("Сборка") }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // ---- карточка текущего проекта ----
        SectionCard {
            Layout.fillWidth: true
            height: 78
            title: ""
            caption: ""

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 4

                Text {
                    text: Engine.name === ""
                          ? qsTr("Новый проект")
                          : Engine.projectName()
                    font.family: Theme.uiFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text
                    elide: Text.ElideMiddle
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: {
                        const lic = Engine.license;
                        const files = Engine.fileList.length;
                        return lic + " • файлов: " + files;
                    }
                    font.family: Theme.uiFamily
                    font.pixelSize: 11
                    color: Theme.textFaint
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ---- пункты навигации ----
        Repeater {
            model: sidebar.sections

            delegate: NavButton {
                required property var modelData
                required property int index
                objectName: "navButton-" + index
                Layout.fillWidth: true
                label: modelData.label
                icon: modelData.icon
                navIndex: index
                active: sidebar.currentPage === index
                onNavigate: (idx) => currentPageChangedExternally(idx)
            }
            onItemAdded: (idx, obj) => {}
        }

        // ---- шаблоны проектов (*.rpmb.json) ----
        Text {
            Layout.fillWidth: true
            leftPadding: 8
            topPadding: 6
            text: qsTr("ШАБЛОН ПРОЕКТА")
            font.family: Theme.uiFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            color: Theme.textFaint
        }
        FlatButton {
            Layout.fillWidth: true
            text: qsTr("Открыть из файла…")
            onClicked: Window.window.pick(
                { mode: "openFile",
                  title: qsTr("Открыть шаблон проекта (*.rpmb.json)"),
                  startDir: StandardPaths.writableLocation(
                                StandardPaths.DocumentsLocation),
                  filterExts: [".rpmb.json", ".json"],
                  filterLabel: qsTr("Шаблоны RPM Builder (*.rpmb.json)") },
                function(paths) {
                    if (paths && paths.length > 0)
                        Engine.loadProjectFromFile(paths[0]);
                })
        }
        FlatButton {
            Layout.fillWidth: true
            text: qsTr("Сохранить в файл…")
            onClicked: {
                const base = Engine.name === ""
                    ? "проект"
                    : (Engine.name + "-" + Engine.version)
                          .replace(/[^A-Za-z0-9._+-]/g, "-");
                const fname = base + ".rpmb.json";
                Window.window.pick(
                    { mode: "saveFile",
                      title: qsTr("Сохранить шаблон проекта (*.rpmb.json)"),
                      defaultName: fname,
                      startDir: StandardPaths.writableLocation(
                                    StandardPaths.DocumentsLocation),
                      filterExts: [".rpmb.json"],
                      filterLabel: qsTr("Шаблоны RPM Builder (*.rpmb.json)") },
                    function(paths) {
                        if (paths && paths.length > 0)
                            Engine.saveProjectToFile(paths[0]);
                    });
            }
        }

        Item { Layout.fillHeight: true }

        // ---- мини-статистика ----
        Rectangle {
            Layout.fillWidth: true
            height: statsEmpty ? 58 : 74
            radius: Theme.radiusCard
            color: Theme.field
            border.color: Theme.hairline
            border.width: 1

            readonly property bool statsEmpty: Engine.totalBuilds === 0

            Column {
                anchors.centerIn: parent
                spacing: 5
                width: parent.width - 20

                visible: true

                Text {
                    visible: !parent.parent.statsEmpty
                    text: qsTr("Всего сборок: %1").arg(Engine.totalBuilds)
                    font.family: Theme.uiFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    visible: !parent.parent.statsEmpty
                    text: Engine.lastBuildAt !== ""
                          ? formatWhen(Engine.lastBuildAt)
                          : ""
                    font.family: Theme.uiFamily
                    font.pixelSize: 11
                    color: Theme.textFaint
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    visible: parent.parent.statsEmpty
                    text: qsTr("Пока ни одной сборки")
                    font.family: Theme.uiFamily
                    font.pixelSize: 11
                    color: Theme.textFaint
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
                Row {
                    visible: !parent.parent.statsEmpty &&
                             Engine.lastRpmBytes > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Rectangle {
                        width: 7; height: 7; radius: 3.5
                        color: Engine.lastBuildOk ? Theme.success : Theme.danger
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: qsTr("%1 в последнем архиве")
                                  .arg(fmtBytes(Engine.lastRpmBytes))
                        font.family: Theme.uiFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                }
            }
        }
    }

    function formatWhen(iso) {
        const d = new Date(iso);
        if (isNaN(d.getTime()))
            return "";
        const loc = Qt.locale();
        return d.toLocaleString(loc, "d MMM, HH:mm");
    }
    function fmtBytes(b) {
        b = Math.max(0, Number(b));
        if (b < 1024) return b + " Б";
        if (b < 1024 * 1024) return Math.round(b / 1024) + " КБ";
        return (b / (1024 * 1024)).toFixed(1) + " МБ";
    }

    // ---- реакция на операции с шаблонами: всплывающее уведомление,
    //      после успешной загрузки — переход к «Метаданные» ----
    Connections {
        target: Engine
        function onProjectIoDone(ok, message) {
            const win = sidebar.Window.window;
            if (win && win.showToast)
                win.showToast(message, ok);
            if (ok && message.indexOf("загружен") >= 0)
                currentPageChangedExternally(1);
        }
    }

    signal currentPageChangedExternally(int idx)
}
