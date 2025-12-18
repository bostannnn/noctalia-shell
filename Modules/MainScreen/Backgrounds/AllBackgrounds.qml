import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Widgets

/**
* AllBackgrounds - Unified Shape container for all bar and panel backgrounds
*
* Unified shadow system. This component contains a single Shape
* with multiple ShapePath children (one for bar, one for each panel type).
*
* Benefits:
* - Single GPU-accelerated rendering pass for all backgrounds
* - Unified shadow system (one MultiEffect for everything)
*/
Item {
  id: root

  enabled: false  // Allow click-through to widgets below

  required property var bar
  required property var windowRoot

  // Apply panelBackgroundOpacity directly to background color for reliable transparency
  readonly property color panelBackgroundColor: Qt.alpha(Color.mSurface, Settings.data.ui.panelBackgroundOpacity)
  readonly property bool isFramedMode: (Settings.data.bar.mode ?? "classic") === "framed"

  anchors.fill: parent

  // Wrapper with layer caching for shadow performance
  Item {
    anchors.fill: parent
    layer.enabled: true

    // Content container - holds both border frame and shape backgrounds
    Item {
      id: backgroundsContainer
      anchors.fill: parent

      // Border frame (framed mode only) - must be rendered before Shape for correct z-order
      BorderFrameMasked {
        backgroundColor: panelBackgroundColor
      }

      Shape {
        id: backgroundsShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        enabled: false

        // Bar background - transparent in framed mode (BorderFrameMasked provides it)
        BarBackground {
          bar: root.bar
          shapeContainer: backgroundsShape
          windowRoot: root.windowRoot
          backgroundColor: (Settings.data.bar.transparent || root.isFramedMode) ? "transparent" : panelBackgroundColor
        }

        /**
        *  Panels
        */

        // Audio
        PanelBackground {
          panel: root.windowRoot.audioPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Battery
        PanelBackground {
          panel: root.windowRoot.batteryPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Bluetooth
        PanelBackground {
          panel: root.windowRoot.bluetoothPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Brightness
        PanelBackground {
          panel: root.windowRoot.brightnessPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Clock
        PanelBackground {
          panel: root.windowRoot.clockPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Control Center
        PanelBackground {
          panel: root.windowRoot.controlCenterPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Changelog
        PanelBackground {
          panel: root.windowRoot.changelogPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Launcher
        PanelBackground {
          panel: root.windowRoot.launcherPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Notification History
        PanelBackground {
          panel: root.windowRoot.notificationHistoryPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Session Menu
        PanelBackground {
          panel: root.windowRoot.sessionMenuPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: Settings.data.sessionMenu.largeButtonsStyle ? Color.transparent : panelBackgroundColor
        }

        // Settings
        PanelBackground {
          panel: root.windowRoot.settingsPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Setup Wizard
        PanelBackground {
          panel: root.windowRoot.setupWizardPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // TodoList
        PanelBackground {
          panel: root.windowRoot.todoPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // TrayDrawer
        PanelBackground {
          panel: root.windowRoot.trayDrawerPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Wallpaper
        PanelBackground {
          panel: root.windowRoot.wallpaperPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // WiFi
        PanelBackground {
          panel: root.windowRoot.wifiPanelPlaceholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Plugin Panel Slot 1
        PanelBackground {
          panel: root.windowRoot.pluginPanel1Placeholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }

        // Plugin Panel Slot 2
        PanelBackground {
          panel: root.windowRoot.pluginPanel2Placeholder
          shapeContainer: backgroundsShape
          backgroundColor: panelBackgroundColor
        }
      }
    }

    // Unified shadow for all backgrounds (including border frame in framed mode)
    NDropShadow {
      anchors.fill: parent
      source: backgroundsContainer
    }
  }
}
