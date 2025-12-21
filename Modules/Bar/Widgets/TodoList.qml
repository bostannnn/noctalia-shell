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
  readonly property string formattedCount: pendingCount > 99 ? "99+" : pendingCount.toString()
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
      }
    ]

    onTriggered: function(action) {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
      if (popupMenuWindow) {
        popupMenuWindow.close();
      }

      if (action === "refresh") {
        TaskService.loadTasks();
      }
    }
  }

  onClicked: {
    var panel = PanelService.getPanel("todoPanel", screen);
    if (panel) panel.toggle(this);
  }

  onRightClicked: {
    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (popupMenuWindow) {
      popupMenuWindow.showContextMenu(contextMenu);
      var pos = BarService.getContextMenuPosition(root, contextMenu.implicitWidth, contextMenu.implicitHeight);
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
    active: pendingCount > 0 || !hideWhenZero
    sourceComponent: Rectangle {
      readonly property real horizontalPadding: 4
      height: Math.max(Style.fontSizeS + 4, 14)
      width: countLabel.implicitWidth + horizontalPadding * 2
      radius: height / 2
      color: Color.mPrimary
      border.color: Color.mSurface
      border.width: Style.borderS

      NText {
        id: countLabel
        anchors.centerIn: parent
        text: root.formattedCount
        color: Color.mOnPrimary
        font.pixelSize: Style.fontSizeS
        font.weight: Font.DemiBold
      }
    }
  }
}
