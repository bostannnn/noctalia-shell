import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

/**
 * The main overview widget showing workspace grid with window previews.
 */
Item {
  id: root
  required property var panelWindow
  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
  readonly property int workspacesShown: OverviewService.rows * OverviewService.columns
  readonly property int workspaceGroup: {
    const wsId = monitor?.activeWorkspace?.id ?? 1;
    return Math.floor((wsId - 1) / workspacesShown);
  }
  property var windowByAddress: HyprlandDataService.windowByAddress
  property var monitorData: HyprlandDataService.monitors.find(m => m.id === root.monitor?.id)
  property real scale: OverviewService.scale
  property color activeBorderColor: Color.mSecondary

  property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ?
      (((monitor?.height ?? 1080) / (monitor?.scale ?? 1) - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.scale) :
      (((monitor?.width ?? 1920) / (monitor?.scale ?? 1) - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.scale)
  property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ?
      (((monitor?.width ?? 1920) / (monitor?.scale ?? 1) - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.scale) :
      (((monitor?.height ?? 1080) / (monitor?.scale ?? 1) - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.scale)

  property real workspaceNumberSize: 250 * (monitor?.scale ?? 1)
  property int workspaceZ: 0
  property int windowZ: 1
  property int windowDraggingZ: 99999
  property real workspaceSpacing: 5
  property real elevationMargin: 10

  property int draggingFromWorkspace: -1
  property int draggingTargetWorkspace: -1

  implicitWidth: overviewBackground.implicitWidth + elevationMargin * 2
  implicitHeight: overviewBackground.implicitHeight + elevationMargin * 2

  // Shadow
  NDropShadow {
    anchors.fill: overviewBackground
    source: overviewBackground
    shadowColor: Color.mShadow
  }

  Rectangle {
    id: overviewBackground
    property real padding: 10
    anchors.fill: parent
    anchors.margins: elevationMargin

    implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
    implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
    radius: Style.screenRadius * root.scale + padding
    color: Color.mSurface
    border.width: Style.borderS
    border.color: Color.mOutline

    ColumnLayout {
      id: workspaceColumnLayout
      z: root.workspaceZ
      anchors.centerIn: parent
      spacing: root.workspaceSpacing

      Repeater {
        model: OverviewService.rows
        delegate: RowLayout {
          id: row
          property int rowIndex: index
          spacing: root.workspaceSpacing

          Repeater {
            model: OverviewService.columns
            Rectangle {
              id: workspace
              property int colIndex: index
              property int workspaceValue: root.workspaceGroup * root.workspacesShown + rowIndex * OverviewService.columns + colIndex + 1
              property color defaultWorkspaceColor: Color.mSurfaceVariant
              property color hoveredWorkspaceColor: Qt.lighter(defaultWorkspaceColor, 1.1)
              property color hoveredBorderColor: Color.mHover
              property bool hoveredWhileDragging: false

              implicitWidth: root.workspaceImplicitWidth
              implicitHeight: root.workspaceImplicitHeight
              color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
              radius: Style.screenRadius * root.scale
              border.width: 2
              border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

              // Workspace number
              NText {
                anchors.centerIn: parent
                text: workspace.workspaceValue
                font.pixelSize: root.workspaceNumberSize * root.scale
                font.weight: Font.DemiBold
                color: Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.2)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              MouseArea {
                id: workspaceArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: {
                  if (root.draggingTargetWorkspace === -1) {
                    OverviewService.close();
                    Hyprland.dispatch(`workspace ${workspace.workspaceValue}`);
                  }
                }
              }

              DropArea {
                anchors.fill: parent
                onEntered: {
                  root.draggingTargetWorkspace = workspace.workspaceValue;
                  if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                  hoveredWhileDragging = true;
                }
                onExited: {
                  hoveredWhileDragging = false;
                  if (root.draggingTargetWorkspace == workspace.workspaceValue) root.draggingTargetWorkspace = -1;
                }
              }
            }
          }
        }
      }
    }

    Item {
      id: windowSpace
      anchors.centerIn: parent
      implicitWidth: workspaceColumnLayout.implicitWidth
      implicitHeight: workspaceColumnLayout.implicitHeight

      // Window repeater
      Repeater {
        model: ScriptModel {
          values: {
            if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values) {
              return [];
            }
            
            var results = [];
            var toplevels = ToplevelManager.toplevels.values;
            
            for (var i = 0; i < toplevels.length; i++) {
              var toplevel = toplevels[i];
              if (!toplevel) continue;
              
              // Try different ways to get address
              var hyprToplevel = toplevel.HyprlandToplevel;
              if (!hyprToplevel) continue;
              
              var rawAddr = hyprToplevel.address;
              if (!rawAddr) continue;
              
              // Check if address already has 0x prefix
              var addr = rawAddr.startsWith("0x") ? rawAddr : `0x${rawAddr}`;
              
              var win = windowByAddress[addr];
              if (!win) continue;
              
              var wsId = win.workspace?.id;
              var inGroup = wsId >= root.workspaceGroup * root.workspacesShown + 1 &&
                     wsId <= (root.workspaceGroup + 1) * root.workspacesShown;
              
              if (inGroup) {
                results.push(toplevel);
              }
            }
            
            // Sort results
            results.sort((a, b) => {
              var addrA = a.HyprlandToplevel?.address ?? "";
              addrA = addrA.startsWith("0x") ? addrA : `0x${addrA}`;
              var addrB = b.HyprlandToplevel?.address ?? "";
              addrB = addrB.startsWith("0x") ? addrB : `0x${addrB}`;
              var winA = windowByAddress[addrA];
              var winB = windowByAddress[addrB];

              if (winA?.pinned !== winB?.pinned) {
                return winA?.pinned ? 1 : -1;
              }
              if (winA?.floating !== winB?.floating) {
                return winA?.floating ? 1 : -1;
              }
              return (winB?.focusHistoryID ?? 0) - (winA?.focusHistoryID ?? 0);
            });
            
            return results;
          }
        }
        delegate: OverviewWindow {
          id: window
          required property var modelData
          required property int index
          property int monitorId: windowData?.monitor ?? 0
          property var windowMonitor: HyprlandDataService.monitors.find(m => m.id === monitorId)
          property string rawAddress: modelData.HyprlandToplevel?.address ?? ""
          property string address: rawAddress.startsWith("0x") ? rawAddress : `0x${rawAddress}`
          windowData: windowByAddress[address] ?? null
          toplevel: modelData
          monitorData: windowMonitor

          property real sourceMonitorWidth: (windowMonitor?.transform % 2 === 1) ?
              (windowMonitor?.height ?? 1920) / (windowMonitor?.scale ?? 1) - (windowMonitor?.reserved?.[0] ?? 0) - (windowMonitor?.reserved?.[2] ?? 0) :
              (windowMonitor?.width ?? 1920) / (windowMonitor?.scale ?? 1) - (windowMonitor?.reserved?.[0] ?? 0) - (windowMonitor?.reserved?.[2] ?? 0)
          property real sourceMonitorHeight: (windowMonitor?.transform % 2 === 1) ?
              (windowMonitor?.width ?? 1080) / (windowMonitor?.scale ?? 1) - (windowMonitor?.reserved?.[1] ?? 0) - (windowMonitor?.reserved?.[3] ?? 0) :
              (windowMonitor?.height ?? 1080) / (windowMonitor?.scale ?? 1) - (windowMonitor?.reserved?.[1] ?? 0) - (windowMonitor?.reserved?.[3] ?? 0)

          scale: Math.min(
            root.workspaceImplicitWidth / Math.max(sourceMonitorWidth, 1),
            root.workspaceImplicitHeight / Math.max(sourceMonitorHeight, 1)
          )

          availableWorkspaceWidth: root.workspaceImplicitWidth
          availableWorkspaceHeight: root.workspaceImplicitHeight
          widgetMonitorId: root.monitor?.id ?? 0

          property bool atInitPosition: (initX == x && initY == y)

          property int workspaceColIndex: ((windowData?.workspace?.id ?? 1) - 1) % OverviewService.columns
          property int workspaceRowIndex: Math.floor(((windowData?.workspace?.id ?? 1) - 1) % root.workspacesShown / OverviewService.columns)
          xOffset: (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColIndex
          yOffset: (root.workspaceImplicitHeight + root.workspaceSpacing) * workspaceRowIndex

          Timer {
            id: updateWindowPosition
            interval: OverviewService.raceConditionDelay
            repeat: false
            running: false
            onTriggered: {
              window.x = Math.round(Math.max((windowData?.at[0] ?? 0) - (windowMonitor?.x ?? 0) - (windowMonitor?.reserved?.[0] ?? 0), 0) * root.scale + xOffset);
              window.y = Math.round(Math.max((windowData?.at[1] ?? 0) - (windowMonitor?.y ?? 0) - (windowMonitor?.reserved?.[1] ?? 0), 0) * root.scale + yOffset);
            }
          }

          z: atInitPosition ? (root.windowZ + index) : root.windowDraggingZ
          Drag.hotSpot.x: targetWindowWidth / 2
          Drag.hotSpot.y: targetWindowHeight / 2

          MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: window.hovered = true
            onExited: window.hovered = false
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            drag.target: parent

            onPressed: (mouse) => {
              root.draggingFromWorkspace = windowData?.workspace?.id ?? -1;
              window.pressed = true;
              window.Drag.active = true;
              window.Drag.source = window;
              window.Drag.hotSpot.x = mouse.x;
              window.Drag.hotSpot.y = mouse.y;
            }

            onReleased: {
              const targetWorkspace = root.draggingTargetWorkspace;
              window.pressed = false;
              window.Drag.active = false;
              root.draggingFromWorkspace = -1;
              if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace?.id) {
                Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${window.windowData?.address}`);
                updateWindowPosition.restart();
              } else {
                window.x = window.initX;
                window.y = window.initY;
              }
            }

            onClicked: (event) => {
              if (!windowData) return;

              if (event.button === Qt.LeftButton) {
                OverviewService.close();
                Hyprland.dispatch(`focuswindow address:${windowData.address}`);
                event.accepted = true;
              } else if (event.button === Qt.MiddleButton) {
                Hyprland.dispatch(`closewindow address:${windowData.address}`);
                event.accepted = true;
              }
            }

            ToolTip {
              id: windowTooltip
              visible: dragArea.containsMouse && !window.Drag.active && windowData
              delay: Style.tooltipDelay
              text: windowData ? `${windowData.title ?? "Unknown"}\n[${windowData.class ?? "unknown"}]${windowData.xwayland ? " [XWayland]" : ""}` : ""

              background: Rectangle {
                color: Color.mSurfaceVariant
                radius: Style.radiusXS
                border.width: Style.borderS
                border.color: Color.mOutline
              }

              contentItem: NText {
                text: windowTooltip.text
                color: Color.mOnSurfaceVariant
                font.pixelSize: Style.fontSizeS
              }
            }
          }
        }
      }

      // Focused workspace indicator
      Rectangle {
        id: focusedWorkspaceIndicator
        property int activeWorkspaceInGroup: (monitor?.activeWorkspace?.id ?? 1) - (root.workspaceGroup * root.workspacesShown)
        property int activeWorkspaceRowIndex: Math.max(0, Math.floor((activeWorkspaceInGroup - 1) / OverviewService.columns))
        property int activeWorkspaceColIndex: Math.max(0, (activeWorkspaceInGroup - 1) % OverviewService.columns)
        x: (root.workspaceImplicitWidth + root.workspaceSpacing) * activeWorkspaceColIndex
        y: (root.workspaceImplicitHeight + root.workspaceSpacing) * activeWorkspaceRowIndex
        z: root.windowZ
        width: root.workspaceImplicitWidth
        height: root.workspaceImplicitHeight
        color: "transparent"
        radius: Style.screenRadius * root.scale
        border.width: 2
        border.color: root.activeBorderColor

        Behavior on x {
          NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutCubic
          }
        }
        Behavior on y {
          NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}


