import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.Commons
import qs.Widgets
import qs.Widgets.LiquidGlass

/**
* AllBackgrounds - Unified Shape container for all bar and panel backgrounds
*
* Unified shadow system. This component contains a single Shape
* with multiple ShapePath children (one for bar, one for each panel type).
*
* Benefits:
* - Single GPU-accelerated rendering pass for all backgrounds
* - Unified shadow system (one MultiEffect for everything)
* - Liquid Glass theme support with frosted effects
*/
Item {
  id: root

  enabled: false  // Allow click-through to widgets below

  required property var bar
  required property var windowRoot

  // Apply panelBackgroundOpacity directly to background color for reliable transparency
  // In liquidGlass mode, use Theme.glassOpacity for more transparent look
  readonly property real effectiveOpacity: Theme.isLiquidGlass
    ? Theme.glassOpacity
    : Settings.data.ui.panelBackgroundOpacity
  readonly property color panelBackgroundColor: Qt.alpha(Color.mSurface, effectiveOpacity)
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
          id: barBackground
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

      // ===========================================
      // LIQUID GLASS OVERLAYS (when theme active)
      // ===========================================
      Loader {
        anchors.fill: parent
        active: Theme.isLiquidGlass

        sourceComponent: Item {
          anchors.fill: parent

          // Bar glass overlay (skip if transparent or framed mode)
          GlassOverlay {
            visible: !Settings.data.bar.transparent && !root.isFramedMode
            isBar: true
            bar: root.bar
          }

          // Audio panel
          GlassOverlay {
            panel: root.windowRoot.audioPanelPlaceholder
          }

          // Battery panel
          GlassOverlay {
            panel: root.windowRoot.batteryPanelPlaceholder
          }

          // Bluetooth panel
          GlassOverlay {
            panel: root.windowRoot.bluetoothPanelPlaceholder
          }

          // Brightness panel
          GlassOverlay {
            panel: root.windowRoot.brightnessPanelPlaceholder
          }

          // Clock panel
          GlassOverlay {
            panel: root.windowRoot.clockPanelPlaceholder
          }

          // Control Center panel
          GlassOverlay {
            panel: root.windowRoot.controlCenterPanelPlaceholder
          }

          // Changelog panel
          GlassOverlay {
            panel: root.windowRoot.changelogPanelPlaceholder
          }

          // Launcher panel
          GlassOverlay {
            panel: root.windowRoot.launcherPanelPlaceholder
          }

          // Notification History panel
          GlassOverlay {
            panel: root.windowRoot.notificationHistoryPanelPlaceholder
          }

          // Session Menu panel (skip if large buttons style)
          GlassOverlay {
            visible: !Settings.data.sessionMenu.largeButtonsStyle
            panel: root.windowRoot.sessionMenuPanelPlaceholder
          }

          // Settings panel
          GlassOverlay {
            panel: root.windowRoot.settingsPanelPlaceholder
          }

          // Setup Wizard panel
          GlassOverlay {
            panel: root.windowRoot.setupWizardPanelPlaceholder
          }

          // TodoList panel
          GlassOverlay {
            panel: root.windowRoot.todoPanelPlaceholder
          }

          // TrayDrawer panel
          GlassOverlay {
            panel: root.windowRoot.trayDrawerPanelPlaceholder
          }

          // Wallpaper panel
          GlassOverlay {
            panel: root.windowRoot.wallpaperPanelPlaceholder
          }

          // WiFi panel
          GlassOverlay {
            panel: root.windowRoot.wifiPanelPlaceholder
          }

          // Plugin Panel 1
          GlassOverlay {
            panel: root.windowRoot.pluginPanel1Placeholder
          }

          // Plugin Panel 2
          GlassOverlay {
            panel: root.windowRoot.pluginPanel2Placeholder
          }
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
