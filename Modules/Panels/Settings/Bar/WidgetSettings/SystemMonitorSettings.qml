import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var widgetData: null
  property var widgetMetadata: null

  // Local, editable state for checkboxes
  property bool valueUsePrimaryColor: widgetData.usePrimaryColor !== undefined ? widgetData.usePrimaryColor : widgetMetadata.usePrimaryColor
  property bool valueShowCpuUsage: widgetData.showCpuUsage !== undefined ? widgetData.showCpuUsage : widgetMetadata.showCpuUsage
  property bool valueShowCpuTemp: widgetData.showCpuTemp !== undefined ? widgetData.showCpuTemp : widgetMetadata.showCpuTemp
  property bool valueShowGpuUsage: widgetData.showGpuUsage !== undefined ? widgetData.showGpuUsage : widgetMetadata.showGpuUsage
  property bool valueShowGpuTemp: widgetData.showGpuTemp !== undefined ? widgetData.showGpuTemp : widgetMetadata.showGpuTemp
  property bool valueShowGpuVram: widgetData.showGpuVram !== undefined ? widgetData.showGpuVram : widgetMetadata.showGpuVram
  property bool valueShowGpuVramAsPercent: widgetData.showGpuVramAsPercent !== undefined ? widgetData.showGpuVramAsPercent : widgetMetadata.showGpuVramAsPercent
  property bool valueShowMemoryUsage: widgetData.showMemoryUsage !== undefined ? widgetData.showMemoryUsage : widgetMetadata.showMemoryUsage
  property bool valueShowMemoryAsPercent: widgetData.showMemoryAsPercent !== undefined ? widgetData.showMemoryAsPercent : widgetMetadata.showMemoryAsPercent
  property bool valueShowNetworkStats: widgetData.showNetworkStats !== undefined ? widgetData.showNetworkStats : widgetMetadata.showNetworkStats
  property bool valueShowDiskUsage: widgetData.showDiskUsage !== undefined ? widgetData.showDiskUsage : widgetMetadata.showDiskUsage
  property string valueDiskPath: widgetData.diskPath !== undefined ? widgetData.diskPath : widgetMetadata.diskPath

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.usePrimaryColor = valueUsePrimaryColor;
    settings.showCpuUsage = valueShowCpuUsage;
    settings.showCpuTemp = valueShowCpuTemp;
    settings.showGpuUsage = valueShowGpuUsage;
    settings.showGpuTemp = valueShowGpuTemp;
    settings.showGpuVram = valueShowGpuVram;
    settings.showGpuVramAsPercent = valueShowGpuVramAsPercent;
    settings.showMemoryUsage = valueShowMemoryUsage;
    settings.showMemoryAsPercent = valueShowMemoryAsPercent;
    settings.showNetworkStats = valueShowNetworkStats;
    settings.showDiskUsage = valueShowDiskUsage;
    settings.diskPath = valueDiskPath;

    return settings;
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.clock.use-primary-color.label")
    description: I18n.tr("bar.widget-settings.clock.use-primary-color.description")
    checked: valueUsePrimaryColor
    onToggled: checked => valueUsePrimaryColor = checked
  }

  NToggle {
    id: showCpuUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.cpu-usage.label")
    description: I18n.tr("bar.widget-settings.system-monitor.cpu-usage.description")
    checked: valueShowCpuUsage
    onToggled: checked => valueShowCpuUsage = checked
  }

  NToggle {
    id: showCpuTemp
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.cpu-temperature.label")
    description: I18n.tr("bar.widget-settings.system-monitor.cpu-temperature.description")
    checked: valueShowCpuTemp
    onToggled: checked => valueShowCpuTemp = checked
  }

  NToggle {
    id: showGpuUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.gpu-usage.label")
    description: I18n.tr("bar.widget-settings.system-monitor.gpu-usage.description")
    checked: valueShowGpuUsage
    onToggled: checked => valueShowGpuUsage = checked
    visible: SystemStatService.gpuUsageAvailable
  }

  NToggle {
    id: showGpuTemp
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.gpu-temperature.label")
    description: I18n.tr("bar.widget-settings.system-monitor.gpu-temperature.description")
    checked: valueShowGpuTemp
    onToggled: checked => valueShowGpuTemp = checked
    visible: SystemStatService.gpuAvailable
  }

  NToggle {
    id: showGpuVram
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.gpu-vram-usage.label")
    description: I18n.tr("bar.widget-settings.system-monitor.gpu-vram-usage.description")
    checked: valueShowGpuVram
    onToggled: checked => valueShowGpuVram = checked
    visible: SystemStatService.gpuVramAvailable
  }

  NToggle {
    id: showGpuVramAsPercent
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.gpu-vram-percentage.label")
    description: I18n.tr("bar.widget-settings.system-monitor.gpu-vram-percentage.description")
    checked: valueShowGpuVramAsPercent
    onToggled: checked => valueShowGpuVramAsPercent = checked
    visible: valueShowGpuVram
  }

  NToggle {
    id: showMemoryUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.memory-usage.label")
    description: I18n.tr("bar.widget-settings.system-monitor.memory-usage.description")
    checked: valueShowMemoryUsage
    onToggled: checked => valueShowMemoryUsage = checked
  }

  NToggle {
    id: showMemoryAsPercent
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.memory-percentage.label")
    description: I18n.tr("bar.widget-settings.system-monitor.memory-percentage.description")
    checked: valueShowMemoryAsPercent
    onToggled: checked => valueShowMemoryAsPercent = checked
    visible: valueShowMemoryUsage
  }

  NToggle {
    id: showNetworkStats
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.network-traffic.label")
    description: I18n.tr("bar.widget-settings.system-monitor.network-traffic.description")
    checked: valueShowNetworkStats
    onToggled: checked => valueShowNetworkStats = checked
  }

  NToggle {
    id: showDiskUsage
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.storage-usage.label")
    description: I18n.tr("bar.widget-settings.system-monitor.storage-usage.description")
    checked: valueShowDiskUsage
    onToggled: checked => valueShowDiskUsage = checked
  }

  NComboBox {
    id: diskPathComboBox
    Layout.fillWidth: true
    label: I18n.tr("bar.widget-settings.system-monitor.disk-path.label")
    description: I18n.tr("bar.widget-settings.system-monitor.disk-path.description")
    visible: valueShowDiskUsage
    model: {
      const paths = Object.keys(SystemStatService.diskPercents).sort();
      return paths.map(path => ({
                                  key: path,
                                  name: path
                                }));
    }
    currentKey: valueDiskPath
    onSelected: key => valueDiskPath = key
  }
}
