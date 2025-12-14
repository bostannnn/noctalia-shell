import QtQuick
import qs.Commons

/**
 * CAnim - Standardized ColorAnimation with Material Design 3 bezier curves
 * 
 * Based on caelestia-dots animation system.
 * Uses smooth bezier easing for color transitions.
 * 
 * Usage:
 *   Behavior on color {
 *     CAnim {}
 *   }
 */
ColorAnimation {
  id: root
  
  // Animation duration - uses Style.animationNormal by default
  duration: Style.animationNormal
  
  // Bezier curve for smooth motion
  easing.type: Easing.BezierSpline
  easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
}
