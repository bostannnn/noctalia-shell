pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Helpers/sha256.js" as Checksum
import qs.Commons

Singleton {
  id: root

  readonly property string cacheDir: Settings.cacheDirImagesWallpapers + "preprocessed/"
   // Manifest persisted to disk to skip revalidation across sessions
  readonly property string manifestPath: cacheDir + "manifest.json"
  property bool imageMagickAvailable: false
  property bool initialized: false
  property var sessionCache: ({})
  property var manifestData: ({})
  property bool manifestLoaded: false
  readonly property int sessionCacheTtlMs: 5 * 60 * 1000

  // Track pending preprocessing operations
  // key: cacheKey, value: { callbacks: [], sourcePath: string, screenName: string }
  property var pendingRequests: ({})

  // Queue system to prevent file descriptor exhaustion
  property var processQueue: []
  property int activeProcesses: 0
  readonly property int maxConcurrentProcesses: 3  // Limit concurrent processes

  // Signals
  signal preprocessComplete(string cacheKey, string cachedPath, string screenName)
  signal preprocessFailed(string cacheKey, string error, string screenName)

  // -------------------------------------------------
  function init() {
    Logger.i("WallpaperCache", "Service started");
    Quickshell.execDetached(["mkdir", "-p", cacheDir]);
    loadManifest();
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

    const sessionKey = sourcePath + "@" + width + "x" + height;
    const cachedEntry = sessionCache[sessionKey];
    if (cachedEntry && (Date.now() - cachedEntry.ts) < sessionCacheTtlMs) {
      callback(cachedEntry.path, cachedEntry.success);
      return;
    }

    if (tryPersistentCacheHit(sessionKey, sourcePath, screenName, width, height, callback)) {
      return;
    }

    if (!imageMagickAvailable) {
      // Fallback: return original path
      storeSessionCache(sessionKey, sourcePath, false, sourcePath, width, height, "");
      callback(sourcePath, false);
      return;
    }

    // First check image dimensions - skip preprocessing if image is smaller than screen
    getImageDimensions(sourcePath, function (imgWidth, imgHeight) {
      if (imgWidth > 0 && imgHeight > 0 && imgWidth <= width && imgHeight <= height) {
        // Image is smaller than or equal to screen - no preprocessing needed
        storeSessionCache(sessionKey, sourcePath, false, sourcePath, width, height, "");
        callback(sourcePath, false);
        return;
      }

      // Image is larger - proceed with preprocessing
      proceedWithPreprocessing(sourcePath, screenName, width, height, callback, sessionKey);
    });
  }

  // -------------------------------------------------
  function proceedWithPreprocessing(sourcePath, screenName, width, height, callback, sessionKey) {
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
          storeSessionCache(sessionKey, cachedPath, true, sourcePath, width, height, mtime);
          callback(cachedPath, true);
          return;
        }

        // Re-check pendingRequests in case another request started processing
        if (pendingRequests[cacheKey]) {
          pendingRequests[cacheKey].callbacks.push({
                                                     callback: callback,
                                                     screenName: screenName
                                                   });
          return;
        }

        // Start new processing
        pendingRequests[cacheKey] = {
          callbacks: [
            {
              callback: callback,
              screenName: screenName
            }
          ],
          sourcePath: sourcePath
        };

        startPreprocessing(sourcePath, cachedPath, width, height, cacheKey, screenName, sessionKey, mtime);
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
  function startPreprocessing(sourcePath, outputPath, width, height, cacheKey, screenName, sessionKey, mtime) {
    const command = buildCommand(sourcePath, outputPath, width, height);

    queueProcess(
      ["bash", "-c", command],
      function(exitCode, stdout, stderrText) {
        if (exitCode !== 0) {
          Logger.e("WallpaperCache", "Preprocess failed", JSON.stringify({
                     "cacheKey": cacheKey,
                     "source": sourcePath,
                     "output": outputPath,
                     "error": stderrText
                   }));
          const srcPath = pendingRequests[cacheKey] ? pendingRequests[cacheKey].sourcePath : "";
          notifyCallbacks(cacheKey, srcPath, false);
          preprocessFailed(cacheKey, stderrText, screenName);
        } else {
          storeSessionCache(sessionKey, outputPath, true, sourcePath, width, height, mtime);
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
        try {
          item.callback(path, success);
        } catch (e) {
          Logger.e("WallpaperCache", "Callback error", JSON.stringify({
                     "cacheKey": cacheKey,
                     "error": e.toString()
                   }));
        }
      });
      delete pendingRequests[cacheKey];
    }
  }

  function storeSessionCache(sessionKey, path, success, sourcePath, width, height, mtime) {
    if (!sessionKey || !path)
      return;

    sessionCache[sessionKey] = {
      path: path,
      success: success,
      ts: Date.now(),
      mtime: mtime
    };

    const manifestEntry = {
      path: path,
      success: success,
      source: sourcePath || "",
      width: width || 0,
      height: height || 0,
      mtime: mtime || "",
      ts: Date.now()
    };

    const existing = manifestData[sessionKey];
    const shouldUpdate = !existing
      || existing.path !== manifestEntry.path
      || existing.mtime !== manifestEntry.mtime
      || existing.success !== manifestEntry.success;

    if (shouldUpdate) {
      manifestData[sessionKey] = manifestEntry;
      saveManifest();
    }
  }

  function tryPersistentCacheHit(sessionKey, sourcePath, screenName, width, height, callback) {
    // If manifest hasn't loaded yet, skip persistent cache (it's async)
    if (!manifestLoaded) {
      return false;
    }

    const entry = manifestData[sessionKey];
    if (!entry || !entry.path)
      return false;

    // Trust the manifest - the cached file should exist
    sessionCache[sessionKey] = {
      path: entry.path,
      success: entry.success,
      ts: Date.now(),
      mtime: entry.mtime
    };
    callback(entry.path, entry.success);
    return true;
  }

  function loadManifest() {
    // Use a Process to read the manifest file for reliable loading
    queueProcess(
      ["cat", manifestPath],
      function(exitCode, stdout, stderr) {
        if (exitCode === 0 && stdout) {
          try {
            manifestData = JSON.parse(stdout);
            Logger.i("WallpaperCache", "Loaded manifest with " + Object.keys(manifestData).length + " entries");
          } catch (e) {
            manifestData = ({});
            Logger.w("WallpaperCache", "Failed to parse manifest", e.toString());
          }
        } else {
          manifestData = ({});
          if (exitCode !== 0) {
            Logger.d("WallpaperCache", "No manifest file found, starting fresh");
          }
        }
        manifestLoaded = true;
      },
      "ManifestLoader"
    );
  }

  function saveManifest() {
    try {
      Quickshell.execDetached(["mkdir", "-p", cacheDir]);
      const data = JSON.stringify(manifestData);
      const pathEsc = manifestPath.replace(/'/g, "'\\''");
      const dataEsc = data.replace(/'/g, "'\\''");
      const cmd = "echo '" + dataEsc + "' > '" + pathEsc + "'";
      Quickshell.execDetached(["bash", "-c", cmd]);
    } catch (e) {
      Logger.w("WallpaperCache", "Failed to save manifest", e.toString());
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
    queueProcess(
      ["stat", "-c", "%Y", filePath],
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
    queueProcess(
      ["identify", "-format", "%w %h", filePath + "[0]"],
      function(exitCode, stdout, stderr) {
        if (exitCode !== 0) {
          Logger.w("WallpaperCache", "Identify failed", JSON.stringify({
                     "source": filePath,
                     "error": stderr
                   }));
        }
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
