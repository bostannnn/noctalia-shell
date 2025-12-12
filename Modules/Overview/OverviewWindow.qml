import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI
import qs.Widgets

/**
 * Individual window preview in the workspace overview.
 * Uses ScreencopyView for live window capture.
 */
Item {
  id: root
  property var toplevel
  property var windowData
  property var monitorData
  property real scale: 0.16
  property real availableWorkspaceWidth: 100
  property real availableWorkspaceHeight: 100
  property real initX: Math.max(((windowData?.at[0] ?? 0) - (monitorData?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)) * root.scale, 0) + xOffset
  property real initY: Math.max(((windowData?.at[1] ?? 0) - (monitorData?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)) * root.scale, 0) + yOffset
  property real xOffset: 0
  property real yOffset: 0
  property int widgetMonitorId: 0

  property real targetWindowWidth: (windowData?.size?.[0] ?? 100) * scale
  property real targetWindowHeight: (windowData?.size?.[1] ?? 100) * scale
  property bool hovered: false
  property bool pressed: false

  property real iconToWindowRatio: 0.25
  property real iconToWindowRatioCompact: 0.45
  property var entry: windowData?.class ? DesktopEntries.heuristicLookup(windowData.class) : null
  property string iconPath: Quickshell.iconPath(entry?.icon ?? windowData?.class ?? "application-x-executable", "image-missing")
  property bool compactMode: Style.fontSizeS * 4 > targetWindowHeight || Style.fontSizeS * 4 > targetWindowWidth

  x: initX
  y: initY
  width: Math.min((windowData?.size?.[0] ?? 100) * root.scale, availableWorkspaceWidth)
  height: Math.min((windowData?.size?.[1] ?? 100) * root.scale, availableWorkspaceHeight)
  opacity: (windowData?.monitor ?? -1) == widgetMonitorId ? 1 : 0.4

  // Simple clipping
  clip: true

  Behavior on x {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }
  Behavior on y {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }
  Behavior on width {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }
  Behavior on height {
    NumberAnimation {
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
  }

  ScreencopyView {
    id: windowPreview
    anchors.fill: parent
    captureSource: OverviewService.isOpen ? root.toplevel : null
    live: true

    // Hover/press overlay - transparent by default to show screencopy
    Rectangle {
      anchors.fill: parent
      radius: Style.radiusM * root.scale
      color: root.pressed ? Qt.rgba(Color.mHover.r, Color.mHover.g, Color.mHover.b, 0.3) :
             root.hovered ? Qt.rgba(Color.mHover.r, Color.mHover.g, Color.mHover.b, 0.15) :
             "transparent"
      border.color: root.hovered ? Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.5) : "transparent"
      border.width: Style.borderS
    }

    // App icon overlay
    ColumnLayout {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.marginXS

      Image {
        id: windowIcon
        property real iconSize: Math.min(root.targetWindowWidth, root.targetWindowHeight) * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / (root.monitorData?.scale ?? 1)
        Layout.alignment: Qt.AlignHCenter
        source: root.iconPath
        width: iconSize
        height: iconSize
        sourceSize: Qt.size(iconSize, iconSize)

        Behavior on width {
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }
        Behavior on height {
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
