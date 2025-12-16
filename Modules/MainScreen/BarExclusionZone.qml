import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

/**
* BarExclusionZone - Invisible PanelWindow that reserves exclusive space for the bar
*
* This is a minimal window that works with the compositor to reserve space,
* while the actual bar UI is rendered in MainScreen.
*
* Bar modes:
*   - "classic": Normal exclusive zone behavior
*   - "floating": Exclusive zone includes margin
*   - "framed": No exclusive zone (gaps_out handles spacing)
*/
PanelWindow {
  id: root

  // Bar mode: "classic", "floating", or "framed"
  readonly property string barMode: Settings.data.bar.mode ?? "classic"
  readonly property bool isFloating: barMode === "floating"
  readonly property bool isFramed: barMode === "framed"

  // Exclusive zone is enabled by default for classic/floating, disabled for framed
  // (BorderExclusionZones handles spacing in framed mode)
  property bool exclusive: (Settings.data.bar.exclusive ?? true) && !isFramed

  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  readonly property real barMarginH: isFloating ? Math.ceil(Settings.data.bar.marginHorizontal * Style.marginXL) : 0
  readonly property real barMarginV: isFloating ? Math.ceil(Settings.data.bar.marginVertical * Style.marginXL) : 0

  // Invisible - just reserves space
  color: "transparent"

  mask: Region {}

  // Wayland layer shell configuration
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "noctalia-bar-exclusion-" + (screen?.name || "unknown")
  WlrLayershell.exclusionMode: exclusive ? ExclusionMode.Auto : ExclusionMode.Ignore

  // Anchor based on bar position
  anchors {
    top: barPosition === "top"
    bottom: barPosition === "bottom"
    left: barPosition === "left" || barPosition === "top" || barPosition === "bottom"
    right: barPosition === "right" || barPosition === "top" || barPosition === "bottom"
  }

  // Size based on bar orientation
  // When floating, only reserve space for the bar + margin on the anchored edge
  implicitWidth: {
    if (barIsVertical) {
      // Vertical bar: reserve bar height + margin on the anchored edge only
      if (isFloating) {
        // For left bar, reserve left margin; for right bar, reserve right margin
        return Style.barHeight + barMarginH + 1;
      }
      return Style.barHeight + 1;
    }
    return 0; // Auto-width when left/right anchors are true
  }

  implicitHeight: {
    if (!barIsVertical) {
      // Horizontal bar: reserve bar height + margin on the anchored edge only
      if (isFloating) {
        // For top bar, reserve top margin; for bottom bar, reserve bottom margin
        return Style.barHeight + barMarginV + 1;
      }
      return Style.barHeight + 1;
    }
    return 0; // Auto-height when top/bottom anchors are true
  }

  Component.onCompleted: {
    Logger.d("BarExclusionZone", "Created for screen:", screen?.name, "mode:", barMode, "exclusive:", exclusive);
  }
}
