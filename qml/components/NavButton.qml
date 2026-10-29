import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder

/*
 *  NavButton — кнопка навигации с геометрической мини-иконкой,
 *  нарисованной примитивами (без внешних глифов).
 */
Item {
    id: btn
    // ВНИМАНИЕ: свойство НАЗВАНО navIndex, а НЕ index — иначе оно
    // затеняет required property index делегата Repeater и клик
    // уходит с неверным номером страницы (семья багов textEdited).
    property int navIndex: 0
    property string label: ""
    property string icon: ""          // overview|meta|files|deps|scripts|spec|build
    property bool active: false
    signal navigate(int idx)

    width: parent ? parent.width : 200
    height: 40

    readonly property bool hovered: zone.containsMouse
    readonly property color stroke:
        btn.active ? (Theme.isDark ? "#FFFFFF" : "#3B3FE0")
                   : (btn.hovered ? Theme.text : Theme.textDim)

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: btn.active ? Theme.accentSoft
                          : (btn.hovered ? Theme.hairlineSoft : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // градиентная полоска активного пункта слева
    Rectangle {
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 3; height: btn.active ? 22 : 0; radius: 2
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.accent1 }
            GradientStop { position: 1; color: Theme.accent2 }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.animMid; easing.type: Easing.OutCubic }
        }
    }

    // ------------------------------ ИКОНКИ ----------------------------------
    component IcOverview: Item {
        Repeater {
            model: [[1,1],[11,1],[1,11],[11,11]]
            delegate: Rectangle {
                x: modelData[0]; y: modelData[1]
                width: 8; height: 8; radius: 2.5
                color: btn.stroke
                opacity: index === 0 ? 1 : 0.55
                required property int index
                required property var modelData
            }
        }
    }

    component IcMeta: Item {
        Rectangle {
            x: 2; y: 6; width: 15; height: 9; radius: 4.5
            rotation: -38
            border.color: btn.stroke
            border.width: 1.6
            color: "transparent"
        }
        Rectangle { x: 13; y: 2; width: 4; height: 4; radius: 2; color: btn.stroke }
    }

    component IcFiles: Item {
        Rectangle {
            x: 1; y: 5; width: 18; height: 11; radius: 3
            color: btn.stroke; opacity: 0.25
        }
        Rectangle {
            x: 1; y: 4; width: 8; height: 3.6; radius: 1.8
            color: btn.stroke
        }
        Rectangle {
            x: 3.5; y: 8.5; width: 7; height: 7.5; radius: 2
            color: btn.stroke; opacity: 0.95
        }
    }

    component IcDeps: Item {
        Rectangle {
            x: 1; y: 6; width: 12; height: 8; radius: 4
            color: "transparent"
            border.color: btn.stroke; border.width: 1.7
        }
        Rectangle {
            x: 7; y: 6; width: 12; height: 8; radius: 4
            color: "transparent"
            border.color: btn.stroke; border.width: 1.7
            opacity: 0.65
        }
    }

    component IcScripts: Item {
        Rectangle {
            x: 1; y: 2; width: 18; height: 16; radius: 4
            color: "transparent"
            border.color: btn.stroke; border.width: 1.6
        }
        Rectangle { x: 5; y: 8; width: 5; height: 2; radius: 1;
                    rotation: 45; color: btn.stroke }
        Rectangle { x: 3; y: 12.6; width: 5; height: 2; radius: 1;
                    rotation: -45; color: btn.stroke }
        Rectangle { x: 12; y: 12; width: 4.5; height: 2; radius: 1;
                    color: btn.stroke }
    }

    component IcSpec: Item {
        Rectangle {
            x: 3; y: 1; width: 14; height: 18; radius: 3
            color: "transparent"
            border.color: btn.stroke; border.width: 1.6
        }
        Repeater {
            model: [4, 7, 10, 13]
            delegate: Rectangle {
                required property int index
                required property var modelData
                x: 6; y: modelData
                width: 8; height: 2; radius: 1
                color: btn.stroke
                opacity: index === 3 ? 0.55 : 0.85
            }
        }
    }

    component IcBuildFrame: Item {
        Rectangle {
            anchors.fill: parent
            radius: 5
            color: "transparent"
            border.color: btn.stroke; border.width: 1.6
        }
    }

    component PathTriangle: Canvas {
        anchors.centerIn: parent
        width: 8; height: 10
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = btn.stroke;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(width, height / 2);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fill();
        }
    }

    Loader {
        id: iconLoader
        sourceComponent: ({
            overview: icOverviewComp, meta: icMetaComp, files: icFilesComp,
            deps: icDepsComp, scripts: icScriptsComp, spec: icSpecComp,
            build: icBuildComp
        })[btn.icon] ?? null
        width: 20; height: 20
        anchors.left: parent.left
        anchors.leftMargin: 17
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: btn.label
        font.family: Theme.uiFamily
        font.pixelSize: 14
        font.weight: btn.active ? Font.DemiBold : Font.Medium
        color: btn.active ? (Theme.isDark ? "#FFFFFF" : "#3B3FE0")
                          : (btn.hovered ? Theme.text : Theme.textDim)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: iconLoader.right
        anchors.leftMargin: 11
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: zone
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.navigate(btn.navIndex)
    }

    Component { id: icOverviewComp; IcOverview {} }
    Component { id: icMetaComp;    IcMeta {} }
    Component { id: icFilesComp;   IcFiles {} }
    Component { id: icDepsComp;    IcDeps {} }
    Component { id: icScriptsComp; IcScripts {} }
    Component { id: icSpecComp;    IcSpec {} }
    Component {
        id: icBuildComp
        Item {
            IcBuildFrame {}
            PathTriangle {}
        }
    }
}
