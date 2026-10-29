import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  Main — корневой безрамочный тонируемый компонент приложения.
 */
ApplicationWindow {
    id: win

    readonly property color scrimBgA: Theme.bgA
    readonly property color scrimBgB: Theme.bgB

    width: 1280
    height: 832
    minimumWidth: 1080
    minimumHeight: 720
    visible: true
    title: qsTr("RPM Builder")

    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"

    // мост: синглтон оформления следует за настройкой движка
    Binding {
        target: Theme
        property: "isDark"
        value: Engine.darkTheme
    }

    function showPage(idx) {
        // ВАЖНО: sidebar.currentPage НЕ трогаем — он привязан к
        // pagesRoot.currentIndex; прямой сброс ломал бы привязку.
        pagesRoot.currentIndex = idx;
        toast.opacityTarget = 0;
    }

    function showToast(msg, ok) {
        toast.show(msg, ok);
    }

    // результат открытия/сохранения шаблона проекта — всегда показать тост,
    // чтобы пользователь видел и успех, и причину отказа
    Connections {
        target: Engine
        function onProjectIoDone(ok, message) {
            win.showToast(message, ok);
        }
    }

    function showAbout() {
        aboutDialog.open();
    }

    // встроенный выбор файлов/папок (вместо системных диалогов —
    // работает в любой среде, включая Wayland и xdg-порталы)
    function pick(opts, cb) {
        filePicker.openFor(opts, cb);
    }

    // вспомогательные для режима скриншотов (--shots)
    function openPickerForShots() {
        filePicker.openFor(
            { mode: "openFiles", title: qsTr("Выберите файлы пакета") }, null);
    }
    function closePickerForShots() {
        filePicker.visible = false;
    }

    // функциональный тест пикера (--picktest): навигация, выделение,
    // режимы openFiles/folder/saveFile
    function pickTest() {
        // этап C: сохранение с авто-расширением
        const stageC = function(paths) {
            console.log("PICKTEST-C:", JSON.stringify(paths));
            console.log("PICKTEST:",
                (paths.length === 1
                 && paths[0] === "/tmp/rb-picktest/result.spec")
                ? "PASS" : "FAIL");
            Qt.quit();
        };
        // этап B: выбор папки
        const stageB = function(paths) {
            console.log("PICKTEST-B:", JSON.stringify(paths));
            filePicker.openFor(
                { mode: "saveFile", title: "t",
                  defaultName: "result", filterExts: [".spec"],
                  startDir: "/tmp/rb-picktest" }, stageC);
            filePicker.acceptSelection();
        };
        // этап A: несколько файлов
        filePicker.openFor(
            { mode: "openFiles", title: "t", startDir: "/tmp/rb-picktest" },
            function(paths) {
                console.log("PICKTEST-A:", JSON.stringify(paths));
                filePicker.openFor(
                    { mode: "folder", title: "t",
                      startDir: "/tmp/rb-picktest" }, stageB);
                filePicker.toggleSel("/tmp/rb-picktest/sub");
                filePicker.acceptSelection();
            });
        filePicker.toggleSel("alpha.txt");
        filePicker.acceptSelection();
    }

    // ---- мягкий градиентный фон окна ----
    Rectangle {
        id: windowChrome
        anchors.fill: parent
        radius: Theme.radiusWin
        border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.09)
                                   : Qt.rgba(20, 22, 40, 0.16)
        border.width: 1

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: win.scrimBgB }
            GradientStop { position: 1; color: win.scrimBgA }
        }

        // тёплое свечение в левом верхнем углу
        Rectangle {
            x: -120; y: -140
            width: 460; height: 340; radius: 170

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                                   Theme.accent1.b,
                                   Theme.isDark ? 0.30 : 0.18)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                                   Theme.accent1.b, 0)
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            TitleBar {
                Layout.fillWidth: true
                win: win
                onAboutClicked: aboutDialog.open()
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.hairline }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                SideBar {
                    id: sidebar
                    Layout.preferredWidth: Theme.sidebarW
                    Layout.fillHeight: true
                    currentPage: pagesRoot.currentIndex
                    onCurrentPageChangedExternally: (idx) => win.showPage(idx)
                }

                Rectangle { width: 1; Layout.fillHeight: true;
                            color: Theme.hairlineSoft }

                // ---------------- контент страниц ----------------
                Item {
                    id: pagesRoot
                    objectName: "pagesRoot"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    property int currentIndex: 0

                    component PageHost: Item {
                        default property alias data_: inner.data
                        property int idx: 0
                        readonly property bool isCurrent:
                            pagesRoot.currentIndex === idx

                        anchors.fill: parent
                        visible: opacity > 0.01
                        opacity: isCurrent ? 1 : 0
                        scale: isCurrent ? 1 : 0.985

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animMid }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animMid
                                easing.type: Easing.OutCubic
                            }
                        }

                        Item { id: inner; anchors.fill: parent }
                    }

                    PageHost {
                        idx: 0
                        DashboardPage {
                            anchors.fill: parent
                            goPage: (i) => win.showPage(i)
                        }
                    }
                    PageHost {
                        idx: 1
                        MetaPage {
                            anchors.fill: parent
                            goPage: (i) => win.showPage(i)
                        }
                    }
                    PageHost {
                        idx: 2
                        FilesPage {
                            anchors.fill: parent
                            toastRef: toast
                        }
                    }
                    PageHost {
                        idx: 3
                        DepsPage { anchors.fill: parent }
                    }
                    PageHost {
                        idx: 4
                        ScriptsPage { anchors.fill: parent }
                    }
                    PageHost {
                        idx: 5
                        SpecPage {
                            anchors.fill: parent
                            toastRef: toast
                        }
                    }
                    PageHost {
                        idx: 6
                        BuildPage {
                            anchors.fill: parent
                            toastRef: toast
                        }
                    }
                }
            }
        }
    }

    // встроенный пикер файлов (см. pick()) — под всплывающим toast
    FilePicker { id: filePicker }

    Toast { id: toast }

    AboutDialog { id: aboutDialog }
}
