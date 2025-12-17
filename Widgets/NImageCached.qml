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

  asynchronous: true
  fillMode: Image.PreserveAspectCrop
  sourceSize.width: maxCacheDimension
  sourceSize.height: maxCacheDimension
  smooth: true
  onImagePathChanged: {
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

  // Check if file is too large for Qt (>10MB) and needs ImageMagick
  function checkFileSizeAndLoad() {
    if (!imagePath || waitingForMagick) return;
    const srcPath = imagePath.replace(/^file:\/\//, "");
    fileSizeChecker.srcPath = srcPath;
    fileSizeChecker.command = ["stat", "-c", "%s", srcPath];
    fileSizeChecker.running = true;
  }

  Process {
    id: fileSizeChecker
    property string srcPath: ""
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        const sizeBytes = parseInt(stdout.text.trim(), 10);
        // If file is larger than 10MB, use ImageMagick directly
        if (sizeBytes > 10 * 1024 * 1024) {
          Logger.d("NImageCached", "Large file detected (" + Math.round(sizeBytes/1024/1024) + "MB), using ImageMagick:", srcPath);
          root.waitingForMagick = true;
          root.generateThumbnailWithMagick();
        } else {
          // File is small enough for Qt, try loading it
          root.source = root.imagePath;
        }
      } else {
        // Couldn't check size, try loading anyway
        root.source = root.imagePath;
      }
    }
  }
  onStatusChanged: {
    // Normalize paths for comparison (remove file:// prefix if present)
    const normalizedSource = source.toString().replace(/^file:\/\//, "");
    const normalizedCache = cachePath.replace(/^file:\/\//, "");
    const normalizedImage = imagePath.replace(/^file:\/\//, "");

    // Debug logging
    if (status === Image.Error) {
      console.log("NImageCached Error loading, source:", normalizedSource);
      console.log("NImageCached   cache:", normalizedCache);
      console.log("NImageCached   image:", normalizedImage);
      console.log("NImageCached   match cache?", normalizedSource === normalizedCache);
    }

    if (normalizedSource === normalizedCache && status === Image.Error) {
      // Cached image was not available - check file size before trying original
      Logger.w("NImageCached", "Cache miss, checking file size for:", normalizedImage);
      checkFileSizeAndLoad();
    } else if (normalizedSource === normalizedImage && status === Image.Error && !waitingForMagick) {
      // Original image failed to load (too large for Qt) - use ImageMagick fallback
      waitingForMagick = true;
      generateThumbnailWithMagick();
    } else if (normalizedSource === normalizedImage && status === Image.Ready && imageHash && cachePath) {
      // Original image is shown and fully loaded, time to cache it
      const grabPath = cachePath;
      if (visible && width > 0 && height > 0 && Window.window && Window.window.visible)
        grabToImage(res => {
                      return res.saveToFile(grabPath);
                    });
    }
  }

  // Use ImageMagick to generate thumbnail for images Qt can't decode
  function generateThumbnailWithMagick() {
    if (!imagePath || !cachePath) return;

    const srcPath = imagePath.replace(/^file:\/\//, "");
    const srcEsc = srcPath.replace(/'/g, "'\\''");
    const dstEsc = cachePath.replace(/'/g, "'\\''");
    const size = maxCacheDimension;

    Logger.d("NImageCached", "Generating thumbnail with ImageMagick:", srcPath);

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
        Logger.d("NImageCached", "Thumbnail generated:", root.cachePath);
        // Thumbnail generated, load it
        root.source = root.cachePath;
      } else {
        Logger.w("NImageCached", "ImageMagick thumbnail failed for:", root.imagePath, "error:", stderr.text);
      }
      root.waitingForMagick = false;
    }
  }
}


