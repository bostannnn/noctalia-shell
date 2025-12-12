import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

/**
 * Workspace Overview for Hyprland.
 * Shows a grid of workspaces with live window previews.
 * Toggle with: quickshell ipc overview toggle
 */
Scope {
  id: overviewScope

  // Only active on Hyprland
  property bool isActive: CompositorService.isHyprland

  Variants {
    id: overviewVariants
    model: isActive ? Quickshell.screens : []

    PanelWindow {
      id: root
      required property var modelData
      readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
      property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
      screen: modelData
      visible: OverviewService.isOpen

      WlrLayershell.namespace: "noctalia-overview"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      mask: Region {
        item: OverviewService.isOpen ? keyHandler : null
      }

      HyprlandFocusGrab {
        id: grab
        windows: [root]
        property bool canBeActive: root.monitorIsFocused
        active: false
        onCleared: () => {
          if (!active)
            OverviewService.close();
        }
      }

      Connections {
        target: OverviewService
        function onOverviewToggled(open) {
          if (open) {
            delayedGrabTimer.start();
          } else {
            // Reset grab state when closing
            grab.active = false;
          }
        }
      }

      Timer {
        id: delayedGrabTimer
        interval: OverviewService.raceConditionDelay
        repeat: false
        onTriggered: {
          if (!grab.canBeActive)
            return;
          grab.active = OverviewService.isOpen;
        }
      }

      implicitWidth: columnLayout.implicitWidth
      implicitHeight: columnLayout.implicitHeight

      Item {
        id: keyHandler
        anchors.fill: parent
        visible: OverviewService.isOpen
        focus: OverviewService.isOpen

        Keys.onPressed: event => {
          // close: Escape or Enter
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return) {
            OverviewService.close();
            event.accepted = true;
            return;
          }

          // Helper: compute current group bounds
          const workspacesPerGroup = OverviewService.rows * OverviewService.columns;
          const currentId = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
          const currentGroup = Math.floor((currentId - 1) / workspacesPerGroup);
          const minWorkspaceId = currentGroup * workspacesPerGroup + 1;
          const maxWorkspaceId = minWorkspaceId + workspacesPerGroup - 1;

          let targetId = null;

          // Arrow keys and vim-style hjkl
          if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            targetId = currentId - 1;
            if (targetId < minWorkspaceId) targetId = maxWorkspaceId;
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            targetId = currentId + 1;
            if (targetId > maxWorkspaceId) targetId = minWorkspaceId;
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            targetId = currentId - OverviewService.columns;
            if (targetId < minWorkspaceId) targetId += workspacesPerGroup;
          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            targetId = currentId + OverviewService.columns;
            if (targetId > maxWorkspaceId) targetId -= workspacesPerGroup;
          }

          // Number keys: jump to workspace within the current group
          else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            const position = event.key - Qt.Key_0;
            if (position <= workspacesPerGroup) {
              targetId = minWorkspaceId + position - 1;
            }
          } else if (event.key === Qt.Key_0) {
            if (workspacesPerGroup >= 10) {
              targetId = minWorkspaceId + 9;
            }
          }

          if (targetId !== null) {
            Hyprland.dispatch("workspace " + targetId);
            event.accepted = true;
          }
        }
      }

      // Semi-transparent background
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.85)
        visible: OverviewService.isOpen

        MouseArea {
          anchors.fill: parent
          onClicked: OverviewService.close()
        }
      }

      ColumnLayout {
        id: columnLayout
        visible: OverviewService.isOpen
        anchors {
          horizontalCenter: parent.horizontalCenter
          top: parent.top
          topMargin: 100
        }

        Loader {
          id: overviewLoader
          active: OverviewService.isOpen
          sourceComponent: OverviewWidget {
            panelWindow: root
            visible: true
          }
        }
      }
    }
  }

  // IPC Handler for overview commands
  IpcHandler {
    target: "overview"

    function toggle() {
      OverviewService.toggle();
    }
    function close() {
      OverviewService.close();
    }
    function open() {
      OverviewService.open();
    }
  }
}
