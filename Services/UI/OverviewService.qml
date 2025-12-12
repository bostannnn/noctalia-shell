pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

/**
 * Service to manage the workspace overview state.
 * Provides open/close/toggle functionality and configuration.
 */
Singleton {
  id: root

  // Overview state
  property bool isOpen: false

  // Configuration (can be moved to Settings later)
  property int rows: 2
  property int columns: 5
  property real scale: 0.16
  property int raceConditionDelay: 150

  // Signals
  signal overviewToggled(bool open)

  function toggle() {
    isOpen = !isOpen;
    overviewToggled(isOpen);
    Logger.d("OverviewService", "Overview toggled:", isOpen);
  }

  function open() {
    if (!isOpen) {
      isOpen = true;
      overviewToggled(true);
      Logger.d("OverviewService", "Overview opened");
    }
  }

  function close() {
    if (isOpen) {
      isOpen = false;
      overviewToggled(false);
      Logger.d("OverviewService", "Overview closed");
    }
  }
}
