import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons

/**
 * ScreenBorder - Draws a colored border around the entire screen (caelestia style)
 * 
 * Only active when bar.mode === "framed"
 * 
 * Also manages Hyprland gaps for all bar modes:
 *   - classic/floating: gaps provide margin between bar and windows
 *   - framed: gaps handled by BorderExclusionZones (Wayland approach)
 */
Item {
  id: root

  // Reference to the bar for position awareness
  property Item bar: null
  
  // Border configuration from Settings
  property int borderThickness: Settings.data.general.screenBorderThickness ?? 10
  property int borderRounding: Settings.data.general.screenBorderRounding ?? Math.round(25 * Settings.data.general.radiusRatio)
  property color borderColor: (Settings.data.general.screenBorderUseThemeColor ?? true)
                              ? Color.mSurface 
                              : (Settings.data.general.screenBorderColor ?? Color.mSurface)
  
  // Only enabled in framed mode
  property string barMode: Settings.data.bar.mode ?? "classic"
  property bool enabled: barMode === "framed"
  
  // Bar position awareness
  property string barPosition: Settings.data.bar?.position ?? "left"
  property bool barIsVertical: barPosition === "left" || barPosition === "right"
  
  // Bar width for mask calculation (use bar's actual width or Style.barHeight)
  property real barWidth: bar ? (barIsVertical ? bar.width : bar.height) : (Style.barHeight ?? 40)

  anchors.fill: parent
  visible: enabled && borderThickness > 0

  // Margin from settings (gap between border edge and windows)
  property int borderMargin: Settings.data.general.screenBorderMargin ?? 10
  
  // Bar gap for classic/floating modes
  property int barGap: Settings.data.bar.gap ?? 10
  
  // Apply Hyprland gaps on startup and when settings change
  Component.onCompleted: {
    Logger.d("ScreenBorder", "Component completed, barMode=" + barMode);
    // Delay to ensure Settings are loaded
    startupTimer.start();
  }
  
  Timer {
    id: startupTimer
    interval: 100
    onTriggered: {
      Logger.d("ScreenBorder", "Startup timer triggered");
      root.applyHyprlandGapsOnStartup();
    }
  }

  // Startup-specific function that writes config and reloads in sequence
  function applyHyprlandGapsOnStartup() {
    if (barMode === "framed") {
      // Framed mode uses Wayland exclusion zones, just set gaps to 0
      Quickshell.execDetached(["sh", "-c",
        "mkdir -p '" + Settings.configDir + "' && " +
        "echo 'general:gaps_out = 0' > '" + gapsConfigPath + "' && " +
        "hyprctl reload"
      ]);
      Logger.d("ScreenBorder", "Startup: framed mode - gaps=0");
    } else {
      // Classic/floating: calculate gaps and apply with reload
      var barHeight = Style.barHeight || 40;
      var gap = barGap;

      var top = gap;
      var right = gap;
      var bottom = gap;
      var left = gap;

      var barMargin = 0;
      if (barMode === "floating") {
        barMargin = Math.ceil((Settings.data.bar.marginHorizontal ?? 0.25) * (Style.marginXL || 16));
      }

      if (barPosition === "left") left = barHeight + barMargin + gap;
      else if (barPosition === "right") right = barHeight + barMargin + gap;
      else if (barPosition === "top") top = barHeight + barMargin + gap;
      else if (barPosition === "bottom") bottom = barHeight + barMargin + gap;

      var gapsValue = top + " " + right + " " + bottom + " " + left;

      // Chain: write config, then reload (ensures config is written before reload reads it)
      Quickshell.execDetached(["sh", "-c",
        "mkdir -p '" + Settings.configDir + "' && " +
        "echo 'general:gaps_out = " + gapsValue + "' > '" + gapsConfigPath + "' && " +
        "hyprctl reload"
      ]);

      Logger.d("ScreenBorder", "Startup: " + barMode + " mode - gaps=" + gapsValue);
    }
  }
  
  onBarModeChanged: {
    Logger.d("ScreenBorder", "barMode changed to: " + barMode);
    updateHyprlandGaps();
  }
  onBorderThicknessChanged: if (enabled) updateHyprlandGaps()
  onBarPositionChanged: updateHyprlandGaps()
  onBorderMarginChanged: if (enabled) updateHyprlandGaps()
  onBarGapChanged: updateHyprlandGaps()

  // Path to generated config file
  readonly property string gapsConfigPath: Settings.configDir + "/hypr-gaps.conf"

  function updateHyprlandGaps() {
    Logger.d("ScreenBorder", "updateHyprlandGaps called, barMode=" + barMode);

    if (barMode === "framed") {
      // Framed mode: BorderExclusionZones handles spacing via Wayland
      // Set gaps to 0 so hyprctl doesn't interfere
      Quickshell.execDetached(["sh", "-c",
        "mkdir -p '" + Settings.configDir + "' && " +
        "echo 'general:gaps_out = 0' > '" + gapsConfigPath + "' && " +
        "hyprctl reload"
      ]);
      Logger.d("ScreenBorder", "Framed mode - gaps=0");
    } else {
      // Classic and floating modes: gaps on all sides
      var barHeight = Style.barHeight || 40;
      var gap = barGap;

      var top = gap;
      var right = gap;
      var bottom = gap;
      var left = gap;

      // Bar side gets bar height + gap (+ margin for floating)
      var barMargin = 0;
      if (barMode === "floating") {
        barMargin = Math.ceil((Settings.data.bar.marginHorizontal ?? 0.25) * (Style.marginXL || 16));
      }

      if (barPosition === "left") left = barHeight + barMargin + gap;
      else if (barPosition === "right") right = barHeight + barMargin + gap;
      else if (barPosition === "top") top = barHeight + barMargin + gap;
      else if (barPosition === "bottom") bottom = barHeight + barMargin + gap;

      var gapsValue = top + " " + right + " " + bottom + " " + left;

      // Chain: write config, then reload
      Quickshell.execDetached(["sh", "-c",
        "mkdir -p '" + Settings.configDir + "' && " +
        "echo 'general:gaps_out = " + gapsValue + "' > '" + gapsConfigPath + "' && " +
        "hyprctl reload"
      ]);

      Logger.d("ScreenBorder", barMode + " mode - gaps=" + gapsValue);
    }
  }

  // The colored rectangle that fills the entire screen
  Rectangle {
    id: borderFill
    anchors.fill: parent
    color: root.borderColor

    // Apply color animation for smooth theme transitions
    Behavior on color {
      ColorAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutQuad
      }
    }

    // Enable layer for mask effect
    layer.enabled: root.enabled
    layer.effect: MultiEffect {
      maskSource: borderMask
      maskEnabled: true
      maskInverted: true  // Invert mask - show only where mask is NOT drawn
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }
  }

  // Mask item - draws the "cutout" area
  // IMPORTANT: The bar area is NOT cut out - it remains part of the border
  Item {
    id: borderMask
    anchors.fill: parent
    layer.enabled: true
    visible: false  // Mask source doesn't need to be visible

    Rectangle {
      id: centerCutout
      
      // The cutout leaves the bar area as part of the border
      // All edges get borderThickness margin
      // Bar side gets borderThickness + barWidth (bar sits inside the border)
      anchors.fill: parent
      anchors.topMargin: root.barPosition === "top" ? (root.borderThickness + root.barWidth) : root.borderThickness
      anchors.rightMargin: root.barPosition === "right" ? (root.borderThickness + root.barWidth) : root.borderThickness
      anchors.bottomMargin: root.barPosition === "bottom" ? (root.borderThickness + root.barWidth) : root.borderThickness
      anchors.leftMargin: root.barPosition === "left" ? (root.borderThickness + root.barWidth) : root.borderThickness
      
      radius: root.borderRounding
      color: "white"  // Any opaque color works for mask
    }
  }
}
