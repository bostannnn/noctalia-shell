import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
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

  component MetricRow: Item {
    id: metricRow
    property string label: ""
    property string value: ""
    property real ratio: 0
    property color accent: Color.mPrimary
    property bool showBar: true

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

          NIcon {
            icon: "performance"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
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

                NIcon {
                  icon: "cpu-usage"
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
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
              }

              MetricRow {
                label: I18n.tr("bar.widget-settings.system-monitor.cpu-temperature.label")
                value: root.formatTemp(SystemStatService.cpuTemp)
                ratio: root.clampRatio(SystemStatService.cpuTemp / Math.max(1, Settings.data.systemMonitor.tempCriticalThreshold))
                accent: root.getUsageColor(SystemStatService.cpuTemp, Settings.data.systemMonitor.tempWarningThreshold, Settings.data.systemMonitor.tempCriticalThreshold)
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

                NIcon {
                  icon: "gpu-temperature"
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
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
                accent: Color.mPrimary
              }

              MetricRow {
                visible: SystemStatService.gpuAvailable
                label: I18n.tr("bar.widget-settings.system-monitor.gpu-temperature.label")
                value: root.formatTemp(SystemStatService.gpuTemp)
                ratio: root.clampRatio(SystemStatService.gpuTemp / Math.max(1, Settings.data.systemMonitor.gpuCriticalThreshold))
                accent: root.getUsageColor(SystemStatService.gpuTemp, Settings.data.systemMonitor.gpuWarningThreshold, Settings.data.systemMonitor.gpuCriticalThreshold)
              }

              MetricRow {
                visible: SystemStatService.gpuVramAvailable
                label: I18n.tr("bar.widget-settings.system-monitor.gpu-vram-usage.label")
                value: root.formatVramLabel()
                ratio: root.clampRatio(SystemStatService.gpuVramPercent / 100.0)
                accent: Color.mPrimary
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

                NIcon {
                  icon: "memory"
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
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

                NIcon {
                  icon: "storage"
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
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

                NIcon {
                  icon: "wifi"
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
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
        }
      }
    }
  }
}
