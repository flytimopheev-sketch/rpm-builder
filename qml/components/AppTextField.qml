import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  AppTextField — поле ввода с внешней меткой и красной рамкой при ошибке.
 */
Column {
    id: ctl

    property alias text: field.text
    property alias placeholder: field.placeholderText
    property string label: ""
    property bool error: false
    property bool showErrorDot: false
    property alias validator: field.validator
    property alias echoMode: field.echoMode
    signal edited(string value)
    signal accepted()          // Enter во внутреннем поле

    // прокидываем выделение во внутреннее поле (для предзаполнения)
    function selectAllText() { field.selectAll(); field.forceActiveFocus(); }
    spacing: 6

    Row {
        spacing: 5
        visible: label !== ""
        Text {
            text: ctl.label
            font.family: Theme.uiFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Theme.textDim
        }
        Rectangle {
            visible: ctl.showErrorDot
            width: 5; height: 5; radius: 2.5
            color: Theme.danger
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    TextField {
        id: field
        width: parent.width
        height: 40

        font.family: Theme.uiFamily
        font.pixelSize: 14
        color: Theme.text
        placeholderTextColor: Theme.textFaint
        selectByMouse: true
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: 13
        rightPadding: 13

        // Пользовательский ввод -> сигнал edited. ВАЖНО: textEdited() в
        // Qt Quick НЕ имеет параметров — читаем field.text напрямую.
        onTextEdited: ctl.edited(field.text)
        onAccepted: ctl.accepted()

        background: Rectangle {
            radius: Theme.radiusCtl
            color: Theme.field
            border.width: field.activeFocus ? 1.6 : 1
            border.color:
                ctl.error ? Theme.danger :
                field.activeFocus ? Theme.accent1 : Theme.hairline
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

            // мягкое свечение фокуса
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: ctl.error ? "transparent"
                                 : Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                                           Theme.accent1.b, 0.10)
                opacity: field.activeFocus ? 1 : 0
                visible: !ctl.error
                anchors.margins: -3
                z: -1
                Behavior on opacity { NumberAnimation { duration: Theme.animMid } }
            }
        }
    }
}
