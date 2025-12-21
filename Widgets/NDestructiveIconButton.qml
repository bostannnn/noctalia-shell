import QtQuick
import qs.Commons

NIconButton {
    // Defaults for a destructive action (delete/remove).
    icon: "trash"
    baseSize: 24
    density: "compact"
    customRadius: Style.radiusS

    colorBg: Qt.alpha(Color.mError, 0.12)
    colorFg: Color.mError
    colorBgHover: Color.mError
    colorFgHover: Color.mOnError
    colorBorder: Qt.alpha(Color.mError, 0.2)
    colorBorderHover: Qt.alpha(Color.mError, 0.2)
}
