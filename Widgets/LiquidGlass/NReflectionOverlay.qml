import QtQuick
import qs.Commons

/**
 * NReflectionOverlay - Animated light reflection that sweeps across surfaces
 *
 * Creates a subtle, animated diagonal gradient that simulates
 * light moving across a glass surface.
 */
Item {
  id: root

  // Corner radius (should match parent)
  property real radius: Style.radiusL

  // Animation properties
  property real intensity: Theme.reflectionIntensity
  property int duration: Theme.reflectionAnimDuration
  property bool animationEnabled: Theme.shouldAnimate

  // Internal animation phase (0 to 1)
  property real phase: 0

  clip: true

  // Animated light sweep
  Rectangle {
    id: lightSweep
    width: parent.width * 0.4
    height: parent.height * 2
    rotation: 25

    // Position based on animation phase
    x: -width + (parent.width + width * 2) * root.phase
    y: -height * 0.25

    opacity: root.intensity

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.3; color: Qt.alpha(Color.white, 0.02) }
      GradientStop { position: 0.5; color: Qt.alpha(Color.white, 0.08) }
      GradientStop { position: 0.7; color: Qt.alpha(Color.white, 0.02) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // Animation sequence
  SequentialAnimation on phase {
    running: root.animationEnabled && root.visible
    loops: Animation.Infinite

    // Sweep across
    NumberAnimation {
      from: 0
      to: 1
      duration: root.duration * 0.4
      easing.type: Easing.InOutQuad
    }

    // Pause before next sweep
    PauseAnimation {
      duration: root.duration * 0.6
    }
  }

  // Note: clip: true handles overflow, parent's radius handles corner masking
}
