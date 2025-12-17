import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.System
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

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId]
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0) {
      var widgets = Settings.data.bar.widgets[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  // Task data from service
  readonly property int pendingCount: TaskService.pendingCount
  readonly property bool isAvailable: TaskService.isAvailable

  // Resolve settings
  readonly property bool hideWhenZero: (widgetSettings.hideWhenZero !== undefined) ? widgetSettings.hideWhenZero : widgetMetadata.hideWhenZero

  baseSize: Style.capsuleHeight
  applyUiScale: false
  density: Settings.data.bar.density
  customRadius: Style.radiusL
  icon: "checklist"
  tooltipText: {
    if (!isAvailable) {
      return I18n.tr("todolist.tooltip.not-installed");
    }
    return pendingCount > 0
      ? I18n.tr("todolist.tooltip.tasks", {"count": pendingCount})
      : I18n.tr("todolist.tooltip.empty");
  }
  tooltipDirection: BarService.getTooltipDirection()
  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface
  colorBorder: Color.transparent
  colorBorderHover: Color.transparent
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("todolist.context.refresh"),
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": I18n.tr("context-menu.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
                   if (popupMenuWindow) {
                     popupMenuWindow.close();
                   }

                   if (action === "refresh") {
                     TaskService.loadTasks();
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onClicked: {
    var panel = PanelService.getPanel("todoPanel", screen);
    panel?.toggle(this);
  }

  onRightClicked: {
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (popupMenuWindow) {
      popupMenuWindow.showContextMenu(contextMenu);
      const pos = BarService.getContextMenuPosition(root, contextMenu.implicitWidth, contextMenu.implicitHeight);
      contextMenu.openAtItem(root, pos.x, pos.y);
    }
  }

  // Badge showing pending count
  Loader {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 2
    anchors.topMargin: 1
    z: 2
    active: !hideWhenZero || pendingCount > 0
    sourceComponent: Rectangle {
      id: badge
      height: 8
      width: height
      radius: Style.radiusXS
      color: Color.mPrimary
      border.color: Color.mSurface
      border.width: Style.borderS
      visible: pendingCount > 0 || !hideWhenZero
    }
  }
}
