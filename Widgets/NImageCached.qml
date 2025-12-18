import QtQuick
import Quickshell
import Quickshell.Io
import "../Helpers/sha256.js" as Checksum
import qs.Commons

Image {
  id: root

  property string imagePath: ""
  property string imageHash: ""
  property string cacheFolder: Settings.cacheDirImages
  property int maxCacheDimension: 384
  readonly property string cachePath: imageHash ? `${cacheFolder}${imageHash}@${maxCacheDimension}x${maxCacheDimension}.png` : ""

  // Track if we're waiting for ImageMagick fallback
  property bool waitingForMagick: false
  // Track if we are regenerating a low-res cache entry
  property bool regeneratingCache: false
  // Track if we're trying to load the original image
  property bool loadingOriginal: false

  asynchronous: true
  fillMode: Image.PreserveAspectCrop
  sourceSize.width: maxCacheDimension
  sourceSize.height: maxCacheDimension
  smooth: true
  onImagePathChanged: {
    loadingTimeout.stop();
    loadingOriginal = false;
    if (imagePath) {
      imageHash = Checksum.sha256(imagePath);
      waitingForMagick = false;
    } else {
      source = "";
      imageHash = "";
      waitingForMagick = false;
    }
  }
  onCachePathChanged: {
    if (imageHash && cachePath) {
      // Try to load the cached version, failure will be detected below in onStatusChanged
      // Failure is expected and warnings are ok in the console. Don't try to improve without consulting.
      source = cachePath;
    }
  }

  // Simplified approach: try Qt first, use ImageMagick fallback on error or timeout
  // For cache miss, just try loading the original directly
  function tryLoadOriginal() {
    if (!imagePath || waitingForMagick) return;
    loadingOriginal = true;
    source = imagePath;
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
      // Cached image was not available - try loading the original
      // Failure is expected and warnings are ok in the console. Don't try to improve without consulting.
      tryLoadOriginal();
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
      waitingForMagick = true;
      generateThumbnailWithMagick();
    } else if (normalizedSource === normalizedImage && status === Image.Ready && imageHash && cachePath) {
      // Original image is shown and fully loaded, time to cache it
      loadingTimeout.stop();
      loadingOriginal = false;
      const grabPath = cachePath;
      if (visible && width > 0 && height > 0 && Window.window && Window.window.visible)
        grabToImage(res => {
                      return res.saveToFile(grabPath);
                    }, Qt.size(maxCacheDimension, maxCacheDimension));
    }
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
      if (exitCode === 0 && root.cachePath) {
        // Thumbnail generated, load it
        root.source = root.cachePath;
      }
      root.waitingForMagick = false;
      root.regeneratingCache = false;
    }
  }
}

