import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Full-screen wallpaper preview modal with zoom/pan support
Rectangle {
  id: root

  property string wallpaperPath: ""
  property string filename: wallpaperPath ? wallpaperPath.split('/').pop() : ""
  property bool isVideo: wallpaperPath !== "" && VideoWallpaperService.isVideoFile(wallpaperPath)
  property var targetScreen: null
  property bool applyToAll: Settings.data.wallpaper.setWallpaperOnAllMonitors

  // Fill mode preview
  property string previewFillMode: Settings.data.wallpaper.fillMode || "crop"

  // Zoom state
  property real zoomLevel: 1.0
  property real minZoom: 0.5
  property real maxZoom: 5.0

  // Signals
  signal closed()
  signal applied(string path)
  signal previousRequested()
  signal nextRequested()

  visible: wallpaperPath !== ""
  color: Qt.rgba(0, 0, 0, 0.92)

  // Close on escape
  Keys.onEscapePressed: close()
  Keys.onLeftPressed: previousRequested()
  Keys.onRightPressed: nextRequested()
  Keys.onReturnPressed: applyWallpaper()
  Keys.onSpacePressed: applyWallpaper()

  focus: visible

  function open(path, screen) {
    wallpaperPath = path;
    targetScreen = screen;
    zoomLevel = 1.0;
    flickable.contentX = 0;
    flickable.contentY = 0;
    forceActiveFocus();
  }

  function close() {
    wallpaperPath = "";
    closed();
  }

  function applyWallpaper() {
    if (!wallpaperPath) return;

    if (applyToAll) {
      WallpaperService.changeWallpaper(wallpaperPath, undefined);
    } else if (targetScreen) {
      WallpaperService.changeWallpaper(wallpaperPath, targetScreen.name);
    }
    applied(wallpaperPath);
    close();
  }

  // Click outside to close
  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  // Main content container
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginXL
    spacing: Style.marginL

    // Header with filename and close button
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      // Fill mode selector
      RowLayout {
        spacing: Style.marginS

        NText {
          text: I18n.tr("wallpaper.preview.fill-mode") || "Fill:"
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
        }

        Repeater {
          model: WallpaperService.fillModeModel

          delegate: Rectangle {
            width: fillModeText.implicitWidth + Style.marginM * 2
            height: Style.baseWidgetSize * 0.6
            radius: Style.radiusS
            color: root.previewFillMode === model.key ? Color.mPrimary : Qt.alpha(Color.mSurface, 0.5)
            border.color: root.previewFillMode === model.key ? Color.transparent : Color.mOutline
            border.width: Style.borderS

            NText {
              id: fillModeText
              anchors.centerIn: parent
              text: model.name
              color: root.previewFillMode === model.key ? Color.mOnPrimary : Color.mOnSurface
              pointSize: Style.fontSizeXS
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.previewFillMode = model.key
            }
          }
        }
      }

      Item { Layout.fillWidth: true }

      // Filename
      NText {
        text: root.filename
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        elide: Text.ElideMiddle
        Layout.maximumWidth: 300
      }

      // Zoom controls
      RowLayout {
        spacing: Style.marginS

        NIconButton {
          icon: "zoom-out"
          tooltipText: I18n.tr("wallpaper.preview.zoom-out") || "Zoom Out"
          enabled: root.zoomLevel > root.minZoom
          onClicked: root.zoomLevel = Math.max(root.minZoom, root.zoomLevel - 0.25)
        }

        NText {
          text: Math.round(root.zoomLevel * 100) + "%"
          color: Color.mOnSurface
          pointSize: Style.fontSizeS
          Layout.minimumWidth: 45
          horizontalAlignment: Text.AlignHCenter
        }

        NIconButton {
          icon: "zoom-in"
          tooltipText: I18n.tr("wallpaper.preview.zoom-in") || "Zoom In"
          enabled: root.zoomLevel < root.maxZoom
          onClicked: root.zoomLevel = Math.min(root.maxZoom, root.zoomLevel + 0.25)
        }

        NIconButton {
          icon: "zoom-reset"
          tooltipText: I18n.tr("wallpaper.preview.zoom-fit") || "Fit to Screen"
          onClicked: root.zoomLevel = 1.0
        }
      }

      // Close button
      NIconButton {
        icon: "close"
        tooltipText: I18n.tr("wallpaper.preview.close") || "Close (Esc)"
        onClicked: root.close()
      }
    }

    // Image preview area
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Settings.data.wallpaper.fillColor || "#000000"
      radius: Style.radiusM
      clip: true

      // Stop clicks from closing modal
      MouseArea {
        anchors.fill: parent
        onClicked: mouse => mouse.accepted = true

        // Wheel zoom
        onWheel: wheel => {
          var delta = wheel.angleDelta.y / 120 * 0.15;
          root.zoomLevel = Math.max(root.minZoom, Math.min(root.maxZoom, root.zoomLevel + delta));
        }
      }

      Flickable {
        id: flickable
        anchors.fill: parent
        anchors.margins: Style.marginS
        contentWidth: imageContainer.width
        contentHeight: imageContainer.height
        clip: true
        interactive: root.zoomLevel > 1.0

        // Center content when smaller than viewport
        property real centerX: Math.max(0, (width - contentWidth) / 2)
        property real centerY: Math.max(0, (height - contentHeight) / 2)

        Item {
          id: imageContainer
          width: Math.max(flickable.width, previewImage.width * root.zoomLevel)
          height: Math.max(flickable.height, previewImage.height * root.zoomLevel)

          // Image preview
          Image {
            id: previewImage
            visible: !root.isVideo
            source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
            asynchronous: true
            cache: false

            // Calculate size based on fill mode preview
            property real aspectRatio: sourceSize.width / Math.max(1, sourceSize.height)
            property real containerAspect: flickable.width / Math.max(1, flickable.height)

            width: {
              if (root.previewFillMode === "stretch") {
                return flickable.width * root.zoomLevel;
              } else if (root.previewFillMode === "fit") {
                if (aspectRatio > containerAspect) {
                  return flickable.width * root.zoomLevel;
                } else {
                  return flickable.height * aspectRatio * root.zoomLevel;
                }
              } else if (root.previewFillMode === "center") {
                return sourceSize.width * root.zoomLevel;
              } else { // crop
                if (aspectRatio > containerAspect) {
                  return flickable.height * aspectRatio * root.zoomLevel;
                } else {
                  return flickable.width * root.zoomLevel;
                }
              }
            }

            height: {
              if (root.previewFillMode === "stretch") {
                return flickable.height * root.zoomLevel;
              } else if (root.previewFillMode === "fit") {
                if (aspectRatio > containerAspect) {
                  return flickable.width / aspectRatio * root.zoomLevel;
                } else {
                  return flickable.height * root.zoomLevel;
                }
              } else if (root.previewFillMode === "center") {
                return sourceSize.height * root.zoomLevel;
              } else { // crop
                if (aspectRatio > containerAspect) {
                  return flickable.height * root.zoomLevel;
                } else {
                  return flickable.width / aspectRatio * root.zoomLevel;
                }
              }
            }

            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit

            // Loading indicator
            Rectangle {
              anchors.centerIn: parent
              width: 80
              height: 80
              radius: Style.radiusM
              color: Qt.alpha(Color.mSurface, 0.8)
              visible: previewImage.status === Image.Loading

              NBusyIndicator {
                anchors.centerIn: parent
              }
            }
          }

          // Video preview (thumbnail only for now)
          Image {
            id: videoPreview
            visible: root.isVideo
            anchors.centerIn: parent
            width: flickable.width * root.zoomLevel
            height: flickable.height * root.zoomLevel
            fillMode: Image.PreserveAspectFit
            asynchronous: true

            Component.onCompleted: {
              if (root.isVideo && root.wallpaperPath) {
                VideoWallpaperService.generateThumbnail(root.wallpaperPath, function(path) {
                  if (path) {
                    videoPreview.source = "file://" + path;
                  }
                }, "full");
              }
            }

            // Video play icon overlay
            Rectangle {
              anchors.centerIn: parent
              width: 80
              height: 80
              radius: width / 2
              color: Qt.alpha(Color.mSurface, 0.8)

              NIcon {
                anchors.centerIn: parent
                icon: "player-play"
                pointSize: 32
                color: Color.mOnSurface
              }
            }
          }
        }

        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      }

      // Screen frame overlay to show crop area
      Rectangle {
        visible: root.previewFillMode === "crop" && root.zoomLevel === 1.0
        anchors.centerIn: parent
        width: flickable.width * 0.9
        height: flickable.height * 0.9
        color: "transparent"
        border.color: Qt.alpha(Color.mPrimary, 0.5)
        border.width: 2
        radius: Style.radiusS

        NText {
          anchors.top: parent.top
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.topMargin: Style.marginS
          text: I18n.tr("wallpaper.preview.visible-area") || "Visible Area"
          color: Color.mPrimary
          pointSize: Style.fontSizeXS
          font.weight: Style.fontWeightBold

          Rectangle {
            anchors.fill: parent
            anchors.margins: -Style.marginXS
            color: Qt.alpha(Color.mSurface, 0.7)
            radius: Style.radiusXS
            z: -1
          }
        }
      }
    }

    // Bottom action bar
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      // Navigation buttons
      NIconButton {
        icon: "arrow-left"
        tooltipText: I18n.tr("wallpaper.preview.previous") || "Previous"
        onClicked: root.previousRequested()
      }

      NIconButton {
        icon: "arrow-right"
        tooltipText: I18n.tr("wallpaper.preview.next") || "Next"
        onClicked: root.nextRequested()
      }

      Item { Layout.fillWidth: true }

      // Resolution info
      NText {
        id: resolutionText
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        text: previewImage.sourceSize.width + " x " + previewImage.sourceSize.height
        visible: previewImage.status === Image.Ready && !root.isVideo
      }

      Item { Layout.fillWidth: true }

      // Apply to all toggle
      RowLayout {
        spacing: Style.marginS

        NText {
          text: I18n.tr("wallpaper.preview.apply-to-all") || "Apply to all monitors"
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
        }

        Switch {
          checked: root.applyToAll
          onToggled: root.applyToAll = checked
        }
      }

      // Apply button
      NButton {
        text: I18n.tr("wallpaper.preview.apply") || "Apply"
        icon: "check"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        onClicked: root.applyWallpaper()
      }
    }
  }

  // Keyboard hints overlay
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.margins: Style.marginL
    width: hintsRow.implicitWidth + Style.marginM * 2
    height: hintsRow.implicitHeight + Style.marginS * 2
    radius: Style.radiusS
    color: Qt.alpha(Color.mSurface, 0.7)

    RowLayout {
      id: hintsRow
      anchors.centerIn: parent
      spacing: Style.marginM

      NText {
        text: "[Esc] " + (I18n.tr("wallpaper.preview.hint.close") || "Close")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
      }

      NText {
        text: "[Enter] " + (I18n.tr("wallpaper.preview.hint.apply") || "Apply")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
      }

      NText {
        text: "[<] [>] " + (I18n.tr("wallpaper.preview.hint.navigate") || "Navigate")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
      }

      NText {
        text: "[Scroll] " + (I18n.tr("wallpaper.preview.hint.zoom") || "Zoom")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
      }
    }
  }
}
