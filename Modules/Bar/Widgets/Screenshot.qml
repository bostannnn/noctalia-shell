import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0) {
      var widgets = Settings.data.bar.widgets[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  // Default mode from settings or "screen" (fullscreen)
  readonly property string defaultMode: widgetSettings.defaultMode ?? "screen"

  icon: ScreenshotService.isPending ? "" : "screenshot"
  tooltipText: I18n.tr("tooltips.screenshot")
  tooltipDirection: BarService.getTooltipDirection()
  density: Settings.data.bar.density
  baseSize: Style.capsuleHeight
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface
  colorBorder: Color.transparent
  colorBorderHover: Color.transparent
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    ScreenshotService.takeScreenshot(defaultMode);
  }

  onRightClicked: {
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (popupMenuWindow) {
      popupMenuWindow.showContextMenu(contextMenu);
      const pos = BarService.getContextMenuPosition(root, contextMenu.implicitWidth, contextMenu.implicitHeight);
      contextMenu.openAtItem(root, pos.x, pos.y);
    }
  }

  // Right-click context menu
  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("context-menu.screenshot-screen"),
        "action": "screen",
        "icon": "device-desktop"
      },
      {
        "label": I18n.tr("context-menu.screenshot-region"),
        "action": "region",
        "icon": "crop"
      },
      {
        "label": I18n.tr("context-menu.screenshot-annotate-last"),
        "action": "annotate",
        "icon": "pencil",
        "enabled": ScreenshotService.lastScreenshot !== ""
      },
      {
        "label": I18n.tr("context-menu.screenshot-open-folder"),
        "action": "open-folder",
        "icon": "folder"
      },
      {
        "label": I18n.tr("context-menu.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
      if (popupMenuWindow) {
        popupMenuWindow.close();
      }

      switch (action) {
        case "region":
          ScreenshotService.takeScreenshot(ScreenshotService.modeRegion);
          break;
        case "screen":
          ScreenshotService.takeScreenshot(ScreenshotService.modeScreen);
          break;
        case "annotate":
          ScreenshotService.annotateLastScreenshot();
          break;
        case "open-folder":
          ScreenshotService.openScreenshotFolder();
          break;
        case "widget-settings":
          BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
          break;
      }
    }
  }

  // Spinner shown during pending screenshot
  NIcon {
    id: pendingSpinner
    icon: "loader-2"
    visible: ScreenshotService.isPending
    pointSize: {
      switch (root.density) {
        case "compact":
          return Math.max(1, root.width * 0.65);
        default:
          return Math.max(1, root.width * 0.48);
      }
    }
    applyUiScale: root.applyUiScale
    color: root.enabled && root.hovering ? colorFgHover : colorFg
    anchors.centerIn: parent
    transformOrigin: Item.Center

    RotationAnimation on rotation {
      running: ScreenshotService.isPending
      from: 0
      to: 360
      duration: Style.animationSlow
      loops: Animation.Infinite
      onStopped: pendingSpinner.rotation = 0
    }
  }
}
