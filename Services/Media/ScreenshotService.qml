pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.UI

Singleton {
  id: root

  readonly property var settings: Settings.data.screenshot ?? {}
  property bool isPending: false
  property string lastScreenshot: ""

  // Check if required tools are available
  readonly property bool isAvailable: ProgramCheckerService.grimAvailable && ProgramCheckerService.slurpAvailable
  readonly property bool hasAnnotationTool: ProgramCheckerService.sattyAvailable || ProgramCheckerService.swappyAvailable

  // Screenshot modes
  readonly property string modeRegion: "region"
  readonly property string modeScreen: "screen"
  readonly property string modeWindow: "window"

  // Settings with defaults
  readonly property string screenshotDir: Settings.preprocessPath(settings.directory ?? "~/Pictures/Screenshots")
  readonly property string annotationTool: {
    // Use user preference, or auto-detect
    if (settings.annotationTool) return settings.annotationTool;
    if (ProgramCheckerService.sattyAvailable) return "satty";
    if (ProgramCheckerService.swappyAvailable) return "swappy";
    return "satty";
  }
  readonly property bool copyToClipboard: settings.copyToClipboard ?? true
  readonly property bool autoAnnotate: settings.autoAnnotate ?? false

  // Take a screenshot
  function takeScreenshot(mode) {
    if (isPending) return;
    if (!isAvailable) {
      ToastService.showError(
        I18n.tr("toast.screenshot.not-available"),
        I18n.tr("toast.screenshot.not-available-desc")
      );
      return;
    }

    isPending = true;

    // Close any opened panel first
    if (PanelService?.openedPanel && !PanelService.openedPanel.isClosing) {
      PanelService.openedPanel.close();
    }

    // Small delay to let panel close
    delayTimer.mode = mode || modeRegion;
    delayTimer.start();
  }

  Timer {
    id: delayTimer
    property string mode: "region"
    interval: 100
    repeat: false
    onTriggered: doScreenshot(mode)
  }

  function doScreenshot(mode) {
    var timestamp = Time.getFormattedTimestamp();
    var filename = "screenshot-" + timestamp + ".png";
    var outputFile = screenshotDir + "/" + filename;

    // Store for later use
    screenshotProcess.outputFile = outputFile;

    // Build the command
    var setupCmd = "mkdir -p '" + screenshotDir + "'";

    var captureCmd;
    switch (mode) {
      case modeScreen:
        captureCmd = "grim '" + outputFile + "'";
        break;
      case modeWindow:
        captureCmd = "grim -g \"$(hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')\" '" + outputFile + "'";
        break;
      case modeRegion:
      default:
        captureCmd = "grim -g \"$(slurp -d)\" '" + outputFile + "'";
        break;
    }

    var fullCmd = setupCmd + " && " + captureCmd;

    // Add clipboard copy if enabled
    if (copyToClipboard) {
      fullCmd += " && wl-copy < '" + outputFile + "'";
    }

    // Set the expected output path for annotation
    lastScreenshot = outputFile;

    // Use execDetached so slurp runs independently and can appear above shell layers
    Quickshell.execDetached(["sh", "-c", fullCmd]);

    // Reset pending and show notification after delay
    screenshotCompleteTimer.outputFile = outputFile;
    screenshotCompleteTimer.start();
  }

  Timer {
    id: screenshotCompleteTimer
    property string outputFile: ""
    interval: 1000
    repeat: false
    onTriggered: {
      isPending = false;
      // Show notification with image preview using notify-send
      showScreenshotNotification(outputFile);
    }
  }

  function showScreenshotNotification(filepath) {
    // Build notify-send command with image and action
    // Use app name "Screenshot" and category hint for noctalia to show larger preview
    var notifyCmd = "notify-send " +
      "--app-name='Screenshot' " +
      "--category='screenshot' " +
      "'Screenshot Saved' " +
      "'" + filepath + "' " +
      "--icon='" + filepath + "' " +
      "--hint=string:image-path:'" + filepath + "' " +
      "--action='annotate=Edit' " +
      "--action='open=Open Folder' " +
      "-t 5000";

    // Run notify-send and capture the action
    notificationProcess.filepath = filepath;
    notificationProcess.exec({
      "command": ["sh", "-c", notifyCmd]
    });
  }

  Process {
    id: notificationProcess
    property string filepath: ""
    stdout: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      var action = (stdout.text || "").trim();
      if (action === "annotate") {
        annotateFile(filepath);
      } else if (action === "open") {
        openScreenshotFolder();
      }
    }
  }

  // Open annotation tool on a file
  function annotateFile(filepath) {
    if (!hasAnnotationTool) {
      ToastService.showError(
        I18n.tr("toast.screenshot.no-annotation-tool"),
        I18n.tr("toast.screenshot.no-annotation-tool-desc")
      );
      return;
    }

    var cmd;
    switch (annotationTool) {
      case "swappy":
        cmd = "swappy -f '" + filepath + "' -o '" + filepath + "'";
        break;
      case "satty":
      default:
        cmd = "satty --filename '" + filepath + "' --output-filename '" + filepath + "'";
        break;
    }

    Quickshell.execDetached(["sh", "-c", cmd]);
  }

  // Annotate the last screenshot
  function annotateLastScreenshot() {
    if (lastScreenshot) {
      annotateFile(lastScreenshot);
    } else {
      ToastService.showError(
        I18n.tr("toast.screenshot.no-last-screenshot"),
        I18n.tr("toast.screenshot.no-last-screenshot-desc")
      );
    }
  }

  // Open the screenshot folder in file manager
  function openScreenshotFolder() {
    Quickshell.execDetached(["xdg-open", screenshotDir]);
  }
}
