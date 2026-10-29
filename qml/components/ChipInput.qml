import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import RpmBuilder

/*
 *  ChipInput — редактор списка «чипами» (зависимости Requires и т.п.).
 *  Enter / запятая / точка с запятой добавляют элемент, Backspace удаляет.
 */
Rectangle {
    id: box

    property string engineKey: ""        // requires | buildRequires | provides
    property string placeholder: ""

    readonly property var model: {
        const list = engineKey === "requires" ? Engine.requiresList() :
                     engineKey === "buildRequires" ? Engine.buildRequiresList() :
                     Engine.providesList()
        return list.slice()
    }

    radius: Theme.radiusCtl
    color: Theme.field
    border.width: input.activeFocus ? 1.6 : 1
    border.color: input.activeFocus ? Theme.accent1 : Theme.hairline
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    height: Math.max(40, flow.implicitHeight + 14)

    function commit(textValue) {
        const t = textValue.trim().replace(/[,;]+$/, "").trim();
        if (t.length === 0)
            return;
        const next = model.slice();
        if (!next.includes(t))
            next.push(t);
        Engine.setDepList(engineKey, next);
        input.clear();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    Flow {
        id: flow
        x: 7; y: 7
        width: parent.width - 14
        spacing: 6

        Repeater {
            model: box.model

            delegate: Rectangle {
                required property string modelData
                required property int index

                width: chipLabel.implicitWidth + 34
                height: 26
                radius: 13

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accentSoft }
                    GradientStop {
                        position: 1
                        color: Qt.lighter(Theme.accent2,
                                          Theme.isDark ? 0.95 : 0.55)
                    }
                }
                border.color: Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                                      Theme.accent1.b, 0.35)
                border.width: 1

                Text {
                    id: chipLabel
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    text: parent.modelData
                    font.family: Theme.monoFamily
                    font.pixelSize: 12
                    color: Theme.isDark ? "#D6D9FF" : "#393B99"
                }
                Text {
                    id: xBtn
                    x: parent.width - 20; y: 6.5
                    text: "\u2715"
                    font.pixelSize: 9
                    font.family: Theme.uiFamily
                    color: mhov.containsMouse ? Theme.danger : Theme.textDim
                }
                MouseArea {
                    id: mhov
                    anchors.centerIn: xBtn
                    width: 22; height: 22
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        const next = box.model.slice();
                        next.splice(index, 1);
                        Engine.setDepList(box.engineKey, next);
                    }
                }
            }
        }

        TextInput {
            id: input
            font.family: Theme.uiFamily
            font.pixelSize: 13
            color: Theme.text
            cursorVisible: activeFocus
            autoScroll: false
            clip: true
            width: Math.max(120, implicitWidth + 10)

            Keys.onReturnPressed: (ev) => { box.commit(text); ev.accepted = true }
            Keys.onEnterPressed:  (ev) => { box.commit(text); ev.accepted = true }

            Keys.onPressed: (ev) => {
                if (text.trim() === "" && ev.key === Qt.Key_Backspace &&
                    box.model.length > 0) {
                    const next = box.model.slice();
                    next.pop();
                    Engine.setDepList(box.engineKey, next);
                    ev.accepted = true;
                }
            }
            onTextEdited: () => {
                if (/[;,]\s*$/.test(text)) box.commit(text)
            }
        }
    }

    Text {
        visible: box.model.length === 0 && input.text === ""
        x: 14; y: 13
        text: box.placeholder
        font.family: Theme.uiFamily
        font.pixelSize: 13
        color: Theme.textFaint
    }
}
