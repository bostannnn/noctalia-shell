import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  // User Interface
  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("settings.user-interface.section.label")
      description: I18n.tr("settings.user-interface.section.description")
    }

    NToggle {
      label: I18n.tr("settings.user-interface.tooltips.label")
      description: I18n.tr("settings.user-interface.tooltips.description")
      checked: Settings.data.ui.tooltipsEnabled
      onToggled: checked => Settings.data.ui.tooltipsEnabled = checked
    }

    // Dim desktop opacity
    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true

      NLabel {
        label: I18n.tr("settings.user-interface.dimmer-opacity.label")
        description: I18n.tr("settings.user-interface.dimmer-opacity.description")
      }

      NValueSlider {
        Layout.fillWidth: true
        from: 0
        to: 1
        stepSize: 0.01
        value: Settings.data.general.dimmerOpacity
        onMoved: value => Settings.data.general.dimmerOpacity = value
        text: Math.floor(Settings.data.general.dimmerOpacity * 100) + "%"
      }
    }

    NToggle {
      label: I18n.tr("settings.user-interface.panels-attached-to-bar.label")
      description: I18n.tr("settings.user-interface.panels-attached-to-bar.description")
      checked: Settings.data.ui.panelsAttachedToBar
      onToggled: checked => Settings.data.ui.panelsAttachedToBar = checked
    }

    NToggle {
      label: I18n.tr("settings.user-interface.settings-panel-attached-to-bar.label")
      description: I18n.tr("settings.user-interface.settings-panel-attached-to-bar.description")
      checked: Settings.data.ui.settingsPanelAttachToBar
      enabled: Settings.data.ui.panelsAttachedToBar
      onToggled: checked => Settings.data.ui.settingsPanelAttachToBar = checked
    }

    NToggle {
      label: I18n.tr("settings.user-interface.shadows.label")
      description: I18n.tr("settings.user-interface.shadows.description")
      checked: Settings.data.general.enableShadows
      onToggled: checked => Settings.data.general.enableShadows = checked
    }

    // Shadow direction
    NComboBox {
      visible: Settings.data.general.enableShadows
      label: I18n.tr("settings.user-interface.shadows.direction.label")
      description: I18n.tr("settings.user-interface.shadows.direction.description")
      Layout.fillWidth: true

      readonly property var shadowOptionsMap: ({
                                                 "top_left": {
                                                   "name": I18n.tr("options.shadow-direction.top_left"),
                                                   "p": Qt.point(-2, -2)
                                                 },
                                                 "top": {
                                                   "name": I18n.tr("options.shadow-direction.top"),
                                                   "p": Qt.point(0, -3)
                                                 },
                                                 "top_right": {
                                                   "name": I18n.tr("options.shadow-direction.top_right"),
                                                   "p": Qt.point(2, -2)
                                                 },
                                                 "left": {
                                                   "name": I18n.tr("options.shadow-direction.left"),
                                                   "p": Qt.point(-3, 0)
                                                 },
                                                 "center": {
                                                   "name": I18n.tr("options.shadow-direction.center"),
                                                   "p": Qt.point(0, 0)
                                                 },
                                                 "right": {
                                                   "name": I18n.tr("options.shadow-direction.right"),
                                                   "p": Qt.point(3, 0)
                                                 },
                                                 "bottom_left": {
                                                   "name": I18n.tr("options.shadow-direction.bottom_left"),
                                                   "p": Qt.point(-2, 2)
                                                 },
                                                 "bottom": {
                                                   "name": I18n.tr("options.shadow-direction.bottom"),
                                                   "p": Qt.point(0, 3)
                                                 },
                                                 "bottom_right": {
                                                   "name": I18n.tr("options.shadow-direction.bottom_right"),
                                                   "p": Qt.point(2, 3)
                                                 }
                                               })

      model: Object.keys(shadowOptionsMap).map(function (k) {
        return {
          "key": k,
          "name": shadowOptionsMap[k].name
        };
      })

      currentKey: Settings.data.general.shadowDirection

      onSelected: function (key) {
        var opt = shadowOptionsMap[key];
        if (opt) {
          Settings.data.general.shadowDirection = key;
          Settings.data.general.shadowOffsetX = opt.p.x;
          Settings.data.general.shadowOffsetY = opt.p.y;
        }
      }
    }

    // Panel Background Opacity
    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true

      NLabel {
        label: I18n.tr("settings.user-interface.panel-background-opacity.label")
        description: I18n.tr("settings.user-interface.panel-background-opacity.description")
      }

      NValueSlider {
        Layout.fillWidth: true
        from: 0
        to: 1
        stepSize: 0.01
        value: Settings.data.ui.panelBackgroundOpacity
        onMoved: value => Settings.data.ui.panelBackgroundOpacity = value
        text: Math.floor(Settings.data.ui.panelBackgroundOpacity * 100) + "%"
      }
    }

    NToggle {
      visible: (Quickshell.screens.length > 1)
      label: I18n.tr("settings.user-interface.allow-panels-without-bar.label")
      description: I18n.tr("settings.user-interface.allow-panels-without-bar.description")
      checked: Settings.data.general.allowPanelsOnScreenWithoutBar
      onToggled: checked => Settings.data.general.allowPanelsOnScreenWithoutBar = checked
    }

    NDivider {
      Layout.fillWidth: true
      Layout.topMargin: Style.marginL
      Layout.bottomMargin: Style.marginL
    }

    // User Interface Scaling
    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true

      NLabel {
        label: I18n.tr("settings.user-interface.scaling.label")
        description: I18n.tr("settings.user-interface.scaling.description")
      }

      RowLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        NValueSlider {
          Layout.fillWidth: true
          from: 0.8
          to: 1.2
          stepSize: 0.05
          value: Settings.data.general.scaleRatio
          onMoved: value => Settings.data.general.scaleRatio = value
          text: Math.floor(Settings.data.general.scaleRatio * 100) + "%"
        }

        // Reset button container
        Item {
          Layout.preferredWidth: 30 * Style.uiScaleRatio
          Layout.preferredHeight: 30 * Style.uiScaleRatio

          NIconButton {
            icon: "refresh"
            baseSize: Style.baseWidgetSize * 0.8
            tooltipText: I18n.tr("settings.user-interface.scaling.reset-scaling")
            onClicked: Settings.data.general.scaleRatio = 1.0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    // Container Border Radius
    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true

      NLabel {
        label: I18n.tr("settings.user-interface.box-border-radius.label")
        description: I18n.tr("settings.user-interface.box-border-radius.description")
      }

      RowLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        NValueSlider {
          Layout.fillWidth: true
          from: 0
          to: 2
          stepSize: 0.01
          value: Settings.data.general.radiusRatio
          onMoved: value => Settings.data.general.radiusRatio = value
          text: Math.floor(Settings.data.general.radiusRatio * 100) + "%"
        }

        // Reset button container
        Item {
          Layout.preferredWidth: 30 * Style.uiScaleRatio
          Layout.preferredHeight: 30 * Style.uiScaleRatio

          NIconButton {
            icon: "refresh"
            baseSize: Style.baseWidgetSize * 0.8
            tooltipText: I18n.tr("settings.user-interface.box-border-radius.reset")
            onClicked: Settings.data.general.radiusRatio = 1.0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    // Control Border Radius (for UI components)
    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true

      NLabel {
        label: I18n.tr("settings.user-interface.control-border-radius.label")
        description: I18n.tr("settings.user-interface.control-border-radius.description")
      }

      RowLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        NValueSlider {
          Layout.fillWidth: true
          from: 0
          to: 2
          stepSize: 0.01
          value: Settings.data.general.iRadiusRatio
          onMoved: value => Settings.data.general.iRadiusRatio = value
          text: Math.floor(Settings.data.general.iRadiusRatio * 100) + "%"
        }

        // Reset button container
        Item {
          Layout.preferredWidth: 30 * Style.uiScaleRatio
          Layout.preferredHeight: 30 * Style.uiScaleRatio

          NIconButton {
            icon: "refresh"
            baseSize: Style.baseWidgetSize * 0.8
            tooltipText: I18n.tr("settings.user-interface.control-border-radius.reset")
            onClicked: Settings.data.general.iRadiusRatio = 1.0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    // Animation Speed
    ColumnLayout {
      spacing: Style.marginL
      Layout.fillWidth: true

      ColumnLayout {
        spacing: Style.marginXXS
        Layout.fillWidth: true
        visible: !Settings.data.general.animationDisabled

        NLabel {
          label: I18n.tr("settings.user-interface.animation-speed.label")
          description: I18n.tr("settings.user-interface.animation-speed.description")
        }

        RowLayout {
          spacing: Style.marginL
          Layout.fillWidth: true

          NValueSlider {
            Layout.fillWidth: true
            from: 0
            to: 2.0
            stepSize: 0.01
            value: Settings.data.general.animationSpeed
            onMoved: value => Settings.data.general.animationSpeed = Math.max(value, 0.05)
            text: Math.round(Settings.data.general.animationSpeed * 100) + "%"
          }

          // Reset button container
          Item {
            Layout.preferredWidth: 30 * Style.uiScaleRatio
            Layout.preferredHeight: 30 * Style.uiScaleRatio

            NIconButton {
              icon: "refresh"
              baseSize: Style.baseWidgetSize * 0.8
              tooltipText: I18n.tr("settings.user-interface.animation-speed.reset")
              onClicked: Settings.data.general.animationSpeed = 1.0
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      NToggle {
        label: I18n.tr("settings.user-interface.animation-disable.label")
        description: I18n.tr("settings.user-interface.animation-disable.description")
        checked: Settings.data.general.animationDisabled
        onToggled: checked => Settings.data.general.animationDisabled = checked
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  // Dock
  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NHeader {
      label: I18n.tr("settings.general.screen-corners.section.label")
      description: I18n.tr("settings.general.screen-corners.section.description")
    }

    NToggle {
      label: I18n.tr("settings.general.screen-corners.show-corners.label")
      description: Settings.data.general.screenBorderEnabled 
                   ? "Forced on while Screen Border is enabled"
                   : I18n.tr("settings.general.screen-corners.show-corners.description")
      checked: Settings.data.general.showScreenCorners
      enabled: !Settings.data.general.screenBorderEnabled
      onToggled: checked => Settings.data.general.showScreenCorners = checked
    }

    NToggle {
      label: I18n.tr("settings.general.screen-corners.solid-black.label")
      description: I18n.tr("settings.general.screen-corners.solid-black.description")
      checked: Settings.data.general.forceBlackScreenCorners
      onToggled: checked => Settings.data.general.forceBlackScreenCorners = checked
    }

    ColumnLayout {
      spacing: Style.marginXXS
      Layout.fillWidth: true

      NLabel {
        label: I18n.tr("settings.general.screen-corners.radius.label")
        description: I18n.tr("settings.general.screen-corners.radius.description")
      }

      RowLayout {
        spacing: Style.marginL
        Layout.fillWidth: true

        NValueSlider {
          Layout.fillWidth: true
          from: 0
          to: 2
          stepSize: 0.01
          value: Settings.data.general.screenRadiusRatio
          onMoved: value => Settings.data.general.screenRadiusRatio = value
          text: Math.floor(Settings.data.general.screenRadiusRatio * 100) + "%"
        }

        // Reset button container
        Item {
          Layout.preferredWidth: 30 * Style.uiScaleRatio
          Layout.preferredHeight: 30 * Style.uiScaleRatio

          NIconButton {
            icon: "refresh"
            baseSize: Style.baseWidgetSize * 0.8
            tooltipText: I18n.tr("settings.general.screen-corners.radius.reset")
            onClicked: Settings.data.general.screenRadiusRatio = 1.0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }

  // Screen Border Section (caelestia-style)
  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    // Note: Gaps are handled by ScreenBorder.qml which writes to hypr-gaps.conf
    // and reacts to Settings changes automatically

    NHeader {
      label: "Screen Border"
      description: "Add a decorative border around the entire screen (caelestia-style)"
    }

    NToggle {
      Layout.fillWidth: true
      label: "Enable Screen Border"
      description: "Shows a colored border strip around the screen edges. Disables floating bar."
      checked: Settings.data.general.screenBorderEnabled
      onToggled: checked => {
        Settings.data.general.screenBorderEnabled = checked;
        if (checked) {
          // Disable floating bar when screen border is enabled
          Settings.data.bar.floating = false;
          // Enable screen corners
          Settings.data.general.showScreenCorners = true;
        }
        // Gaps are updated automatically by ScreenBorder.qml via property binding
      }
    }

    ColumnLayout {
      visible: Settings.data.general.screenBorderEnabled
      spacing: Style.marginM
      Layout.fillWidth: true

      // Border thickness
      NSpinBox {
        Layout.fillWidth: true
        label: "Border Thickness"
        description: "Width of the border in pixels (also sets window gaps)"
        minimum: 1
        maximum: 50
        value: Settings.data.general.screenBorderThickness
        stepSize: 1
        suffix: "px"
        onValueChanged: {
          Settings.data.general.screenBorderThickness = value;
          // Gaps are updated automatically by ScreenBorder.qml via property binding
        }
      }

      // Border rounding
      NSpinBox {
        Layout.fillWidth: true
        label: "Corner Rounding"
        description: "Radius of the rounded corners"
        minimum: 0
        maximum: 100
        value: Settings.data.general.screenBorderRounding
        stepSize: 1
        suffix: "px"
        onValueChanged: Settings.data.general.screenBorderRounding = value
      }

      // Window margin
      NSpinBox {
        Layout.fillWidth: true
        label: "Window Margin"
        description: "Gap between the border and windows"
        minimum: 0
        maximum: 50
        value: Settings.data.general.screenBorderMargin
        stepSize: 1
        suffix: "px"
        onValueChanged: {
          Settings.data.general.screenBorderMargin = value;
        }
      }

      // Use theme color toggle
      NToggle {
        Layout.fillWidth: true
        label: "Use Theme Color"
        description: "Match border color to current theme surface color"
        checked: Settings.data.general.screenBorderUseThemeColor
        onToggled: checked => Settings.data.general.screenBorderUseThemeColor = checked
      }

      // Custom color input (visible when not using theme color)
      RowLayout {
        Layout.fillWidth: true
        visible: !Settings.data.general.screenBorderUseThemeColor
        spacing: Style.marginM

        NLabel {
          label: "Border Color"
          description: "Custom border color (hex format)"
          Layout.fillWidth: true
        }

        Rectangle {
          width: 32
          height: 32
          radius: Style.iRadiusS
          color: Settings.data.general.screenBorderColor
          border.color: Color.mOutline
          border.width: Style.borderS
        }

        NTextInput {
          id: borderColorInput
          Layout.preferredWidth: 100
          text: Settings.data.general.screenBorderColor
          placeholderText: "#1e1e2e"
          onEditingFinished: {
            // Validate hex color
            if (/^#[0-9A-Fa-f]{6}$/.test(text)) {
              Settings.data.general.screenBorderColor = text;
            }
          }
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginL
    Layout.bottomMargin: Style.marginL
  }
}


