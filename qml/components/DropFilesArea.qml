import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  DropFilesArea — зона перетаскивания файлов/папок с подсветкой при drag.
 */
Rectangle {
    id: zone

    signal pathsDropped(var pathList)
    signal clickedEmpty()

    property alias title: titleText.text
    property alias subtitle: subText.text

    radius: Theme.radiusCard
    color: dropArea.containsDrag ? Theme.accentSoft : Theme.field

    border.width: 1.8
    border.color: dropArea.containsDrag ? Theme.accent2 : Theme.hairline
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    // пунктирная рамка поверх сплошной прозрачной (эффект dashed)
    Canvas {
        id: dashes
        anchors.fill: parent
        anchors.margins: -1
        opacity: 0.9
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = dropArea.containsDrag
                              ? Theme.accent2 : Theme.textFaint;
            ctx.lineWidth = 1.6;
            if (ctx.setLineDash)
                ctx.setLineDash([7, 6]);
            roundRectPath(ctx, 0.8, 0.8, width - 1.6, height - 1.6,
                          Theme.radiusCard);
            ctx.stroke();
        }
        function roundRectPath(ctx, x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
        }
        Connections {
            function onContainsDragChanged() { dashes.requestPaint() }
            target: dropArea
        }
        Connections {
            function onIsDarkChanged() { dashes.requestPaint() }
            target: Theme
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]

        onDropped: (drop) => {
            const list = [];
            for (const url of drop.urls) {
                if (!url.toString().startsWith("file://"))
                    continue;
                let p = decodeURIComponent(url.toString()
                                              .replace(/^file:\/\//, ""));
                // на Linux файлы приходят уже без третьего слеша проблем
                if (/^\/[A-Za-z]:/.test(p) === false && p.length > 2 &&
                    p[2] === ":") {}     // no-op для Windows-путей не нужен
                list.push(p);
            }
            if (list.length > 0) {
                zone.pathsDropped(list);
                drop.acceptProposedAction();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: zone.clickedEmpty()
    }

    Column {
        anchors.centerIn: parent
        spacing: 10

        // стилизованная стопка файлов
        Item {
            width: 46; height: 40
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                x: 14; y: 0; width: 24; height: 30; radius: 5
                rotation: 8
                color: Qt.rgba(Theme.accent1.r, Theme.accent1.g,
                               Theme.accent1.b, 0.22)
            }
            Rectangle {
                x: 9; y: 2; width: 24; height: 30; radius: 5
                rotation: -5
                color: Qt.rgba(Theme.accent2.r, Theme.accent2.g,
                               Theme.accent2.b, 0.26)
            }
            Rectangle {
                x: 11; y: 5; width: 24; height: 30; radius: 5
                border.width: 1.6
                border.color: dropArea.containsDrag ? "#FFFFFF" : Theme.accentText
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.surface2 }
                    GradientStop { position: 1; color: Theme.field }
                }
            }
            Repeater {
                model: [12, 16, 20]
                delegate: Rectangle {
                    x: 15; y: modelData + 4
                    width: 16; height: 2; radius: 1
                    color: dropArea.containsDrag ? "#FFFFFF" : Theme.accentText
                    opacity: 0.7
                }
            }
        }

        Text {
            id: titleText
            text: qsTr("Перетащите сюда файлы или папки")
            font.family: Theme.uiFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            id: subText
            text: qsTr("или кликните, чтобы выбрать")
            font.family: Theme.uiFamily
            font.pixelSize: 12
            color: Theme.textFaint
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
