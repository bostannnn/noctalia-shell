import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

/**
 * BorderExclusionZones - Creates 4 invisible windows to reserve screen border space
 * 
 * Uses Wayland layer shell exclusive zones instead of hyprctl gaps.
 * This approach:
 *   - Doesn't reset on Hyprland config reload
 *   - No bouncing windows
 *   - Proper Wayland protocol
 * 
 * Based on caelestia's Exclusions.qml
 */
Item {
  id: root

  required property var screen

  // Only active in framed mode
  readonly property string barMode: Settings.data.bar.mode ?? "classic"
  readonly property bool enabled: barMode === "framed"
  
  // Border configuration
  readonly property int borderThickness: Settings.data.general.screenBorderThickness ?? 10
  readonly property int barGap: Settings.data.bar.gap ?? 10

  // Bar position
  readonly property string barPosition: Settings.data.bar?.position ?? "left"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  readonly property int barWidth: Style.barHeight ?? 40

  // Total exclusion for non-bar edges: barGap + borderThickness
  readonly property int baseExclusion: barGap + borderThickness

  // Total exclusion for bar edge: barWidth + barGap + borderThickness
  readonly property int barExclusion: barWidth + barGap + borderThickness
  
  Component.onCompleted: {
    Logger.d("BorderExclusionZones", "Created for screen:", screen?.name, 
             "enabled:", enabled, "barMode:", barMode,
             "baseExclusion:", baseExclusion, "barExclusion:", barExclusion,
             "barPosition:", barPosition);
  }
  
  onEnabledChanged: {
    Logger.d("BorderExclusionZones", "enabled changed to:", enabled);
  }
  
  // Left edge exclusion zone
  NLayerShellWindow {
    id: leftZone
    screen: root.screen
    color: "transparent"
    mask: Region {}
    
    visible: root.enabled
    
    layerShellLayer: WlrLayer.Bottom
    layerNamespace: "noctalia-border-left"
    layerShellExclusionMode: ExclusionMode.Auto
    
    anchors {
      left: true
      top: true
      bottom: true
    }
    
    // Bar on left = barExclusion, otherwise baseExclusion
    implicitWidth: root.enabled ? (root.barPosition === "left" ? root.barExclusion : root.baseExclusion) : 0
    implicitHeight: 1
    
    Component.onCompleted: {
      Logger.d("BorderExclusionZones", "leftZone width:", implicitWidth, "visible:", visible);
    }
  }
  
  // Right edge exclusion zone
  NLayerShellWindow {
    id: rightZone
    screen: root.screen
    color: "transparent"
    mask: Region {}
    
    visible: root.enabled
    
    layerShellLayer: WlrLayer.Bottom
    layerNamespace: "noctalia-border-right"
    layerShellExclusionMode: ExclusionMode.Auto
    
    anchors {
      right: true
      top: true
      bottom: true
    }
    
    implicitWidth: root.enabled ? (root.barPosition === "right" ? root.barExclusion : root.baseExclusion) : 0
    implicitHeight: 1
  }
  
  // Top edge exclusion zone
  NLayerShellWindow {
    id: topZone
    screen: root.screen
    color: "transparent"
    mask: Region {}
    
    visible: root.enabled
    
    layerShellLayer: WlrLayer.Bottom
    layerNamespace: "noctalia-border-top"
    layerShellExclusionMode: ExclusionMode.Auto
    
    anchors {
      top: true
      left: true
      right: true
    }
    
    implicitWidth: 1
    implicitHeight: root.enabled ? (root.barPosition === "top" ? root.barExclusion : root.baseExclusion) : 0
  }
  
  // Bottom edge exclusion zone
  NLayerShellWindow {
    id: bottomZone
    screen: root.screen
    color: "transparent"
    mask: Region {}
    
    visible: root.enabled
    
    layerShellLayer: WlrLayer.Bottom
    layerNamespace: "noctalia-border-bottom"
    layerShellExclusionMode: ExclusionMode.Auto
    
    anchors {
      bottom: true
      left: true
      right: true
    }
    
    implicitWidth: 1
    implicitHeight: root.enabled ? (root.barPosition === "bottom" ? root.barExclusion : root.baseExclusion) : 0
  }
}
