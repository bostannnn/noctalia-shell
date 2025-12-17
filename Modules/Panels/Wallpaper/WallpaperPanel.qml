import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Helpers/FuzzySort.js" as FuzzySort
import qs.Commons
import qs.Modules.MainScreen
import qs.Modules.Panels.Settings
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: 900 * Style.uiScaleRatio
  preferredHeight: 700 * Style.uiScaleRatio
  preferredWidthRatio: 0.5
  preferredHeightRatio: 0.7

  // Positioning
  readonly property string panelPosition: {
    if (Settings.data.wallpaper.panelPosition === "follow_bar") {
      if (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") {
        return `center_${Settings.data.bar.position}`;
      } else {
        return `${Settings.data.bar.position}_center`;
      }
    } else {
      return Settings.data.wallpaper.panelPosition;
    }
  }
  panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
  panelAnchorVerticalCenter: panelPosition === "center"
  panelAnchorLeft: panelPosition !== "center" && panelPosition.endsWith("_left")
  panelAnchorRight: panelPosition !== "center" && panelPosition.endsWith("_right")
  panelAnchorBottom: panelPosition.startsWith("bottom_")
  panelAnchorTop: panelPosition.startsWith("top_")

  // Store direct reference to content for instant access
  property var contentItem: null

  // Override keyboard handlers to enable grid navigation
  function onDownPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView) {
      if (!view.gridView.activeFocus) {
        view.gridView.forceActiveFocus();
        if (view.gridView.currentIndex < 0) {
          view.gridView.currentIndex = 0;
        }
      } else {
        view.gridView.moveCurrentIndexDown();
      }
    }
  }

  function onUpPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      view.gridView.moveCurrentIndexUp();
    }
  }

  function onLeftPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      view.gridView.moveCurrentIndexLeft();
    }
  }

  function onRightPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      view.gridView.moveCurrentIndexRight();
    }
  }

  function onReturnPressed() {
    if (!contentItem)
      return;
    let view = contentItem.screenRepeater.itemAt(contentItem.currentScreenIndex);
    if (view?.gridView?.activeFocus) {
      let gridView = view.gridView;
      if (gridView.currentIndex >= 0 && gridView.currentIndex < gridView.model.length) {
        let path = gridView.model[gridView.currentIndex];
        if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
          WallpaperService.changeWallpaper(path, undefined);
        } else {
          WallpaperService.changeWallpaper(path, view.targetScreen.name);
        }
      }
    }
  }

  panelContent: Rectangle {
    id: wallpaperPanel

    property int currentScreenIndex: {
      if (screen !== null) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          if (Quickshell.screens[i].name == screen.name) {
            return i;
          }
        }
      }
      return 0;
    }
    property var currentScreen: Quickshell.screens[currentScreenIndex]
    property string filterText: ""
    property string mediaFilter: "all"  // "all", "images", "videos"
    property alias screenRepeater: screenRepeater

    Component.onCompleted: {
      root.contentItem = wallpaperPanel;
    }

    // Function to update Wallhaven resolution filter
    function updateWallhavenResolution() {
      if (typeof WallhavenService === "undefined") {
        return;
      }

      var width = Settings.data.wallpaper.wallhavenResolutionWidth || "";
      var height = Settings.data.wallpaper.wallhavenResolutionHeight || "";
      var mode = Settings.data.wallpaper.wallhavenResolutionMode || "atleast";

      if (width && height) {
        var resolution = width + "x" + height;
        if (mode === "atleast") {
          WallhavenService.minResolution = resolution;
          WallhavenService.resolutions = "";
        } else {
          WallhavenService.minResolution = "";
          WallhavenService.resolutions = resolution;
        }
      } else {
        WallhavenService.minResolution = "";
        WallhavenService.resolutions = "";
      }

      // Trigger new search with updated resolution
      if (Settings.data.wallpaper.useWallhaven) {
        if (wallhavenView) {
          wallhavenView.loading = true;
        }
        WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
      }
    }

    color: Color.transparent

    // Wallhaven settings popup
    Loader {
      id: wallhavenSettingsPopup
      source: "WallhavenSettingsPopup.qml"
      onLoaded: {
        if (item) {
          item.screen = screen;
        }
      }
    }

    // Focus management
    Connections {
      target: root
      function onOpened() {
        // Ensure contentItem is set
        if (!root.contentItem) {
          root.contentItem = wallpaperPanel;
        }
        // Give initial focus to search input
        Qt.callLater(() => {
                       if (searchInput.inputItem) {
                         searchInput.inputItem.forceActiveFocus();
                       }
                     });
      }
    }

    // Debounce timer for search
    Timer {
      id: searchDebounceTimer
      interval: 150
      onTriggered: {
        wallpaperPanel.filterText = searchInput.text;
        // Trigger update on all screen views
        for (var i = 0; i < screenRepeater.count; i++) {
          let item = screenRepeater.itemAt(i);
          if (item && item.updateFiltered) {
            item.updateFiltered();
          }
        }
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Debounce timer for Wallhaven search
      Timer {
        id: wallhavenSearchDebounceTimer
        interval: 500
        onTriggered: {
          Settings.data.wallpaper.wallhavenQuery = searchInput.text;
          if (typeof WallhavenService !== "undefined") {
            wallhavenView.loading = true;
            WallhavenService.search(searchInput.text, 1);
          }
        }
      }

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerColumn.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
          id: headerColumn
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "settings-wallpaper-selector"
              pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NText {
              text: I18n.tr("wallpaper.panel.title")
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "settings"
              tooltipText: I18n.tr("settings.wallpaper.settings.section.label")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                var settingsPanel = PanelService.getPanel("settingsPanel", screen);
                settingsPanel.requestedTab = SettingsPanel.Tab.Wallpaper;
                settingsPanel.open();
              }
            }

            NIconButton {
              icon: "refresh"
              tooltipText: Settings.data.wallpaper.useWallhaven ? I18n.tr("tooltips.refresh-wallhaven") : I18n.tr("tooltips.refresh-wallpaper-list")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                if (Settings.data.wallpaper.useWallhaven) {
                  if (typeof WallhavenService !== "undefined") {
                    WallhavenService.search(Settings.data.wallpaper.wallhavenQuery, 1);
                  }
                } else {
                  WallpaperService.refreshWallpapersList();
                }
              }
            }

            NIconButton {
              icon: "arrows-shuffle"
              tooltipText: I18n.tr("tooltips.random-wallpaper")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: WallpaperService.setRandomWallpaper()
            }

            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("tooltips.close")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: root.close()
            }
          }

          NDivider {
            Layout.fillWidth: true
          }

          NToggle {
            label: I18n.tr("wallpaper.panel.apply-all-monitors.label")
            description: I18n.tr("wallpaper.panel.apply-all-monitors.description")
            checked: Settings.data.wallpaper.setWallpaperOnAllMonitors
            onToggled: checked => Settings.data.wallpaper.setWallpaperOnAllMonitors = checked
            Layout.fillWidth: true
          }

          // Monitor tabs
          NTabBar {
            id: screenTabBar
            visible: (!Settings.data.wallpaper.setWallpaperOnAllMonitors || Settings.data.wallpaper.enableMultiMonitorDirectories)
            Layout.fillWidth: true
            currentIndex: currentScreenIndex
            onCurrentIndexChanged: currentScreenIndex = currentIndex
            spacing: Style.marginM

            Repeater {
              model: Quickshell.screens
              NTabButton {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                text: modelData.name || `Screen ${index + 1}`
                tabIndex: index
                checked: {
                  screenTabBar.currentIndex === index;
                }
              }
            }
          }

          // Unified search input and source
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NTextInput {
              id: searchInput
              placeholderText: Settings.data.wallpaper.useWallhaven ? I18n.tr("placeholders.search-wallhaven") : I18n.tr("placeholders.search-wallpapers")
              Layout.fillWidth: true

              property bool initializing: true
              Component.onCompleted: {
                // Initialize text based on current mode
                if (Settings.data.wallpaper.useWallhaven) {
                  searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                } else {
                  searchInput.text = wallpaperPanel.filterText || "";
                }
                // Give focus to search input
                if (searchInput.inputItem && searchInput.inputItem.visible) {
                  searchInput.inputItem.forceActiveFocus();
                }
                // Mark initialization as complete after a short delay
                Qt.callLater(function () {
                  searchInput.initializing = false;
                });
              }

              Connections {
                target: Settings.data.wallpaper
                function onUseWallhavenChanged() {
                  // Update text when mode changes
                  if (Settings.data.wallpaper.useWallhaven) {
                    searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                  } else {
                    searchInput.text = wallpaperPanel.filterText || "";
                  }
                }
              }

              onTextChanged: {
                // Don't trigger search during initialization - Component.onCompleted will handle initial search
                if (initializing) {
                  return;
                }
                if (Settings.data.wallpaper.useWallhaven) {
                  wallhavenSearchDebounceTimer.restart();
                } else {
                  searchDebounceTimer.restart();
                }
              }

              onEditingFinished: {
                if (Settings.data.wallpaper.useWallhaven) {
                  wallhavenSearchDebounceTimer.stop();
                  Settings.data.wallpaper.wallhavenQuery = text;
                  if (typeof WallhavenService !== "undefined") {
                    wallhavenView.loading = true;
                    WallhavenService.search(text, 1);
                  }
                }
              }

              Keys.onDownPressed: {
                if (Settings.data.wallpaper.useWallhaven) {
                  if (wallhavenView && wallhavenView.gridView) {
                    wallhavenView.gridView.forceActiveFocus();
                  }
                } else {
                  let currentView = screenRepeater.itemAt(currentScreenIndex);
                  if (currentView && currentView.gridView) {
                    currentView.gridView.forceActiveFocus();
                  }
                }
              }
            }

            NComboBox {
              id: sourceComboBox
              Layout.fillWidth: false

              model: [
                {
                  "key": "local",
                  "name": I18n.tr("wallpaper.panel.source.local")
                },
                {
                  "key": "wallhaven",
                  "name": I18n.tr("wallpaper.panel.source.wallhaven")
                }
              ]
              currentKey: Settings.data.wallpaper.useWallhaven ? "wallhaven" : "local"
              property bool skipNextSelected: false
              Component.onCompleted: {
                // Skip the first onSelected if it fires during initialization
                skipNextSelected = true;
                Qt.callLater(function () {
                  skipNextSelected = false;
                });
              }
              onSelected: key => {
                            if (skipNextSelected) {
                              return;
                            }
                            var useWallhaven = (key === "wallhaven");
                            Settings.data.wallpaper.useWallhaven = useWallhaven;
                            // Update search input text based on mode
                            if (useWallhaven) {
                              searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                            } else {
                              searchInput.text = wallpaperPanel.filterText || "";
                            }
                            if (useWallhaven && typeof WallhavenService !== "undefined") {
                              // Update service properties when switching to Wallhaven
                              // Don't search here - Component.onCompleted will handle it when the component is created
                              // This prevents duplicate searches
                              WallhavenService.categories = Settings.data.wallpaper.wallhavenCategories;
                              WallhavenService.purity = Settings.data.wallpaper.wallhavenPurity;
                              WallhavenService.sorting = Settings.data.wallpaper.wallhavenSorting;
                              WallhavenService.order = Settings.data.wallpaper.wallhavenOrder;

                              // Update resolution settings
                              wallpaperPanel.updateWallhavenResolution();

                              // If the view is already initialized, trigger a new search when switching to it
                              if (wallhavenView && wallhavenView.initialized && !WallhavenService.fetching) {
                                wallhavenView.loading = true;
                                WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
                              }
                            }
                          }
            }

            // Discover button (only visible for Wallhaven) - random wallpaper discovery
            NIconButton {
              icon: "dice-5"
              tooltipText: I18n.tr("tooltips.discover-wallpapers")
              baseSize: Style.baseWidgetSize * 0.8
              visible: Settings.data.wallpaper.useWallhaven
              onClicked: {
                if (typeof WallhavenService !== "undefined") {
                  wallhavenView.loading = true;
                  WallhavenService.discover();
                }
              }
            }

            // Settings button (only visible for Wallhaven)
            NIconButton {
              id: wallhavenSettingsButton
              icon: "settings"
              tooltipText: I18n.tr("wallpaper.panel.wallhaven-settings.title")
              baseSize: Style.baseWidgetSize * 0.8
              visible: Settings.data.wallpaper.useWallhaven
              onClicked: {
                if (searchInput.inputItem) {
                  searchInput.inputItem.focus = false;
                }
                if (wallhavenSettingsPopup.item) {
                  wallhavenSettingsPopup.item.showAt(wallhavenSettingsButton);
                }
              }
            }
          }

          // Media type filter buttons (only for local wallpapers)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: !Settings.data.wallpaper.useWallhaven

            NText {
              text: I18n.tr("wallpaper.panel.filter.label")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            NButton {
              text: I18n.tr("wallpaper.panel.filter.all")
              backgroundColor: wallpaperPanel.mediaFilter === "all" ? Color.mPrimary : Color.mSurfaceVariant
              textColor: wallpaperPanel.mediaFilter === "all" ? Color.mOnPrimary : Color.mOnSurfaceVariant
              onClicked: {
                wallpaperPanel.mediaFilter = "all"
                for (var i = 0; i < screenRepeater.count; i++) {
                  let item = screenRepeater.itemAt(i)
                  if (item && item.updateFiltered) item.updateFiltered()
                }
              }
            }

            NButton {
              text: I18n.tr("wallpaper.panel.filter.videos")
              icon: "movie"
              backgroundColor: wallpaperPanel.mediaFilter === "videos" ? Color.mPrimary : Color.mSurfaceVariant
              textColor: wallpaperPanel.mediaFilter === "videos" ? Color.mOnPrimary : Color.mOnSurfaceVariant
              onClicked: {
                wallpaperPanel.mediaFilter = "videos"
                for (var i = 0; i < screenRepeater.count; i++) {
                  let item = screenRepeater.itemAt(i)
                  if (item && item.updateFiltered) item.updateFiltered()
                }
              }
            }

            NButton {
              text: I18n.tr("wallpaper.panel.filter.images")
              icon: "image"
              backgroundColor: wallpaperPanel.mediaFilter === "images" ? Color.mPrimary : Color.mSurfaceVariant
              textColor: wallpaperPanel.mediaFilter === "images" ? Color.mOnPrimary : Color.mOnSurfaceVariant
              onClicked: {
                wallpaperPanel.mediaFilter = "images"
                for (var i = 0; i < screenRepeater.count; i++) {
                  let item = screenRepeater.itemAt(i)
                  if (item && item.updateFiltered) item.updateFiltered()
                }
              }
            }

            Item { Layout.fillWidth: true }
          }
        }
      }

      // Content stack: Wallhaven or Local
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant

        StackLayout {
          id: contentStack
          anchors.fill: parent
          anchors.margins: Style.marginL

          currentIndex: Settings.data.wallpaper.useWallhaven ? 1 : 0

          // Local wallpapers
          StackLayout {
            id: screenStack
            currentIndex: currentScreenIndex

            Repeater {
              id: screenRepeater
              model: Quickshell.screens
              delegate: WallpaperScreenView {
                targetScreen: modelData
              }
            }
          }

          // Wallhaven wallpapers
          WallhavenView {
            id: wallhavenView
          }
        }

        // Overlay gradient to smooth the hard cut due to scrolling
        Rectangle {
          anchors.fill: parent
          anchors.margins: Style.borderS
          radius: Style.radiusM
          gradient: Gradient {
            GradientStop {
              position: 0.0
              color: Color.transparent
            }
            GradientStop {
              position: 0.9
              color: Color.transparent
            }
            GradientStop {
              position: 1.0
              color: Color.mSurfaceVariant
            }
          }
        }
      }
    }
  }

  // Component for each screen's wallpaper view
  component WallpaperScreenView: Item {
    property var targetScreen
    property alias gridView: wallpaperGridView

    // Local reactive state for this screen
    property list<string> wallpapersList: []
    property string currentWallpaper: ""
    property list<string> filteredWallpapers: []
    property var wallpapersWithNames: [] // Cached basenames

    // Expose updateFiltered as a proper function property
    function updateFiltered() {
      // Start with full list
      var baseList = wallpapersList;
      
      // Apply media type filter
      if (wallpaperPanel.mediaFilter === "images") {
        baseList = wallpapersList.filter(function(p) {
          return !VideoWallpaperService.isVideoFile(p);
        });
      } else if (wallpaperPanel.mediaFilter === "videos") {
        baseList = wallpapersList.filter(function(p) {
          return VideoWallpaperService.isVideoFile(p);
        });
      }
      
      // Apply text search filter
      if (!wallpaperPanel.filterText || wallpaperPanel.filterText.trim().length === 0) {
        filteredWallpapers = baseList;
        return;
      }

      // Build search list from filtered base
      var searchList = baseList.map(function(p) {
        return { "path": p, "name": p.split('/').pop() };
      });
      
      const results = FuzzySort.go(wallpaperPanel.filterText.trim(), searchList, {
                                     "key": 'name',
                                     "limit": 200
                                   });
      // Map back to path list
      filteredWallpapers = results.map(function (r) {
        return r.obj.path;
      });
    }

    Component.onCompleted: {
      refreshWallpaperScreenData();
    }

    Connections {
      target: WallpaperService
      function onWallpaperChanged(screenName, path) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          currentWallpaper = WallpaperService.getWallpaper(targetScreen.name);
        }
      }
      function onWallpaperDirectoryChanged(screenName, directory) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          refreshWallpaperScreenData();
        }
      }
      function onWallpaperListChanged(screenName, count) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          refreshWallpaperScreenData();
        }
      }
    }

    function refreshWallpaperScreenData() {
      if (targetScreen === null) {
        return;
      }
      var rawList = WallpaperService.getWallpapersList(targetScreen.name);
      Logger.d("WallpaperPanel", "Got", rawList.length, "wallpapers for screen", targetScreen.name);

      // Sort videos first, then images (alphabetically within each group)
      var videos = [];
      var images = [];
      for (var i = 0; i < rawList.length; i++) {
        if (VideoWallpaperService.isVideoFile(rawList[i])) {
          videos.push(rawList[i]);
        } else {
          images.push(rawList[i]);
        }
      }
      
      // Sort each group alphabetically by filename
      var sortByName = function(a, b) {
        var nameA = a.split('/').pop().toLowerCase();
        var nameB = b.split('/').pop().toLowerCase();
        return nameA.localeCompare(nameB);
      };
      videos.sort(sortByName);
      images.sort(sortByName);
      
      // Combine: videos first, then images
      wallpapersList = videos.concat(images);
      Logger.d("WallpaperPanel", "Sorted:", videos.length, "videos,", images.length, "images");

      // Pre-compute basenames once for better performance
      wallpapersWithNames = wallpapersList.map(function (p) {
        return {
          "path": p,
          "name": p.split('/').pop()
        };
      });

      currentWallpaper = WallpaperService.getWallpaper(targetScreen.name);
      updateFiltered();
    }

    // Delete wallpaper function
    function deleteWallpaper(path) {
      var deleteProcess = Qt.createQmlObject(`
        import QtQuick
        import Quickshell.Io
        Process {
          command: ["gio", "trash", "${path.replace(/"/g, '\\"')}"]
        }
      `, parent, "DeleteWallpaper");

      deleteProcess.exited.connect(function(exitCode) {
        if (exitCode === 0) {
          Logger.i("WallpaperPanel", "Moved to trash:", path);
          ToastService.showNotice(I18n.tr("wallpaper.panel.deleted"), "");
        } else {
          // Fallback to rm if gio trash fails
          var rmProcess = Qt.createQmlObject(`
            import QtQuick
            import Quickshell.Io
            Process {
              command: ["rm", "${path.replace(/"/g, '\\"')}"]
            }
          `, parent, "DeleteWallpaperRm");

          rmProcess.exited.connect(function(rmExitCode) {
            if (rmExitCode === 0) {
              Logger.i("WallpaperPanel", "Deleted:", path);
              ToastService.showNotice(I18n.tr("wallpaper.panel.deleted"), "");
            } else {
              Logger.e("WallpaperPanel", "Failed to delete:", path);
              ToastService.showWarning(I18n.tr("wallpaper.panel.delete-failed"), "");
            }
            rmProcess.destroy();
          });

          rmProcess.running = true;
        }
        WallpaperService.refreshWallpapersList();
        deleteProcess.destroy();
      });

      deleteProcess.running = true;
    }

    // Context menu for wallpaper items
    Menu {
      id: wallpaperContextMenu
      property string wallpaperToDelete: ""

      MenuItem {
        text: I18n.tr("wallpaper.panel.context.delete")
        icon.name: "trash"
        onTriggered: {
          if (wallpaperContextMenu.wallpaperToDelete) {
            deleteWallpaper(wallpaperContextMenu.wallpaperToDelete)
          }
        }
      }

      MenuItem {
        text: I18n.tr("wallpaper.panel.context.open-folder")
        icon.name: "folder-open"
        onTriggered: {
          if (wallpaperContextMenu.wallpaperToDelete) {
            var folder = wallpaperContextMenu.wallpaperToDelete.substring(0, wallpaperContextMenu.wallpaperToDelete.lastIndexOf('/'))
            Qt.openUrlExternally("file://" + folder)
          }
        }
      }

      MenuItem {
        text: WallpaperService.isUpscaling ? I18n.tr("wallpaper.panel.context.upscaling") : I18n.tr("wallpaper.panel.context.upscale")
        icon.name: "photo-up"
        enabled: {
          if (WallpaperService.isUpscaling) return false;
          if (!ProgramCheckerService.realesrganAvailable) return false;
          var path = wallpaperContextMenu.wallpaperToDelete;
          if (!path) return false;
          var ext = path.split('.').pop().toLowerCase();
          var imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "pnm"];
          return imageExtensions.indexOf(ext) !== -1;
        }
        onTriggered: {
          if (wallpaperContextMenu.wallpaperToDelete) {
            WallpaperService.upscaleWallpaper(wallpaperContextMenu.wallpaperToDelete)
          }
        }
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      GridView {
        id: wallpaperGridView

        Layout.fillWidth: true
        Layout.fillHeight: true

        visible: !WallpaperService.scanning
        interactive: true
        clip: true
        focus: true
        keyNavigationEnabled: true
        keyNavigationWraps: false

        model: filteredWallpapers

        // Capture clicks on empty areas to give focus to GridView
        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: {
            wallpaperGridView.forceActiveFocus();
            if (wallpaperGridView.currentIndex < 0 && filteredWallpapers.length > 0) {
              wallpaperGridView.currentIndex = 0;
            }
          }
        }

        property int columns: 4
        property int itemSize: cellWidth

        cellWidth: Math.floor((width - leftMargin - rightMargin) / columns)
        cellHeight: Math.floor(itemSize * 0.63) + Style.marginXS + Style.fontSizeXS + Style.marginM

        leftMargin: Style.marginS
        rightMargin: Style.marginS
        topMargin: Style.marginS
        bottomMargin: Style.marginS

        onCurrentIndexChanged: {
          // Synchronize scroll with current item position
          if (currentIndex >= 0) {
            let row = Math.floor(currentIndex / columns);
            let itemY = row * cellHeight;
            let viewportTop = contentY;
            let viewportBottom = viewportTop + height;

            // If item is out of view, scroll
            if (itemY < viewportTop) {
              contentY = Math.max(0, itemY - cellHeight);
            } else if (itemY + cellHeight > viewportBottom) {
              contentY = itemY + cellHeight - height + cellHeight;
            }
          }
        }

        Keys.onPressed: event => {
                          if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                            if (currentIndex >= 0 && currentIndex < filteredWallpapers.length) {
                              let path = filteredWallpapers[currentIndex];
                              if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
                                WallpaperService.changeWallpaper(path, undefined);
                              } else {
                                WallpaperService.changeWallpaper(path, targetScreen.name);
                              }
                            }
                            event.accepted = true;
                          }
                        }

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AsNeeded
          parent: wallpaperGridView
          x: wallpaperGridView.mirrored ? 0 : wallpaperGridView.width - width
          y: 0
          height: wallpaperGridView.height

          property color handleColor: Qt.alpha(Color.mHover, 0.8)
          property color handleHoverColor: handleColor
          property color handlePressedColor: handleColor
          property real handleWidth: 6
          property real handleRadius: Style.radiusM

          contentItem: Rectangle {
            implicitWidth: parent.handleWidth
            implicitHeight: 100
            radius: parent.handleRadius
            color: parent.pressed ? parent.handlePressedColor : parent.hovered ? parent.handleHoverColor : parent.handleColor
            opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 1.0 : 0.0

            Behavior on opacity {
              NumberAnimation {
                duration: Style.animationFast
              }
            }

            Behavior on color {
              ColorAnimation {
                duration: Style.animationFast
              }
            }
          }

          background: Rectangle {
            implicitWidth: parent.handleWidth
            implicitHeight: 100
            color: Color.transparent
            opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 0.3 : 0.0
            radius: parent.handleRadius / 2

            Behavior on opacity {
              NumberAnimation {
                duration: Style.animationFast
              }
            }
          }
        }

        delegate: ColumnLayout {
          id: wallpaperItem

          property string wallpaperPath: modelData
          property bool isSelected: (wallpaperPath === currentWallpaper)
          property string filename: wallpaperPath.split('/').pop()
          property bool isVideo: VideoWallpaperService.isVideoFile(wallpaperPath)
          property string thumbnailPath: ""
          property bool thumbnailReady: false

          // Metadata properties
          property bool isUpscaled: filename.indexOf("_upscaled") !== -1
          property string resolution: ""
          property string fileSize: ""
          property bool metadataLoaded: false

          width: wallpaperGridView.itemSize
          spacing: Style.marginXS

          // Load metadata when item is created
          Component.onCompleted: {
            if (isVideo && VideoWallpaperService.isInitialized) {
              loadThumbnail()
            } else if (isVideo) {
              thumbnailRetryTimer.start()
            }
            // Load file metadata
            loadMetadata()
          }

          function loadMetadata() {
            var itemRef = wallpaperItem;
            var path = wallpaperPath;

            // Get file size and resolution using stat and file/identify
            var metaProcess = Qt.createQmlObject(`
              import QtQuick
              import Quickshell.Io
              Process {
                property string filePath: ""
                command: ["sh", "-c", "stat -c '%s' '" + filePath + "' 2>/dev/null && (file '" + filePath + "' | grep -oP '\\\\d+\\\\s*x\\\\s*\\\\d+' | head -1 || identify -format '%wx%h' '" + filePath + "' 2>/dev/null || echo '')"]
                stdout: StdioCollector {}
              }
            `, wallpaperItem, "MetadataProcess");

            metaProcess.filePath = path;
            metaProcess.exited.connect(function(exitCode) {
              if (exitCode === 0 && itemRef) {
                var lines = metaProcess.stdout.text.trim().split('\\n');
                if (lines.length >= 1) {
                  // Parse file size (first line)
                  var sizeBytes = parseInt(lines[0]);
                  if (!isNaN(sizeBytes)) {
                    itemRef.fileSize = formatFileSize(sizeBytes);
                  }
                }
                if (lines.length >= 2 && lines[1]) {
                  // Parse resolution (second line)
                  itemRef.resolution = lines[1].replace(/\\s+/g, '');
                }
                itemRef.metadataLoaded = true;
              }
              metaProcess.destroy();
            });
            metaProcess.running = true;
          }

          function formatFileSize(bytes) {
            if (bytes < 1024) return bytes + " B";
            if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
            if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB";
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
          }
          
          function loadThumbnail() {
            var itemRef = wallpaperItem
            VideoWallpaperService.generateThumbnail(wallpaperPath, function(path) {
              // Check if delegate still exists (wasn't recycled)
              if (path && itemRef && itemRef.wallpaperPath) {
                itemRef.thumbnailPath = "file://" + path
                itemRef.thumbnailReady = true
              }
            }, "preview")
          }
          
          Timer {
            id: thumbnailRetryTimer
            interval: 500
            onTriggered: {
              if (wallpaperItem && wallpaperItem.isVideo && VideoWallpaperService.isInitialized) {
                wallpaperItem.loadThumbnail()
              }
            }
          }

          Rectangle {
            id: imageContainer
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(wallpaperGridView.itemSize * 0.6)
            color: Color.mSurface

            // Image preview (for images)
            NImageCached {
              id: img
              imagePath: wallpaperItem.isVideo ? "" : wallpaperPath
              cacheFolder: Settings.cacheDirImagesWallpapers
              anchors.fill: parent
              visible: !wallpaperItem.isVideo
            }

            // Video thumbnail
            Image {
              id: videoThumbnail
              source: wallpaperItem.thumbnailPath
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              visible: wallpaperItem.isVideo && wallpaperItem.thumbnailReady
              asynchronous: true
            }

            // Video placeholder while thumbnail generates
            Rectangle {
              anchors.fill: parent
              color: Color.mSurfaceVariant
              visible: wallpaperItem.isVideo && !wallpaperItem.thumbnailReady

              NIcon {
                anchors.centerIn: parent
                icon: "movie"
                pointSize: 32
                color: Color.mOnSurfaceVariant
              }
            }

            Rectangle {
              anchors.fill: parent
              color: Color.transparent
              border.color: {
                if (isSelected) {
                  return Color.mSecondary;
                }
                if (wallpaperGridView.currentIndex === index) {
                  return Color.mHover;
                }
                return Color.mSurface;
              }
              border.width: Math.max(1, Style.borderL * 1.5)
            }

            Rectangle {
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: Style.marginS
              width: 28
              height: 28
              radius: width / 2
              color: Color.mSecondary
              border.color: Color.mOutline
              border.width: Style.borderS
              visible: isSelected

              NIcon {
                icon: "check"
                pointSize: Style.fontSizeM
                color: Color.mOnSecondary
                anchors.centerIn: parent
              }
            }

            Rectangle {
              anchors.fill: parent
              color: Color.mSurface
              opacity: (hoverHandler.hovered || isSelected || wallpaperGridView.currentIndex === index) ? 0 : 0.3
              radius: parent.radius
              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                }
              }
            }

            // Video play icon badge (small, in corner)
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.margins: Style.marginS
              width: 24
              height: 24
              radius: 4
              color: Color.mSurface
              opacity: 0.85
              visible: wallpaperItem.isVideo

              NIcon {
                anchors.centerIn: parent
                icon: "player-play"
                pointSize: 14
                color: Color.mOnSurface
              }
            }

            // Upscaled badge (top-left corner)
            Rectangle {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.margins: Style.marginS
              height: 18
              width: upscaledLabel.implicitWidth + Style.marginS * 2
              radius: 4
              color: Color.mPrimary
              visible: wallpaperItem.isUpscaled

              NText {
                id: upscaledLabel
                anchors.centerIn: parent
                text: "AI"
                pointSize: Style.fontSizeXXS
                font.weight: Style.fontWeightBold
                color: Color.mOnPrimary
              }
            }

            // Metadata overlay (shows on hover)
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: metadataColumn.implicitHeight + Style.marginS * 2
              color: Qt.rgba(0, 0, 0, 0.7)
              visible: hoverHandler.hovered && wallpaperItem.metadataLoaded
              opacity: hoverHandler.hovered ? 1 : 0

              Behavior on opacity {
                NumberAnimation { duration: Style.animationFast }
              }

              Column {
                id: metadataColumn
                anchors.fill: parent
                anchors.margins: Style.marginS
                spacing: 2

                NText {
                  text: wallpaperItem.resolution || ""
                  pointSize: Style.fontSizeXXS
                  color: "white"
                  visible: wallpaperItem.resolution !== ""
                }

                NText {
                  text: wallpaperItem.fileSize || ""
                  pointSize: Style.fontSizeXXS
                  color: Qt.rgba(1, 1, 1, 0.8)
                  visible: wallpaperItem.fileSize !== ""
                }
              }
            }

            // More efficient hover handling
            HoverHandler {
              id: hoverHandler
            }

            TapHandler {
              onTapped: {
                wallpaperGridView.forceActiveFocus();
                wallpaperGridView.currentIndex = index;
                if (Settings.data.wallpaper.setWallpaperOnAllMonitors) {
                  WallpaperService.changeWallpaper(wallpaperPath, undefined);
                } else {
                  WallpaperService.changeWallpaper(wallpaperPath, targetScreen.name);
                }
              }
            }

            // Right-click for context menu
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.RightButton
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                  wallpaperContextMenu.wallpaperToDelete = wallpaperPath
                  wallpaperContextMenu.popup()
                }
              }
            }
          }

          NText {
            text: filename
            visible: !Settings.data.wallpaper.hideWallpaperFilenames
            color: (hoverHandler.hovered || isSelected || wallpaperGridView.currentIndex === index) ? Color.mOnSurface : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            Layout.fillWidth: true
            Layout.leftMargin: Style.marginS
            Layout.rightMargin: Style.marginS
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }

      // Empty / scanning state
      Rectangle {
        color: Color.mSurface
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: Style.borderS
        visible: (filteredWallpapers.length === 0 && !WallpaperService.scanning) || WallpaperService.scanning
        Layout.fillWidth: true
        Layout.preferredHeight: 130

        ColumnLayout {
          anchors.fill: parent
          visible: WallpaperService.scanning
          NBusyIndicator {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          }
        }

        ColumnLayout {
          anchors.fill: parent
          visible: filteredWallpapers.length === 0 && !WallpaperService.scanning
          Item {
            Layout.fillHeight: true
          }
          NIcon {
            icon: "folder-open"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (wallpaperPanel.filterText && wallpaperPanel.filterText.length > 0) ? I18n.tr("wallpaper.no-match") : I18n.tr("wallpaper.no-wallpaper")
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (wallpaperPanel.filterText && wallpaperPanel.filterText.length > 0) ? I18n.tr("wallpaper.try-different-search") : I18n.tr("wallpaper.configure-directory")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.alignment: Qt.AlignHCenter
          }
          Item {
            Layout.fillHeight: true
          }
        }
      }
    }
  }

  // Component for Wallhaven wallpapers view
  component WallhavenView: Item {
    id: wallhavenViewRoot
    property alias gridView: wallhavenGridView

    property var wallpapers: []
    property bool loading: false
    property string errorMessage: ""
    property bool initialized: false
    property bool searchScheduled: false

    Connections {
      target: typeof WallhavenService !== "undefined" ? WallhavenService : null
      function onSearchCompleted(results, meta) {
        wallhavenViewRoot.wallpapers = results || [];
        wallhavenViewRoot.loading = false;
        wallhavenViewRoot.errorMessage = "";
        wallhavenViewRoot.searchScheduled = false;
      }
      function onSearchFailed(error) {
        wallhavenViewRoot.loading = false;
        wallhavenViewRoot.errorMessage = error || "";
        wallhavenViewRoot.searchScheduled = false;
      }
    }

    Component.onCompleted: {
      // Initialize service properties and perform initial search if Wallhaven is active
      if (typeof WallhavenService !== "undefined" && Settings.data.wallpaper.useWallhaven && !initialized) {
        // Set flags immediately to prevent race conditions
        if (WallhavenService.initialSearchScheduled) {
          // Another instance already scheduled the search, just initialize properties
          initialized = true;
          return;
        }

        // We're the first one - claim the search
        initialized = true;
        WallhavenService.initialSearchScheduled = true;
        WallhavenService.categories = Settings.data.wallpaper.wallhavenCategories;
        WallhavenService.purity = Settings.data.wallpaper.wallhavenPurity;
        WallhavenService.sorting = Settings.data.wallpaper.wallhavenSorting;
        WallhavenService.order = Settings.data.wallpaper.wallhavenOrder;

        // Initialize resolution settings
        var width = Settings.data.wallpaper.wallhavenResolutionWidth || "";
        var height = Settings.data.wallpaper.wallhavenResolutionHeight || "";
        var mode = Settings.data.wallpaper.wallhavenResolutionMode || "atleast";
        if (width && height) {
          var resolution = width + "x" + height;
          if (mode === "atleast") {
            WallhavenService.minResolution = resolution;
            WallhavenService.resolutions = "";
          } else {
            WallhavenService.minResolution = "";
            WallhavenService.resolutions = resolution;
          }
        } else {
          WallhavenService.minResolution = "";
          WallhavenService.resolutions = "";
        }

        // Now check if we can actually search (fetching check is in WallhavenService.search)
        loading = true;
        WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        GridView {
          id: wallhavenGridView

          anchors.fill: parent

          visible: !loading && errorMessage === "" && (wallpapers && wallpapers.length > 0)
          interactive: true
          clip: true
          focus: true
          keyNavigationEnabled: true
          keyNavigationWraps: false

          model: wallpapers || []

          property int columns: 4
          property int itemSize: cellWidth

          cellWidth: Math.floor((width - leftMargin - rightMargin) / columns)
          cellHeight: Math.floor(itemSize * 0.63) + Style.marginXS + (Settings.data.wallpaper.hideWallpaperFilenames ? 0 : Style.fontSizeXS + Style.marginM)

          leftMargin: Style.marginS
          rightMargin: Style.marginS
          topMargin: Style.marginS
          bottomMargin: Style.marginS

          onCurrentIndexChanged: {
            if (currentIndex >= 0) {
              let row = Math.floor(currentIndex / columns);
              let itemY = row * cellHeight;
              let viewportTop = contentY;
              let viewportBottom = viewportTop + height;

              if (itemY < viewportTop) {
                contentY = Math.max(0, itemY - cellHeight);
              } else if (itemY + cellHeight > viewportBottom) {
                contentY = itemY + cellHeight - height + cellHeight;
              }
            }
          }

          Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                              if (currentIndex >= 0 && currentIndex < wallpapers.length) {
                                let wallpaper = wallpapers[currentIndex];
                                wallhavenDownloadAndApply(wallpaper);
                              }
                              event.accepted = true;
                            }
                          }

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            parent: wallhavenGridView
            x: wallhavenGridView.mirrored ? 0 : wallhavenGridView.width - width
            y: 0
            height: wallhavenGridView.height

            property color handleColor: Qt.alpha(Color.mHover, 0.8)
            property color handleHoverColor: handleColor
            property color handlePressedColor: handleColor
            property real handleWidth: 6
            property real handleRadius: Style.radiusM

            contentItem: Rectangle {
              implicitWidth: parent.handleWidth
              implicitHeight: 100
              radius: parent.handleRadius
              color: parent.pressed ? parent.handlePressedColor : parent.hovered ? parent.handleHoverColor : parent.handleColor
              opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 1.0 : 0.0

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                }
              }

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                }
              }
            }

            background: Rectangle {
              implicitWidth: parent.handleWidth
              implicitHeight: 100
              color: Color.transparent
              opacity: parent.policy === ScrollBar.AlwaysOn || parent.active ? 0.3 : 0.0
              radius: parent.handleRadius / 2

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                }
              }
            }
          }

          delegate: ColumnLayout {
            id: wallhavenItem

            required property var modelData
            required property int index
            property string thumbnailUrl: (modelData && typeof WallhavenService !== "undefined") ? WallhavenService.getThumbnailUrl(modelData, "large") : ""
            property string wallpaperId: (modelData && modelData.id) ? modelData.id : ""

            width: wallhavenGridView.itemSize
            spacing: Style.marginXS

            Rectangle {
              id: imageContainer
              Layout.fillWidth: true
              Layout.preferredHeight: Math.round(wallhavenGridView.itemSize * 0.6)
              color: Color.transparent

              Image {
                id: img
                source: thumbnailUrl
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: Math.round(wallhavenGridView.itemSize * 0.6)
                sourceSize.height: Math.round(wallhavenGridView.itemSize * 0.6)
              }

              Rectangle {
                anchors.fill: parent
                color: Color.transparent
                border.color: wallhavenGridView.currentIndex === index ? Color.mHover : Color.mSurface
                border.width: Math.max(1, Style.borderL * 1.5)
              }

              Rectangle {
                anchors.fill: parent
                color: Color.mSurface
                opacity: hoverHandler.hovered || wallhavenGridView.currentIndex === index ? 0 : 0.3
                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              HoverHandler {
                id: hoverHandler
              }

              TapHandler {
                onTapped: {
                  wallhavenGridView.currentIndex = index;
                  wallhavenDownloadAndApply(modelData);
                }
              }
            }

            NText {
              text: wallpaperId || I18n.tr("wallpaper.unknown")
              visible: !Settings.data.wallpaper.hideWallpaperFilenames
              color: hoverHandler.hovered || wallhavenGridView.currentIndex === index ? Color.mOnSurface : Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              Layout.fillWidth: true
              Layout.leftMargin: Style.marginS
              Layout.rightMargin: Style.marginS
              Layout.alignment: Qt.AlignHCenter
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
          }
        }

        // Loading overlay - fills same space as GridView to prevent jumping
        Rectangle {
          anchors.fill: parent
          color: Color.mSurface
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          visible: loading
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NBusyIndicator {
              size: Style.baseWidgetSize * 1.5
              color: Color.mPrimary
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: I18n.tr("wallpaper.wallhaven.loading")
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeM
              Layout.alignment: Qt.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }

        // Error overlay
        Rectangle {
          anchors.fill: parent
          color: Color.mSurface
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          visible: errorMessage !== "" && !loading
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "alert-circle"
              pointSize: Style.fontSizeXXL
              color: Color.mError
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: errorMessage
              color: Color.mOnSurface
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }

        // Empty state overlay
        Rectangle {
          anchors.fill: parent
          color: Color.mSurface
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          visible: (!wallpapers || wallpapers.length === 0) && !loading && errorMessage === ""
          z: 10

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "image"
              pointSize: Style.fontSizeXXL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: I18n.tr("wallpaper.wallhaven.no-results")
              color: Color.mOnSurface
              wrapMode: Text.WordWrap
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      // Pagination
      RowLayout {
        Layout.fillWidth: true
        visible: !loading && errorMessage === "" && typeof WallhavenService !== "undefined"
        spacing: Style.marginS

        Item {
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "chevron-left"
          enabled: WallhavenService.currentPage > 1 && !WallhavenService.fetching
          onClicked: WallhavenService.previousPage()
        }

        NText {
          text: I18n.tr("wallpaper.wallhaven.page").replace("{current}", WallhavenService.currentPage).replace("{total}", WallhavenService.lastPage)
          color: Color.mOnSurface
          horizontalAlignment: Text.AlignHCenter
        }

        NIconButton {
          icon: "chevron-right"
          enabled: WallhavenService.currentPage < WallhavenService.lastPage && !WallhavenService.fetching
          onClicked: WallhavenService.nextPage()
        }

        Item {
          Layout.fillWidth: true
        }
      }
    }

    // -------------------------------
    function wallhavenDownloadAndApply(wallpaper, targetScreen) {
      if (typeof WallhavenService !== "undefined") {
        WallhavenService.downloadWallpaper(wallpaper, function (success, localPath) {
          if (success) {
            if (!Settings.data.wallpaper.setWallpaperOnAllMonitors && currentScreenIndex < Quickshell.screens.length) {
              WallpaperService.changeWallpaper(localPath, Quickshell.screens[currentScreenIndex].name);
            } else {
              WallpaperService.changeWallpaper(localPath, undefined);
            }
          }
        });
      }
    }
  }
}


