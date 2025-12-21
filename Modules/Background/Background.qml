import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "." as Background

Variants {
  id: backgroundVariants
  model: Quickshell.screens

  delegate: Loader {

    required property ShellScreen modelData

    active: modelData && Settings.data.wallpaper.enabled

    sourceComponent: NLayerShellWindow {
      id: root

      // Track what we're ACTUALLY displaying
      property string lastDisplayedSource: ""
      property bool lastDisplayedWasVideo: false
      
      // Cached video thumbnail for smooth transitions FROM video
      property string cachedVideoThumbnail: ""
      
      // Used to debounce wallpaper changes
      property string futureWallpaper: ""
      
      // Track the wallpaper we're currently transitioning to
      property string transitionTarget: ""
      
      // Transition state
      property bool transitioning: false
      
      // swww daemon status
      property bool swwwReady: false

      // swww transition types
      readonly property var swwwTransitions: ["fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "wave"]

      Component.onCompleted: checkSwwwDaemon()

      Component.onDestruction: {
        debounceTimer.stop();
        swwwProc.running = false;
        swwwCheckProc.running = false;
      }

      // External state management
      Connections {
        target: WallpaperService
        function onWallpaperChanged(screenName, path) {
          if (screenName !== modelData.name) return;

          // Skip for video files - VideoWallpaper handles those
          if (VideoWallpaperService.isVideoFile(path)) {
            Logger.d("Background", "Video wallpaper requested:", path)
            return;
          }

          // Queue image transition
          futureWallpaper = path;
          debounceTimer.restart();
        }
      }

      // Re-apply wallpaper when fill mode changes
      Connections {
        target: WallpaperService
        function onReapplyWallpapers() {
          if (!swwwReady || !lastDisplayedSource || lastDisplayedSource === "") return;
          // Skip if currently showing video
          if (VideoWallpaperService.isVideoFile(lastDisplayedSource)) return;

          Logger.d("Background", "Re-applying wallpaper with new fill mode")
          // Re-apply with instant transition to show fill mode change immediately
          var resizeMode = getResizeMode();
          swwwProc.command = ["swww", "img", lastDisplayedSource,
            "--transition-type", "none",
            "--resize", resizeMode,
            "--outputs", modelData.name];
          swwwProc.running = true;
        }
      }

      color: Color.transparent
      screen: modelData
      layerShellLayer: WlrLayer.Background
      layerShellExclusionMode: ExclusionMode.Ignore
      layerNamespace: "noctalia-wallpaper-" + (screen?.name || "unknown")

      anchors {
        bottom: true
        top: true
        right: true
        left: true
      }

      Timer {
        id: debounceTimer
        interval: 333
        running: false
        repeat: false
        onTriggered: doTransition()
      }

      // Check if swww-daemon is running
      Process {
        id: swwwCheckProc
        onExited: (code, status) => {
          if (code !== 0) {
            Logger.e("Background", "swww-daemon not running! Start with: swww-daemon &")
            root.swwwReady = false;
            return;
          }
          root.swwwReady = true;
          setWallpaperInitial();
        }
      }

      // swww transition process
      Process {
        id: swwwProc
        onExited: (code, status) => {
          if (code !== 0) {
            Logger.w("Background", "swww transition failed with code:", code)
          }
          
          root.lastDisplayedSource = root.transitionTarget;
          root.lastDisplayedWasVideo = false;
          root.cachedVideoThumbnail = "";
          root.transitioning = false;
          Logger.d("Background", "swww transition complete, now showing:", root.transitionTarget)
          
          // Check if futureWallpaper changed during transition
          if (root.futureWallpaper !== "" && root.futureWallpaper !== root.transitionTarget) {
            Logger.d("Background", "Wallpaper changed during transition, starting new transition")
            Qt.callLater(doTransition);
          }
          
          root.transitionTarget = "";
        }
      }

      function checkSwwwDaemon() {
        swwwCheckProc.command = ["swww", "query"];
        swwwCheckProc.running = true;
      }

      function getTransitionType() {
        var t = Settings.data.wallpaper.transitionType || "fade";
        if (t === "random") {
          t = swwwTransitions[Math.floor(Math.random() * swwwTransitions.length)];
        }
        // Map custom types to swww equivalents
        if (t === "disc") t = "center";
        if (t === "stripes") t = "wipe";
        return t;
      }

      // Map fillMode setting to swww --resize parameter
      function getResizeMode() {
        var mode = Settings.data.wallpaper.fillMode || "crop";
        // swww supports: no, crop, fit
        // We map: center->no, crop->crop, fit->fit, stretch->crop (closest approximation)
        switch (mode) {
          case "center": return "no";
          case "fit": return "fit";
          case "stretch": return "crop"; // swww doesn't have stretch, crop is closest
          default: return "crop";
        }
      }

      function doTransition() {
        if (!futureWallpaper || futureWallpaper === "") return;
        if (!swwwReady) {
          Logger.w("Background", "swww not ready, skipping transition")
          return;
        }
        
        // If already transitioning to this target, skip
        if (transitioning && transitionTarget === futureWallpaper) {
          Logger.d("Background", "Already transitioning to:", futureWallpaper)
          return;
        }
        
        // If transitioning to something else, let it finish (onExited will start new one)
        if (transitioning) {
          Logger.d("Background", "Transition in progress, will queue:", futureWallpaper)
          return;
        }
        
        var transitionType = getTransitionType();
        var duration = (Settings.data.wallpaper.transitionDuration || 800) / 1000;
        
        transitionTarget = futureWallpaper;
        var resizeMode = getResizeMode();

        if (transitionType === "none") {
          swwwProc.command = ["swww", "img", futureWallpaper,
            "--transition-type", "none",
            "--resize", resizeMode,
            "--outputs", modelData.name];
        } else {
          swwwProc.command = ["swww", "img", futureWallpaper,
            "--transition-type", transitionType,
            "--transition-duration", duration.toFixed(1),
            "--transition-fps", "60",
            "--resize", resizeMode,
            "--outputs", modelData.name];
        }
        
        Logger.d("Background", "swww transition to:", futureWallpaper, "type:", transitionType)
        root.transitioning = true;
        swwwProc.running = true;
      }

      function setWallpaperInitial() {
        // Wait for service to be ready
        if (!WallpaperService || !WallpaperService.isInitialized) {
          Qt.callLater(setWallpaperInitial);
          return;
        }

        const wallpaperPath = WallpaperService.getWallpaper(modelData.name);
        
        // Check for null/empty path
        if (!wallpaperPath || wallpaperPath === "") {
          Logger.d("Background", "No initial wallpaper set")
          return;
        }

        // Skip for video files
        if (VideoWallpaperService.isVideoFile(wallpaperPath)) {
          Logger.d("Background", "Initial wallpaper is video, skipping")
          return;
        }

        // Set initial wallpaper without transition
        futureWallpaper = wallpaperPath;
        transitionTarget = wallpaperPath;
        root.transitioning = true;
        var resizeMode = getResizeMode();
        swwwProc.command = ["swww", "img", wallpaperPath,
          "--transition-type", "none",
          "--resize", resizeMode,
          "--outputs", modelData.name];
        swwwProc.running = true;
      }

      // Video wallpaper overlay
      Loader {
        id: videoWallpaperLoader
        anchors.fill: parent
        active: (VideoWallpaperService.isInitialized && VideoWallpaperService.hasVideoWallpaper(modelData.name)) || false
        z: 10

        property string videoPath: VideoWallpaperService.getVideoWallpaper(modelData.name) || ""

        Connections {
          target: VideoWallpaperService
          function onVideoWallpaperChanged(screenName, path) {
            if (screenName === modelData.name) {
              videoWallpaperLoader.active = (path && path !== "")
              videoWallpaperLoader.videoPath = path || ""
            }
          }
        }

        sourceComponent: Background.VideoWallpaper {
          id: videoWallpaper
          screenName: modelData.name
          active: videoWallpaperLoader.active
          videoSource: videoWallpaperLoader.videoPath
          
          // Capture values at component creation (not live bindings)
          Component.onCompleted: {
            previousSource = root.lastDisplayedSource;
            previousWasVideo = root.lastDisplayedWasVideo;
          }
          
          // Cache thumbnail for smooth transitions FROM video
          onThumbnailReady: function(thumbnailPath) {
            root.cachedVideoThumbnail = thumbnailPath;
            Logger.d("Background", "Video thumbnail cached:", thumbnailPath)
          }
          
          // Track when video actually starts playing
          onVideoStarted: {
            root.lastDisplayedWasVideo = true;
            root.lastDisplayedSource = videoWallpaperLoader.videoPath;
            Logger.d("Background", "Video now playing, updated lastDisplayed")
          }
        }
      }
    }
  }
}

