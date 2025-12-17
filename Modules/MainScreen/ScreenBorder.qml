import QtQuick
import Quickshell
import qs.Commons

/**
 * ScreenBorder - Manages Hyprland gaps for all bar modes
 *
 * Gap behavior:
 *   - classic/floating: gaps provide margin between bar and windows
 *   - framed: gaps handled by BorderExclusionZones (Wayland approach)
 *
 * Note: Visual border rendering is handled by BorderFrameBackground in AllBackgrounds
 */
Item {
  id: root

  // Bar position awareness
  readonly property string barMode: Settings.data.bar.mode ?? "classic"
  readonly property string barPosition: Settings.data.bar?.position ?? "left"
  readonly property int barGap: Settings.data.bar.gap ?? 10

  // Path to generated config file
  readonly property string gapsConfigPath: Settings.configDir + "/hypr-gaps.conf"

  anchors.fill: parent
  visible: false  // No visual rendering - gaps only

  // Apply Hyprland gaps on startup
  Component.onCompleted: {
    startupTimer.start();
  }

  Timer {
    id: startupTimer
    interval: 100
    onTriggered: root.applyHyprlandGaps()
  }

  onBarModeChanged: applyHyprlandGaps()
  onBarPositionChanged: applyHyprlandGaps()
  onBarGapChanged: applyHyprlandGaps()

  // Calculate and apply Hyprland gaps based on current bar mode
  function applyHyprlandGaps() {
    var gapsValue = calculateGapsValue();

    Quickshell.execDetached(["sh", "-c",
      "mkdir -p '" + Settings.configDir + "' && " +
      "echo 'general:gaps_out = " + gapsValue + "' > '" + gapsConfigPath + "' && " +
      "hyprctl reload"
    ]);

    Logger.d("ScreenBorder", barMode + " mode - gaps=" + gapsValue);
  }

  // Calculate gaps value based on bar mode
  function calculateGapsValue() {
    if (barMode === "framed") {
      return "0";
    }

    var barHeight = Style.barHeight || 40;
    var gap = barGap;
    var top = gap, right = gap, bottom = gap, left = gap;

    // Bar side gets bar height + gap (+ margin for floating)
    var floatingMargin = 0;
    if (barMode === "floating") {
      floatingMargin = Math.ceil((Settings.data.bar.marginHorizontal ?? 0.25) * (Style.marginXL || 16));
    }

    switch (barPosition) {
      case "left": left = barHeight + floatingMargin + gap; break;
      case "right": right = barHeight + floatingMargin + gap; break;
      case "top": top = barHeight + floatingMargin + gap; break;
      case "bottom": bottom = barHeight + floatingMargin + gap; break;
    }

    return top + " " + right + " " + bottom + " " + left;
  }
}
