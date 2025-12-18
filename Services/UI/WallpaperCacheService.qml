pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Helpers/sha256.js" as Checksum
import qs.Commons

Singleton {
  id: root

  readonly property string cacheDir: Settings.cacheDirImagesWallpapers + "preprocessed/"
  property bool imageMagickAvailable: false
  property bool initialized: false

  // Track pending preprocessing operations
  // key: cacheKey, value: { callbacks: [], sourcePath: string, screenName: string }
  property var pendingRequests: ({})

  // Queue system to prevent file descriptor exhaustion
  property var processQueue: []
  property int activeProcesses: 0
  readonly property int maxConcurrentProcesses: 6  // Limit concurrent processes

  // Signals
  signal preprocessComplete(string cacheKey, string cachedPath, string screenName)
  signal preprocessFailed(string cacheKey, string error, string screenName)

  // -------------------------------------------------
  function init() {
    Logger.i("WallpaperCache", "Service started");
    Quickshell.execDetached(["mkdir", "-p", cacheDir]);
    checkMagickProcess.running = true;
  }

  // -------------------------------------------------
  // Main API: Request preprocessed wallpaper
  // callback signature: function(cachedPath: string, success: bool)
  function getPreprocessed(sourcePath, screenName, width, height, callback) {
    if (!sourcePath || sourcePath === "") {
      callback("", false);
      return;
    }

    if (!imageMagickAvailable) {
      // Fallback: return original path
      Logger.d("WallpaperCache", "ImageMagick not available, using original:", sourcePath);
      callback(sourcePath, false);
      return;
    }

    // First check image dimensions - skip preprocessing if image is smaller than screen
    getImageDimensions(sourcePath, function (imgWidth, imgHeight) {
      if (imgWidth > 0 && imgHeight > 0 && imgWidth <= width && imgHeight <= height) {
        // Image is smaller than or equal to screen - no preprocessing needed
        Logger.d("WallpaperCache", `Image ${imgWidth}x${imgHeight} <= screen ${width}x${height}, using original`);
        callback(sourcePath, false);
        return;
      }

      // Image is larger - proceed with preprocessing
      proceedWithPreprocessing(sourcePath, screenName, width, height, callback);
    });
  }

  // -------------------------------------------------
  function proceedWithPreprocessing(sourcePath, screenName, width, height, callback) {
    // Get mtime for cache invalidation
    getMtime(sourcePath, function (mtime) {
      const cacheKey = generateCacheKey(sourcePath, width, height, mtime);
      const cachedPath = cacheDir + cacheKey + ".jpg";

      // Check if already processing this exact request
      if (pendingRequests[cacheKey]) {
        pendingRequests[cacheKey].callbacks.push({
                                                   callback: callback,
                                                   screenName: screenName
                                                 });
        Logger.d("WallpaperCache", "Coalescing request for:", cacheKey);
        return;
      }

      // Check cache first
      checkFileExists(cachedPath, function (exists) {
        if (exists) {
          Logger.d("WallpaperCache", "Cache hit:", cachedPath);
          callback(cachedPath, true);
          return;
        }

        // Re-check pendingRequests in case another request started processing
        // while we were checking file existence (race condition fix)
        if (pendingRequests[cacheKey]) {
          pendingRequests[cacheKey].callbacks.push({
                                                     callback: callback,
                                                     screenName: screenName
                                                   });
          Logger.d("WallpaperCache", "Coalescing request (late):", cacheKey);
          return;
        }

        // Start new processing
        Logger.d("WallpaperCache", `Preprocessing ${sourcePath} to ${width}x${height}`);
        pendingRequests[cacheKey] = {
          callbacks: [
            {
              callback: callback,
              screenName: screenName
            }
          ],
          sourcePath: sourcePath
        };

        startPreprocessing(sourcePath, cachedPath, width, height, cacheKey, screenName);
      });
    });
  }

  // -------------------------------------------------
  function generateCacheKey(sourcePath, width, height, mtime) {
    const keyString = sourcePath + "@" + width + "x" + height + "@" + (mtime || "unknown");
    return Checksum.sha256(keyString);
  }

  // -------------------------------------------------
  function buildCommand(sourcePath, outputPath, width, height) {
    // Escape paths for shell
    const srcEsc = sourcePath.replace(/'/g, "'\\''");
    const dstEsc = outputPath.replace(/'/g, "'\\''");

    // Resize to cover screen dimensions, preserve aspect ratio
    // The ^ flag ensures the image covers the target (smaller dimension fits exactly)
    // The > flag ensures we only shrink, never enlarge (prevents blurry upscaling)
    // The shader will handle actual fill mode (crop/fit/center/stretch)
    return `convert '${srcEsc}' -resize '${width}x${height}^>' -quality 95 '${dstEsc}'`;
  }

  // -------------------------------------------------
  function startPreprocessing(sourcePath, outputPath, width, height, cacheKey, screenName) {
    const command = buildCommand(sourcePath, outputPath, width, height);

    queueProcess(
      ["bash", "-c", command],
      function(exitCode, stdout, stderrText) {
        if (exitCode !== 0) {
          Logger.e("WallpaperCache", "Preprocessing failed:", stderrText);
          const srcPath = pendingRequests[cacheKey] ? pendingRequests[cacheKey].sourcePath : "";
          notifyCallbacks(cacheKey, srcPath, false);
          preprocessFailed(cacheKey, stderrText, screenName);
        } else {
          Logger.d("WallpaperCache", "Preprocessing complete:", outputPath);
          notifyCallbacks(cacheKey, outputPath, true);
          preprocessComplete(cacheKey, outputPath, screenName);
        }
      },
      "PreprocessProcess_" + cacheKey
    );
  }

  // -------------------------------------------------
  function notifyCallbacks(cacheKey, path, success) {
    const request = pendingRequests[cacheKey];
    if (request) {
      request.callbacks.forEach(function (item) {
        item.callback(path, success);
      });
      delete pendingRequests[cacheKey];
    }
  }

  // -------------------------------------------------
  // Queue a process for execution with concurrency limiting
  function queueProcess(command, onComplete, name) {
    processQueue.push({
      command: command,
      onComplete: onComplete,
      name: name || "QueuedProcess"
    });
    runNextProcess();
  }

  function runNextProcess() {
    while (activeProcesses < maxConcurrentProcesses && processQueue.length > 0) {
      const item = processQueue.shift();
      executeProcess(item);
    }
  }

  function executeProcess(item) {
    activeProcesses++;

    const processString = `
      import QtQuick
      import Quickshell.Io
      Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `;

    try {
      const processObj = Qt.createQmlObject(processString, root, item.name);
      processObj.command = item.command;

      processObj.exited.connect(function (exitCode) {
        root.activeProcesses--;
        item.onComplete(exitCode, processObj.stdout.text, processObj.stderr.text);
        processObj.destroy();
        root.runNextProcess();
      });

      processObj.running = true;
    } catch (e) {
      Logger.e("WallpaperCache", "Failed to create process:", e);
      activeProcesses--;
      item.onComplete(-1, "", "Failed to create process");
      runNextProcess();
    }
  }

  // -------------------------------------------------
  function getMtime(filePath, callback) {
    const pathEsc = filePath.replace(/'/g, "'\\''");
    queueProcess(
      ["stat", "-c", "%Y", pathEsc],
      function(exitCode, stdout, stderr) {
        callback(exitCode === 0 ? stdout.trim() : "");
      },
      "MtimeProcess"
    );
  }

  // -------------------------------------------------
  function checkFileExists(filePath, callback) {
    queueProcess(
      ["test", "-f", filePath],
      function(exitCode, stdout, stderr) {
        callback(exitCode === 0);
      },
      "FileExistsProcess"
    );
  }

  // -------------------------------------------------
  // Get image dimensions using ImageMagick identify
  function getImageDimensions(filePath, callback) {
    const pathEsc = filePath.replace(/'/g, "'\\''");
    queueProcess(
      ["identify", "-format", "%w %h", pathEsc + "[0]"],
      function(exitCode, stdout, stderr) {
        let width = 0, height = 0;
        if (exitCode === 0) {
          const parts = stdout.trim().split(" ");
          if (parts.length >= 2) {
            width = parseInt(parts[0], 10) || 0;
            height = parseInt(parts[1], 10) || 0;
          }
        }
        callback(width, height);
      },
      "IdentifyProcess"
    );
  }

  // -------------------------------------------------
  // Utility: Clear cache for a specific source
  function invalidateForSource(sourcePath) {
    // Since cache keys include the source path hash, we'd need to track mappings
    // For simplicity, this clears the entire cache
    Logger.i("WallpaperCache", "Invalidating cache for:", sourcePath);
    clearAllCache();
  }

  // -------------------------------------------------
  // Utility: Clear entire cache
  function clearAllCache() {
    Logger.i("WallpaperCache", "Clearing all cache");
    Quickshell.execDetached(["rm", "-rf", cacheDir]);
    Quickshell.execDetached(["mkdir", "-p", cacheDir]);
  }

  // -------------------------------------------------
  // Check if ImageMagick is available
  Process {
    id: checkMagickProcess
    command: ["which", "convert"]
    running: false

    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      root.imageMagickAvailable = (exitCode === 0);
      root.initialized = true;
      if (root.imageMagickAvailable) {
        Logger.i("WallpaperCache", "ImageMagick available");
      } else {
        Logger.w("WallpaperCache", "ImageMagick not found, caching disabled");
      }
    }
  }
}
