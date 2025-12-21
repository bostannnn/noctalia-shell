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

  JsonProcess {
    id: getClients
    command: ["hyprctl", "clients", "-j"]
    logTag: "HyprlandDataService"

    onJsonReady: function(clients) {
      root.windowList = clients;
      let tempWinByAddress = {};
      for (var i = 0; i < root.windowList.length; ++i) {
        var win = root.windowList[i];
        if (win?.address) {
          tempWinByAddress[win.address] = win;
        }
      }
      root.windowByAddress = tempWinByAddress;
      root.addresses = root.windowList.filter(win => win?.address).map(win => win.address);
    }
  }

  JsonProcess {
    id: getMonitors
    command: ["hyprctl", "monitors", "-j"]
    logTag: "HyprlandDataService"
    onJsonReady: function(monitors) {
      root.monitors = monitors;
    }
  }

  JsonProcess {
    id: getLayers
    command: ["hyprctl", "layers", "-j"]
    logTag: "HyprlandDataService"
    onJsonReady: function(layers) {
      root.layers = layers;
    }
  }

  JsonProcess {
    id: getWorkspaces
    command: ["hyprctl", "workspaces", "-j"]
    logTag: "HyprlandDataService"
    onJsonReady: function(workspaces) {
      root.workspaces = workspaces;
      let tempWorkspaceById = {};
      for (var i = 0; i < root.workspaces.length; ++i) {
        var ws = root.workspaces[i];
        if (ws?.id !== undefined) {
          tempWorkspaceById[ws.id] = ws;
        }
      }
      root.workspaceById = tempWorkspaceById;
      root.workspaceIds = root.workspaces.filter(ws => ws?.id !== undefined).map(ws => ws.id);
    }
  }

  JsonProcess {
    id: getActiveWorkspace
    command: ["hyprctl", "activeworkspace", "-j"]
    logTag: "HyprlandDataService"
    onJsonReady: function(activeWorkspace) {
      root.activeWorkspace = activeWorkspace;
    }
  }
}
