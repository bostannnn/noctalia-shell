import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  property var sourceWidget: null

  preferredWidth: Math.round(560 * Style.uiScaleRatio)
  preferredHeight: Math.round(520 * Style.uiScaleRatio)

  readonly property color warningColor: Settings.data.systemMonitor.useCustomColors ? (Settings.data.systemMonitor.warningColor || Color.mTertiary) : Color.mTertiary
  readonly property color criticalColor: Settings.data.systemMonitor.useCustomColors ? (Settings.data.systemMonitor.criticalColor || Color.mError) : Color.mError
  readonly property color cpuColor: Color.mPrimary
  readonly property color gpuColor: Color.mTertiary
  readonly property color memoryColor: Color.mSecondary
  readonly property color storageColor: warningColor
  readonly property color networkColor: Color.mPrimary

  property string psPath: ""
  property bool processViewerAvailable: false
  property var topCpuProcesses: []
  property var topMemProcesses: []
  property int processMaxRows: 8
  property int processRefreshIntervalMs: 2000
  property string expandedProcessPid: ""
  property string expandedProcessMetric: ""
  property var killTarget: null

  property int historyMaxPoints: 40
  property int historyIntervalMs: 1000
  property var cpuUsageHistory: []
  property var cpuTempHistory: []
  property var gpuUsageHistory: []
  property var gpuTempHistory: []
  property var gpuVramHistory: []
  property var memHistory: []
  property var diskHistory: []

  readonly property string diskPath: {
    if (sourceWidget && sourceWidget.diskPath) {
      return sourceWidget.diskPath;
    }
    const widget = BarService.lookupWidget("SystemMonitor", screen?.name);
    if (widget && widget.diskPath) {
      return widget.diskPath;
    }
    return "/";
  }

  readonly property int diskPercent: SystemStatService.diskPercents[diskPath] ?? 0
  readonly property bool hasGpuStats: SystemStatService.gpuAvailable || SystemStatService.gpuUsageAvailable || SystemStatService.gpuVramAvailable
  readonly property string gpuTypeLabel: {
    if (!SystemStatService.gpuAvailable) {
      return "";
    }
    if (SystemStatService.gpuType === "nvidia") {
      return "NVIDIA";
    }
    if (SystemStatService.gpuType === "amd") {
      return "AMD";
    }
    if (SystemStatService.gpuType === "intel") {
      return "Intel";
    }
    return "GPU";
  }

  function clampRatio(value) {
    return Math.max(0, Math.min(1, value));
  }

  function formatTemp(value) {
    if (!value || value <= 0) {
      return "n/a";
    }
    return `${Math.round(value)}°C`;
  }

  function formatPercent(value) {
    if (value === undefined || value === null || isNaN(value)) {
      return "n/a";
    }
    return `${Math.round(value)}%`;
  }

  function formatMemoryUsed(valueGb, percent) {
    if (valueGb === undefined || valueGb === null || isNaN(valueGb)) {
      return "n/a";
    }
    const usedText = SystemStatService.formatMemoryGb(valueGb);
    if (percent === undefined || percent === null || isNaN(percent)) {
      return usedText;
    }
    return `${usedText} (${Math.round(percent)}%)`;
  }

  function formatVramLabel() {
    if (!SystemStatService.gpuVramAvailable || SystemStatService.gpuVramTotalMb <= 0) {
      return "n/a";
    }
    const usedGb = SystemStatService.gpuVramUsedMb / 1024.0;
    const totalGb = SystemStatService.gpuVramTotalMb / 1024.0;
    const usedText = SystemStatService.formatMemoryGb(usedGb.toFixed(1));
    const totalText = SystemStatService.formatMemoryGb(totalGb.toFixed(1));
    const percent = Math.round(SystemStatService.gpuVramPercent);
    return `${usedText}/${totalText} (${percent}%)`;
  }

  function getUsageColor(value, warning, critical) {
    if (value >= critical) {
      return criticalColor;
    }
    if (value >= warning) {
      return warningColor;
    }
    return Color.mPrimary;
  }

  function parseProcessOutput(output) {
    const trimmed = output.trim();
    if (!trimmed) {
      topCpuProcesses = [];
      topMemProcesses = [];
      return;
    }
    const lines = trimmed.split("\n");
    const items = [];
    for (var i = 0; i < lines.length; i++) {
      const parts = lines[i].trim().split(/\s+/);
      if (parts.length < 4) {
        continue;
      }
      const pid = parts[0];
      const name = parts[1];
      const cpu = parseFloat(parts[2]);
      const mem = parseFloat(parts[3]);
      if (!isNaN(cpu) && !isNaN(mem)) {
        items.push({
                     "pid": pid,
                     "name": name,
                     "cpu": cpu,
                     "mem": mem
                   });
      }
    }
    const cpuSorted = items.slice().sort((a, b) => b.cpu - a.cpu);
    const memSorted = items.slice().sort((a, b) => b.mem - a.mem);
    topCpuProcesses = cpuSorted.slice(0, processMaxRows);
    topMemProcesses = memSorted.slice(0, processMaxRows);
  }

  function refreshProcessList() {
    if (!processViewerAvailable || !psPath) {
      return;
    }
    if (psProcess.running) {
      return;
    }
    psProcess.running = true;
  }

  function appendHistory(list, value) {
    const next = list.slice();
    if (next.length >= historyMaxPoints) {
      next.shift();
    }
    next.push(value);
    return next;
  }

  function toggleProcessDetails(process, metricLabel) {
    if (!process || !process.pid) {
      return;
    }
    if (expandedProcessPid === process.pid && expandedProcessMetric === metricLabel) {
      expandedProcessPid = "";
      expandedProcessMetric = "";
    } else {
      expandedProcessPid = process.pid;
      expandedProcessMetric = metricLabel;
    }
  }

  function cancelProcessAction() {
    expandedProcessPid = "";
    expandedProcessMetric = "";
  }

  function requestProcessKill(process) {
    if (!process || !process.pid || killProcess.running) {
      return;
    }
    killTarget = process;
    killProcess.command = ["kill", "-TERM", process.pid];
    killProcess.running = true;
    cancelProcessAction();
  }

  Component.onCompleted: psCheck.running = true

  Timer {
    id: processRefreshTimer
    interval: processRefreshIntervalMs
    repeat: true
    running: root.isPanelOpen && processViewerAvailable
    triggeredOnStart: true
    onTriggered: refreshProcessList()
  }

  Timer {
    id: historyTimer
    interval: historyIntervalMs
    repeat: true
    running: root.isPanelOpen
    triggeredOnStart: true
    onTriggered: {
      cpuUsageHistory = appendHistory(cpuUsageHistory, clampRatio(SystemStatService.cpuUsage / 100.0));
      cpuTempHistory = appendHistory(cpuTempHistory, clampRatio(SystemStatService.cpuTemp / Math.max(1, Settings.data.systemMonitor.tempCriticalThreshold)));
      memHistory = appendHistory(memHistory, clampRatio(SystemStatService.memPercent / 100.0));
      diskHistory = appendHistory(diskHistory, clampRatio(diskPercent / 100.0));

      if (SystemStatService.gpuUsageAvailable) {
        gpuUsageHistory = appendHistory(gpuUsageHistory, clampRatio(SystemStatService.gpuUsage / 100.0));
      }
      if (SystemStatService.gpuAvailable) {
        gpuTempHistory = appendHistory(gpuTempHistory, clampRatio(SystemStatService.gpuTemp / Math.max(1, Settings.data.systemMonitor.gpuCriticalThreshold)));
      }
      if (SystemStatService.gpuVramAvailable) {
        gpuVramHistory = appendHistory(gpuVramHistory, clampRatio(SystemStatService.gpuVramPercent / 100.0));
      }
    }
  }

  Process {
    id: psCheck
    command: ["sh", "-c", "if command -v ps >/dev/null 2>&1; then command -v ps; elif [ -x /run/current-system/sw/bin/ps ]; then echo /run/current-system/sw/bin/ps; fi"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const path = text.trim();
        psPath = path;
        processViewerAvailable = path.length > 0;
        if (!processViewerAvailable) {
          topCpuProcesses = [];
          topMemProcesses = [];
        }
      }
    }
  }

  Process {
    id: killProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode === 0) {
        ToastService.showNotice(I18n.tr("settings.system-monitor.processes-section.kill-success"), killTarget ? killTarget.name : "", "trash");
      } else {
        const desc = stderr.text && stderr.text.trim() ? stderr.text.trim() : `Exit code ${exitCode}`;
        ToastService.showError(I18n.tr("settings.system-monitor.processes-section.kill-failed"), desc);
      }
      killTarget = null;
    }
  }

  Process {
    id: psProcess
    command: [psPath || "ps", "-eo", "pid,comm,%cpu,%mem", "--no-headers"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: parseProcessOutput(text)
    }
  }

  component MetricRow: Item {
    id: metricRow
    property string label: ""
    property string value: ""
    property real ratio: 0
    property color accent: Color.mPrimary
    property bool showBar: true
    property var sparkValues: []
    property color sparkColor: accent

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.marginXXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: metricRow.label
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.alignment: Qt.AlignVCenter
        }

        Item {
          Layout.fillWidth: true
        }

        Sparkline {
          visible: metricRow.sparkValues && metricRow.sparkValues.length > 1
          values: metricRow.sparkValues
          lineColor: metricRow.sparkColor
          Layout.preferredWidth: Math.round(84 * Style.uiScaleRatio)
          Layout.preferredHeight: Math.round(18 * Style.uiScaleRatio)
          Layout.alignment: Qt.AlignVCenter
        }

        NText {
          text: metricRow.value
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          font.weight: Style.fontWeightMedium
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
      }

      Rectangle {
        id: barTrack
        visible: metricRow.showBar
        Layout.fillWidth: true
        implicitHeight: Math.max(4, Math.round(4 * Style.uiScaleRatio))
        radius: Math.round(implicitHeight / 2)
        color: Qt.alpha(Color.mOnSurfaceVariant, 0.2)

        Rectangle {
          width: Math.max(2, Math.round(barTrack.width * root.clampRatio(metricRow.ratio)))
          height: barTrack.height
          radius: barTrack.radius
          color: metricRow.accent
        }
      }
    }
  }

  component Sparkline: Canvas {
    id: sparkline
    property var values: []
    property color lineColor: Color.mPrimary
    property color fillColor: Qt.alpha(lineColor, 0.18)
    property bool fill: false

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      if (!values || values.length < 2) {
        return;
      }
      const w = width;
      const h = height;
      const step = w / (values.length - 1);
      ctx.beginPath();
      for (var i = 0; i < values.length; i++) {
        const x = i * step;
        const y = h - (values[i] * h);
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.lineWidth = Math.max(1, Math.round(Style.uiScaleRatio));
      ctx.strokeStyle = lineColor;
      ctx.stroke();

      if (fill) {
        ctx.lineTo(w, h);
        ctx.lineTo(0, h);
        ctx.closePath();
        ctx.fillStyle = fillColor;
        ctx.fill();
      }
    }
  }

  component ProcessRow: Rectangle {
    id: processRow

    required property var process
    required property string metricLabel
    required property real metricValue
    required property color accent

    readonly property bool expanded: root.expandedProcessPid === process.pid && root.expandedProcessMetric === metricLabel

    Layout.fillWidth: true
    radius: Style.radiusS
    color: expanded ? Qt.alpha(accent, 0.08) : Qt.alpha(Color.mSurface, 0.35)
    border.width: Style.borderS
    border.color: expanded ? accent : Qt.alpha(Color.mOutline, 0.5)
    implicitHeight: rowColumn.implicitHeight + Style.marginS * 2

    ColumnLayout {
      id: rowColumn
      anchors.fill: parent
      anchors.margins: Style.marginS
      spacing: Style.marginXS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            text: process.name
            pointSize: Style.fontSizeS
            font.weight: expanded ? Style.fontWeightBold : Style.fontWeightMedium
            color: Color.mOnSurface
            elide: Text.ElideRight
          }

          NText {
            text: `PID ${process.pid}`
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }
        }

        NText {
          text: `${metricValue.toFixed(1)}%`
          pointSize: Style.fontSizeS
          font.family: Settings.data.ui.fontFixed
          font.weight: Style.fontWeightMedium
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignRight
          Layout.preferredWidth: Math.round(56 * Style.uiScaleRatio)
        }

        NIcon {
          icon: "chevron-down"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          rotation: expanded ? 180 : 0
          Layout.alignment: Qt.AlignVCenter

          Behavior on rotation {
            NumberAnimation {
              duration: Style.animationFast
              easing.type: Easing.OutCubic
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          onClicked: root.toggleProcessDetails(process, metricLabel)
        }
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(3, Math.round(3 * Style.uiScaleRatio))
        radius: Math.round(implicitHeight / 2)
        color: Qt.alpha(Color.mOnSurfaceVariant, 0.2)

        Rectangle {
          width: Math.max(2, Math.round(parent.width * root.clampRatio(metricValue / 100.0)))
          height: parent.height
          radius: parent.radius
          color: accent
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS
        visible: expanded

        NText {
          text: I18n.tr("settings.system-monitor.processes-section.confirm", {
                           "name": process.name,
                           "pid": process.pid
                         })
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NButton {
            text: I18n.tr("settings.system-monitor.processes-section.kill")
            icon: "trash"
            backgroundColor: Color.mError
            hoverColor: Color.mError
            textColor: Color.mOnError
            onClicked: root.requestProcessKill(process)
          }

          NButton {
            text: I18n.tr("settings.system-monitor.processes-section.cancel")
            icon: "x"
            outlined: true
            backgroundColor: Color.mOutline
            textColor: Color.mOnSurface
            onClicked: root.cancelProcessAction()
          }
        }
      }
    }

  }

  panelContent: Item {
    property real contentPreferredHeight: mainColumn.implicitHeight + Style.marginL * 2

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + (Style.marginM * 2)

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          Rectangle {
            width: Style.baseWidgetSize
            height: Style.baseWidgetSize
            radius: Style.radiusM
            color: Qt.alpha(Color.mPrimary, 0.15)

            NIcon {
              icon: "performance"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
              anchors.centerIn: parent
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            NText {
              text: I18n.tr("settings.system-monitor.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("tooltips.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.close()
          }
        }
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        clip: true
        contentWidth: availableWidth

        GridLayout {
          id: grid
          width: parent.width
          columns: 2
          columnSpacing: Style.marginM
          rowSpacing: Style.marginM

          NBox {
            Layout.fillWidth: true
            implicitHeight: cpuColumn.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: cpuColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  width: Style.baseWidgetSize * 0.7
                  height: Style.baseWidgetSize * 0.7
                  radius: Style.radiusS
                  color: Qt.alpha(root.cpuColor, 0.18)

                  NIcon {
                    icon: "cpu-usage"
                    pointSize: Style.fontSizeM
                    color: root.cpuColor
                    anchors.centerIn: parent
                  }
                }

                NText {
                  text: I18n.tr("settings.system-monitor.cpu-section.label")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                }
              }

              MetricRow {
                label: I18n.tr("bar.widget-settings.system-monitor.cpu-usage.label")
                value: root.formatPercent(SystemStatService.cpuUsage)
                ratio: root.clampRatio(SystemStatService.cpuUsage / 100.0)
                accent: root.getUsageColor(SystemStatService.cpuUsage, Settings.data.systemMonitor.cpuWarningThreshold, Settings.data.systemMonitor.cpuCriticalThreshold)
                sparkValues: root.cpuUsageHistory
              }

              MetricRow {
                label: I18n.tr("bar.widget-settings.system-monitor.cpu-temperature.label")
                value: root.formatTemp(SystemStatService.cpuTemp)
                ratio: root.clampRatio(SystemStatService.cpuTemp / Math.max(1, Settings.data.systemMonitor.tempCriticalThreshold))
                accent: root.getUsageColor(SystemStatService.cpuTemp, Settings.data.systemMonitor.tempWarningThreshold, Settings.data.systemMonitor.tempCriticalThreshold)
                sparkValues: root.cpuTempHistory
                sparkColor: root.warningColor
              }
            }
          }

          NBox {
            Layout.fillWidth: true
            implicitHeight: gpuColumn.implicitHeight + Style.marginM * 2
            visible: root.hasGpuStats

            ColumnLayout {
              id: gpuColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  width: Style.baseWidgetSize * 0.7
                  height: Style.baseWidgetSize * 0.7
                  radius: Style.radiusS
                  color: Qt.alpha(root.gpuColor, 0.18)

                  NIcon {
                    icon: "gpu-temperature"
                    pointSize: Style.fontSizeM
                    color: root.gpuColor
                    anchors.centerIn: parent
                  }
                }

                NText {
                  text: I18n.tr("settings.system-monitor.gpu-section.label")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                  Layout.fillWidth: true
                }

                NText {
                  text: root.gpuTypeLabel
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignRight
                }
              }

              MetricRow {
                visible: SystemStatService.gpuUsageAvailable
                label: I18n.tr("bar.widget-settings.system-monitor.gpu-usage.label")
                value: root.formatPercent(SystemStatService.gpuUsage)
                ratio: root.clampRatio(SystemStatService.gpuUsage / 100.0)
                accent: root.gpuColor
                sparkValues: root.gpuUsageHistory
              }

              MetricRow {
                visible: SystemStatService.gpuAvailable
                label: I18n.tr("bar.widget-settings.system-monitor.gpu-temperature.label")
                value: root.formatTemp(SystemStatService.gpuTemp)
                ratio: root.clampRatio(SystemStatService.gpuTemp / Math.max(1, Settings.data.systemMonitor.gpuCriticalThreshold))
                accent: root.getUsageColor(SystemStatService.gpuTemp, Settings.data.systemMonitor.gpuWarningThreshold, Settings.data.systemMonitor.gpuCriticalThreshold)
                sparkValues: root.gpuTempHistory
                sparkColor: root.warningColor
              }

              MetricRow {
                visible: SystemStatService.gpuVramAvailable
                label: I18n.tr("bar.widget-settings.system-monitor.gpu-vram-usage.label")
                value: root.formatVramLabel()
                ratio: root.clampRatio(SystemStatService.gpuVramPercent / 100.0)
                accent: root.gpuColor
                sparkValues: root.gpuVramHistory
              }
            }
          }

          NBox {
            Layout.fillWidth: true
            implicitHeight: memoryColumn.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: memoryColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  width: Style.baseWidgetSize * 0.7
                  height: Style.baseWidgetSize * 0.7
                  radius: Style.radiusS
                  color: Qt.alpha(root.memoryColor, 0.18)

                  NIcon {
                    icon: "memory"
                    pointSize: Style.fontSizeM
                    color: root.memoryColor
                    anchors.centerIn: parent
                  }
                }

                NText {
                  text: I18n.tr("settings.system-monitor.memory-section.label")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                }
              }

              MetricRow {
                label: I18n.tr("bar.widget-settings.system-monitor.memory-usage.label")
                value: root.formatMemoryUsed(SystemStatService.memGb, SystemStatService.memPercent)
                ratio: root.clampRatio(SystemStatService.memPercent / 100.0)
                accent: root.getUsageColor(SystemStatService.memPercent, Settings.data.systemMonitor.memWarningThreshold, Settings.data.systemMonitor.memCriticalThreshold)
                sparkValues: root.memHistory
                sparkColor: root.memoryColor
              }
            }
          }

          NBox {
            Layout.fillWidth: true
            implicitHeight: storageColumn.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: storageColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  width: Style.baseWidgetSize * 0.7
                  height: Style.baseWidgetSize * 0.7
                  radius: Style.radiusS
                  color: Qt.alpha(root.storageColor, 0.18)

                  NIcon {
                    icon: "storage"
                    pointSize: Style.fontSizeM
                    color: root.storageColor
                    anchors.centerIn: parent
                  }
                }

                NText {
                  text: I18n.tr("settings.system-monitor.disk-section.label")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                  Layout.fillWidth: true
                }

                NText {
                  text: root.diskPath
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignRight
                }
              }

              MetricRow {
                label: I18n.tr("bar.widget-settings.system-monitor.storage-usage.label")
                value: root.diskPercent > 0 ? `${root.diskPercent}%` : "n/a"
                ratio: root.clampRatio(root.diskPercent / 100.0)
                accent: root.getUsageColor(root.diskPercent, Settings.data.systemMonitor.diskWarningThreshold, Settings.data.systemMonitor.diskCriticalThreshold)
                sparkValues: root.diskHistory
                sparkColor: root.storageColor
              }
            }
          }

          NBox {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            implicitHeight: networkColumn.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: networkColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  width: Style.baseWidgetSize * 0.7
                  height: Style.baseWidgetSize * 0.7
                  radius: Style.radiusS
                  color: Qt.alpha(root.networkColor, 0.18)

                  NIcon {
                    icon: "wifi"
                    pointSize: Style.fontSizeM
                    color: root.networkColor
                    anchors.centerIn: parent
                  }
                }

                NText {
                  text: I18n.tr("settings.system-monitor.network-section.label")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                }
              }

              MetricRow {
                label: "RX"
                value: SystemStatService.formatSpeed(SystemStatService.rxSpeed)
                showBar: false
              }

              MetricRow {
                label: "TX"
                value: SystemStatService.formatSpeed(SystemStatService.txSpeed)
                showBar: false
              }
            }
          }

          NBox {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            implicitHeight: processColumn.implicitHeight + Style.marginM * 2

            ColumnLayout {
              id: processColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                  width: Style.baseWidgetSize * 0.7
                  height: Style.baseWidgetSize * 0.7
                  radius: Style.radiusS
                  color: Qt.alpha(Color.mPrimary, 0.18)

                  NIcon {
                    icon: "activity"
                    pointSize: Style.fontSizeM
                    color: Color.mPrimary
                    anchors.centerIn: parent
                  }
                }

                NText {
                  text: I18n.tr("settings.system-monitor.processes-section.label")
                  pointSize: Style.fontSizeM
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM
                visible: processViewerAvailable

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  NText {
                    text: I18n.tr("settings.system-monitor.processes-section.cpu")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                      text: I18n.tr("settings.system-monitor.processes-section.process")
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                      Layout.fillWidth: true
                    }

                    NText {
                      text: I18n.tr("settings.system-monitor.processes-section.cpu")
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                      Layout.preferredWidth: Math.round(56 * Style.uiScaleRatio)
                      horizontalAlignment: Text.AlignRight
                    }
                  }

                  Repeater {
                    model: topCpuProcesses
                    delegate: ProcessRow {
                      process: modelData
                      metricLabel: "cpu"
                      metricValue: modelData.cpu
                      accent: root.cpuColor
                    }
                  }

                  NText {
                    visible: topCpuProcesses.length === 0
                    text: I18n.tr("settings.system-monitor.processes-section.empty")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginS

                  NText {
                    text: I18n.tr("settings.system-monitor.processes-section.memory")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                      text: I18n.tr("settings.system-monitor.processes-section.process")
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                      Layout.fillWidth: true
                    }

                    NText {
                      text: I18n.tr("settings.system-monitor.processes-section.memory")
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                      Layout.preferredWidth: Math.round(56 * Style.uiScaleRatio)
                      horizontalAlignment: Text.AlignRight
                    }
                  }

                  Repeater {
                    model: topMemProcesses
                    delegate: ProcessRow {
                      process: modelData
                      metricLabel: "mem"
                      metricValue: modelData.mem
                      accent: root.memoryColor
                    }
                  }

                  NText {
                    visible: topMemProcesses.length === 0
                    text: I18n.tr("settings.system-monitor.processes-section.empty")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }
                }
              }

              NText {
                visible: !processViewerAvailable
                text: I18n.tr("settings.system-monitor.processes-section.unavailable")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
              }
            }
          }
        }
      }
    }
  }
}
