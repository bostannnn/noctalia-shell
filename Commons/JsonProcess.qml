import QtQuick
import Quickshell.Io
import qs.Commons

Process {
  id: root

  property string logTag: "JsonProcess"
  property bool logErrors: true

  property string accumulatedOutput: ""

  signal jsonReady(var data)
  signal jsonFailed(int exitCode, string reason)

  stdout: SplitParser {
    onRead: function(line) {
      root.accumulatedOutput += line;
    }
  }

  onExited: function(exitCode) {
    const output = root.accumulatedOutput;
    root.accumulatedOutput = "";

    if (exitCode !== 0 || !output) {
      if (root.logErrors) {
        Logger.e(root.logTag, "JSON command failed, exit code:", exitCode);
      }
      root.jsonFailed(exitCode, "nonzero exit code or empty output");
      return;
    }

    try {
      const parsed = JSON.parse(output);
      root.jsonReady(parsed);
    } catch (e) {
      if (root.logErrors) {
        Logger.e(root.logTag, "Failed to parse JSON:", e);
      }
      root.jsonFailed(exitCode, "json parse error");
    }
  }
}

