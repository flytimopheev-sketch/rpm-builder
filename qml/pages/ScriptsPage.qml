import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  ScriptsPage — редактор скриплетов %pre/%post/%preun/%postun
 *  и секций сборки из исходников %build/%install/%files.
 */
Item {
    id: page
    clip: true

    readonly property var sections:
        ["pre", "post", "preun", "postun", "build", "install", "files"]
    property int activeIdx: 1        // стартуем на самом частом %post

    readonly property var captions: {
        "pre":   qsTr("выполняется перед установкой файлов"),
        "post":  qsTr("после распаковки файлов"),
        "preun": qsTr("перед удалением пакета"),
        "postun": qsTr("после удаления пакета"),
        "build":   qsTr("компиляция при сборке RPM: cargo build, go build, make, gcc…"),
        "install": qsTr("что и куда положить в пакет; если пусто — файлы копируются автоматически"),
        "files":   qsTr("список файлов пакета; если пусто — составляется автоматически")
    }
    readonly property var samples: {
        "pre": "#!/bin/sh\n/usr/bin/systemctl stop myapp.service || true\nexit 0\n",
        "post": "#!/bin/sh\nif [ -f /usr/lib/systemd/system/myapp.service ]; then\n" +
                "    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || true\nfi\nexit 0\n",
        "preun": "#!/bin/sh\nif [ \"$1\" = \"0\" ]; then\n" +
                 "    /usr/bin/systemctl disable --now myapp.service >/dev/null 2>&1 || true\nfi\nexit 0\n",
        "postun": "#!/bin/sh\nexit 0\n",
        "build": "# Rust: проект добавлен на странице «Файлы» целиком\n" +
                 "# Рабочий каталог пуст, поэтому переходим к источникам:\ncd %{_sourcedir}/myapp\n" +
                 "cargo build --release\n" +
                 "# Go:  cd %{_sourcedir}/myapp && go build -o myapp ./cmd/myapp\n" +
                 "# C:   gcc %{_sourcedir}/myapp/main.c -O2 -o myapp\n",
        "install": "install -Dm755 %{_sourcedir}/myapp/target/release/myapp \\\n    %{buildroot}%{_bindir}/myapp\n",
        "files": "%{_bindir}/myapp\n"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: qsTr("Скрипты и сборка")
                font.family: Theme.uiFamily
                font.pixelSize: 19
                font.weight: Font.Bold
                color: Theme.text
                Layout.fillWidth: true
            }
            FlatButton {
                text: qsTr("Вставить пример")
                visible: Engine.script(sections[page.activeIdx]) === ""
                onClicked: Engine.setScript(sections[page.activeIdx],
                                            page.samples[sections[page.activeIdx]])
            }
        }

        // ---- сегментированные табы ----
        Rectangle {
            Layout.fillWidth: true
            height: 46
            radius: 12
            color: Theme.field
            border.color: Theme.hairline
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 6

                Repeater {
                    model: page.sections

                    delegate: Item {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: "transparent"

                            // градиентная заливка активного таба
                            Rectangle {
                                visible: page.activeIdx === parent.index
                                anchors.fill: parent
                                radius: 9
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Theme.accentSoft }
                                    GradientStop { position: 1;
                                        color: Qt.rgba(Theme.accent2.r,
                                                       Theme.accent2.g,
                                                       Theme.accent2.b, 0.12) }
                                }
                            }
                            border.width: page.activeIdx === parent.index ? 1.4 : 0
                            border.color:
                                page.activeIdx === parent.index ? Theme.accentText
                                                                : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "%" + modelData
                            font.family: Theme.monoFamily
                            font.pixelSize: 13
                            font.weight: page.activeIdx === parent.index ?
                                             Font.DemiBold : Font.Medium
                            color: page.activeIdx === parent.index
                                   ? Theme.text : Theme.textDim
                        }

                        // индикатор «скрипт непустой»
                        Rectangle {
                            x: parent.width / 2 + implicitWidth + 22
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.success
                            visible:
                                Engine.script(modelData) !== "" &&
                                page.activeIdx !== index
                        }

                        MouseArea {
                            id: tabZone
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.activeIdx = index
                        }
                    }
                }
            }
        }

        Text {
            text: captions[sections[activeIdx]]
            font.family: Theme.uiFamily
            font.pixelSize: 12
            color: Theme.textFaint
        }

        SectionCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "%" + sections[activeIdx]
            caption: qsTr("bash-подобный синтаксис")

            AppTextArea {
                x: 16; y: 44
                width: parent.width - 32
                height: parent.height - 60
                mono: true
                placeholder: {
                    const k = sections[page.activeIdx];
                    if (k === "build")
                        return qsTr("# Команды выполняются во время rpmbuild…\n" +
                                    "# Источники лежат в %{_sourcedir}, рабочий каталог пуст:\n" +
                                    "cd %{_sourcedir}/имя_проекта\nmake %{?_smp_mflags}");
                    if (k === "install")
                        return qsTr("# Если пусто — добавленные файлы копируются автоматически\n" +
                                    "# Пример:\ninstall -Dm755 %{_sourcedir}/proj/app \\\n    %{buildroot}%{_bindir}/app");
                    if (k === "files")
                        return qsTr("# Если пусто — список составится автоматически\n" +
                                    "# Пример:\n%{_bindir}/app");
                    return qsTr("# Скрипт выполняется в chroot целевой системы…\n" +
                                "# $1 = число пакетов той же версии, остающихся в системе");
                }
                text: Engine.script(sections[page.activeIdx])
                onTextChanged: {
                    const key = sections[page.activeIdx];
                    if (Engine && Engine.script(key) !== text)
                        Engine.setScript(key, text);
                }
            }
        }
    }
}
