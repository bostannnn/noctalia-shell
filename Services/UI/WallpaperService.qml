pragma Singleton
import Qt.labs.folderlistmodel

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System

Singleton {
  id: root

  readonly property ListModel fillModeModel: ListModel {}
  readonly property string defaultDirectory: Settings.preprocessPath(Settings.data.wallpaper.directory)

  // Local wallpaper sort options (combined field + order)
  readonly property ListModel localSortModel: ListModel {}

  // Wallhaven sort/filter presets (trending, popular, etc.)
  readonly property ListModel wallhavenSortModel: ListModel {}

  // All available wallpaper transitions
  readonly property ListModel transitionsModel: ListModel {}

  // All transition keys but filter out "none" and "random" so we are left with the real transitions
  readonly property var allTransitions: Array.from({
                                                     "length": transitionsModel.count
                                                   }, (_, i) => transitionsModel.get(i).key).filter(key => key !== "random" && key != "none")

  property var wallpaperLists: ({})
  property int scanningCount: 0

  // Cache for current wallpapers - can be updated directly since we use signals for notifications
  property var currentWallpapers: ({})

  // Smart Rotation: shuffle queues per screen (wallpapers to show before reshuffling)
  property var shuffleQueues: ({})
  // Smart Rotation: history of shown wallpapers for "previous" navigation
  property var wallpaperHistory: []
  // Smart Rotation: current position in history (for prev/next navigation)
  property int historyPosition: -1
  // Smart Rotation: flag to prevent adding to history when navigating
  property bool _navigatingHistory: false
  // Auto-outpaint queue for sequential processing
  property var _autoOutpaintQueue: []
  property bool _autoOutpaintRunning: false
  property var _autoOutpaintPending: ({})

  property bool isInitialized: false
  property string wallpaperCacheFile: ""
  property string rotationCacheFile: ""

  readonly property bool scanning: (scanningCount > 0)
  readonly property string noctaliaDefaultWallpaper: Quickshell.shellDir + "/Assets/Wallpaper/noctalia.png"
  property string defaultWallpaper: noctaliaDefaultWallpaper

  // Signals for reactive UI updates
  signal wallpaperChanged(string screenName, string path)
  // Emitted when a wallpaper changes
  signal wallpaperDirectoryChanged(string screenName, string directory)
  // Emitted when a monitor's directory changes
  signal wallpaperListChanged(string screenName, int count)

  // Upscaling state
  property bool isUpscaling: false
  property bool isUpscalingVideo: false
  property string upscalingFile: ""
  property real videoUpscaleProgress: 0.0  // 0.0 to 1.0
  property string videoUpscaleStage: ""    // extracting, upscaling, encoding
  property string _videoUpscaleTempDir: "" // Internal: temp directory for progress tracking
  property int _videoUpscaleTotalFrames: 0 // Internal: total frames count
  signal upscaleCompleted(string originalPath, string upscaledPath)
  signal upscaleFailed(string originalPath, string error)

  // Emitted when available wallpapers list changes
  Connections {
    target: Settings.data.wallpaper
    function onDirectoryChanged() {
      root.refreshWallpapersList();
      // Emit directory change signals for monitors using the default directory
      if (!Settings.data.wallpaper.enableMultiMonitorDirectories) {
        // All monitors use the main directory
        for (var i = 0; i < Quickshell.screens.length; i++) {
          root.wallpaperDirectoryChanged(Quickshell.screens[i].name, root.defaultDirectory);
        }
      } else {
        // Only monitors without custom directories are affected
        for (var i = 0; i < Quickshell.screens.length; i++) {
          var screenName = Quickshell.screens[i].name;
          var monitor = root.getMonitorConfig(screenName);
          if (!monitor || !monitor.directory) {
            root.wallpaperDirectoryChanged(screenName, root.defaultDirectory);
          }
        }
      }
    }
    function onEnableMultiMonitorDirectoriesChanged() {
      root.refreshWallpapersList();
      // Notify all monitors about potential directory changes
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        root.wallpaperDirectoryChanged(screenName, root.getMonitorDirectory(screenName));
      }
    }
    function onRandomEnabledChanged() {
      root.toggleRandomWallpaper();
    }
    function onRandomIntervalSecChanged() {
      root.restartRandomWallpaperTimer();
    }
    function onRecursiveSearchChanged() {
      root.refreshWallpapersList();
    }
  }

  // -------------------------------------------------
  function init() {
    Logger.i("Wallpaper", "Service started");

    translateModels();

    // Initialize cache file paths
    Qt.callLater(() => {
                   if (typeof Settings !== 'undefined' && Settings.cacheDir) {
                     wallpaperCacheFile = Settings.cacheDir + "wallpapers.json";
                     wallpaperCacheView.path = wallpaperCacheFile;
                     rotationCacheFile = Settings.cacheDir + "wallpaper-rotation.json";
                     rotationCacheView.path = rotationCacheFile;
                   }
                 });

    // Note: isInitialized will be set to true in wallpaperCacheView.onLoaded
    Logger.d("Wallpaper", "Triggering initial wallpaper scan");
    Qt.callLater(refreshWallpapersList);
  }

  // -------------------------------------------------
  function translateModels() {
    // Wait for i18n to be ready by retrying every time
    if (!I18n.isLoaded) {
      Qt.callLater(translateModels);
      return;
    }

    // Populate fillModeModel with translated names
    fillModeModel.append({
                           "key": "center",
                           "name": I18n.tr("wallpaper.fill-modes.center"),
                           "uniform": 0.0
                         });
    fillModeModel.append({
                           "key": "crop",
                           "name": I18n.tr("wallpaper.fill-modes.crop"),
                           "uniform": 1.0
                         });
    fillModeModel.append({
                           "key": "fit",
                           "name": I18n.tr("wallpaper.fill-modes.fit"),
                           "uniform": 2.0
                         });
    fillModeModel.append({
                           "key": "stretch",
                           "name": I18n.tr("wallpaper.fill-modes.stretch"),
                           "uniform": 3.0
                         });

    // Populate transitionsModel with translated names
    transitionsModel.append({
                              "key": "none",
                              "name": I18n.tr("wallpaper.transitions.none")
                            });
    transitionsModel.append({
                              "key": "random",
                              "name": I18n.tr("wallpaper.transitions.random")
                            });
    transitionsModel.append({
                              "key": "fade",
                              "name": I18n.tr("wallpaper.transitions.fade")
                            });
    transitionsModel.append({
                              "key": "disc",
                              "name": I18n.tr("wallpaper.transitions.disc")
                            });
    transitionsModel.append({
                              "key": "stripes",
                              "name": I18n.tr("wallpaper.transitions.stripes")
                            });
    transitionsModel.append({
                              "key": "wipe",
                              "name": I18n.tr("wallpaper.transitions.wipe")
                            });

    // Populate localSortModel with combined sort options
    localSortModel.append({
                            "key": "date-desc",
                            "name": I18n.tr("wallpaper.sort.date-newest")
                          });
    localSortModel.append({
                            "key": "date-asc",
                            "name": I18n.tr("wallpaper.sort.date-oldest")
                          });
    localSortModel.append({
                            "key": "name-asc",
                            "name": I18n.tr("wallpaper.sort.name-az")
                          });
    localSortModel.append({
                            "key": "name-desc",
                            "name": I18n.tr("wallpaper.sort.name-za")
                          });

    // Populate wallhavenSortModel with translated names
    wallhavenSortModel.append({
                                "key": "random",
                                "name": I18n.tr("wallpaper.wallhaven-sort.random"),
                                "sorting": "random",
                                "topRange": ""
                              });
    wallhavenSortModel.append({
                                "key": "trending-day",
                                "name": I18n.tr("wallpaper.wallhaven-sort.trending-day"),
                                "sorting": "toplist",
                                "topRange": "1d"
                              });
    wallhavenSortModel.append({
                                "key": "trending-week",
                                "name": I18n.tr("wallpaper.wallhaven-sort.trending-week"),
                                "sorting": "toplist",
                                "topRange": "1w"
                              });
    wallhavenSortModel.append({
                                "key": "popular-month",
                                "name": I18n.tr("wallpaper.wallhaven-sort.popular-month"),
                                "sorting": "toplist",
                                "topRange": "1M"
                              });
    wallhavenSortModel.append({
                                "key": "popular-year",
                                "name": I18n.tr("wallpaper.wallhaven-sort.popular-year"),
                                "sorting": "toplist",
                                "topRange": "1y"
                              });
    wallhavenSortModel.append({
                                "key": "most-viewed",
                                "name": I18n.tr("wallpaper.wallhaven-sort.most-viewed"),
                                "sorting": "views",
                                "topRange": ""
                              });
    wallhavenSortModel.append({
                                "key": "most-favorites",
                                "name": I18n.tr("wallpaper.wallhaven-sort.most-favorites"),
                                "sorting": "favorites",
                                "topRange": ""
                              });
    wallhavenSortModel.append({
                                "key": "newest",
                                "name": I18n.tr("wallpaper.wallhaven-sort.newest"),
                                "sorting": "date_added",
                                "topRange": ""
                              });
  }

  // -------------------------------------------------------------------
  function getFillModeUniform() {
    for (var i = 0; i < fillModeModel.count; i++) {
      const mode = fillModeModel.get(i);
      if (mode.key === Settings.data.wallpaper.fillMode) {
        return mode.uniform;
      }
    }
    // Fallback to crop
    return 1.0;
  }

  // -------------------------------------------------------------------
  // Get specific monitor wallpaper data
  function getMonitorConfig(screenName) {
    var monitors = Settings.data.wallpaper.monitorDirectories;
    if (monitors !== undefined) {
      for (var i = 0; i < monitors.length; i++) {
        if (monitors[i].name !== undefined && monitors[i].name === screenName) {
          return monitors[i];
        }
      }
    }
  }

  // -------------------------------------------------------------------
  // Get specific monitor directory
  function getMonitorDirectory(screenName) {
    if (!Settings.data.wallpaper.enableMultiMonitorDirectories) {
      return root.defaultDirectory;
    }

    var monitor = getMonitorConfig(screenName);
    if (monitor !== undefined && monitor.directory !== undefined) {
      return Settings.preprocessPath(monitor.directory);
    }

    // Fall back to the main/single directory
    return root.defaultDirectory;
  }

  // -------------------------------------------------------------------
  // Set specific monitor directory
  function setMonitorDirectory(screenName, directory) {
    var monitors = Settings.data.wallpaper.monitorDirectories || [];
    var found = false;

    // Create a new array with updated values
    var newMonitors = monitors.map(function (monitor) {
      if (monitor.name === screenName) {
        found = true;
        return {
          "name": screenName,
          "directory": directory,
          "wallpaper": monitor.wallpaper || ""
        };
      }
      return monitor;
    });

    if (!found) {
      newMonitors.push({
                         "name": screenName,
                         "directory": directory,
                         "wallpaper": ""
                       });
    }

    // Update Settings with new array to ensure proper persistence
    Settings.data.wallpaper.monitorDirectories = newMonitors.slice();
    root.wallpaperDirectoryChanged(screenName, Settings.preprocessPath(directory));
  }

  // -------------------------------------------------------------------
  // Get specific monitor wallpaper - now from cache
  function getWallpaper(screenName) {
    return currentWallpapers[screenName] || root.defaultWallpaper;
  }

  // -------------------------------------------------------------------
  function _getScreenByName(screenName) {
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (Quickshell.screens[i].name === screenName) {
        return Quickshell.screens[i];
      }
    }
    return null;
  }

  // -------------------------------------------------------------------
  function _isImageFile(path) {
    if (!path) {
      return false;
    }
    if (typeof VideoWallpaperService !== 'undefined' && VideoWallpaperService.isVideoFile(path)) {
      return false;
    }
    var ext = path.split('.').pop().toLowerCase();
    var imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "pnm"];
    return imageExtensions.indexOf(ext) !== -1;
  }

  // -------------------------------------------------------------------
  function _isOutpaintedPath(path) {
    if (!path) {
      return false;
    }
    if (typeof OutpaintService !== "undefined" && OutpaintService.cacheDir && path.indexOf(OutpaintService.cacheDir) === 0) {
      return true;
    }
    return path.indexOf("_outpainted_") !== -1;
  }

  // -------------------------------------------------------------------
  function _queueAutoOutpaint(path, screenName) {
    var key = screenName + "::" + path;
    if (_autoOutpaintPending[key]) {
      return;
    }
    _autoOutpaintPending[key] = true;
    _autoOutpaintQueue.push({
                              path: path,
                              screenName: screenName
                            });
    if (!_autoOutpaintRunning) {
      _processAutoOutpaintQueue();
    }
  }

  // -------------------------------------------------------------------
  function _processAutoOutpaintQueue() {
    if (_autoOutpaintQueue.length === 0) {
      _autoOutpaintRunning = false;
      return;
    }

    _autoOutpaintRunning = true;
    var item = _autoOutpaintQueue.shift();
    delete _autoOutpaintPending[item.screenName + "::" + item.path];

    if (OutpaintService.isProcessing) {
      _autoOutpaintQueue.unshift(item);
      _autoOutpaintRunning = false;
      if (!autoOutpaintRetryTimer.running) {
        autoOutpaintRetryTimer.start();
      }
      return;
    }

    var screen = _getScreenByName(item.screenName);
    if (!screen) {
      _processAutoOutpaintQueue();
      return;
    }

    OutpaintService.outpaint(item.path, screen.width, screen.height, function(resultPath) {
      if (resultPath && resultPath !== item.path) {
        _setWallpaper(item.screenName, resultPath, { "skipAutoOutpaint": true });
      }
      _processAutoOutpaintQueue();
    });
  }

  // -------------------------------------------------------------------
  function changeWallpaper(path, screenName) {
    if (screenName !== undefined) {
      _setWallpaper(screenName, path);
    } else {
      // If no screenName specified change for all screens
      for (var i = 0; i < Quickshell.screens.length; i++) {
        _setWallpaper(Quickshell.screens[i].name, path);
      }
    }
  }

  // -------------------------------------------------------------------
  // Re-apply current wallpapers (e.g., when fill mode changes)
  signal reapplyWallpapers()

  function reapplyCurrentWallpapers() {
    Logger.d("Wallpaper", "Re-applying current wallpapers");
    root.reapplyWallpapers();
  }

  // -------------------------------------------------------------------
  function _setWallpaper(screenName, path) {
    var options = arguments.length > 2 ? arguments[2] : {};
    if (path === "" || path === undefined) {
      return;
    }

    if (screenName === undefined) {
      Logger.w("Wallpaper", "setWallpaper", "no screen specified");
      return;
    }

    //Logger.i("Wallpaper", "setWallpaper on", screenName, ": ", path)

    // Check if wallpaper actually changed
    var oldPath = currentWallpapers[screenName] || "";
    var wallpaperChanged = (oldPath !== path);

    if (!wallpaperChanged) {
      // No change needed
      return;
    }

    if (!options.skipAutoOutpaint
        && typeof OutpaintService !== "undefined"
        && OutpaintService.autoOutpaint
        && _isImageFile(path)
        && !_isOutpaintedPath(path)
        && (!WallpaperCacheService || WallpaperCacheService.imageMagickAvailable)) {
      _queueAutoOutpaint(path, screenName);
    }

    // Update cache directly
    currentWallpapers[screenName] = path;

    // Save to cache file with debounce
    saveTimer.restart();

    // Check if this is a video wallpaper and notify VideoWallpaperService
    if (typeof VideoWallpaperService !== 'undefined' && VideoWallpaperService.isVideoFile(path)) {
      VideoWallpaperService.setVideoWallpaper(screenName, path);
    } else if (typeof VideoWallpaperService !== 'undefined') {
      // Clear video wallpaper if switching to an image
      VideoWallpaperService.clearVideoWallpaper(screenName);
    }

    // Emit signal for this specific wallpaper change
    root.wallpaperChanged(screenName, path);

    // Restart the random wallpaper timer
    if (randomWallpaperTimer.running) {
      randomWallpaperTimer.restart();
    }
  }

  // -------------------------------------------------------------------
  // Fisher-Yates shuffle algorithm for unbiased randomization
  function _shuffleArray(array) {
    var shuffled = array.slice(); // Clone the array
    for (var i = shuffled.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    return shuffled;
  }

  // -------------------------------------------------------------------
  // Get or create shuffle queue for a screen
  function _getShuffleQueue(screenName) {
    if (!shuffleQueues[screenName] || shuffleQueues[screenName].length === 0) {
      var wallpaperList = getWallpapersList(screenName);
      if (wallpaperList.length === 0) {
        return [];
      }

      // Create new shuffled queue
      var newQueue = _shuffleArray(wallpaperList);

      // Avoid showing the same wallpaper at the start of the new cycle
      var currentWallpaper = currentWallpapers[screenName];
      if (currentWallpaper && newQueue.length > 1 && newQueue[0] === currentWallpaper) {
        // Move current wallpaper to end of queue
        newQueue.push(newQueue.shift());
      }

      shuffleQueues[screenName] = newQueue;
      Logger.i("Wallpaper", "Created new shuffle queue for", screenName, "with", newQueue.length, "wallpapers");

      // Save rotation state
      _saveRotationState();
    }
    return shuffleQueues[screenName];
  }

  // -------------------------------------------------------------------
  // Add wallpaper to history
  function _addToHistory(wallpaperPath, screenName) {
    if (_navigatingHistory) return;

    var historyEntry = {
      "path": wallpaperPath,
      "screen": screenName,
      "timestamp": Date.now()
    };

    // If we're not at the end of history, truncate forward history
    if (historyPosition >= 0 && historyPosition < wallpaperHistory.length - 1) {
      wallpaperHistory = wallpaperHistory.slice(0, historyPosition + 1);
    }

    wallpaperHistory.push(historyEntry);

    // Trim history to configured size
    var maxHistory = Settings.data.wallpaper.historySize || 50;
    if (wallpaperHistory.length > maxHistory) {
      wallpaperHistory = wallpaperHistory.slice(-maxHistory);
    }

    historyPosition = wallpaperHistory.length - 1;
    _saveRotationState();
  }

  // -------------------------------------------------------------------
  function setRandomWallpaper() {
    Logger.d("Wallpaper", "setRandomWallpaper (smart rotation:", Settings.data.wallpaper.smartRotation, ")");

    if (Settings.data.wallpaper.enableMultiMonitorDirectories) {
      // Pick a wallpaper per screen
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        _setRandomWallpaperForScreen(screenName);
      }
    } else {
      // Pick a wallpaper common to all screens
      _setRandomWallpaperForScreen(Screen.name, true);
    }
  }

  // -------------------------------------------------------------------
  function _setRandomWallpaperForScreen(screenName, applyToAll) {
    var wallpaperList = getWallpapersList(screenName);
    if (wallpaperList.length === 0) return;

    var selectedPath;

    if (Settings.data.wallpaper.smartRotation) {
      // Smart rotation: use shuffle queue
      var queue = _getShuffleQueue(screenName);
      if (queue.length === 0) return;

      selectedPath = queue.shift();
      shuffleQueues[screenName] = queue;

      Logger.d("Wallpaper", "Smart rotation: selected", selectedPath, "- remaining in queue:", queue.length);
      _saveRotationState();
    } else {
      // Pure random: original behavior
      var randomIndex = Math.floor(Math.random() * wallpaperList.length);
      selectedPath = wallpaperList[randomIndex];
    }

    if (applyToAll) {
      changeWallpaper(selectedPath, undefined);
      _addToHistory(selectedPath, "all");
    } else {
      changeWallpaper(selectedPath, screenName);
      _addToHistory(selectedPath, screenName);
    }
  }

  // -------------------------------------------------------------------
  // Go to previous wallpaper in history
  function previousWallpaper() {
    if (wallpaperHistory.length === 0 || historyPosition <= 0) {
      Logger.d("Wallpaper", "No previous wallpaper in history");
      ToastService.showNotice(
        I18n.tr("wallpaper.history.no-previous") || "No Previous",
        I18n.tr("wallpaper.history.no-previous-desc") || "No previous wallpaper in history"
      );
      return false;
    }

    historyPosition--;
    var entry = wallpaperHistory[historyPosition];

    _navigatingHistory = true;
    if (entry.screen === "all") {
      changeWallpaper(entry.path, undefined);
    } else {
      changeWallpaper(entry.path, entry.screen);
    }
    _navigatingHistory = false;

    Logger.i("Wallpaper", "Previous wallpaper:", entry.path, "(position", historyPosition, "of", wallpaperHistory.length, ")");
    _saveRotationState();
    return true;
  }

  // -------------------------------------------------------------------
  // Go to next wallpaper in history (if we went back)
  function nextWallpaper() {
    if (historyPosition >= wallpaperHistory.length - 1) {
      // At end of history, get a new random wallpaper
      setRandomWallpaper();
      return true;
    }

    historyPosition++;
    var entry = wallpaperHistory[historyPosition];

    _navigatingHistory = true;
    if (entry.screen === "all") {
      changeWallpaper(entry.path, undefined);
    } else {
      changeWallpaper(entry.path, entry.screen);
    }
    _navigatingHistory = false;

    Logger.i("Wallpaper", "Next wallpaper:", entry.path, "(position", historyPosition, "of", wallpaperHistory.length, ")");
    _saveRotationState();
    return true;
  }

  // -------------------------------------------------------------------
  // Clear shuffle queues (e.g., when wallpaper list changes)
  function resetShuffleQueues() {
    shuffleQueues = {};
    Logger.d("Wallpaper", "Shuffle queues reset");
    _saveRotationState();
  }

  // -------------------------------------------------------------------
  // Save rotation state to cache file
  function _saveRotationState() {
    rotationSaveTimer.restart();
  }

  // -------------------------------------------------------------------
  function toggleRandomWallpaper() {
    Logger.d("Wallpaper", "toggleRandomWallpaper");
    if (Settings.data.wallpaper.randomEnabled) {
      restartRandomWallpaperTimer();
      setRandomWallpaper();
    }
  }

  // -------------------------------------------------------------------
  // Upscale a wallpaper image using Real-ESRGAN
  function upscaleWallpaper(imagePath) {
    if (isUpscaling) {
      Logger.w("Wallpaper", "Upscaling already in progress");
      ToastService.showWarning(
        I18n.tr("wallpaper.upscale.already-in-progress"),
        I18n.tr("wallpaper.upscale.already-in-progress-desc")
      );
      return;
    }

    if (!ProgramCheckerService.realesrganAvailable) {
      Logger.e("Wallpaper", "realesrgan-ncnn-vulkan not available");
      ToastService.showError(
        I18n.tr("wallpaper.upscale.not-available"),
        I18n.tr("wallpaper.upscale.not-available-desc")
      );
      return;
    }

    // Check if it's an image (not video)
    var ext = imagePath.split('.').pop().toLowerCase();
    var imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "pnm"];
    if (imageExtensions.indexOf(ext) === -1) {
      Logger.w("Wallpaper", "Cannot upscale non-image file:", imagePath);
      ToastService.showWarning(
        I18n.tr("wallpaper.upscale.not-image"),
        I18n.tr("wallpaper.upscale.not-image-desc")
      );
      return;
    }

    isUpscaling = true;
    upscalingFile = imagePath;

    // Check which screens have this as active wallpaper (to auto-apply upscaled version)
    var screensWithThisWallpaper = [];
    for (var screenName in currentWallpapers) {
      if (currentWallpapers[screenName] === imagePath) {
        screensWithThisWallpaper.push(screenName);
      }
    }

    // Generate output filename with _upscaled suffix
    var basePath = imagePath.substring(0, imagePath.lastIndexOf('.'));
    var outputPath = basePath + "_upscaled.png"; // Real-ESRGAN outputs PNG

    Logger.i("Wallpaper", "Starting upscale:", imagePath, "->", outputPath);
    if (screensWithThisWallpaper.length > 0) {
      Logger.i("Wallpaper", "Will auto-apply to screens:", screensWithThisWallpaper.join(", "));
    }
    ToastService.showNotice(
      I18n.tr("wallpaper.upscale.started"),
      I18n.tr("wallpaper.upscale.started-desc")
    );

    // Create process for upscaling using settings (image models are always x4)
    var model = Settings.data.wallpaper.imageUpscaleModel || "realesrgan-x4plus-anime";
    var scale = 4; // Image models (realesrgan-x4plus, realesrgan-x4plus-anime) only support x4

    var processString = `
      import QtQuick
      import Quickshell.Io
      Process {
        property string inputPath: ""
        property string outputPath: ""
        property string model: ""
        property int scale: 4
        command: ["realesrgan-ncnn-vulkan", "-i", inputPath, "-o", outputPath, "-n", model, "-s", scale.toString()]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `;

    var upscaleProcess = Qt.createQmlObject(processString, root, "UpscaleProcess");
    upscaleProcess.inputPath = imagePath;
    upscaleProcess.outputPath = outputPath;
    upscaleProcess.model = model;
    upscaleProcess.scale = scale;

    upscaleProcess.exited.connect(function(exitCode) {
      isUpscaling = false;
      upscalingFile = "";

      if (exitCode === 0) {
        Logger.i("Wallpaper", "Upscale completed:", outputPath);

        // Move original to Originals folder
        var dirPath = imagePath.substring(0, imagePath.lastIndexOf('/'));
        var fileName = imagePath.split('/').pop();
        var originalsDir = dirPath + "/Originals";
        var newOriginalPath = originalsDir + "/" + fileName;

        Logger.i("Wallpaper", "Moving original to:", newOriginalPath);

        // Use separate commands array to avoid shell escaping issues
        var mkdirProcess = Qt.createQmlObject(`
          import QtQuick
          import Quickshell.Io
          Process {
            command: ["mkdir", "-p", "` + originalsDir.replace(/"/g, '\\"') + `"]
            stdout: StdioCollector {}
            stderr: StdioCollector {}
          }
        `, root, "MkdirProcess");

        mkdirProcess.exited.connect(function(mkdirExitCode) {
          if (mkdirExitCode === 0) {
            // Now move the file
            var mvProcess = Qt.createQmlObject(`
              import QtQuick
              import Quickshell.Io
              Process {
                command: ["mv", "` + imagePath.replace(/"/g, '\\"') + `", "` + newOriginalPath.replace(/"/g, '\\"') + `"]
                stdout: StdioCollector {}
                stderr: StdioCollector {}
              }
            `, root, "MvProcess");

            mvProcess.exited.connect(function(mvExitCode) {
              if (mvExitCode === 0) {
                Logger.i("Wallpaper", "Original moved to:", newOriginalPath);
              } else {
                Logger.w("Wallpaper", "Failed to move original:", mvProcess.stderr.text);
              }
              mvProcess.destroy();

              // Auto-apply upscaled wallpaper to screens that had the original
              for (var i = 0; i < screensWithThisWallpaper.length; i++) {
                var screen = screensWithThisWallpaper[i];
                Logger.i("Wallpaper", "Auto-applying upscaled wallpaper to:", screen);
                changeWallpaper(outputPath, screen);
              }

              // Refresh wallpaper list after move
              refreshWallpapersList();
            });
            mvProcess.running = true;
          } else {
            Logger.w("Wallpaper", "Failed to create Originals folder:", mkdirProcess.stderr.text);
            refreshWallpapersList();
          }
          mkdirProcess.destroy();
        });
        mkdirProcess.running = true;

        ToastService.showNotice(
          I18n.tr("wallpaper.upscale.completed"),
          I18n.tr("wallpaper.upscale.completed-desc")
        );
        upscaleCompleted(imagePath, outputPath);
      } else {
        var errorMsg = upscaleProcess.stderr.text || "Unknown error";
        Logger.e("Wallpaper", "Upscale failed:", errorMsg);
        ToastService.showError(
          I18n.tr("wallpaper.upscale.failed"),
          errorMsg
        );
        upscaleFailed(imagePath, errorMsg);
      }

      upscaleProcess.destroy();
    });

    upscaleProcess.running = true;
  }

  // -------------------------------------------------------------------
  // Upscale a video wallpaper using Real-ESRGAN via upscale-video.sh
  function upscaleVideo(videoPath) {
    if (isUpscaling || isUpscalingVideo) {
      Logger.w("Wallpaper", "Upscaling already in progress");
      ToastService.showWarning(
        I18n.tr("wallpaper.upscale.already-in-progress"),
        I18n.tr("wallpaper.upscale.already-in-progress-desc")
      );
      return;
    }

    if (!ProgramCheckerService.realesrganAvailable) {
      Logger.e("Wallpaper", "realesrgan-ncnn-vulkan not available");
      ToastService.showError(
        I18n.tr("wallpaper.upscale.not-available"),
        I18n.tr("wallpaper.upscale.not-available-desc")
      );
      return;
    }

    // Check if it's a video file
    var ext = videoPath.split('.').pop().toLowerCase();
    var videoExtensions = ["mp4", "webm", "mkv", "avi", "mov", "ogv", "m4v"];
    if (videoExtensions.indexOf(ext) === -1) {
      Logger.w("Wallpaper", "Cannot upscale non-video file:", videoPath);
      ToastService.showWarning(
        I18n.tr("wallpaper.upscale.not-video"),
        I18n.tr("wallpaper.upscale.not-video-desc")
      );
      return;
    }

    isUpscalingVideo = true;
    upscalingFile = videoPath;

    // Check which screens have this as active wallpaper (to auto-apply upscaled version)
    var screensWithThisWallpaper = [];
    for (var screenName in currentWallpapers) {
      if (currentWallpapers[screenName] === videoPath) {
        screensWithThisWallpaper.push(screenName);
      }
    }

    // Generate output filename with _upscaled suffix
    var basePath = videoPath.substring(0, videoPath.lastIndexOf('.'));
    var outputPath = basePath + "_upscaled." + ext;

    Logger.i("Wallpaper", "Starting video upscale:", videoPath, "->", outputPath);
    if (screensWithThisWallpaper.length > 0) {
      Logger.i("Wallpaper", "Will auto-apply to screens:", screensWithThisWallpaper.join(", "));
    }
    ToastService.showNotice(
      I18n.tr("wallpaper.upscale.video-started"),
      I18n.tr("wallpaper.upscale.video-started-desc")
    );

    // Reset progress
    videoUpscaleProgress = 0.0;
    videoUpscaleStage = "extracting";

    var scriptPath = Quickshell.shellDir + "/Assets/Scripts/upscale-video.sh";
    var model = Settings.data.wallpaper.videoUpscaleModel || "realesr-animevideov3";
    // Only realesr-animevideov3 supports variable scale, others are x4 only
    var scale = (model === "realesr-animevideov3") ? (Settings.data.wallpaper.videoUpscaleScale || 4) : 4;

    var processString = `
      import QtQuick
      import Quickshell.Io
      Process {
        property string script: ""
        property string input: ""
        property string output: ""
        property string model: ""
        property string scale: ""
        command: ["bash", script, input, output, model, scale]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `;

    var upscaleProcess = Qt.createQmlObject(processString, root, "VideoUpscaleProcess");
    upscaleProcess.script = scriptPath;
    upscaleProcess.input = videoPath;
    upscaleProcess.output = outputPath;
    upscaleProcess.model = model;
    upscaleProcess.scale = scale.toString();

    // Calculate progress file path (same as script: md5sum of video path)
    var escapedPath = videoPath.replace(/'/g, "'\\''"); // Escape single quotes for shell
    var progressFileProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["sh", "-c", "echo -n '` + escapedPath + `' | md5sum | cut -d' ' -f1"]
        stdout: StdioCollector {}
      }
    `, root, "HashProcess");

    var progressFilePath = "";
    var progressTimer = null;

    progressFileProcess.exited.connect(function(code) {
      if (code === 0) {
        var hash = progressFileProcess.stdout.text.trim();
        progressFilePath = "/tmp/video-upscale-progress-" + hash;
        Logger.i("Wallpaper", "Progress file path:", progressFilePath);

        // Start timer to poll progress file
        progressTimer = Qt.createQmlObject(`
          import QtQuick
          Timer {
            interval: 500
            repeat: true
            running: true
          }
        `, root, "ProgressTimer");

        progressTimer.triggered.connect(function() {
          var readProcess = Qt.createQmlObject(`
            import QtQuick
            import Quickshell.Io
            Process {
              property string file: ""
              command: ["cat", file]
              stdout: StdioCollector {}
            }
          `, root, "ReadProgressProcess");
          readProcess.file = progressFilePath;
          readProcess.exited.connect(function(readCode) {
            if (readCode === 0) {
              var content = readProcess.stdout.text.trim();
              if (content) {
                var parts = content.split(":");
                if (parts.length >= 2) {
                  var progress = parseFloat(parts[0]);
                  var stage = parts[1];
                  if (!isNaN(progress)) {
                    videoUpscaleProgress = Math.min(1.0, Math.max(0.0, progress));
                    videoUpscaleStage = stage;
                  }
                }
              }
            }
            readProcess.destroy();
          });
          readProcess.running = true;
        });
      }
      progressFileProcess.destroy();
    });
    progressFileProcess.running = true;

    Logger.i("Wallpaper", "Progress timer started for video upscale");

    upscaleProcess.exited.connect(function(exitCode) {
      // Stop and cleanup progress timer
      if (progressTimer) {
        progressTimer.running = false;
        progressTimer.destroy();
      }

      isUpscalingVideo = false;
      upscalingFile = "";
      videoUpscaleProgress = 0.0;
      videoUpscaleStage = "";

      if (exitCode === 0) {
        Logger.i("Wallpaper", "Video upscale completed:", outputPath);

        // Move original to Originals folder
        var dirPath = videoPath.substring(0, videoPath.lastIndexOf('/'));
        var fileName = videoPath.split('/').pop();
        var originalsDir = dirPath + "/Originals";
        var newOriginalPath = originalsDir + "/" + fileName;

        Logger.i("Wallpaper", "Moving original video to:", newOriginalPath);

        var mkdirProcess = Qt.createQmlObject(`
          import QtQuick
          import Quickshell.Io
          Process {
            property string dir: ""
            command: ["mkdir", "-p", dir]
            stdout: StdioCollector {}
            stderr: StdioCollector {}
          }
        `, root, "MkdirVideoProcess");
        mkdirProcess.dir = originalsDir;

        mkdirProcess.exited.connect(function(mkdirExitCode) {
          if (mkdirExitCode === 0) {
            var mvProcess = Qt.createQmlObject(`
              import QtQuick
              import Quickshell.Io
              Process {
                property string src: ""
                property string dest: ""
                command: ["mv", src, dest]
                stdout: StdioCollector {}
                stderr: StdioCollector {}
              }
            `, root, "MvVideoProcess");
            mvProcess.src = videoPath;
            mvProcess.dest = newOriginalPath;

            mvProcess.exited.connect(function(mvExitCode) {
              if (mvExitCode === 0) {
                Logger.i("Wallpaper", "Original video moved to:", newOriginalPath);
              } else {
                Logger.w("Wallpaper", "Failed to move original video:", mvProcess.stderr.text);
              }
              mvProcess.destroy();

              // Auto-apply upscaled video to screens that had the original
              for (var i = 0; i < screensWithThisWallpaper.length; i++) {
                var screen = screensWithThisWallpaper[i];
                Logger.i("Wallpaper", "Auto-applying upscaled video to:", screen);
                changeWallpaper(outputPath, screen);
              }

              refreshWallpapersList();
            });
            mvProcess.running = true;
          } else {
            Logger.w("Wallpaper", "Failed to create Originals folder:", mkdirProcess.stderr.text);
            refreshWallpapersList();
          }
          mkdirProcess.destroy();
        });
        mkdirProcess.running = true;

        ToastService.showNotice(
          I18n.tr("wallpaper.upscale.video-completed"),
          I18n.tr("wallpaper.upscale.video-completed-desc")
        );
        upscaleCompleted(videoPath, outputPath);
      } else {
        var errorMsg = upscaleProcess.stderr.text || "Unknown error";
        Logger.e("Wallpaper", "Video upscale failed:", errorMsg);
        ToastService.showError(
          I18n.tr("wallpaper.upscale.video-failed"),
          errorMsg
        );
        upscaleFailed(videoPath, errorMsg);
      }

      upscaleProcess.destroy();
    });

    upscaleProcess.running = true;
  }

  // -------------------------------------------------------------------
  // Clear all wallpaper-related caches
  function clearAllCache() {
    Logger.i("Wallpaper", "Clearing all wallpaper caches");

    // Clear WallpaperCacheService preprocessed images
    WallpaperCacheService.clearAllCache();

    // Clear VideoWallpaperService thumbnails
    var videoThumbDir = VideoWallpaperService.thumbnailCacheDir;
    Quickshell.execDetached(["rm", "-rf", videoThumbDir]);
    Quickshell.execDetached(["mkdir", "-p", videoThumbDir]);
    VideoWallpaperService.thumbnailCache = {};

    // Clear NImageCached thumbnails (image grid thumbnails)
    var imageCacheDir = Settings.cacheDirImages;
    Quickshell.execDetached(["rm", "-rf", imageCacheDir]);
    Quickshell.execDetached(["mkdir", "-p", imageCacheDir]);

    ToastService.showNotice(
      "Cache Cleared",
      "All wallpaper caches have been cleared"
    );

    // Refresh wallpapers list to reload thumbnails
    Qt.callLater(refreshWallpapersList);
  }

  // -------------------------------------------------------------------
  // Clear cache for a specific wallpaper path
  function clearCacheForPath(wallpaperPath) {
    if (!wallpaperPath) return;

    Logger.i("Wallpaper", "Clearing cache for:", wallpaperPath);

    // Check if it's a video or image
    var isVideo = VideoWallpaperService.isVideoFile(wallpaperPath);

    if (isVideo) {
      // Clear video thumbnail - uses MD5 hash
      var videoHash = Qt.md5(wallpaperPath);
      var videoThumbDir = VideoWallpaperService.thumbnailCacheDir;
      Quickshell.execDetached(["rm", "-f", videoThumbDir + "/" + videoHash + ".jpg"]);
      Quickshell.execDetached(["rm", "-f", videoThumbDir + "/" + videoHash + "_full.jpg"]);
      // Clear from memory cache
      delete VideoWallpaperService.thumbnailCache[videoThumbDir + "/" + videoHash + ".jpg"];
      delete VideoWallpaperService.thumbnailCache[videoThumbDir + "/" + videoHash + "_full.jpg"];
    } else {
      // Clear image caches using grep to find files containing the path hash
      // NImageCached uses sha256 of path
      var imageCacheDir = Settings.cacheDirImages;
      var preprocessedDir = WallpaperCacheService.cacheDir;

      // Use find to delete files matching the sha256 hash pattern
      // Since we can't easily compute sha256 here, use a simpler approach:
      // Delete files that match based on the path
      var cleanPath = wallpaperPath.replace(/^file:\/\//, "");
      var pathEsc = cleanPath.replace(/'/g, "'\\''");

      // Clear NImageCached thumbnails (all sizes for this path)
      // The hash is sha256(imagePath), so we need to compute it
      // For simplicity, we'll use a shell command to find and delete
      var clearCmd = "sha256sum <<< '" + pathEsc + "' | cut -d' ' -f1 | xargs -I{} find '" + imageCacheDir + "' -name '{}*' -delete 2>/dev/null";
      Quickshell.execDetached(["bash", "-c", clearCmd]);

      // Also clear WallpaperCacheService preprocessed versions
      // These use sha256(sourcePath + "@" + width + "x" + height + "@" + mtime)
      // Since we don't know all variations, just clear files that start with a computed base
      var clearPreprocessedCmd = "find '" + preprocessedDir + "' -type f -name '*.jpg' 2>/dev/null | while read f; do rm -f \"$f\"; done";
      // Actually, better to just invalidate for this source
      WallpaperCacheService.invalidateForSource(cleanPath);
    }

    ToastService.showNotice(
      "Cache Cleared",
      "Cache cleared for this wallpaper"
    );

    // Refresh to reload thumbnail
    Qt.callLater(refreshWallpapersList);
  }

  // -------------------------------------------------------------------
  function restartRandomWallpaperTimer() {
    if (Settings.data.wallpaper.randomEnabled) {
      randomWallpaperTimer.restart();
    }
  }

  // -------------------------------------------------------------------
  function getWallpapersList(screenName) {
    if (screenName != undefined && wallpaperLists[screenName] != undefined) {
      return wallpaperLists[screenName];
    }
    return [];
  }

  // -------------------------------------------------------------------
  function refreshWallpapersList() {
    Logger.d("Wallpaper", "refreshWallpapersList", "recursive:", Settings.data.wallpaper.recursiveSearch);
    scanningCount = 0;

    if (Settings.data.wallpaper.recursiveSearch) {
      // Use Process-based recursive search for all screens
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        var directory = getMonitorDirectory(screenName);
        scanDirectoryRecursive(screenName, directory);
      }
    } else {
      // Use FolderListModel (non-recursive)
      // Force refresh by toggling each scanner's currentDirectory
      for (var i = 0; i < wallpaperScanners.count; i++) {
        var scanner = wallpaperScanners.objectAt(i);
        if (scanner) {
          // Capture scanner in closure
          (function (s) {
            var directory = root.getMonitorDirectory(s.screenName);
            // Trigger a change by setting to /tmp (always exists) then back to the actual directory
            // Note: This causes harmless Qt warnings (QTBUG-52262) but is necessary to force FolderListModel to re-scan
            s.currentDirectory = "/tmp";
            Qt.callLater(function () {
              s.currentDirectory = directory;
            });
          })(scanner);
        }
      }
    }
  }

  // Process instances for recursive scanning (one per screen)
  property var recursiveProcesses: ({})

  // -------------------------------------------------------------------
  function scanDirectoryRecursive(screenName, directory) {
    if (!directory || directory === "") {
      Logger.w("Wallpaper", "Empty directory for", screenName);
      wallpaperLists[screenName] = [];
      wallpaperListChanged(screenName, 0);
      return;
    }

    // Cancel any existing scan for this screen
    if (recursiveProcesses[screenName]) {
      Logger.d("Wallpaper", "Cancelling existing scan for", screenName);
      recursiveProcesses[screenName].running = false;
      recursiveProcesses[screenName].destroy();
      delete recursiveProcesses[screenName];
      scanningCount--;
    }

    scanningCount++;
    Logger.i("Wallpaper", "Starting recursive scan for", screenName, "in", directory);

    // Create Process component inline
    // Use find with -printf to get modification time, then sort by time (newest first)
    var processComponent = Qt.createComponent("", root);
    var processString = `
    import QtQuick
    import Quickshell.Io
    Process {
    id: process
    command: ["sh", "-c", "find -L '` + directory.replace(/'/g, "'\\''") + `' -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.pnm' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.mov' -o -iname '*.ogv' -o -iname '*.m4v' \\) -printf '%T@ %p\\n' 2>/dev/null | sort -rn | cut -d' ' -f2-"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    }
    `;

    var processObject = Qt.createQmlObject(processString, root, "RecursiveScan_" + screenName);

    // Store reference to avoid garbage collection
    recursiveProcesses[screenName] = processObject;

    var handler = function (exitCode) {
      scanningCount--;
      Logger.d("Wallpaper", "Process exited with code", exitCode, "for", screenName);
      if (exitCode === 0) {
        var lines = processObject.stdout.text.split('\n');
        var files = [];
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (line !== '') {
            files.push(line);
          }
        }
        // Files are already sorted by modification time (newest first) from the command
        wallpaperLists[screenName] = files;
        Logger.i("Wallpaper", "Recursive scan completed for", screenName, "found", files.length, "files");
        wallpaperListChanged(screenName, files.length);
      } else {
        Logger.w("Wallpaper", "Recursive scan failed for", screenName, "exit code:", exitCode, "(directory might not exist)");
        wallpaperLists[screenName] = [];
        wallpaperListChanged(screenName, 0);
      }
      // Clean up
      delete recursiveProcesses[screenName];
      processObject.destroy();
    };

    processObject.exited.connect(handler);
    Logger.d("Wallpaper", "Starting process for", screenName);
    processObject.running = true;
  }

  // -------------------------------------------------------------------
  // -------------------------------------------------------------------
  // -------------------------------------------------------------------
  Timer {
    id: randomWallpaperTimer
    interval: Settings.data.wallpaper.randomIntervalSec * 1000
    running: Settings.data.wallpaper.randomEnabled
    repeat: true
    onTriggered: setRandomWallpaper()
    triggeredOnStart: false
  }

  // Instantiator (not Repeater) to create FolderListModel for each monitor
  Instantiator {
    id: wallpaperScanners
    model: Quickshell.screens
    delegate: FolderListModel {
      property string screenName: modelData.name
      property string currentDirectory: root.getMonitorDirectory(screenName)

      folder: "file://" + currentDirectory
      nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.pnm", "*.bmp", "*.mp4", "*.webm", "*.mkv", "*.avi", "*.mov", "*.ogv", "*.m4v"]
      showDirs: false
      sortField: FolderListModel.Time
      sortReversed: true // Newest first

      // Watch for directory changes via property binding
      onCurrentDirectoryChanged: {
        folder = "file://" + currentDirectory;
      }

      Component.onCompleted: {
        // Connect to directory change signal
        root.wallpaperDirectoryChanged.connect(function (screen, directory) {
          if (screen === screenName) {
            currentDirectory = directory;
          }
        });
      }

      onStatusChanged: {
        if (status === FolderListModel.Null) {
          // Flush the list
          root.wallpaperLists[screenName] = [];
          root.wallpaperListChanged(screenName, 0);
        } else if (status === FolderListModel.Loading) {
          // Flush the list
          root.wallpaperLists[screenName] = [];
          scanningCount++;
        } else if (status === FolderListModel.Ready) {
          var files = [];
          for (var i = 0; i < count; i++) {
            var directory = root.getMonitorDirectory(screenName);
            var filepath = directory + "/" + get(i, "fileName");
            files.push(filepath);
          }

          // Update the list
          root.wallpaperLists[screenName] = files;

          scanningCount--;
          Logger.d("Wallpaper", "List refreshed for", screenName, "count:", files.length);
          root.wallpaperListChanged(screenName, files.length);
        }
      }
    }
  }

  // -------------------------------------------------------------------
  // Cache file persistence
  // -------------------------------------------------------------------
  FileView {
    id: wallpaperCacheView
    printErrors: false
    watchChanges: false

    adapter: JsonAdapter {
      id: wallpaperCacheAdapter
      property var wallpapers: ({})
      property string defaultWallpaper: root.noctaliaDefaultWallpaper
    }

    onLoaded: {
      // Load wallpapers from cache file
      root.currentWallpapers = wallpaperCacheAdapter.wallpapers || {};

      // Load default wallpaper from cache if it exists, otherwise use Noctalia default
      if (wallpaperCacheAdapter.defaultWallpaper && wallpaperCacheAdapter.defaultWallpaper !== "") {
        root.defaultWallpaper = wallpaperCacheAdapter.defaultWallpaper;
        Logger.d("Wallpaper", "Loaded default wallpaper from cache:", wallpaperCacheAdapter.defaultWallpaper);
      } else {
        root.defaultWallpaper = root.noctaliaDefaultWallpaper;
        Logger.d("Wallpaper", "Using Noctalia default wallpaper");
      }

      Logger.d("Wallpaper", "Loaded wallpapers from cache file:", Object.keys(root.currentWallpapers).length, "screens");
      
      // Notify VideoWallpaperService about any video wallpapers from cache
      if (typeof VideoWallpaperService !== 'undefined') {
        for (var screenName in root.currentWallpapers) {
          var path = root.currentWallpapers[screenName];
          if (VideoWallpaperService.isVideoFile(path)) {
            Logger.i("Wallpaper", "Restoring video wallpaper for", screenName, ":", path);
            VideoWallpaperService.setVideoWallpaper(screenName, path);
          }
        }
      }
      
      root.isInitialized = true;
    }

    onLoadFailed: error => {
      // File doesn't exist yet or failed to load - initialize with empty state
      root.currentWallpapers = {};
      Logger.d("Wallpaper", "Cache file doesn't exist or failed to load, starting with empty wallpapers");
      root.isInitialized = true;
    }
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: {
      wallpaperCacheAdapter.wallpapers = root.currentWallpapers;
      wallpaperCacheAdapter.defaultWallpaper = root.defaultWallpaper;
      wallpaperCacheView.writeAdapter();
      Logger.d("Wallpaper", "Saved wallpapers to cache file");
    }
  }

  // -------------------------------------------------------------------
  // Smart Rotation cache persistence
  // -------------------------------------------------------------------
  FileView {
    id: rotationCacheView
    printErrors: false
    watchChanges: false

    adapter: JsonAdapter {
      id: rotationCacheAdapter
      property var shuffleQueues: ({})
      property var wallpaperHistory: []
      property int historyPosition: -1
    }

    onLoaded: {
      root.shuffleQueues = rotationCacheAdapter.shuffleQueues || {};
      root.wallpaperHistory = rotationCacheAdapter.wallpaperHistory || [];
      root.historyPosition = rotationCacheAdapter.historyPosition >= 0 ? rotationCacheAdapter.historyPosition : (root.wallpaperHistory.length - 1);
      Logger.d("Wallpaper", "Loaded rotation state: queues for", Object.keys(root.shuffleQueues).length, "screens, history:", root.wallpaperHistory.length, "entries");
    }

    onLoadFailed: error => {
      root.shuffleQueues = {};
      root.wallpaperHistory = [];
      root.historyPosition = -1;
      Logger.d("Wallpaper", "Rotation cache doesn't exist, starting fresh");
    }
  }

  Timer {
    id: rotationSaveTimer
    interval: 1000
    repeat: false
    onTriggered: {
      rotationCacheAdapter.shuffleQueues = root.shuffleQueues;
      rotationCacheAdapter.wallpaperHistory = root.wallpaperHistory;
      rotationCacheAdapter.historyPosition = root.historyPosition;
      rotationCacheView.writeAdapter();
      Logger.d("Wallpaper", "Saved rotation state");
    }
  }

  Timer {
    id: autoOutpaintRetryTimer
    interval: 1000
    repeat: false
    onTriggered: _processAutoOutpaintQueue()
  }

  // Reset shuffle queues when wallpaper list changes
  Connections {
    target: root
    function onWallpaperListChanged(screenName, count) {
      // Invalidate shuffle queue for this screen when its list changes
      if (root.shuffleQueues[screenName]) {
        delete root.shuffleQueues[screenName];
        Logger.d("Wallpaper", "Shuffle queue invalidated for", screenName, "due to list change");
      }
    }
  }
}
