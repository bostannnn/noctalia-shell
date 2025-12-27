import QtQuick
import QtQuick.Effects
import qs.Commons

/**
 * NGlowBorder - Soft glowing border effect for glass surfaces
 *
 * Creates a subtle glow effect on the border using the primary theme color.
 * Can be used as an overlay on any rectangular element.
 */
Item {
  id: root

  // Corner radius (should match parent)
  property real radius: Style.radiusL

  // Glow properties
  property real glowIntensity: Theme.borderGlowIntensity
  property color glowColor: Theme.glowColor
  property real borderWidth: Style.borderS

  // Whether glow should be visible
  property bool glowEnabled: Theme.isLiquidGlass && glowIntensity > 0

  // ===========================================
  // OUTER GLOW (subtle shadow effect)
  // ===========================================
  Rectangle {
    id: glowRect
    anchors.fill: parent
    radius: root.radius
    color: "transparent"
    visible: root.glowEnabled

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowBlur: Theme.borderGlowBlur
      shadowOpacity: root.glowIntensity
      shadowColor: Color.mPrimary
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
    }
  }

  // ===========================================
  // GRADIENT BORDER
  // ===========================================
  Rectangle {
    id: borderRect
    anchors.fill: parent
    radius: root.radius
    color: "transparent"

    border.width: root.borderWidth
    border.color: root.glowEnabled ? root.glowColor : Color.mOutline

    // Subtle inner gradient for depth
    Rectangle {
      anchors.fill: parent
      anchors.margins: root.borderWidth
      radius: Math.max(0, root.radius - root.borderWidth)
      color: "transparent"
      border.width: 1
      border.color: Qt.alpha(Color.mOnSurface, 0.03)
    }
  }

  // ===========================================
  // TOP EDGE HIGHLIGHT
  // ===========================================
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: root.borderWidth + 1
    height: 1
    radius: root.radius > 0 ? root.radius - root.borderWidth - 1 : 0
    color: Qt.alpha(Color.white, root.glowEnabled ? 0.15 : 0.05)
  }
}
