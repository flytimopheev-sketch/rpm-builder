import QtQuick

/*
 *  AppIcon — логотип приложения (SVG из ресурсов), масштабируемый.
 */
Image {
    id: icon
    source: "qrc:/qt/qml/RpmBuilder/assets/rpm-builder.svg"
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    asynchronous: false
}
