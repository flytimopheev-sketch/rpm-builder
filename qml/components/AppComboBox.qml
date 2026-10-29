import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  AppComboBox — выпадающий список с возможностью свободного ввода.
 */
ComboBox {
    id: combo

    editable: true
    font.family: Theme.uiFamily
    font.pixelSize: 13
    height: 40

    background: Rectangle {
        radius: Theme.radiusCtl
        color: Theme.field
        border.width: combo.activeFocus ? 1.6 : 1
        border.color: combo.activeFocus ? Theme.accent1 : Theme.hairline
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    contentItem: TextInput {
        text: combo.editText
        font: combo.font
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        leftPadding: 12
        rightPadding: combo.indicator ? combo.indicator.width + 4 : 30
        selectByMouse: true
        readOnly: !combo.editable
        onTextChanged: if (combo.editable && activeFocus) combo.editText = text
    }

    indicator: Canvas {
        id: arrowCanvas
        x: combo.width - width - 12
        y: (combo.height - height) / 2
        width: 10; height: 6
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = Theme.textDim;
            ctx.lineWidth = 1.8;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(0.5, 0.5);
            ctx.lineTo(width / 2, height - 0.5);
            ctx.lineTo(width - 0.5, 0.5);
            ctx.stroke();
        }
        Connections {
            function onIsDarkChanged() { arrowCanvas.requestPaint() }
            target: Theme
        }
    }

    delegate: ItemDelegate {
        id: del
        required property var model
        required property int index
        width: combo.popup.width
        height: 34
        contentItem: Text {
            text: del.model[combo.textRole] ?? del.model[modelData]
                  ?? del.model.display ?? modelData
                  ?? ""
            font.family: Theme.uiFamily
            font.pixelSize: 13
            color: Theme.text
            verticalAlignment: Text.AlignVCenter
        }
        highlighted: combo.highlightedIndex === index
        background: Rectangle {
            radius: 7
            color: del.highlighted ? Theme.accentSoft : "transparent"
        }
    }

    popup: Popup {
        y: combo.height + 4
        width: Math.max(combo.width, 220)
        padding: 4
        implicitHeight: contentItem.implicitHeight > 300 ? 300 : contentItem.implicitHeight

        background: Rectangle {
            radius: 10
            color: Theme.surface2
            border.color: Theme.hairline
            border.width: 1
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: combo.popup.visible ? combo.delegateModel : null
            currentIndex: combo.highlightedIndex
            spacing: 2
        }
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animFast }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.animFast }
        }
    }
}
