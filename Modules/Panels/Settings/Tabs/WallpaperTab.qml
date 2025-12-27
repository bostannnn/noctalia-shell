import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  property string specificFolderMonitorName: ""

  spacing: Style.marginL

  NHeader {
    label: I18n.tr("settings.wallpaper.settings.section.label")
    description: I18n.tr("settings.wallpaper.settings.section.description")
  }

  NToggle {
    label: I18n.tr("settings.wallpaper.settings.enable-management.label")
    description: I18n.tr("settings.wallpaper.settings.enable-management.description")
    checked: Settings.data.wallpaper.enabled
    onToggled: checked => Settings.data.wallpaper.enabled = checked
    Layout.bottomMargin: Style.marginL
  }

  NToggle {
    visible: Settings.data.wallpaper.enabled && CompositorService.isNiri
    label: I18n.tr("settings.wallpaper.settings.enable-overview.label")
    description: I18n.tr("settings.wallpaper.settings.enable-overview.description")
    checked: Settings.data.wallpaper.overviewEnabled
    onToggled: checked => Settings.data.wallpaper.overviewEnabled = checked
    Layout.bottomMargin: Style.marginL
  }

  NDivider {
    visible: Settings.data.wallpaper.enabled
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  ColumnLayout {
    visible: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    NTextInputButton {
      id: wallpaperPathInput
      label: I18n.tr("settings.wallpaper.settings.folder.label")
      description: I18n.tr("settings.wallpaper.settings.folder.description")
      text: Settings.data.wallpaper.directory
      buttonIcon: "folder-open"
      buttonTooltip: I18n.tr("settings.wallpaper.settings.folder.tooltip")
      Layout.fillWidth: true
      onInputEditingFinished: Settings.data.wallpaper.directory = text
      onButtonClicked: mainFolderPicker.open()
    }

    RowLayout {
      NLabel {
        label: I18n.tr("settings.wallpaper.settings.selector.label")
        description: I18n.tr("settings.wallpaper.settings.selector.description")
        Layout.alignment: Qt.AlignTop
      }

      NIconButton {
        icon: "wallpaper-selector"
        tooltipText: I18n.tr("settings.wallpaper.settings.selector.tooltip")
        onClicked: PanelService.getPanel("wallpaperPanel", screen)?.toggle()
      }
    }

    // Recursive search
    NToggle {
      label: I18n.tr("settings.wallpaper.settings.recursive-search.label")
      description: I18n.tr("settings.wallpaper.settings.recursive-search.description")
      checked: Settings.data.wallpaper.recursiveSearch
      onToggled: checked => Settings.data.wallpaper.recursiveSearch = checked
    }

    // Monitor-specific directories
    NToggle {
      label: I18n.tr("settings.wallpaper.settings.monitor-specific.label")
      description: I18n.tr("settings.wallpaper.settings.monitor-specific.description")
      checked: Settings.data.wallpaper.enableMultiMonitorDirectories
      onToggled: checked => Settings.data.wallpaper.enableMultiMonitorDirectories = checked
    }
    // Hide wallpaper filenames
    NToggle {
      label: I18n.tr("settings.wallpaper.settings.hide-wallpaper-filenames.label")
      description: I18n.tr("settings.wallpaper.settings.hide-wallpaper-filenames.description")
      checked: Settings.data.wallpaper.hideWallpaperFilenames
      onToggled: checked => Settings.data.wallpaper.hideWallpaperFilenames = checked
    }

    NBox {
      visible: Settings.data.wallpaper.enableMultiMonitorDirectories

      Layout.fillWidth: true
      radius: Style.radiusM
      color: Color.mSurface
      border.color: Color.mOutline
      border.width: Style.borderS
      implicitHeight: contentCol.implicitHeight + Style.marginL * 2
      clip: true

      ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM
        Repeater {
          model: Quickshell.screens || []
          delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: (modelData.name || "Unknown")
              color: Color.mPrimary
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeM
            }

            NTextInputButton {
              text: WallpaperService.getMonitorDirectory(modelData.name)
              buttonIcon: "folder-open"
              buttonTooltip: I18n.tr("settings.wallpaper.settings.monitor-specific.tooltip")
              Layout.fillWidth: true
              onInputEditingFinished: WallpaperService.setMonitorDirectory(modelData.name, text)
              onButtonClicked: {
                specificFolderMonitorName = modelData.name;
                monitorFolderPicker.open();
              }
            }
          }
        }
      }
    }

    NComboBox {
      label: I18n.tr("settings.wallpaper.settings.selector-position.label")
      description: I18n.tr("settings.wallpaper.settings.selector-position.description")
      Layout.fillWidth: true
      model: [
        {
          "key": "follow_bar",
          "name": I18n.tr("options.launcher.position.follow_bar")
        },
        {
          "key": "center",
          "name": I18n.tr("options.launcher.position.center")
        },
        {
          "key": "top_center",
          "name": I18n.tr("options.launcher.position.top_center")
        },
        {
          "key": "top_left",
          "name": I18n.tr("options.launcher.position.top_left")
        },
        {
          "key": "top_right",
          "name": I18n.tr("options.launcher.position.top_right")
        },
        {
          "key": "bottom_left",
          "name": I18n.tr("options.launcher.position.bottom_left")
        },
        {
          "key": "bottom_right",
          "name": I18n.tr("options.launcher.position.bottom_right")
        },
        {
          "key": "bottom_center",
          "name": I18n.tr("options.launcher.position.bottom_center")
        }
      ]
      currentKey: Settings.data.wallpaper.panelPosition
      onSelected: function (key) {
        Settings.data.wallpaper.panelPosition = key;
      }
    }
  }

  NDivider {
    visible: Settings.data.wallpaper.enabled
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  ColumnLayout {
    visible: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("settings.wallpaper.look-feel.section.label")
    }

    // Fill Mode
    NComboBox {
      label: I18n.tr("settings.wallpaper.look-feel.fill-mode.label")
      description: I18n.tr("settings.wallpaper.look-feel.fill-mode.description")
      model: WallpaperService.fillModeModel
      currentKey: Settings.data.wallpaper.fillMode
      onSelected: key => Settings.data.wallpaper.fillMode = key
    }

    RowLayout {
      NLabel {
        label: I18n.tr("settings.wallpaper.look-feel.fill-color.label")
        description: I18n.tr("settings.wallpaper.look-feel.fill-color.description")
        Layout.alignment: Qt.AlignTop
      }

      NColorPicker {
        selectedColor: Settings.data.wallpaper.fillColor
        onColorSelected: color => Settings.data.wallpaper.fillColor = color
      }
    }

    // Transition Type
    NComboBox {
      label: I18n.tr("settings.wallpaper.look-feel.transition-type.label")
      description: I18n.tr("settings.wallpaper.look-feel.transition-type.description")
      model: WallpaperService.transitionsModel
      currentKey: Settings.data.wallpaper.transitionType
      onSelected: key => Settings.data.wallpaper.transitionType = key
    }

    // Transition Duration
    ColumnLayout {
      NLabel {
        label: I18n.tr("settings.wallpaper.look-feel.transition-duration.label")
        description: I18n.tr("settings.wallpaper.look-feel.transition-duration.description")
      }

      NValueSlider {
        Layout.fillWidth: true
        from: 500
        to: 10000
        stepSize: 100
        value: Settings.data.wallpaper.transitionDuration
        onMoved: value => Settings.data.wallpaper.transitionDuration = value
        text: (Settings.data.wallpaper.transitionDuration / 1000).toFixed(1) + "s"
      }
    }

    // Edge Smoothness
    ColumnLayout {
      NLabel {
        label: I18n.tr("settings.wallpaper.look-feel.edge-smoothness.label")
        description: I18n.tr("settings.wallpaper.look-feel.edge-smoothness.description")
      }

      NValueSlider {
        Layout.fillWidth: true
        from: 0.0
        to: 1.0
        value: Settings.data.wallpaper.transitionEdgeSmoothness
        onMoved: value => Settings.data.wallpaper.transitionEdgeSmoothness = value
        text: Math.round(Settings.data.wallpaper.transitionEdgeSmoothness * 100) + "%"
      }
    }
  }

  NDivider {
    visible: Settings.data.wallpaper.enabled
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  ColumnLayout {
    visible: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("settings.wallpaper.automation.section.label")
    }

    // Random Wallpaper
    NToggle {
      label: I18n.tr("settings.wallpaper.automation.random-wallpaper.label")
      description: I18n.tr("settings.wallpaper.automation.random-wallpaper.description")
      checked: Settings.data.wallpaper.randomEnabled
      onToggled: checked => Settings.data.wallpaper.randomEnabled = checked
    }

    // Smart Rotation
    NToggle {
      visible: Settings.data.wallpaper.randomEnabled
      label: I18n.tr("settings.wallpaper.automation.smart-rotation.label") || "Smart Rotation"
      description: I18n.tr("settings.wallpaper.automation.smart-rotation.description") || "Show each wallpaper once before repeating any. Enables history navigation."
      checked: Settings.data.wallpaper.smartRotation ?? true
      onToggled: checked => Settings.data.wallpaper.smartRotation = checked
    }

    // History navigation buttons
    RowLayout {
      visible: Settings.data.wallpaper.randomEnabled && (Settings.data.wallpaper.smartRotation ?? true)
      spacing: Style.marginM

      NLabel {
        label: I18n.tr("settings.wallpaper.automation.history.label") || "Wallpaper History"
        description: I18n.tr("settings.wallpaper.automation.history.description") || "Navigate through previously shown wallpapers"
        Layout.fillWidth: true
      }

      NIconButton {
        icon: "arrow-left"
        tooltipText: I18n.tr("settings.wallpaper.automation.history.previous") || "Previous wallpaper"
        enabled: WallpaperService.historyPosition > 0
        onClicked: WallpaperService.previousWallpaper()
      }

      NText {
        text: (WallpaperService.historyPosition + 1) + "/" + WallpaperService.wallpaperHistory.length
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NIconButton {
        icon: "arrow-right"
        tooltipText: I18n.tr("settings.wallpaper.automation.history.next") || "Next wallpaper"
        onClicked: WallpaperService.nextWallpaper()
      }
    }

    // Interval
    ColumnLayout {
      visible: Settings.data.wallpaper.randomEnabled
      RowLayout {
        NLabel {
          label: I18n.tr("settings.wallpaper.automation.interval.label")
          description: I18n.tr("settings.wallpaper.automation.interval.description")
          Layout.fillWidth: true
        }

        NText {
          // Show friendly H:MM format from current settings
          text: Time.formatVagueHumanReadableDuration(Settings.data.wallpaper.randomIntervalSec)
          Layout.alignment: Qt.AlignBottom | Qt.AlignRight
        }
      }

      // Preset chips using Repeater
      RowLayout {
        id: presetRow
        spacing: Style.marginS

        // Factorized presets data
        property var intervalPresets: [5 * 60, 10 * 60, 15 * 60, 30 * 60, 45 * 60, 60 * 60, 90 * 60, 120 * 60]

        // Whether current interval equals one of the presets
        property bool isCurrentPreset: {
          return intervalPresets.some(seconds => seconds === Settings.data.wallpaper.randomIntervalSec);
        }
        // Allow user to force open the custom input; otherwise it's auto-open when not a preset
        property bool customForcedVisible: false

        function setIntervalSeconds(sec) {
          Settings.data.wallpaper.randomIntervalSec = sec;
          WallpaperService.restartRandomWallpaperTimer();
          // Hide custom when selecting a preset
          customForcedVisible = false;
        }

        // Helper to color selected chip
        function isSelected(sec) {
          return Settings.data.wallpaper.randomIntervalSec === sec;
        }

        // Repeater for preset chips
        Repeater {
          model: presetRow.intervalPresets
          delegate: IntervalPresetChip {
            seconds: modelData
            label: Time.formatVagueHumanReadableDuration(modelData)
            selected: presetRow.isSelected(modelData)
            onClicked: presetRow.setIntervalSeconds(modelData)
          }
        }

        // Custom… opens inline input
        IntervalPresetChip {
          label: customRow.visible ? "Custom" : "Custom…"
          selected: customRow.visible
          onClicked: presetRow.customForcedVisible = !presetRow.customForcedVisible
        }
      }

      // Custom HH:MM inline input
      RowLayout {
        id: customRow
        visible: presetRow.customForcedVisible || !presetRow.isCurrentPreset
        spacing: Style.marginS
        Layout.topMargin: Style.marginS

        NTextInput {
          label: I18n.tr("settings.wallpaper.automation.custom-interval.label")
          description: I18n.tr("settings.wallpaper.automation.custom-interval.description")
          text: {
            const s = Settings.data.wallpaper.randomIntervalSec;
            const h = Math.floor(s / 3600);
            const m = Math.floor((s % 3600) / 60);
            return h + ":" + (m < 10 ? ("0" + m) : m);
          }
          onEditingFinished: {
            const m = text.trim().match(/^(\d{1,2}):(\d{2})$/);
            if (m) {
              let h = parseInt(m[1]);
              let min = parseInt(m[2]);
              if (isNaN(h) || isNaN(min))
                return;
              h = Math.max(0, Math.min(24, h));
              min = Math.max(0, Math.min(59, min));
              Settings.data.wallpaper.randomIntervalSec = (h * 3600) + (min * 60);
              WallpaperService.restartRandomWallpaperTimer();
              // Keep custom visible after manual entry
              presetRow.customForcedVisible = true;
            }
          }
        }
      }
    }
  }

  // Reusable component for interval preset chips
  component IntervalPresetChip: Rectangle {
    property int seconds: 0
    property string label: ""
    property bool selected: false
    signal clicked

    radius: height * 0.5
    color: selected ? Color.mPrimary : Color.mSurfaceVariant
    implicitHeight: Math.max(Style.baseWidgetSize * 0.55, 24)
    implicitWidth: chipLabel.implicitWidth + Style.marginM * 1.5
    border.width: Style.borderS
    border.color: selected ? Color.transparent : Color.mOutline

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }

    NText {
      id: chipLabel
      anchors.centerIn: parent
      text: parent.label
      pointSize: Style.fontSizeS
      color: parent.selected ? Color.mOnPrimary : Color.mOnSurface
    }
  }

  NDivider {
    visible: Settings.data.wallpaper.enabled
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  // Video Wallpaper Settings
  ColumnLayout {
    visible: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("settings.wallpaper.video.section.label")
      description: I18n.tr("settings.wallpaper.video.section.description")
    }

    NToggle {
      label: I18n.tr("settings.wallpaper.video.muted.label")
      description: I18n.tr("settings.wallpaper.video.muted.description")
      checked: Settings.data.wallpaper.videoMuted ?? true
      onToggled: checked => VideoWallpaperService.setMuted(checked)
    }

    NText {
      text: I18n.tr("settings.wallpaper.video.info")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }

  NDivider {
    visible: Settings.data.wallpaper.enabled && ProgramCheckerService.realesrganAvailable
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  // AI Upscaling Settings
  ColumnLayout {
    visible: Settings.data.wallpaper.enabled && ProgramCheckerService.realesrganAvailable
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("settings.wallpaper.upscale.section.label") || "AI Upscaling"
      description: I18n.tr("settings.wallpaper.upscale.section.description") || "Settings for Real-ESRGAN image/video upscaling"
    }

    NComboBox {
      label: I18n.tr("settings.wallpaper.upscale.image-model.label") || "Image Upscale Model"
      description: I18n.tr("settings.wallpaper.upscale.image-model.description") || "Model for upscaling images (always 4x)"
      Layout.fillWidth: true
      model: [
        {
          "key": "realesrgan-x4plus",
          "name": I18n.tr("settings.wallpaper.upscale.model.general") || "General (photos, real-world)"
        },
        {
          "key": "realesrgan-x4plus-anime",
          "name": I18n.tr("settings.wallpaper.upscale.model.anime") || "Anime/Cartoon"
        }
      ]
      currentKey: Settings.data.wallpaper.imageUpscaleModel || "realesrgan-x4plus-anime"
      onSelected: key => Settings.data.wallpaper.imageUpscaleModel = key
    }

    NComboBox {
      label: I18n.tr("settings.wallpaper.upscale.video-model.label") || "Video Upscale Model"
      description: I18n.tr("settings.wallpaper.upscale.video-model.description") || "Model for upscaling videos"
      Layout.fillWidth: true
      model: [
        {
          "key": "realesrgan-x4plus",
          "name": I18n.tr("settings.wallpaper.upscale.model.general") || "General (photos, real-world) - 4x only"
        },
        {
          "key": "realesrgan-x4plus-anime",
          "name": I18n.tr("settings.wallpaper.upscale.model.anime") || "Anime/Cartoon - 4x only"
        },
        {
          "key": "realesr-animevideov3",
          "name": I18n.tr("settings.wallpaper.upscale.model.anime-video") || "Anime Video (2x/3x/4x)"
        }
      ]
      currentKey: Settings.data.wallpaper.videoUpscaleModel || "realesr-animevideov3"
      onSelected: key => Settings.data.wallpaper.videoUpscaleModel = key
    }

    NComboBox {
      visible: Settings.data.wallpaper.videoUpscaleModel === "realesr-animevideov3"
      label: I18n.tr("settings.wallpaper.upscale.scale.label") || "Video Upscale Factor"
      description: I18n.tr("settings.wallpaper.upscale.scale.description") || "How much to upscale (higher = larger file, longer processing)"
      Layout.fillWidth: true
      model: [
        { "key": "2", "name": "2x" },
        { "key": "3", "name": "3x" },
        { "key": "4", "name": "4x" }
      ]
      currentKey: (Settings.data.wallpaper.videoUpscaleScale || 4).toString()
      onSelected: key => Settings.data.wallpaper.videoUpscaleScale = parseInt(key)
    }
  }

  NDivider {
    visible: Settings.data.wallpaper.enabled
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  // Outpainting Settings
  ColumnLayout {
    visible: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("settings.wallpaper.outpaint.section.label") || "Outpainting"
      description: I18n.tr("settings.wallpaper.outpaint.section.description") || "Extend wallpapers to fit your screen aspect ratio"
    }

    NComboBox {
      label: I18n.tr("settings.wallpaper.outpaint.provider.label") || "Method"
      description: I18n.tr("settings.wallpaper.outpaint.provider.description") || "How to extend wallpaper edges"
      Layout.fillWidth: true
      model: [
        { "key": "edge_extend", "name": I18n.tr("settings.wallpaper.outpaint.provider.edge") || "Edge Extension (Fast)" },
        { "key": "comfyui", "name": I18n.tr("settings.wallpaper.outpaint.provider.comfyui") || "ComfyUI AI (Slow)" }
      ]
      currentKey: OutpaintService.provider
      onSelected: key => OutpaintService.setProvider(key)
    }

    NComboBox {
      label: I18n.tr("settings.wallpaper.outpaint.direction.label") || "Extend Direction"
      description: I18n.tr("settings.wallpaper.outpaint.direction.description") || "Which sides to extend"
      Layout.fillWidth: true
      model: [
        { "key": "auto", "name": I18n.tr("settings.wallpaper.outpaint.direction.auto") || "Auto (Best fit)" },
        { "key": "horizontal", "name": I18n.tr("settings.wallpaper.outpaint.direction.horizontal") || "Horizontal (Left/Right)" },
        { "key": "vertical", "name": I18n.tr("settings.wallpaper.outpaint.direction.vertical") || "Vertical (Top/Bottom)" }
      ]
      currentKey: OutpaintService.extendDirection
      onSelected: key => OutpaintService.setExtendDirection(key)
    }

    // ComfyUI Settings
    ColumnLayout {
      visible: OutpaintService.provider === "comfyui"
      Layout.fillWidth: true
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NTextInput {
          id: comfyuiUrlInput
          label: I18n.tr("settings.wallpaper.outpaint.comfyui-url.label") || "ComfyUI API URL"
          description: I18n.tr("settings.wallpaper.outpaint.comfyui-url.description") || "ComfyUI server address"
          text: OutpaintService.comfyuiUrl
          onEditingFinished: OutpaintService.setComfyuiUrl(text)
          Layout.fillWidth: true
        }

        NButton {
          text: comfyuiTestResult === "testing" ? "..." : (comfyuiTestResult === "success" ? "✓" : (comfyuiTestResult === "failed" ? "✗" : I18n.tr("settings.wallpaper.outpaint.test") || "Test"))
          backgroundColor: comfyuiTestResult === "success" ? Color.mSuccess : (comfyuiTestResult === "failed" ? Color.mError : Color.mPrimary)
          textColor: Color.mOnPrimary
          Layout.alignment: Qt.AlignBottom
          Layout.bottomMargin: Style.marginS
          onClicked: {
            comfyuiTestResult = "testing";
            OutpaintService.testConnection(function(success) {
              comfyuiTestResult = success ? "success" : "failed";
              comfyuiTestResetTimer.restart();
            });
          }

          property string comfyuiTestResult: ""

          Timer {
            id: comfyuiTestResetTimer
            interval: 3000
            onTriggered: parent.comfyuiTestResult = ""
          }
        }
      }

      NTextInput {
        label: I18n.tr("settings.wallpaper.outpaint.comfyui-checkpoint.label") || "Checkpoint"
        description: I18n.tr("settings.wallpaper.outpaint.comfyui-checkpoint.description") || "Model checkpoint name (leave empty for default)"
        text: OutpaintService.comfyuiCheckpoint
        onEditingFinished: OutpaintService.setComfyuiCheckpoint(text)
        Layout.fillWidth: true
      }

      ColumnLayout {
        Layout.fillWidth: true

        NLabel {
          label: I18n.tr("settings.wallpaper.outpaint.comfyui-steps.label") || "Steps"
          description: I18n.tr("settings.wallpaper.outpaint.comfyui-steps.description") || "More steps = better quality, slower"
        }

        NValueSlider {
          Layout.fillWidth: true
          from: 10
          to: 50
          stepSize: 5
          value: OutpaintService.comfyuiSteps
          onMoved: value => OutpaintService.setComfyuiSteps(Math.round(value))
          text: OutpaintService.comfyuiSteps.toString()
        }
      }

      ColumnLayout {
        Layout.fillWidth: true

        NLabel {
          label: I18n.tr("settings.wallpaper.outpaint.comfyui-denoise.label") || "Denoise Strength"
          description: I18n.tr("settings.wallpaper.outpaint.comfyui-denoise.description") || "How much to modify the extended area"
        }

        NValueSlider {
          Layout.fillWidth: true
          from: 0.5
          to: 1.0
          stepSize: 0.05
          value: OutpaintService.comfyuiDenoise
          onMoved: value => OutpaintService.setComfyuiDenoise(value)
          text: OutpaintService.comfyuiDenoise.toFixed(2)
        }
      }

      // Setup Guide
      NCollapsible {
        label: "Setup Guide"
        description: "How to configure ComfyUI for outpainting"
        Layout.fillWidth: true
        contentSpacing: Style.marginS

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            text: "1. Install ComfyUI"
            color: Color.mPrimary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM
          }
          NText {
            text: "Download from: github.com/comfyanonymous/ComfyUI"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            text: "2. Download an Inpainting Model"
            color: Color.mPrimary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM
            Layout.topMargin: Style.marginS
          }
          NText {
            text: "Recommended: Juggernaut XL Inpainting\nAlternative: RealVisXL Inpainting\n\nPlace the model in: ComfyUI/models/checkpoints/"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            text: "3. Start ComfyUI"
            color: Color.mPrimary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM
            Layout.topMargin: Style.marginS
          }
          NText {
            text: "Run: python main.py --listen\n\nDefault URL: http://127.0.0.1:8188"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            text: "4. Configure Above"
            color: Color.mPrimary
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeM
            Layout.topMargin: Style.marginS
          }
          NText {
            text: "Enter the checkpoint filename in the Checkpoint field above (e.g., juggernautXL_inpainting.safetensors)"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }
      }
    }

    NToggle {
      label: I18n.tr("settings.wallpaper.outpaint.auto.label") || "Auto Outpaint"
      description: I18n.tr("settings.wallpaper.outpaint.auto.description") || "Automatically outpaint when applying mismatched wallpapers"
      checked: OutpaintService.autoOutpaint
      onToggled: checked => OutpaintService.setAutoOutpaint(checked)
    }

    NText {
      text: I18n.tr("settings.wallpaper.outpaint.info") || "Right-click a wallpaper and select 'Outpaint' to extend it manually."
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }

  NDivider {
    visible: Settings.data.wallpaper.enabled
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  // Cache Management
  ColumnLayout {
    visible: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: "Cache"
      description: "Manage wallpaper thumbnail and preview cache"
    }

    RowLayout {
      spacing: Style.marginM

      NLabel {
        label: "Clear All Cache"
        description: "Remove all cached thumbnails and previews"
        Layout.fillWidth: true
      }

      NButton {
        text: "Clear"
        icon: "trash"
        onClicked: {
          WallpaperService.clearAllCache();
          OutpaintService.clearCache();
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  NFilePicker {
    id: mainFolderPicker
    selectionMode: "folders"
    title: I18n.tr("settings.wallpaper.settings.select-folder")
    initialPath: Settings.data.wallpaper.directory || Quickshell.env("HOME") + "/Pictures"
    onAccepted: paths => {
                  if (paths.length > 0) {
                    Settings.data.wallpaper.directory = paths[0];
                  }
                }
  }

  NFilePicker {
    id: monitorFolderPicker
    selectionMode: "folders"
    title: I18n.tr("settings.wallpaper.settings.select-monitor-folder")
    initialPath: WallpaperService.getMonitorDirectory(specificFolderMonitorName) || Quickshell.env("HOME") + "/Pictures"
    onAccepted: paths => {
                  if (paths.length > 0) {
                    WallpaperService.setMonitorDirectory(specificFolderMonitorName, paths[0]);
                  }
                }
  }
}


