import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  AppTextArea — многострочный редактор (описание, скрипты, журнал).
 */
Column {
    id: ctl

    property alias text: area.text
    property alias placeholder: area.placeholderText
    property alias readOnly: area.readOnly
    property alias wrapMode: area.wrapMode
    property string label: ""
    property bool mono: false
    property bool error: false
    spacing: 6

    Text {
        visible: ctl.label !== ""
        text: ctl.label
        font.family: Theme.uiFamily
        font.pixelSize: 12
        font.weight: Font.Medium
        color: Theme.textDim
    }

    Rectangle {
        width: parent.width
        height: parent.height - (ctl.label !== "" ? 24 : 0)
        radius: Theme.radiusCtl
        color: Theme.field
        border.width: area.activeFocus ? 1.6 : 1
        border.color:
            ctl.error ? Theme.danger :
            area.activeFocus ? Theme.accent1 : Theme.hairline
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        ScrollView {
            anchors.fill: parent
            anchors.margins: 2
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded

            TextArea {
                id: area
                font.family: ctl.mono ? Theme.monoFamily : Theme.uiFamily
                font.pixelSize: ctl.mono ? 12.5 : 13.5
                color: Theme.text
                placeholderTextColor: Theme.textFaint
                selectByMouse: true
                selectionColor: Theme.accentSoft
                wrapMode: TextArea.Wrap
                leftPadding: 10
                rightPadding: 10
                topPadding: 8
                bottomPadding: 8
                background: null
            }
        }
    }
}
