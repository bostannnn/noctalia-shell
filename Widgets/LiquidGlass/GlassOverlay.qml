import QtQuick
import qs.Commons

/**
 * GlassOverlay - Positions glass effects over a panel or bar background
 *
 * Combines specular highlight, glow border, and optional reflection
 * effects. Designed to be layered on top of Shape-based backgrounds.
 */
Item {
  id: root

  // Disable interactions - allow click-through
  enabled: false

  // Source item for positioning (panel or bar)
  property var sourceItem: null

  // Corner radius
  property real radius: Style.radiusL

  // Whether this overlay is for the bar (uses different positioning)
  property bool isBar: false

  // Bar reference for bar mode
  property var bar: null

  // Panel placeholder reference for panel mode
  property var panel: null

  // Get panel's actual panel item
  readonly property var panelBg: (!isBar && panel && panel.visible) ? panel.panelItem : null

  // Computed position and size from source
  readonly property real overlayX: isBar ? (bar ? bar.x : 0) : (panelBg ? panelBg.x : 0)
  readonly property real overlayY: isBar ? (bar ? bar.y : 0) : (panelBg ? panelBg.y : 0)
  readonly property real overlayWidth: isBar ? (bar ? bar.width : 0) : (panelBg ? panelBg.width : 0)
  readonly property real overlayHeight: isBar ? (bar ? bar.height : 0) : (panelBg ? panelBg.height : 0)

  // Only show when source is valid and visible
  visible: Theme.isLiquidGlass && overlayWidth > 0 && overlayHeight > 0

  // Position based on source
  x: overlayX
  y: overlayY
  width: overlayWidth
  height: overlayHeight

  // ===========================================
  // SPECULAR HIGHLIGHT (top edge shine)
  // ===========================================
  Rectangle {
    id: specularHighlight
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 1
    anchors.leftMargin: 1
    anchors.rightMargin: 1
    height: Math.min(Theme.specularHeight, parent.height * 0.4)
    radius: root.radius - 1

    gradient: Gradient {
      GradientStop { position: 0.0; color: Theme.specularColor }
      GradientStop { position: 1.0; color: Theme.specularFade }
    }
  }

  // ===========================================
  // GLOW BORDER
  // ===========================================
  NGlowBorder {
    anchors.fill: parent
    radius: root.radius
    glowIntensity: Theme.borderGlowIntensity
    glowColor: Theme.glowColor
  }

  // ===========================================
  // REFLECTION OVERLAY (optional animation)
  // ===========================================
  Loader {
    anchors.fill: parent
    active: Theme.shouldAnimate && Theme.reflectionIntensity > 0

    sourceComponent: NReflectionOverlay {
      radius: root.radius
      intensity: Theme.reflectionIntensity
      duration: Theme.reflectionAnimDuration
      animationEnabled: Theme.shouldAnimate
    }
  }
}
