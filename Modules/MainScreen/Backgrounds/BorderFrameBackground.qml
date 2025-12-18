import QtQuick
import QtQuick.Shapes
import qs.Commons

/**
 * BorderFrameBackground - ShapePath for rendering screen border frame
 *
 * NOTE: This component is now DEPRECATED for framed mode rendering.
 * BorderFrameMasked.qml handles framed mode with proper inner shadows.
 * This remains for potential future use or fallback.
 */
ShapePath {
  id: root

  required property var shapeContainer
  required property color backgroundColor

  // Configuration
  readonly property int borderThickness: Settings.data.general.screenBorderThickness ?? 10
  readonly property int borderRounding: Settings.data.general.screenBorderRounding ?? Math.round(25 * Settings.data.general.radiusRatio)
  readonly property string barPosition: Settings.data.bar?.position ?? "top"
  readonly property real barWidth: Style.barHeight ?? 40

  // Screen dimensions
  readonly property real sw: shapeContainer?.width ?? 0
  readonly property real sh: shapeContainer?.height ?? 0

  // Inner margins - bar side includes bar width
  readonly property real iTop: barPosition === "top" ? borderThickness + barWidth : borderThickness
  readonly property real iRight: barPosition === "right" ? borderThickness + barWidth : borderThickness
  readonly property real iBottom: barPosition === "bottom" ? borderThickness + barWidth : borderThickness
  readonly property real iLeft: barPosition === "left" ? borderThickness + barWidth : borderThickness

  // Disabled - BorderFrameMasked handles framed mode rendering with proper shadows
  readonly property bool active: false

  fillColor: "transparent"
  strokeWidth: -1
  fillRule: ShapePath.OddEvenFill

  // Outer rectangle (clockwise)
  startX: 0
  startY: 0
  PathLine { x: root.sw; y: 0 }
  PathLine { x: root.sw; y: root.sh }
  PathLine { x: 0; y: root.sh }
  PathLine { x: 0; y: 0 }

  // Inner rounded rectangle (counter-clockwise for hole)
  PathMove { x: root.iLeft + root.borderRounding; y: root.iTop }

  // Top edge
  PathLine { x: root.sw - root.iRight - root.borderRounding; y: root.iTop }
  PathArc {
    x: root.sw - root.iRight; y: root.iTop + root.borderRounding
    radiusX: root.borderRounding; radiusY: root.borderRounding
    direction: PathArc.Clockwise
  }

  // Right edge
  PathLine { x: root.sw - root.iRight; y: root.sh - root.iBottom - root.borderRounding }
  PathArc {
    x: root.sw - root.iRight - root.borderRounding; y: root.sh - root.iBottom
    radiusX: root.borderRounding; radiusY: root.borderRounding
    direction: PathArc.Clockwise
  }

  // Bottom edge
  PathLine { x: root.iLeft + root.borderRounding; y: root.sh - root.iBottom }
  PathArc {
    x: root.iLeft; y: root.sh - root.iBottom - root.borderRounding
    radiusX: root.borderRounding; radiusY: root.borderRounding
    direction: PathArc.Clockwise
  }

  // Left edge
  PathLine { x: root.iLeft; y: root.iTop + root.borderRounding }
  PathArc {
    x: root.iLeft + root.borderRounding; y: root.iTop
    radiusX: root.borderRounding; radiusY: root.borderRounding
    direction: PathArc.Clockwise
  }
}
