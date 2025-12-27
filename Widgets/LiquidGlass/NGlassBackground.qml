import QtQuick
import QtQuick.Effects
import qs.Commons

/**
 * NGlassBackground - Reusable frosted glass background component
 *
 * Features:
 * - Optional backdrop blur via MultiEffect
 * - Frosted cloudy gradient overlay
 * - Specular highlight on top edge
 * - Respects Theme.isLiquidGlass for conditional rendering
 */
Item {
  id: root

  // Blur properties
  property real blurRadius: Theme.glassBlurRadius
  property real blurMax: Theme.glassBlurMax
  property bool blurEnabled: Theme.isLiquidGlass

  // Opacity properties
  property real glassOpacity: Theme.glassOpacity

  // Corner radius (should match parent)
  property real radius: Style.radiusL

  // Optional source for backdrop blur (ShaderEffectSource)
  property var blurSource: null

  // Whether to show specular highlight
  property bool showSpecular: true

  // Whether to show cloudy overlay
  property bool showOverlay: true

  // ===========================================
  // BACKDROP BLUR LAYER (when source provided)
  // ===========================================
  Loader {
    id: blurLoader
    anchors.fill: parent
    active: root.blurEnabled && root.blurSource !== null

    sourceComponent: Item {
      anchors.fill: parent

      ShaderEffectSource {
        id: blurSourceCopy
        anchors.fill: parent
        sourceItem: root.blurSource
        sourceRect: Qt.rect(
          root.mapToItem(root.blurSource, 0, 0).x,
          root.mapToItem(root.blurSource, 0, 0).y,
          root.width,
          root.height
        )
        visible: false
      }

      MultiEffect {
        anchors.fill: parent
        source: blurSourceCopy
        blurEnabled: true
        blurMax: root.blurMax
        blur: root.blurRadius / root.blurMax
      }

      // Clip to radius
      layer.enabled: true
      layer.effect: Item {
        Rectangle {
          anchors.fill: parent
          radius: root.radius
        }
      }
    }
  }

  // ===========================================
  // FROSTED OVERLAY LAYER
  // ===========================================
  Rectangle {
    id: frostedOverlay
    anchors.fill: parent
    radius: root.radius
    visible: root.showOverlay

    // Base frosted color
    color: Qt.alpha(Color.mSurface, root.glassOpacity * 0.3)

    // Cloudy gradient overlay
    Rectangle {
      anchors.fill: parent
      radius: root.radius

      gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.glassOverlayLight }
        GradientStop { position: 0.3; color: Theme.glassOverlayMid }
        GradientStop { position: 0.7; color: Qt.alpha(Theme.glassOverlayDark, 0.02) }
        GradientStop { position: 1.0; color: Theme.glassOverlayDark }
      }
    }
  }

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
    visible: root.showSpecular

    gradient: Gradient {
      GradientStop { position: 0.0; color: Theme.specularColor }
      GradientStop { position: 1.0; color: Theme.specularFade }
    }
  }

  // ===========================================
  // SUBTLE INNER BORDER
  // ===========================================
  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: "transparent"
    border.width: Style.borderS
    border.color: Qt.alpha(Color.mOnSurface, 0.08)
  }
}
