import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

 /**
 * Workspace Overview for Hyprland.
 * Shows a grid of workspaces with live window previews.
 * Toggle with: quickshell ipc call overview toggle
 */
Scope {
  id: overviewScope

  // Only active on Hyprland
  property bool isActive: CompositorService.isHyprland

  // Fullscreen background layer - covers entire screen including bar area
  Variants {
    id: backgroundVariants
    model: isActive ? Quickshell.screens : []

    NLayerShellWindow {
      id: bgWindow
      required property var modelData
      screen: modelData
      visible: OverviewService.backgroundVisible

      layerNamespace: "noctalia-overview-bg"
      // Keep the background below the actual overview UI (which is Overlay),
      // otherwise it can occlude the grid and look like a "grey screen".
      layerShellLayer: WlrLayer.Top
      layerShellExclusionMode: ExclusionMode.Ignore
      // Dim the screen while keeping the overview UI readable.
      color: Qt.rgba(0, 0, 0, 0.55)

      // Use screen dimensions directly to cover full screen
      implicitWidth: screen?.width ?? 1920
      implicitHeight: screen?.height ?? 1080

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      // Click anywhere on background to cancel
      MouseArea {
        anchors.fill: parent
        onClicked: OverviewService.cancel()
      }
    }
  }

  // Main overview UI layer
  Variants {
    id: overviewVariants
    model: isActive ? Quickshell.screens : []

    NLayerShellWindow {
      id: root
      required property var modelData
      readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
      property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
      screen: modelData
      visible: OverviewService.isOpen

      layerNamespace: "noctalia-overview"
      layerShellLayer: WlrLayer.Overlay
      layerShellKeyboardFocus: WlrKeyboardFocus.Exclusive
      layerShellExclusionMode: ExclusionMode.Ignore
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

      implicitWidth: columnLayout.implicitWidth
      implicitHeight: columnLayout.implicitHeight

      Item {
        id: keyHandler
        anchors.fill: parent
        visible: OverviewService.isOpen
        focus: OverviewService.isOpen

        Keys.onPressed: event => {
          // Escape: cancel and return to original workspace
          if (event.key === Qt.Key_Escape) {
            OverviewService.cancel();
            event.accepted = true;
            return;
          }

          // Enter: close and stay on current workspace
          if (event.key === Qt.Key_Return) {
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
            OverviewService.setCurrentWorkspace(targetId);
            event.accepted = true;
          }
        }
      }

      ColumnLayout {
        id: columnLayout
        visible: OverviewService.isOpen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.10)

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

  // IPC wiring lives in `Services/Control/IPCService.qml` to keep all IPC targets centralized.
}
