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
        // Trigger random discovery when opening in Wallhaven mode (with delay to ensure service is ready)
        if (Settings.data.wallpaper.useWallhaven) {
          wallhavenDiscoverTimer.start();
        }
      }
    }

    // Timer to trigger Wallhaven discovery after a short delay
    Timer {
      id: wallhavenDiscoverTimer
      interval: 150
      repeat: false
      onTriggered: {
        if (typeof WallhavenService !== "undefined" && !WallhavenService.fetching && wallhavenView) {
          wallhavenView.initialized = true;
          wallhavenView.loading = true;
          WallhavenService.discover();
        }
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

              // Update search box when discover generates a random query
              Connections {
                target: typeof WallhavenService !== "undefined" ? WallhavenService : null
                function onDiscoveryQueryGenerated(query) {
                  searchInput.initializing = true;
                  searchInput.text = query;
                  Settings.data.wallpaper.wallhavenQuery = query;
                  Qt.callLater(function() {
                    searchInput.initializing = false;
                  });
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

            // Source switcher tabs
            RowLayout {
              spacing: 0

              NButton {
                text: I18n.tr("wallpaper.panel.source.local")
                icon: "folder"
                backgroundColor: !Settings.data.wallpaper.useWallhaven ? Color.mPrimary : Color.mSurfaceVariant
                textColor: !Settings.data.wallpaper.useWallhaven ? Color.mOnPrimary : Color.mOnSurfaceVariant
                onClicked: {
                  if (Settings.data.wallpaper.useWallhaven) {
                    Settings.data.wallpaper.useWallhaven = false;
                    searchInput.text = wallpaperPanel.filterText || "";
                  }
                }
              }

              NButton {
                text: I18n.tr("wallpaper.panel.source.wallhaven")
                icon: "world"
                backgroundColor: Settings.data.wallpaper.useWallhaven ? Color.mPrimary : Color.mSurfaceVariant
                textColor: Settings.data.wallpaper.useWallhaven ? Color.mOnPrimary : Color.mOnSurfaceVariant
                onClicked: {
                  if (!Settings.data.wallpaper.useWallhaven) {
                    Settings.data.wallpaper.useWallhaven = true;
                    searchInput.text = Settings.data.wallpaper.wallhavenQuery || "";
                    if (typeof WallhavenService !== "undefined") {
                      WallhavenService.categories = Settings.data.wallpaper.wallhavenCategories;
                      WallhavenService.purity = Settings.data.wallpaper.wallhavenPurity;
                      WallhavenService.order = Settings.data.wallpaper.wallhavenOrder;
                      wallpaperPanel.updateWallhavenResolution();
                      // Always trigger a discover when switching to Wallhaven mode
                      if (wallhavenView && !WallhavenService.fetching) {
                        wallhavenView.initialized = true;
                        wallhavenView.loading = true;
                        WallhavenService.discover();
                      }
                    }
                  }
                }
              }
            }
          }

          // Wallhaven controls row (only visible for Wallhaven)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: Settings.data.wallpaper.useWallhaven

            // Discover button - random wallpaper discovery
            NIconButton {
              icon: "dice-5"
              tooltipText: I18n.tr("tooltips.discover-wallpapers")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                if (typeof WallhavenService !== "undefined") {
                  wallhavenView.loading = true;
                  WallhavenService.discover();
                }
              }
            }

            // Anime discover button - random anime wallpaper discovery
            NIconButton {
              icon: "cherry-filled"
              tooltipText: I18n.tr("tooltips.discover-anime")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                if (typeof WallhavenService !== "undefined") {
                  wallhavenView.loading = true;
                  WallhavenService.discoverAnime();
                }
              }
            }

            // Settings button
            NIconButton {
              id: wallhavenSettingsButton
              icon: "settings"
              tooltipText: I18n.tr("wallpaper.panel.wallhaven-settings.title")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                if (searchInput.inputItem) {
                  searchInput.inputItem.focus = false;
                }
                if (wallhavenSettingsPopup.item) {
                  wallhavenSettingsPopup.item.showAt(wallhavenSettingsButton);
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Wallhaven sort dropdown
            NComboBox {
              id: wallhavenSortComboBox
              Layout.preferredWidth: 140
              model: WallpaperService.wallhavenSortModel
              currentKey: Settings.data.wallpaper.wallhavenSortPreset || "random"
              onSelected: key => {
                if (Settings.data.wallpaper.wallhavenSortPreset === key) return;
                Settings.data.wallpaper.wallhavenSortPreset = key;
                // Apply the sort preset and trigger search
                if (typeof WallhavenService !== "undefined") {
                  for (var i = 0; i < WallpaperService.wallhavenSortModel.count; i++) {
                    var preset = WallpaperService.wallhavenSortModel.get(i);
                    if (preset.key === key) {
                      WallhavenService.sorting = preset.sorting;
                      if (preset.topRange) {
                        WallhavenService.topRange = preset.topRange;
                      }
                      break;
                    }
                  }
                  wallhavenView.loading = true;
                  WallhavenService.search(Settings.data.wallpaper.wallhavenQuery || "", 1);
                }
              }
            }

            NComboBox {
              id: wallhavenFillModeComboBox
              Layout.preferredWidth: 80
              model: WallpaperService.fillModeModel
              currentKey: Settings.data.wallpaper.fillMode || "crop"
              onSelected: key => {
                if (Settings.data.wallpaper.fillMode === key) return;
                Settings.data.wallpaper.fillMode = key;
                WallpaperService.reapplyCurrentWallpapers();
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

            NComboBox {
              id: localSortComboBox
              Layout.preferredWidth: 120
              model: WallpaperService.localSortModel
              currentKey: Settings.data.wallpaper.localSort || "date-desc"
              onSelected: key => {
                if (Settings.data.wallpaper.localSort === key) return;
                Settings.data.wallpaper.localSort = key;
                // Trigger re-sort of wallpapers (need full refresh to get proper base order)
                for (var i = 0; i < screenRepeater.count; i++) {
                  let item = screenRepeater.itemAt(i)
                  if (item && item.refreshWallpaperScreenData) item.refreshWallpaperScreenData()
                }
              }
            }

            NComboBox {
              id: fillModeComboBox
              Layout.preferredWidth: 80
              model: WallpaperService.fillModeModel
              currentKey: Settings.data.wallpaper.fillMode || "crop"
              onSelected: key => {
                if (Settings.data.wallpaper.fillMode === key) return;
                Settings.data.wallpaper.fillMode = key;
                // Re-apply current wallpaper with new fill mode
                WallpaperService.reapplyCurrentWallpapers();
              }
            }
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
      var baseList = wallpapersList.slice(); // Clone the array

      // Apply media type filter
      if (wallpaperPanel.mediaFilter === "images") {
        baseList = baseList.filter(function(p) {
          return !VideoWallpaperService.isVideoFile(p);
        });
      } else if (wallpaperPanel.mediaFilter === "videos") {
        baseList = baseList.filter(function(p) {
          return VideoWallpaperService.isVideoFile(p);
        });
      }

      // Apply sorting based on combined key (e.g., "date-desc", "name-asc")
      var sortKey = Settings.data.wallpaper.localSort || "date-desc";

      if (sortKey === "name-asc") {
        baseList.sort(function(a, b) {
          var nameA = a.split('/').pop().toLowerCase();
          var nameB = b.split('/').pop().toLowerCase();
          return nameA.localeCompare(nameB);
        });
      } else if (sortKey === "name-desc") {
        baseList.sort(function(a, b) {
          var nameA = a.split('/').pop().toLowerCase();
          var nameB = b.split('/').pop().toLowerCase();
          return nameB.localeCompare(nameA);
        });
      } else if (sortKey === "date-desc") {
        // Base list is oldest first, reverse to get newest first
        baseList.reverse();
      }
      // "date-asc" - keep original order (oldest first)

      // Ensure current wallpaper stays at front after sorting
      if (currentWallpaper) {
        var currentIdx = baseList.indexOf(currentWallpaper);
        if (currentIdx > 0) {
          baseList.splice(currentIdx, 1);
          baseList.unshift(currentWallpaper);
        }
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
          currentWallpaper = path;
          // Move the new wallpaper to the front of the list dynamically
          moveWallpaperToFront(path);
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

    // Move a wallpaper to the front of the list without full refresh
    function moveWallpaperToFront(path) {
      if (!path) {
        Logger.w("WallpaperPanel", "moveWallpaperToFront: no path provided");
        return;
      }

      var idx = wallpapersList.indexOf(path);
      Logger.d("WallpaperPanel", "moveWallpaperToFront: path=", path.split('/').pop(), "idx=", idx, "listSize=", wallpapersList.length);

      if (idx > 0) {
        // Remove from current position and add to front
        var newList = wallpapersList.slice();
        newList.splice(idx, 1);
        newList.unshift(path);
        wallpapersList = newList;

        // Update the cached names list too
        wallpapersWithNames = wallpapersList.map(function (p) {
          return { "path": p, "name": p.split('/').pop() };
        });

        // Update filtered list
        updateFiltered();

        Logger.d("WallpaperPanel", "Moved wallpaper to front:", path.split('/').pop());
      } else if (idx === 0) {
        Logger.d("WallpaperPanel", "Wallpaper already at front:", path.split('/').pop());
      } else {
        Logger.w("WallpaperPanel", "Wallpaper not found in list:", path.split('/').pop());
      }
    }

    function refreshWallpaperScreenData() {
      if (targetScreen === null) {
        return;
      }
      var rawList = WallpaperService.getWallpapersList(targetScreen.name);
      Logger.d("WallpaperPanel", "Got", rawList.length, "wallpapers for screen", targetScreen.name);

      // Check current sort mode
      var sortKey = Settings.data.wallpaper.localSort || "date-desc";
      var isDateSort = sortKey.startsWith("date-");

      var combined;

      if (isDateSort) {
        // For date sorting, preserve the FolderListModel order (already sorted by time)
        // Don't separate videos/images to maintain proper time order
        combined = rawList.slice();
      } else {
        // For name sorting, separate videos and images, sort each alphabetically
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
        combined = videos.concat(images);
        Logger.d("WallpaperPanel", "Name sorted:", videos.length, "videos,", images.length, "images");
      }

      // Move current wallpaper to the front
      var current = WallpaperService.getWallpaper(targetScreen.name);
      if (current) {
        var currentIndex = combined.indexOf(current);
        if (currentIndex > 0) {
          combined.splice(currentIndex, 1);
          combined.unshift(current);
        }
      }

      wallpapersList = combined;

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

    // Styled context menu for wallpaper items
    Menu {
      id: wallpaperContextMenu
      property string wallpaperToDelete: ""

      // Style the menu background
      background: Rectangle {
        implicitWidth: 220
        color: Color.mSurface
        radius: Style.radiusS
        border.color: Color.mOutline
        border.width: Style.borderS
      }

      // Delete item
      MenuItem {
        id: deleteItem
        text: I18n.tr("wallpaper.panel.context.delete")
        icon.name: "user-trash-symbolic"
        icon.color: deleteItemArea.containsMouse ? Color.mOnHover : Color.mOnSurface

        background: Rectangle {
          color: deleteItemArea.containsMouse ? Color.mHover : Color.transparent
          radius: Style.radiusXS
        }

        contentItem: RowLayout {
          spacing: Style.marginS
          NIcon {
            icon: "trash"
            pointSize: Style.fontSizeM
            color: deleteItemArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          }
          NText {
            text: deleteItem.text
            pointSize: Style.fontSizeS
            color: deleteItemArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: deleteItemArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (wallpaperContextMenu.wallpaperToDelete) {
              deleteWallpaper(wallpaperContextMenu.wallpaperToDelete);
            }
            wallpaperContextMenu.close();
          }
        }
      }

      // Open folder item
      MenuItem {
        id: openFolderItem
        text: I18n.tr("wallpaper.panel.context.open-folder")

        background: Rectangle {
          color: openFolderArea.containsMouse ? Color.mHover : Color.transparent
          radius: Style.radiusXS
        }

        contentItem: RowLayout {
          spacing: Style.marginS
          NIcon {
            icon: "folder-open"
            pointSize: Style.fontSizeM
            color: openFolderArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          }
          NText {
            text: openFolderItem.text
            pointSize: Style.fontSizeS
            color: openFolderArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: openFolderArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (wallpaperContextMenu.wallpaperToDelete) {
              var folder = wallpaperContextMenu.wallpaperToDelete.substring(0, wallpaperContextMenu.wallpaperToDelete.lastIndexOf('/'));
              Qt.openUrlExternally("file://" + folder);
            }
            wallpaperContextMenu.close();
          }
        }
      }

      // Upscale item (for images)
      MenuItem {
        id: upscaleItem
        property bool isImage: {
          var path = wallpaperContextMenu.wallpaperToDelete;
          if (!path) return false;
          var ext = path.split('.').pop().toLowerCase();
          var imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "pnm"];
          return imageExtensions.indexOf(ext) !== -1;
        }
        property bool shouldShow: ProgramCheckerService.realesrganAvailable && isImage
        visible: shouldShow
        height: shouldShow ? implicitHeight : 0
        text: WallpaperService.isUpscaling ? I18n.tr("wallpaper.panel.context.upscaling") : I18n.tr("wallpaper.panel.context.upscale")
        enabled: !WallpaperService.isUpscaling && !WallpaperService.isUpscalingVideo && isImage

        background: Rectangle {
          color: upscaleArea.containsMouse && upscaleItem.enabled ? Color.mHover : Color.transparent
          radius: Style.radiusXS
        }

        contentItem: RowLayout {
          spacing: Style.marginS
          opacity: upscaleItem.enabled ? 1.0 : 0.5
          NIcon {
            icon: "photo-up"
            pointSize: Style.fontSizeM
            color: upscaleArea.containsMouse && upscaleItem.enabled ? Color.mOnHover : Color.mOnSurface
          }
          NText {
            text: upscaleItem.text
            pointSize: Style.fontSizeS
            color: upscaleArea.containsMouse && upscaleItem.enabled ? Color.mOnHover : Color.mOnSurface
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: upscaleArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: upscaleItem.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (upscaleItem.enabled && wallpaperContextMenu.wallpaperToDelete) {
              WallpaperService.upscaleWallpaper(wallpaperContextMenu.wallpaperToDelete);
            }
            wallpaperContextMenu.close();
          }
        }
      }

      // Upscale video item
      MenuItem {
        id: upscaleVideoItem
        property bool isVideo: {
          var path = wallpaperContextMenu.wallpaperToDelete;
          if (!path) return false;
          var ext = path.split('.').pop().toLowerCase();
          var videoExtensions = ["mp4", "webm", "mkv", "avi", "mov", "ogv", "m4v"];
          return videoExtensions.indexOf(ext) !== -1;
        }
        property bool shouldShow: ProgramCheckerService.realesrganAvailable && isVideo
        visible: shouldShow
        height: shouldShow ? implicitHeight : 0
        text: WallpaperService.isUpscalingVideo ? I18n.tr("wallpaper.panel.context.upscaling-video") : I18n.tr("wallpaper.panel.context.upscale-video")
        enabled: !WallpaperService.isUpscaling && !WallpaperService.isUpscalingVideo && isVideo

        background: Rectangle {
          color: upscaleVideoArea.containsMouse && upscaleVideoItem.enabled ? Color.mHover : Color.transparent
          radius: Style.radiusXS
        }

        contentItem: RowLayout {
          spacing: Style.marginS
          opacity: upscaleVideoItem.enabled ? 1.0 : 0.5
          NIcon {
            icon: "movie"
            pointSize: Style.fontSizeM
            color: upscaleVideoArea.containsMouse && upscaleVideoItem.enabled ? Color.mOnHover : Color.mOnSurface
          }
          NText {
            text: upscaleVideoItem.text
            pointSize: Style.fontSizeS
            color: upscaleVideoArea.containsMouse && upscaleVideoItem.enabled ? Color.mOnHover : Color.mOnSurface
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: upscaleVideoArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: upscaleVideoItem.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (upscaleVideoItem.enabled && wallpaperContextMenu.wallpaperToDelete) {
              WallpaperService.upscaleVideo(wallpaperContextMenu.wallpaperToDelete);
            }
            wallpaperContextMenu.close();
          }
        }
      }

      // Clear cache item
      MenuItem {
        id: clearCacheItem
        text: "Clear Cache"

        background: Rectangle {
          color: clearCacheArea.containsMouse ? Color.mHover : Color.transparent
          radius: Style.radiusXS
        }

        contentItem: RowLayout {
          spacing: Style.marginS
          NIcon {
            icon: "refresh"
            pointSize: Style.fontSizeM
            color: clearCacheArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          }
          NText {
            text: clearCacheItem.text
            pointSize: Style.fontSizeS
            color: clearCacheArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            Layout.fillWidth: true
          }
        }

        MouseArea {
          id: clearCacheArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (wallpaperContextMenu.wallpaperToDelete) {
              WallpaperService.clearCacheForPath(wallpaperContextMenu.wallpaperToDelete);
            }
            wallpaperContextMenu.close();
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
          property bool metadataLoading: false

          width: wallpaperGridView.itemSize
          spacing: Style.marginXS

          // Load metadata when item is created
          Component.onCompleted: {
            if (isVideo && VideoWallpaperService.isInitialized) {
              loadThumbnail()
            } else if (isVideo) {
              thumbnailRetryTimer.start()
            }
          }

          // Load metadata lazily on hover
          function loadMetadataIfNeeded() {
            if (metadataLoaded || metadataLoading) return;
            metadataLoading = true;

            var itemRef = wallpaperItem;
            var path = wallpaperPath;
            var isVid = isVideo;

            // Combined command to get both size and resolution
            var cmd = isVid
              ? "stat -c '%s' '" + path + "' && ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 '" + path + "' 2>/dev/null | tr ',' 'x'"
              : "stat -c '%s' '" + path + "' && identify -format '%wx%h' '" + path + "' 2>/dev/null";

            var metaProcess = Qt.createQmlObject(`
              import QtQuick
              import Quickshell.Io
              Process {
                command: ["sh", "-c", "` + cmd.replace(/"/g, '\\"') + `"]
                stdout: StdioCollector {}
              }
            `, wallpaperItem, "MetaProcess");

            metaProcess.exited.connect(function(exitCode) {
              if (itemRef) {
                var lines = metaProcess.stdout.text.trim().split('\n');
                if (lines.length >= 1) {
                  var sizeBytes = parseInt(lines[0]);
                  if (!isNaN(sizeBytes)) {
                    if (sizeBytes < 1024) itemRef.fileSize = sizeBytes + " B";
                    else if (sizeBytes < 1024 * 1024) itemRef.fileSize = (sizeBytes / 1024).toFixed(1) + " KB";
                    else if (sizeBytes < 1024 * 1024 * 1024) itemRef.fileSize = (sizeBytes / (1024 * 1024)).toFixed(1) + " MB";
                    else itemRef.fileSize = (sizeBytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
                  }
                }
                if (lines.length >= 2 && lines[1]) {
                  itemRef.resolution = lines[1].trim();
                }
                itemRef.metadataLoaded = true;
                itemRef.metadataLoading = false;
              }
              metaProcess.destroy();
            });
            metaProcess.running = true;
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

            // Video upscale progress overlay
            Rectangle {
              id: upscaleProgressOverlay
              anchors.fill: parent
              color: Qt.rgba(0, 0, 0, 0.75)
              radius: parent.radius
              visible: WallpaperService.isUpscalingVideo && WallpaperService.upscalingFile === wallpaperPath

              Column {
                anchors.centerIn: parent
                spacing: Style.marginS
                width: parent.width - Style.marginM * 2

                NText {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: {
                    var stage = WallpaperService.videoUpscaleStage;
                    switch (stage) {
                      case "analyzing": return I18n.tr("wallpaper.upscale.stage.analyzing") || "Analyzing...";
                      case "extracting": return I18n.tr("wallpaper.upscale.stage.extracting") || "Extracting...";
                      case "upscaling": return I18n.tr("wallpaper.upscale.stage.upscaling") || "Upscaling...";
                      case "encoding": return I18n.tr("wallpaper.upscale.stage.encoding") || "Encoding...";
                      default: return I18n.tr("wallpaper.upscale.stage.processing") || "Processing...";
                    }
                  }
                  color: Color.mOnSurface
                  pointSize: Style.fontSizeXS
                  font.weight: Style.fontWeightBold
                }

                // Progress bar background
                Rectangle {
                  width: parent.width
                  height: 6
                  radius: 3
                  color: Color.mSurfaceVariant

                  // Progress bar fill
                  Rectangle {
                    width: parent.width * WallpaperService.videoUpscaleProgress
                    height: parent.height
                    radius: parent.radius
                    color: Color.mPrimary

                    Behavior on width {
                      NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }
                  }
                }

                NText {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Math.round(WallpaperService.videoUpscaleProgress * 100) + "%"
                  color: Color.mOnSurfaceVariant
                  pointSize: Style.fontSizeXS
                }
              }
            }

            // More efficient hover handling
            HoverHandler {
              id: hoverHandler
              onHoveredChanged: {
                if (hovered) {
                  wallpaperItem.loadMetadataIfNeeded();
                }
              }
            }

            TapHandler {
              acceptedButtons: Qt.LeftButton
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
            TapHandler {
              acceptedButtons: Qt.RightButton
              onTapped: {
                wallpaperContextMenu.wallpaperToDelete = wallpaperPath;
                wallpaperContextMenu.popup();
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

    // Delayed initialization timer for Wallhaven
    Timer {
      id: wallhavenInitTimer
      interval: 100
      repeat: false
      onTriggered: {
        if (typeof WallhavenService !== "undefined" && Settings.data.wallpaper.useWallhaven && !wallhavenViewRoot.initialized) {
          wallhavenViewRoot.initialized = true;
          WallhavenService.categories = Settings.data.wallpaper.wallhavenCategories;
          WallhavenService.purity = Settings.data.wallpaper.wallhavenPurity;
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

          // Start with random discovery for fresh experience each time
          wallhavenViewRoot.loading = true;
          WallhavenService.discover();
        }
      }
    }

    Component.onCompleted: {
      // Use timer to ensure all services are loaded
      if (Settings.data.wallpaper.useWallhaven) {
        wallhavenInitTimer.start();
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


