import QtQuick
import QtQuick.Controls.Basic
import RpmBuilder
import QtQuick.Layouts

/*
 *  SectionCard — карточка-секция с заголовком и опциональной припиской.
 */
Rectangle {
    id: card
    property string title: ""
    property string caption: ""

    radius: Theme.radiusCard
    color: Theme.surface
    border.color: Theme.hairline
    border.width: 1

    // мягкая верхняя подсветка для объёма (тёмная тема)
    Rectangle {
        visible: Theme.isDark && title !== ""
        anchors.top: parent.top
        x: 14; width: parent.width - 28; height: 1
        color: Qt.rgba(1, 1, 1, 0.05)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            visible: card.title !== ""
            spacing: 8

            Rectangle {
                visible: card.title !== ""
                width: 4; height: 16; radius: 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent1 }
                    GradientStop { position: 1; color: Theme.accent2 }
                }
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: card.title
                font.family: Theme.uiFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.text
                Layout.fillWidth: true
            }
            Text {
                text: card.caption
                visible: card.caption !== ""
                font.family: Theme.uiFamily
                font.pixelSize: 12
                color: Theme.textFaint
            }
        }

        default property alias contentData: inner.data
        Item { id: inner; Layout.fillWidth: true; Layout.fillHeight: true }
    }
}
