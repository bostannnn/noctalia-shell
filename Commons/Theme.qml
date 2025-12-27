pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  // Theme mode: "standard" or "liquidGlass"
  readonly property string mode: Settings.data.ui.themeMode ?? "standard"
  readonly property bool isLiquidGlass: mode === "liquidGlass"
  readonly property bool isStandard: mode === "standard"

  // ===========================================
  // LIQUID GLASS EFFECT PARAMETERS
  // ===========================================

  // Blur settings
  readonly property real glassBlurRadius: Settings.data.ui.glassBlurRadius ?? 32
  readonly property real glassBlurMax: 64
  readonly property real glassBlur: glassBlurRadius / glassBlurMax

  // Opacity settings
  readonly property real glassOpacity: Settings.data.ui.glassOpacity ?? 0.65
  readonly property real glassOverlayOpacity: 0.08

  // Reflection settings
  readonly property real reflectionIntensity: Settings.data.ui.reflectionIntensity ?? 0.3
  readonly property bool reflectionAnimationsEnabled: Settings.data.ui.glassAnimationsEnabled ?? true
  readonly property int reflectionAnimDuration: 8000

  // Border glow settings
  readonly property real borderGlowIntensity: Settings.data.ui.borderGlowIntensity ?? 0.4
  readonly property real borderGlowBlur: 0.4

  // Specular highlight settings
  readonly property real specularIntensity: 0.12
  readonly property real specularHeight: 30

  // ===========================================
  // DERIVED COLORS (from Color.qml palette)
  // ===========================================

  // Frosted overlay colors
  readonly property color glassOverlayLight: Qt.alpha(Color.mOnSurface, glassOverlayOpacity)
  readonly property color glassOverlayMid: Qt.alpha(Color.mOnSurface, glassOverlayOpacity * 0.5)
  readonly property color glassOverlayDark: Qt.alpha(Color.mSurface, glassOverlayOpacity * 2)

  // Specular highlight color
  readonly property color specularColor: Qt.alpha(Color.white, specularIntensity)
  readonly property color specularFade: Qt.alpha(Color.white, 0)

  // Border glow color
  readonly property color glowColor: Qt.alpha(Color.mPrimary, borderGlowIntensity)
  readonly property color glowColorSubtle: Qt.alpha(Color.mPrimary, borderGlowIntensity * 0.5)

  // Glass surface colors (with glass opacity applied)
  readonly property color glassSurface: Qt.alpha(Color.mSurface, glassOpacity)
  readonly property color glassSurfaceVariant: Qt.alpha(Color.mSurfaceVariant, glassOpacity)

  // ===========================================
  // HELPER FUNCTIONS
  // ===========================================

  // Apply glass opacity to any color
  function withGlassOpacity(color) {
    return Qt.alpha(color, glassOpacity)
  }

  // Apply glass opacity only if liquid glass mode is active
  function conditionalGlass(color, fallback) {
    return isLiquidGlass ? Qt.alpha(color, glassOpacity) : (fallback ?? color)
  }

  // Check if animations should run (respects global animation settings)
  readonly property bool shouldAnimate: isLiquidGlass
    && reflectionAnimationsEnabled
    && !Settings.data.general.animationDisabled
}
