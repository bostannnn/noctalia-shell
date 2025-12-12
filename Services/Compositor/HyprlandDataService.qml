pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons

/**
 * Provides access to Hyprland data not available in Quickshell.Hyprland.
 * Used primarily by the workspace overview for window positioning.
 */
Singleton {
  id: root

  property var windowList: []
  property var addresses: []
  property var windowByAddress: ({})
  property var workspaces: []
  property var workspaceIds: []
  property var workspaceById: ({})
  property var activeWorkspace: null
  property var monitors: []
  property var layers: ({})

  function updateWindowList() {
    getClients.running = true;
  }

  function updateLayers() {
    getLayers.running = true;
  }

  function updateMonitors() {
    getMonitors.running = true;
  }

  function updateWorkspaces() {
    getWorkspaces.running = true;
    getActiveWorkspace.running = true;
  }

  function updateAll() {
    updateWindowList();
    updateMonitors();
    updateLayers();
    updateWorkspaces();
  }

  function biggestWindowForWorkspace(workspaceId) {
    const windowsInThisWorkspace = root.windowList.filter(w => w?.workspace?.id == workspaceId);
    return windowsInThisWorkspace.reduce((maxWin, win) => {
      const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
      const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
      return winArea > maxArea ? win : maxWin;
    }, null);
  }

  Component.onCompleted: {
    updateAll();
  }

  // Debounce timer to prevent excessive updates
  Timer {
    id: debounceTimer
    interval: 50
    repeat: false
    onTriggered: updateAll()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      // Debounce updates - restart timer on each event
      debounceTimer.restart();
    }
  }

  Process {
    id: getClients
    command: ["hyprctl", "clients", "-j"]
    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function(line) {
        getClients.accumulatedOutput += line;
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandDataService", "Failed to query clients, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        root.windowList = JSON.parse(accumulatedOutput);
        let tempWinByAddress = {};
        for (var i = 0; i < root.windowList.length; ++i) {
          var win = root.windowList[i];
          if (win?.address) {
            tempWinByAddress[win.address] = win;
          }
        }
        root.windowByAddress = tempWinByAddress;
        root.addresses = root.windowList.filter(win => win?.address).map(win => win.address);
      } catch (e) {
        Logger.e("HyprlandDataService", "Failed to parse clients:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  Process {
    id: getMonitors
    command: ["hyprctl", "monitors", "-j"]
    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function(line) {
        getMonitors.accumulatedOutput += line;
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandDataService", "Failed to query monitors, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        root.monitors = JSON.parse(accumulatedOutput);
      } catch (e) {
        Logger.e("HyprlandDataService", "Failed to parse monitors:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  Process {
    id: getLayers
    command: ["hyprctl", "layers", "-j"]
    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function(line) {
        getLayers.accumulatedOutput += line;
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandDataService", "Failed to query layers, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        root.layers = JSON.parse(accumulatedOutput);
      } catch (e) {
        Logger.e("HyprlandDataService", "Failed to parse layers:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  Process {
    id: getWorkspaces
    command: ["hyprctl", "workspaces", "-j"]
    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function(line) {
        getWorkspaces.accumulatedOutput += line;
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandDataService", "Failed to query workspaces, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        root.workspaces = JSON.parse(accumulatedOutput);
        let tempWorkspaceById = {};
        for (var i = 0; i < root.workspaces.length; ++i) {
          var ws = root.workspaces[i];
          if (ws?.id !== undefined) {
            tempWorkspaceById[ws.id] = ws;
          }
        }
        root.workspaceById = tempWorkspaceById;
        root.workspaceIds = root.workspaces.filter(ws => ws?.id !== undefined).map(ws => ws.id);
      } catch (e) {
        Logger.e("HyprlandDataService", "Failed to parse workspaces:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }

  Process {
    id: getActiveWorkspace
    command: ["hyprctl", "activeworkspace", "-j"]
    property string accumulatedOutput: ""

    stdout: SplitParser {
      onRead: function(line) {
        getActiveWorkspace.accumulatedOutput += line;
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0 || !accumulatedOutput) {
        Logger.e("HyprlandDataService", "Failed to query active workspace, exit code:", exitCode);
        accumulatedOutput = "";
        return;
      }

      try {
        root.activeWorkspace = JSON.parse(accumulatedOutput);
      } catch (e) {
        Logger.e("HyprlandDataService", "Failed to parse active workspace:", e);
      } finally {
        accumulatedOutput = "";
      }
    }
  }
}
