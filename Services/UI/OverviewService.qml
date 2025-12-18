pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons

/**
 * Service to manage the workspace overview state.
 * Provides open/close/toggle functionality and configuration.
 */
Singleton {
  id: root

  // Overview state
  property bool isOpen: false
  property bool backgroundVisible: false  // Separate from isOpen to mask transition

  // Configuration (can be moved to Settings later)
  property int rows: 2
  property int columns: 5
  property real scale: 0.16
  property int raceConditionDelay: 150

  // Track workspaces
  property int originalWorkspace: 1   // Workspace when overview was opened
  property int currentWorkspace: 1    // Currently navigated workspace

  // Signals
  signal overviewToggled(bool open)

  property int _targetWorkspace: -1

  // Processes to control animations
  Process {
    id: disableAnimations
    command: ["hyprctl", "keyword", "animations:enabled", "0"]
    onExited: {
      // Close the overlay
      root.isOpen = false;
      root.overviewToggled(false);
      // Wait for Hyprland's focus restoration, then switch workspace
      workspaceTimer.start();
    }
  }

  Process {
    id: enableAnimations
    command: ["hyprctl", "keyword", "animations:enabled", "1"]
  }

  Timer {
    id: workspaceTimer
    interval: 10
    repeat: false
    onTriggered: {
      if (root._targetWorkspace > 0) {
        Hyprland.dispatch("workspace " + root._targetWorkspace);
        root._targetWorkspace = -1;
      }
      // Small delay before hiding background to let workspace switch complete
      hideBackgroundTimer.start();
    }
  }

  Timer {
    id: hideBackgroundTimer
    interval: 30
    repeat: false
    onTriggered: {
      root.backgroundVisible = false;
      enableAnimations.running = true;
    }
  }

  function toggle() {
    if (isOpen) {
      close();
    } else {
      open();
    }
  }

  function open() {
    if (!isOpen) {
      // Remember current workspace for cancel
      originalWorkspace = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
      currentWorkspace = originalWorkspace;
      backgroundVisible = true;
      isOpen = true;
      overviewToggled(true);
      Logger.d("OverviewService", "Overview opened, original workspace:", originalWorkspace);
    }
  }

  // Update current workspace when navigating
  function setCurrentWorkspace(wsId) {
    currentWorkspace = wsId;
    Logger.d("OverviewService", "Current workspace set to:", wsId);
  }

  // Close and stay on current workspace
  function close() {
    if (isOpen) {
      _targetWorkspace = currentWorkspace;
      Logger.d("OverviewService", "Overview closing, target workspace:", _targetWorkspace);
      // Disable animations first, then close in callback
      disableAnimations.running = true;
    }
  }

  // Close and return to original workspace (for Escape)
  function cancel() {
    if (isOpen) {
      _targetWorkspace = originalWorkspace;
      Logger.d("OverviewService", "Overview cancelling, target workspace:", _targetWorkspace);
      // Disable animations first, then close in callback
      disableAnimations.running = true;
    }
  }
}


