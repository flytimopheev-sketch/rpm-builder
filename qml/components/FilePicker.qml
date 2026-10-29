import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore
import RpmBuilder

/*
 *  FilePicker — встроенный выбор файлов/папок поверх окна приложения.
 *
 *  Заменяет системные QtQuick.Dialogs (FileDialog/FolderDialog), которые
 *  в некоторых окружениях (Wayland, xdg-порталы, редкие темы) молча
 *  не открываются. Этот пикер — обычный QML-оверлей, работает всегда.
 *
 *  Режимы: "openFiles" (несколько файлов) | "openFile" (один файл)
 *          "folder" (папка) | "saveFile" (сохранить как)
 *
 *  Использование:
 *      picker.openFor({ mode:"openFiles", title:"..." }, function(paths) {...})
 */
Rectangle {
    id: root

    // ---- публичный API -----------------------------------------------------
    function openFor(opts, cb) {
        mode        = opts.mode || "openFiles";
        dialogTitle = opts.title || "";
        filterExts  = opts.filterExts || [];
        filterLabel = opts.filterLabel || "";
        defaultName = opts.defaultName || "";
        cbFn        = cb;

        let start = opts.startDir || "";
        if (start === "" || !Engine.isDirPath(start))
            start = Engine.homeDir();
        currentDir = start;
        selOrder = [];
        selMap = {};
        visible = true;
        showHidden = false;
        refresh();
        if (mode === "saveFile") {
            nameField.text = defaultName;
            nameField.selectAllText();
        } else {
            pathField.forceActiveFocus();
        }
    }

    function cancel() { visible = false; if (cbFn) { const f = cbFn; cbFn = null; f([]); } }

    // ---- состояние ---------------------------------------------------------
    property string mode: "openFiles"
    property string dialogTitle: ""
    property var    filterExts: []
    property string filterLabel: ""
    property string defaultName: ""
    property var    cbFn: null
    property string currentDir: Engine.homeDir()
    property bool   showHidden: false
    property var    selMap: ({})          // выделение: имя -> true
    property var    selOrder: []          // порядок выделения

    readonly property bool saveMode: mode === "saveFile"
    readonly property bool folderMode: mode === "folder"
    readonly property bool multiMode: mode === "openFiles"

    readonly property string selectedDir: {
        if (!folderMode) return currentDir;
        return selOrder.length === 1 ? selOrder[0] : currentDir;
    }

    function refresh() {
        entries.clear();
        const list = Engine.listDir(currentDir, showHidden);
        for (let i = 0; i < list.length; ++i) {
            const e = list[i];
            if (!e.isDir && filterExts.length > 0) {
                const nm = e.name.toLowerCase();
                let ok = false;
                for (let j = 0; j < filterExts.length; ++j)
                    if (nm.endsWith(filterExts[j].toLowerCase())) { ok = true; break; }
                if (!ok) continue;
            }
            entries.append(e);
        }
        pathField.text = currentDir;
        pathError = false;
    }

    function go(p) {
        p = String(p).replace(/~(?=\/|$)/, Engine.homeDir());
        if (!Engine.isDirPath(p)) { pathError = true; return; }
        currentDir = p;
        refresh();
    }

    function joinDir(base, name) {
        return base === "/" ? "/" + name : base + "/" + name;
    }

    function parentOf(p) {
        const i = p.lastIndexOf("/");
        return i <= 0 ? "/" : p.slice(0, i);
    }

    function toggleSel(name) {
        if (selMap[name]) {
            delete selMap[name];
            selOrder = selOrder.filter(n => n !== name);
        } else {
            if (!multiMode) { selMap = {}; selOrder = []; }
            selMap[name] = true;
            selOrder.push(name);
        }
        selMap = Object.assign({}, selMap);   // триггер перерисовки
        selOrder = selOrder.slice();
    }

    function clearSel() { selMap = {}; selOrder = selOrder.slice(); }

    function acceptSelection() {
        const paths = [];
        if (folderMode) {
            paths.push(selectedDir);
        } else if (saveMode) {
            let nm = nameField.text.trim();
            if (nm === "") return;
            if (filterExts.length > 0 && !filterExts.some(
                    e => nm.toLowerCase().endsWith(e.toLowerCase())))
                nm += filterExts[0];
            paths.push(joinDir(currentDir, nm));
        } else {
            for (let i = 0; i < selOrder.length; ++i)
                paths.push(joinDir(currentDir, selOrder[i]));
            if (paths.length === 0) return;
        }
        visible = false;
        if (cbFn) { const f = cbFn; cbFn = null; f(paths); }
    }

    function fmtSize(b) {
        b = Math.max(0, Number(b));
        if (b < 1024) return b + " Б";
        if (b < 1024 * 1024) return Math.max(1, Math.round(b / 1024)) + " КБ";
        return (b / (1024 * 1024)).toFixed(1) + " МБ";
    }

    anchors.fill: parent
    visible: false
    z: 500
    color: Theme.isDark ? Qt.rgba(0.04, 0.05, 0.08, 0.62)
                        : Qt.rgba(0.12, 0.14, 0.22, 0.38)
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    Shortcut {
        sequence: StandardKey.Cancel
        enabled: root.visible
        onActivated: root.cancel()
    }

    // ---- панель --------------------------------------------------------------
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.max(460, Math.min(parent.width - 64, 780))
        height: Math.max(380, Math.min(parent.height - 64, 580))
        radius: Theme.radiusCard
        color: Theme.surface
        border.color: Theme.hairline
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // ---------- заголовок ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Theme.accentText
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: root.dialogTitle !== ""
                          ? root.dialogTitle
                          : (root.folderMode ? qsTr("Выберите папку")
                             : root.saveMode ? qsTr("Сохранить как")
                             : qsTr("Выберите файлы"))
                    font.family: Theme.uiFamily
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: Theme.text
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                FlatButton {
                    text: qsTr("✕")
                    implicitWidth: 36
                    onClicked: root.cancel()
                }
            }

            // ---------- адресная строка ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                FlatButton {
                    text: qsTr("↑ Вверх")
                    enabled: root.currentDir !== "/"
                    onClicked: root.go(root.parentOf(root.currentDir))
                }
                FlatButton {
                    text: qsTr("Домой")
                    onClicked: root.go(Engine.homeDir())
                }
                AppTextField {
                    id: pathField
                    Layout.fillWidth: true
                    error: pathError
                    onEdited: (v) => pathError = false
                    onAccepted: root.go(text.trim())
                }
                FlatButton {
                    text: qsTr("↻")
                    implicitWidth: 36
                    onClicked: root.refresh()
                }
            }

            // ---------- быстрые места ----------
            Flow {
                Layout.fillWidth: true
                spacing: 6

                property var places: [
                    { label: qsTr("Документы"),
                      path: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) },
                    { label: qsTr("Загрузки"),
                      path: StandardPaths.writableLocation(StandardPaths.DownloadLocation) },
                    { label: qsTr("Рабочий стол"),
                      path: StandardPaths.writableLocation(StandardPaths.DesktopLocation) },
                    { label: qsTr("Каталог результатов"), path: Engine.outputDir }
                ]

                Repeater {
                    model: parent.places
                    delegate: FlatButton {
                        required property var modelData
                        text: modelData.label
                        enabled: modelData.path !== ""
                                 && Engine.isDirPath(modelData.path)
                                 && modelData.path !== root.currentDir
                        onClicked: root.go(modelData.path)
                    }
                }
            }

            // ---------- список ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusCtl
                color: Theme.field
                border.color: Theme.hairline
                border.width: 1
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    model: ListModel { id: entries }
                    clip: true
                    flickDeceleration: 8000
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 5; radius: 2.5
                            color: Theme.hairline
                        }
                    }

                    delegate: Rectangle {
                        id: row
                        width: list.width
                        height: 34
                        radius: 7
                        required property var model
                        required property int index

                        readonly property string nm: model.name
                        readonly property bool isDir: model.isDir
                        readonly property bool selected: root.selMap[nm] === true
                        readonly property bool rowSelectable:
                            root.folderMode ? isDir : !isDir

                        color: selected ? Theme.accentSoft
                                        : (rowMa.containsMouse ? Theme.hairlineSoft
                                                               : "transparent")
                        border.color: selected ? Theme.accentText : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            // индикатор выбора / типа
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: row.selected ? Theme.accentText : "transparent"
                                border.color: row.selected ? Theme.accentText
                                                           : Theme.textFaint
                                border.width: 1
                                visible: row.rowSelectable
                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("✓")
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.isDark ? "#15171C" : "#FFFFFF"
                                    visible: row.selected
                                }
                            }

                            // значок типа
                            Rectangle {
                                width: 18; height: 14; radius: 3
                                visible: !row.rowSelectable || row.isDir
                                color: "transparent"
                                border.color: row.isDir ? Theme.accentText
                                                        : Theme.textFaint
                                border.width: 1
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 2
                                    width: 6; height: 3; radius: 1
                                    color: Theme.accentText
                                    visible: row.isDir
                                }
                            }

                            Text {
                                text: row.nm + (row.isDir ? " /" : "")
                                font.family: Theme.monoFamily
                                font.pixelSize: 12
                                color: row.isDir ? Theme.accentText
                                                 : (row.rowSelectable
                                                    ? Theme.text : Theme.textDim)
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            Text {
                                text: row.isDir ? "" : root.fmtSize(model.size)
                                font.family: Theme.uiFamily
                                font.pixelSize: 11
                                color: Theme.textFaint
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (row.isDir) {
                                    if (root.folderMode) {
                                        root.clearSel();
                                        root.toggleSel(root.joinDir(
                                            root.currentDir, row.nm));
                                    } else {
                                        root.go(root.joinDir(
                                            root.currentDir, row.nm));
                                    }
                                } else {
                                    root.toggleSel(row.nm);
                                }
                            }
                            onDoubleClicked: {
                                if (row.isDir) {
                                    root.go(root.joinDir(root.currentDir, row.nm));
                                } else if (!root.folderMode && !root.saveMode) {
                                    root.clearSel();
                                    root.toggleSel(row.nm);
                                    root.acceptSelection();
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: root.showHidden
                              ? qsTr("Папка пуста")
                              : qsTr("Папка пуста (или только скрытые файлы)")
                        color: Theme.textFaint
                        font.family: Theme.uiFamily
                        font.pixelSize: 13
                    }
                }
            }

            // ---------- имя файла (режим сохранения) ----------
            AppTextField {
                id: nameField
                Layout.fillWidth: true
                visible: root.saveMode
                label: qsTr("Имя файла")
                placeholder: qsTr("введите имя файла")
                error: saveMode && text.trim() === ""
                onAccepted: root.acceptSelection()
            }

            Text {
                visible: root.saveMode && nameField.text.trim() !== ""
                         && Engine.pathExists(root.joinDir(
                             root.currentDir, nameField.text.trim()))
                text: qsTr("Файл существует и будет перезаписан")
                color: Theme.warning
                font.family: Theme.uiFamily
                font.pixelSize: 11
                Layout.fillWidth: true
            }

            // ---------- нижняя строка ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: {
                        if (root.folderMode)
                            return root.selectedDir;
                        if (root.multiMode && root.selOrder.length > 0)
                            return qsTr("Выбрано: %1").arg(root.selOrder.length);
                        return root.filterLabel !== "" ? root.filterLabel
                                                       : qsTr("Enter — открыть · Esc — отмена");
                    }
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                    color: Theme.textFaint
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                FlatButton {
                    text: qsTr("Отмена")
                    onClicked: root.cancel()
                }
                GradientButton {
                    text: root.folderMode ? qsTr("Выбрать папку")
                          : root.saveMode ? qsTr("Сохранить")
                          : qsTr("Добавить")
                    implicitWidth: 150
                    enabled: root.folderMode ? true
                             : root.saveMode ? nameField.text.trim() !== ""
                             : root.selOrder.length > 0
                    onClicked: root.acceptSelection()
                }
            }
        }
    }

    property bool pathError: false
}
