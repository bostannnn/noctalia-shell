import QtQuick
import Quickshell
import Quickshell.Io
import "../Helpers/sha256.js" as Checksum
import "../Helpers/FileUtils.js" as FileUtils
import qs.Commons

Image {
  id: root

  property string imagePath: ""
  property string imageHash: ""
  property string cacheFolder: Settings.cacheDirImages
  property int maxCacheDimension: 384
  readonly property string cachePath: imageHash ? `${cacheFolder}${imageHash}@${maxCacheDimension}x${maxCacheDimension}.png` : ""
  readonly property string cacheUrl: cachePath ? normalizeFilePath(cachePath) : ""

  // Track if we're waiting for ImageMagick fallback
  property bool waitingForMagick: false
  // Track if we are regenerating a low-res cache entry
  property bool regeneratingCache: false
  // Track if we're trying to load the original image
  property bool loadingOriginal: false
  // Track if generation failed to avoid infinite retries
  property bool generationFailed: false

  asynchronous: true
  fillMode: Image.PreserveAspectCrop
  sourceSize.width: maxCacheDimension
  sourceSize.height: maxCacheDimension
  smooth: true
  onImagePathChanged: {
    loadingTimeout.stop();
    loadingOriginal = false;
    ensureCacheDir();
    if (imagePath) {
      imageHash = Checksum.sha256(imagePath);
      waitingForMagick = false;
      generationFailed = false;
    } else {
      source = "";
      imageHash = "";
      waitingForMagick = false;
      generationFailed = false;
    }
  }
  onCachePathChanged: {
    if (imageHash && cachePath) {
      // Try cached thumbnail first; fallback happens in onStatusChanged if it is missing
      ensureCacheDir();
      if (!generationFailed && cacheExists()) {
        source = cacheUrl;
      } else if (!generationFailed) {
        tryLoadOriginal();
      }
    }
  }

  // Simplified approach: try Qt first, use ImageMagick fallback on error or timeout
  // For cache miss, just try loading the original directly
  function tryLoadOriginal() {
    if (!imagePath || waitingForMagick || generationFailed) return;
    loadingOriginal = true;
    source = normalizeFilePath(imagePath);
    // Start timeout - if Qt doesn't load within 3 seconds, use ImageMagick
    loadingTimeout.restart();
  }

  // Timeout for loading original images - some large images make Qt hang forever
  Timer {
    id: loadingTimeout
    interval: 3000
    repeat: false
    onTriggered: {
      if (root.loadingOriginal && root.status === Image.Loading && !root.waitingForMagick) {
        root.loadingOriginal = false;
        root.waitingForMagick = true;
        root.generateThumbnailWithMagick();
      }
    }
  }
  onStatusChanged: {
    // Normalize paths for comparison (remove file:// prefix if present)
    const normalizedSource = source.toString().replace(/^file:\/\//, "");
    const normalizedCache = cachePath.replace(/^file:\/\//, "");
    const normalizedImage = imagePath.replace(/^file:\/\//, "");

    if (normalizedSource === normalizedCache && status === Image.Error) {
      // Cached image failed to load (maybe corrupt/oversized) - rebuild it
      rebuildCacheFromOriginal();
    } else if (normalizedSource === normalizedCache && status === Image.Ready) {
      // If cached thumbnail is smaller than our target, regenerate it to avoid blurriness
      if (!waitingForMagick && (sourceSize.width < maxCacheDimension || sourceSize.height < maxCacheDimension)) {
        waitingForMagick = true;
        regeneratingCache = true;
        generateThumbnailWithMagick();
        return;
      }
    } else if (normalizedSource === normalizedImage && status === Image.Error && !waitingForMagick) {
      // Original image failed to load (too large for Qt) - use ImageMagick fallback
      loadingTimeout.stop();
      loadingOriginal = false;
      rebuildCacheFromOriginal();
    } else if (normalizedSource === normalizedImage && status === Image.Ready && imageHash && cachePath) {
      // Original image is shown and fully loaded, time to cache it if missing
      loadingTimeout.stop();
      loadingOriginal = false;
      cacheIfMissing();
    }
  }

  function normalizeFilePath(path) {
    if (!path)
      return "";
    return path.startsWith("file://") ? path : "file://" + path;
  }

  function ensureCacheDir() {
    if (cacheFolder && cacheFolder !== "") {
      Quickshell.execDetached(["mkdir", "-p", cacheFolder]);
    }
  }

  function cacheExists() {
    return cachePath && FileUtils.fileExists(cachePath, root);
  }

  function rebuildCacheFromOriginal() {
    if (!cachePath || waitingForMagick || generationFailed)
      return;

    // Remove broken cache and regenerate using ImageMagick
    Quickshell.execDetached(["rm", "-f", cachePath]);
    waitingForMagick = true;
    generateThumbnailWithMagick();
  }

  function cacheIfMissing() {
    if (!cachePath || cacheExists() || waitingForMagick || generationFailed)
      return;

    ensureCacheDir();

    const srcPath = imagePath.replace(/^file:\/\//, "");
    const srcEsc = srcPath.replace(/'/g, "'\\''");
    const dstEsc = cachePath.replace(/'/g, "'\\''");
    const size = maxCacheDimension;

    // Use magick (IMv7) with convert fallback
    const cmd = `magick '${srcEsc}[0]' -thumbnail '${size}x${size}^' -gravity center -extent '${size}x${size}' '${dstEsc}' 2>/dev/null || convert '${srcEsc}[0]' -thumbnail '${size}x${size}^' -gravity center -extent '${size}x${size}' '${dstEsc}'`;

    waitingForMagick = true;
    magickProcess.command = ["bash", "-c", cmd];
    magickProcess.running = true;
  }

  // Use ImageMagick to generate thumbnail for images Qt can't decode
  function generateThumbnailWithMagick() {
    if (!imagePath || !cachePath) return;

    const srcPath = imagePath.replace(/^file:\/\//, "");
    const srcEsc = srcPath.replace(/'/g, "'\\''");
    const dstEsc = cachePath.replace(/'/g, "'\\''");
    const size = maxCacheDimension;

    // Use magick (IMv7) with convert fallback
    const cmd = `magick '${srcEsc}[0]' -thumbnail '${size}x${size}^' -gravity center -extent '${size}x${size}' '${dstEsc}' 2>/dev/null || convert '${srcEsc}[0]' -thumbnail '${size}x${size}^' -gravity center -extent '${size}x${size}' '${dstEsc}'`;

    magickProcess.command = ["bash", "-c", cmd];
    magickProcess.running = true;
  }

  Process {
    id: magickProcess
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0 && root.cacheUrl) {
        // Thumbnail generated, load it
        root.source = root.cacheUrl;
        root.generationFailed = false;
      } else if (exitCode !== 0) {
        // Give up to avoid infinite retries on huge/broken files
        root.generationFailed = true;
        root.source = "";
      }
      root.waitingForMagick = false;
      root.regeneratingCache = false;
    }
  }
}
