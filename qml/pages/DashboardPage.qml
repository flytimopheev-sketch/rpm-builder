import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  DashboardPage — обзор: приветствие, статистика сборок, недавние проекты.
 */
ScrollView {
    id: page
    clip: true

    property var goPage: null        // функция перехода, задаётся в Main

    function fmtWhen(iso) {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? "" : d.toLocaleString(Qt.locale(), "d MMM yyyy, HH:mm");
    }
    function fmtBytes(b) {
        b = Math.max(0, Number(b));
        if (b < 1024) return b + " Б";
        if (b < 1024 * 1024) return (b / 1024).toFixed(0) + " КБ";
        return (b / 1024 / 1024).toFixed(1) + " МБ";
    }
    function fmtSecs(s) {
        s = Number(s);
        return s >= 10 ? s.toFixed(0) : s.toFixed(1);
    }

    contentWidth: availableWidth

    ColumnLayout {
        id: content
        x: 26; y: 22
        width: page.width - 52
        spacing: 16

        // ------------------------- приветствие -------------------------
        Rectangle {
            Layout.fillWidth: true
            height: 148
            radius: Theme.radiusCard
            border.color: Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                                  Theme.accent1.b, 0.35)
            border.width: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;
                    color: Theme.isDark ? "#2A2C6B" : "#DDE1FD" }
                GradientStop { position: 0.55;
                    color: Theme.isDark ? "#3A2372" : "#EBDDFB" }
                GradientStop { position: 1.0;
                    color: Theme.isDark ? "#23253F" : "#F3ECFC" }
            }

            // декоративные окружности
            Repeater {
                model: [
                    [260, -60, 150], [230, 90, 90], [-40, 110, 120]
                ]
                delegate: Rectangle {
                    x: parent.width - modelData[0]
                    y: modelData[1] === undefined ? 0 : modelData[1]
                    anchors.verticalCenterOffset: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: modelData[2]; height: modelData[2]; radius: modelData[2]/2
                    color: "transparent"
                    border.color: "#FFFFFF"
                    border.width: 1
                    opacity: Theme.isDark ? 0.10 : 0.35
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 24

                ColumnLayout {
                    spacing: 6
                    Layout.fillWidth: true

                    Text {
                        text: qsTr("Собирайте RPM — не изучая rpmbuild")
                        font.family: Theme.uiFamily
                        font.pixelSize: 21
                        font.weight: Font.Bold
                        color: Theme.isDark ? "#FFFFFF" : "#191A66"
                    }
                    Text {
                        text: qsTr("Заполните карточку пакета, перетащите файлы и нажмите «Собрать». SPEC-файл сгенерируется автоматически.")
                        font.family: Theme.uiFamily
                        font.pixelSize: 13
                        color: Theme.isDark ? "#C9CCF4" : "#3C3E80"
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 520
                        lineHeight: 1.25
                    }
                }

                GradientButton {
                    text: qsTr("Новый проект")
                    implicitWidth: 172
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        Engine.resetProject();
                        if (page.goPage) page.goPage(1);
                    }
                }
            }
        }

        // ------------------------- статистика -------------------------
        GridLayout {
            Layout.fillWidth: true
            columns: {
                const w = page.width;
                return w > 1180 ? 4 : (w > 860 ? 2 : 1);
            }
            columnSpacing: 14
            rowSpacing: 14

            StatCard {
                Layout.fillWidth: true; height: 84
                value: String(Engine.totalBuilds)
                label: qsTr("всего сборок")
                tint: Theme.accent1
            }
            StatCard {
                Layout.fillWidth: true; height: 84
                value: Engine.lastBuildAt !== ""
                       ? page.fmtSecs(Engine.lastBuildSeconds) + qsTr(" сек")
                       : "—"
                label: qsTr("время последней сборки")
                tint: Theme.info
            }
            StatCard {
                Layout.fillWidth: true; height: 84
                value: Engine.lastRpmBytes > 0
                       ? page.fmtBytes(Engine.lastRpmBytes) : "—"
                label: qsTr("размер последнего RPM")
                tint: Theme.accent2
            }
            StatCard {
                Layout.fillWidth: true; height: 84
                value: Engine.lastBuildAt !== ""
                       ? page.fmtWhen(Engine.lastBuildAt) : "—"
                valueSize: 15
                label: qsTr("дата последней сборки")
                tint: Engine.totalBuilds > 0 && !Engine.lastBuildOk
                      ? Theme.danger : Theme.success
            }
        }

        // ------------------------- недавние проекты -------------------------
        SectionCard {
            id: cardRecents
            Layout.fillWidth: true
            title: qsTr("Недавние проекты")
            caption: Engine.recentProjects.length > 0
                     ? qsTr("%1 шт.").arg(Engine.recentProjects.length) : ""

            implicitHeight: recentsHolder.height + (title !== "" ? 70 : 46)
            height: implicitHeight

            function surfaceTintDummy() {}

            Item {
                id: recentsHolder
                anchors.left: parent.left
                anchors.right: parent.right
                y: 44

                readonly property int n: Engine.recentProjects.length
                height: n > 0 ? n * 72 + (n - 1) * 9 : 130

                Column {
                    id: stackCol
                    width: parent.width
                    spacing: 0

                // пустое состояние
                Column {
                    visible: Engine.recentProjects.length === 0
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: parent.width
                        height: 108
                        radius: Theme.radiusCtl
                        border.color: Theme.hairline
                        border.width: 1
                        color: Theme.field

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Здесь появятся ваши проекты")
                                font.family: Theme.uiFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Theme.textDim
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Соберите первый пакет — история сохранится автоматически")
                                font.family: Theme.uiFamily
                                font.pixelSize: 11
                                color: Theme.textFaint
                            }
                        }
                    }
                }

                // список проектов
                Column {
                    id: listCol
                    visible: Engine.recentProjects.length > 0
                    width: parent.width
                    spacing: 9

                    Repeater {
                        model: Engine.recentProjects.slice().reverse()

                        delegate: Rectangle {
                            required property var modelData
                            required property int index


                            readonly property var snap: modelData
                            readonly property int trueIdx:
                                Engine.recentProjects.length - 1 - index
                            readonly property string status:
                                snap.lastOk === undefined ? "?"
                                    : (snap.lastOk ? "ok" : "fail")

                            width: parent.width
                            height: 72
                            radius: Theme.radiusCtl
                            color: rHover.containsMouse ? Theme.surface2
                                                        : Theme.field
                            border.color: Theme.hairline
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            MouseArea {
                                id: rHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 12
                                spacing: 14

                                Rectangle {
                                    width: 38; height: 38; radius: 10
                                    color: status === "ok" ? Theme.successSoft :
                                           status === "fail" ? Theme.dangerSoft :
                                                               Theme.accentSoft
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10; height: 10; radius: 5
                                        color: status === "ok" ? Theme.success :
                                               status === "fail" ? Theme.danger :
                                                                   Theme.accentText
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true

                                    Text {
                                        text: (snap.name || "?") + "-" +
                                              (snap.version || "") + "-" +
                                              (snap.release || "")
                                        font.family: Theme.monoFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                    }
                                    Row {
                                        spacing: 10
                                        Text {
                                            text: [snap.license,
                                                   qsTr("файлов: ") +
                                                   (snap.files?.length ?? 0)]
                                                  .filter(Boolean)
                                                  .join(" • ")
                                            font.family: Theme.uiFamily
                                            font.pixelSize: 11
                                            color: Theme.textFaint
                                        }
                                    }
                                }

                                Text {
                                    text: snap.savedAt ?
                                          page.fmtWhen(snap.savedAt) : ""
                                    font.family: Theme.uiFamily
                                    font.pixelSize: 11
                                    color: Theme.textFaint
                                }

                                FlatButton {
                                    text: qsTr("Открыть")
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: {
                                        Engine.loadProject(trueIdx);
                                        if (page.goPage) page.goPage(1);
                                    }
                                }
                                Rectangle {
                                    width: 28; height: 28; radius: 7
                                    color: delHov.containsMouse ?
                                               Theme.dangerSoft : "transparent"
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u2715"
                                        font.pixelSize: 10
                                        color: delHov.containsMouse ?
                                                   Theme.danger : Theme.textDim
                                    }
                                    MouseArea {
                                        id: delHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Engine.deleteProject(trueIdx)
                                    }
                                }
                            }
                        }
                    }
                }
                } // stackCol
            }
        }

        // отступ снизу прокрутки
        Item { height: 20; Layout.fillWidth: true }
    }
}
