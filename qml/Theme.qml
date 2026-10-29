pragma Singleton
import QtQuick

/*
 *  Theme — синглтон оформления RPM Builder.
 *  Две палитры: тёмный премиум (по умолчанию) и светлая.
 */
Item {
    id: root

    width: 0; height: 0   // визуально не отображается

    property bool isDark: true   // переключается из TitleBar через Engine.darkTheme

    // ---------- шрифты ----------
    property string uiFamily: "Inter"
    property string monoFamily: "JetBrains Mono"

    FontLoader {
        id: fontInter
        source: "qrc:/qt/qml/RpmBuilder/assets/InterVariable.ttf"
        onStatusChanged: if (status === FontLoader.Ready)
                             root.uiFamily = "Inter"
    }
    FontLoader {
        id: fontMono
        source: "qrc:/qt/qml/RpmBuilder/assets/JetBrainsMono-Regular.ttf"
        onStatusChanged: if (status === FontLoader.Ready)
                             root.monoFamily = "JetBrains Mono"
    }

    // ---------- палитра ----------
    // фон окна (два тона для мягкого градиента)
    readonly property color bgA:  isDark ? "#101218" : "#F2F3F8"
    readonly property color bgB:  isDark ? "#15171C" : "#EDEEF4"

    // поверхности
    readonly property color surface:      isDark ? "#1B1E25" : "#FFFFFF"
    readonly property color surface2:     isDark ? "#22252E" : "#FAFAFE"
    readonly property color field:        isDark ? "#14161B" : "#FFFFFF"
    readonly property color consoleBg:    isDark ? "#0D0F13" : "#1B1D26"

    // текст
    readonly property color text:         isDark ? "#E8EAF2" : "#191B22"
    readonly property color textDim:      isDark ? "#9AA1B2" : "#5C6373"
    readonly property color textFaint:    isDark ? "#646B7C" : "#8A90A0"

    // линии
    readonly property color hairline:     isDark ? Qt.rgba(1,1,1,0.07)  : Qt.rgba(20,22,40,0.10)
    readonly property color hairlineSoft: isDark ? Qt.rgba(1,1,1,0.045) : Qt.rgba(20,22,40,0.06)

    // акценты
    readonly property color accent1:  "#6366F1"   // индиго
    readonly property color accent2:  "#A855F7"   // фиолет
    readonly property color success:  "#34D399"
    readonly property color danger:   "#F87171"
    readonly property color warning:  "#FBBF24"
    readonly property color info:     "#38BDF8"

    readonly property color accentText: isDark ? "#C7CBFF" : "#5458EE"

    // прозрачные подложки для чипов/иконок
    readonly property color accentSoft: isDark ? Qt.rgba(0.39,0.40,0.95,0.16)
                                               : Qt.rgba(0.39,0.40,0.95,0.12)
    readonly property color successSoft: isDark ? Qt.rgba(0.20,0.83,0.60,0.14) : Qt.rgba(0.05,0.70,0.48,0.14)
    readonly property color dangerSoft:  isDark ? Qt.rgba(0.97,0.44,0.44,0.15) : Qt.rgba(0.86,0.24,0.24,0.12)
    readonly property color warningSoft: isDark ? Qt.rgba(0.98,0.75,0.14,0.15) : Qt.rgba(0.79,0.55,0.02,0.14)

    // тень карточек (светлая тема чуть заметнее)
    readonly property bool cardShadow: !isDark

    // ---------- геометрия ----------
    readonly property int    radiusWin:   16
    readonly property int    radiusCard:  14
    readonly property int    radiusCtl:   10
    readonly property int    titleBarH:   54
    readonly property int    sidebarW:    228

    // ---------- анимации ----------
    readonly property int animFast: 140
    readonly property int animMid:  200

    // градиент главной кнопки/баннера
    function accentGradientAngle() { return Qt.createQmlObject(
        'import QtQuick; Gradient { orientation: Gradient.Horizontal;
          GradientStop { position: 0.0; color: "#6366F1" }
          GradientStop { position: 1.0; color: "#A855F7" } }', root) }
}
