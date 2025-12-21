import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Bar
import qs.Services.UI
import qs.Widgets

/**
* BarContentWindow - Separate transparent PanelWindow for bar content
*
* This window contains only the bar widgets (content), while the background
* is rendered in MainScreen's unified Shape system. This separation prevents
* fullscreen redraws when bar widgets redraw.
*
* Bar modes:
*   - "classic": Bar at screen edge, no margins
*   - "floating": Bar with margins around it
*   - "framed": Bar inside screen border (caelestia style)
*
* This component should be instantiated once per screen by AllScreens.qml
*/
NLayerShellWindow {
  id: barWindow

  // Note: screen property is inherited from PanelWindow and should be set by parent
  color: Color.transparent // Transparent - background is in MainScreen below

  Component.onCompleted: {
    Logger.d("BarContentWindow", "Bar content window created for screen:", barWindow.screen?.name, "mode:", barMode);
  }

  // Wayland layer configuration
  layerNamespace: "noctalia-bar-content-" + (barWindow.screen?.name || "unknown")
  layerShellLayer: WlrLayer.Top
  layerShellExclusionMode: ExclusionMode.Ignore // Don't reserve space - BarExclusionZone in MainScreen handles that

  // Position and size to match bar location
  readonly property string barPosition: Settings.data.bar.position || "top"
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  
  // Bar mode: "classic", "floating", or "framed"
  readonly property string barMode: Settings.data.bar.mode ?? "classic"
  readonly property bool isFloating: barMode === "floating"
  readonly property bool isFramed: barMode === "framed"
  
  // Floating mode margins
  readonly property real barMarginH: Math.ceil(isFloating ? Settings.data.bar.marginHorizontal * Style.marginXL : 0)
  readonly property real barMarginV: Math.ceil(isFloating ? Settings.data.bar.marginVertical * Style.marginXL : 0)
  
  // Framed mode offset (bar sits inside the border)
  readonly property int borderThickness: Settings.data.general.screenBorderThickness ?? 10
  readonly property int borderOffset: isFramed ? borderThickness : 0

  // Anchor to the bar's edge
  anchors {
    top: barPosition === "top" || barIsVertical
    bottom: barPosition === "bottom" || barIsVertical
    left: barPosition === "left" || !barIsVertical
    right: barPosition === "right" || !barIsVertical
  }

  // Handle margins based on mode
  // In framed mode, bar window covers full border+bar area
  // Bar's own edge: no margin (window starts at screen edge)
  // Other edges: borderThickness margin
  margins {
    top: barMarginV + ((isFramed && barPosition !== "top") ? borderThickness : 0)
    bottom: barMarginV + ((isFramed && barPosition !== "bottom") ? borderThickness : 0)
    left: barMarginH + ((isFramed && barPosition !== "left") ? borderThickness : 0)
    right: barMarginH + ((isFramed && barPosition !== "right") ? borderThickness : 0)
  }

  // Set window size
  // In framed mode, include border area so widgets center across full visual area
  implicitWidth: barIsVertical ? (Style.barHeight + (isFramed ? borderThickness : 0)) : barWindow.screen.width
  implicitHeight: barIsVertical ? barWindow.screen.height : (Style.barHeight + (isFramed ? borderThickness : 0))

  // Bar content fills the window
  // In framed mode, window is 50px (border+bar), widgets will center at 25px
  Bar {
    id: barContent
    anchors.fill: parent
    screen: barWindow.screen
  }
}
