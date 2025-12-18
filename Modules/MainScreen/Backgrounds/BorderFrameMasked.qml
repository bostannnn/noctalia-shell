import QtQuick
import QtQuick.Effects
import qs.Commons

/**
 * BorderFrameMasked - Mask-based border frame for framed mode
 *
 * Uses MultiEffect mask technique to create a "donut" shape.
 * Shadow is handled by NDropShadow in AllBackgrounds for unified appearance.
 */
Item {
  id: root

  required property color backgroundColor

  // Configuration
  readonly property int borderThickness: Settings.data.general.screenBorderThickness ?? 10
  readonly property int borderRounding: Settings.data.general.screenBorderRounding ?? Math.round(25 * Settings.data.general.radiusRatio)
  readonly property string barPosition: Settings.data.bar?.position ?? "top"
  readonly property real barWidth: Style.barHeight ?? 40

  // Only render in framed mode
  readonly property bool active: (Settings.data.bar.mode ?? "classic") === "framed"

  anchors.fill: parent
  visible: active

  // Background rectangle (will be masked to create donut shape)
  Rectangle {
    id: borderRect
    anchors.fill: parent
    color: root.backgroundColor

    layer.enabled: root.active
    layer.effect: MultiEffect {
      maskSource: mask
      maskEnabled: true
      maskInverted: true
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }
  }

  // Mask item - the inner rectangle that gets cut out
  Item {
    id: mask
    anchors.fill: parent
    layer.enabled: true
    visible: false

    Rectangle {
      id: innerCutout
      anchors.fill: parent

      // Margins based on bar position
      anchors.topMargin: root.barPosition === "top" ? root.borderThickness + root.barWidth : root.borderThickness
      anchors.rightMargin: root.barPosition === "right" ? root.borderThickness + root.barWidth : root.borderThickness
      anchors.bottomMargin: root.barPosition === "bottom" ? root.borderThickness + root.barWidth : root.borderThickness
      anchors.leftMargin: root.barPosition === "left" ? root.borderThickness + root.barWidth : root.borderThickness

      radius: root.borderRounding
    }
  }
}
