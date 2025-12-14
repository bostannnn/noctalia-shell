import QtQuick
import qs.Commons

/**
 * Anim - Standardized NumberAnimation with Material Design 3 bezier curves
 * 
 * Based on caelestia-dots animation system.
 * Uses smooth bezier easing for more natural motion.
 * 
 * Usage:
 *   Behavior on width {
 *     Anim {}
 *   }
 * 
 * Or in SequentialAnimation:
 *   SequentialAnimation {
 *     Anim {
 *       target: myItem
 *       property: "opacity"
 *       to: 1
 *     }
 *   }
 */
NumberAnimation {
  id: root
  
  // Animation duration - uses Style.animationNormal by default
  duration: Style.animationNormal
  
  // Bezier curve for smooth motion
  // This is the Material Design 3 "standard" curve
  easing.type: Easing.BezierSpline
  easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
}
