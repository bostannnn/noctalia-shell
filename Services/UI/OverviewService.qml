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
  property bool _closeInProgress: false
  property bool _disabledAnimationsThisClose: false

  function _requestClose(targetWsId) {
    if (!isOpen && !backgroundVisible) return;
    if (targetWsId !== undefined && targetWsId !== null) {
      _targetWorkspace = targetWsId;
    }

    if (_closeInProgress) return;
    _closeInProgress = true;
    _disabledAnimationsThisClose = false;
    closeFallbackTimer.restart();
    disableAnimations.running = true;
  }

  function _completeClose() {
    if (!_closeInProgress) return;
    closeFallbackTimer.stop();
    root.isOpen = false;
    root.overviewToggled(false);
    workspaceTimer.start();
    _closeInProgress = false;
  }

  // Processes to control animations
  Process {
    id: disableAnimations
    command: ["hyprctl", "keyword", "animations:enabled", "0"]
    onExited: function(exitCode) {
      root._disabledAnimationsThisClose = (exitCode === 0);
      root._completeClose();
    }
  }

  Process {
    id: enableAnimations
    command: ["hyprctl", "keyword", "animations:enabled", "1"]
  }

  Timer {
    id: closeFallbackTimer
    interval: 400
    repeat: false
    onTriggered: {
      Logger.w("OverviewService", "Close fallback timer triggered; forcing close.");
      root._completeClose();
    }
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
      if (root._disabledAnimationsThisClose) {
        enableAnimations.running = true;
      }
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
    if (_closeInProgress) return;
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
      Logger.d("OverviewService", "Overview closing, target workspace:", currentWorkspace);
      _requestClose(currentWorkspace);
    }
  }

  // Close and return to original workspace (for Escape)
  function cancel() {
    if (isOpen) {
      Logger.d("OverviewService", "Overview cancelling, target workspace:", originalWorkspace);
      _requestClose(originalWorkspace);
    }
  }
}
