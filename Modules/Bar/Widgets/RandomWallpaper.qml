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

  // Right-click for context menu
  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("context-menu.random-wallpaper"),
        "action": "shuffle",
        "icon": "dice"
      },
      {
        "label": autoShuffle 
          ? I18n.tr("context-menu.disable-auto-shuffle")
          : I18n.tr("context-menu.enable-auto-shuffle"),
        "action": "toggle-auto",
        "icon": autoShuffle ? "clock-off" : "clock"
      }
    ]

    onTriggered: action => {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen)
      if (popupMenuWindow) {
        popupMenuWindow.close()
      }

      if (action === "shuffle") {
        WallpaperService.setRandomWallpaper()
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

