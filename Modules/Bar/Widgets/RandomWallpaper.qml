import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Auto-shuffle state
  property bool autoShuffle: Settings.data.wallpaper.randomEnabled ?? false

  icon: "dice"
  tooltipText: autoShuffle 
    ? I18n.tr("tooltips.random-wallpaper-auto", { "interval": Settings.data.wallpaper.randomIntervalSec || 300 })
    : I18n.tr("tooltips.random-wallpaper")
  tooltipDirection: BarService.getTooltipDirection()
  density: Settings.data.bar.density
  baseSize: Style.capsuleHeight
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: autoShuffle ? Qt.alpha(Color.mPrimary, 0.18) : Style.capsuleColor
  colorFg: autoShuffle ? Color.mPrimary : Color.mOnSurface
  colorBorder: Color.transparent
  colorBorderHover: Color.transparent

  // Click to shuffle
  onClicked: {
    WallpaperService.setRandomWallpaper()
  }

  // Smart rotation state
  property bool smartRotation: Settings.data.wallpaper.smartRotation ?? true
  property bool hasPrevious: WallpaperService.historyPosition > 0
  property bool hasNext: WallpaperService.historyPosition < WallpaperService.wallpaperHistory.length - 1

  // Right-click for context menu
  NPopupContextMenu {
    id: contextMenu

    model: {
      var items = [
        {
          "label": I18n.tr("context-menu.random-wallpaper") || "Random Wallpaper",
          "action": "shuffle",
          "icon": "dice"
        }
      ];

      // Add prev/next options if smart rotation is enabled
      if (root.smartRotation) {
        items.push({
          "label": I18n.tr("context-menu.previous-wallpaper") || "Previous Wallpaper",
          "action": "previous",
          "icon": "arrow-left",
          "enabled": root.hasPrevious
        });
        items.push({
          "label": I18n.tr("context-menu.next-wallpaper") || "Next Wallpaper",
          "action": "next",
          "icon": "arrow-right"
        });
      }

      items.push({
        "label": root.autoShuffle
          ? I18n.tr("context-menu.disable-auto-shuffle")
          : I18n.tr("context-menu.enable-auto-shuffle"),
        "action": "toggle-auto",
        "icon": root.autoShuffle ? "clock-off" : "clock"
      });

      return items;
    }

    onTriggered: action => {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen)
      if (popupMenuWindow) {
        popupMenuWindow.close()
      }

      if (action === "shuffle") {
        WallpaperService.setRandomWallpaper()
      } else if (action === "previous") {
        WallpaperService.previousWallpaper()
      } else if (action === "next") {
        WallpaperService.nextWallpaper()
      } else if (action === "toggle-auto") {
        Settings.data.wallpaper.randomEnabled = !Settings.data.wallpaper.randomEnabled
      }
    }
  }

  onRightClicked: {
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen)
    if (popupMenuWindow) {
      popupMenuWindow.showContextMenu(contextMenu)
      const pos = BarService.getContextMenuPosition(root, contextMenu.implicitWidth, contextMenu.implicitHeight)
      contextMenu.openAtItem(root, pos.x, pos.y)
    }
  }

  // Sync with settings
  Connections {
    target: Settings.data.wallpaper
    function onRandomEnabledChanged() {
      root.autoShuffle = Settings.data.wallpaper.randomEnabled ?? false
    }
  }
}

