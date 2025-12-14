import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    required property string screenName
    property string videoSource: ""
    property bool active: false
    
    // Previous display state (captured from Background.qml at creation)
    property string previousSource: ""
    property bool previousWasVideo: false

    // Internal state
    property string currentVideo: ""
    property string pendingVideo: ""
    property bool transitioning: false
    property bool videoReady: false
    property bool hasError: false
    
    // Thumbnail of current video
    property string currentThumbnail: ""
    
    // Signals for Background.qml
    signal thumbnailReady(string thumbnailPath)
    signal videoStarted()

    readonly property int transitionDuration: Settings.data.wallpaper.transitionDuration || 800
    readonly property var swwwTransitions: ["fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "wave"]

    visible: active && (currentVideo !== "" || transitioning)

    // Loading/error indicator
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        visible: root.hasError || (!root.videoReady && root.currentVideo !== "" && !root.transitioning)
        opacity: 0.9
        z: 50

        NIcon {
            anchors.centerIn: parent
            icon: root.hasError ? "alert-triangle" : "refresh"
            pointSize: 48
            color: Color.mOnSurfaceVariant
            RotationAnimation on rotation {
                running: !root.hasError && !root.videoReady
                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
            }
        }
    }

    // swww sync process (sets swww to current state before transition)
    Process {
        id: swwwSyncProc
        onExited: (code, status) => {
            if (code !== 0) {
                Logger.w("VideoWallpaper", "swww sync failed with code:", code)
            }
            // Check if we're still active and should continue
            if (!root.active) {
                resetState();
                return;
            }
            doThumbnailTransition();
        }
    }

    // swww transition process
    Process {
        id: swwwProc
        onExited: (code, status) => {
            if (code !== 0) {
                Logger.w("VideoWallpaper", "swww transition failed with code:", code)
            }
            
            // Check if we're still active
            if (!root.active) {
                resetState();
                return;
            }
            
            root.currentVideo = root.pendingVideo;
            root.pendingVideo = "";
            root.transitioning = false;
            Logger.d("VideoWallpaper", "swww transition complete, now playing:", root.currentVideo)
            
            // Check if videoSource changed during transition - need another transition
            if (root.videoSource !== "" && root.videoSource !== root.currentVideo) {
                Logger.d("VideoWallpaper", "videoSource changed during transition, starting new transition")
                Qt.callLater(function() {
                    startTransition(root.videoSource, false);
                });
            }
        }
    }

    // mpvpaper playback process
    Process {
        id: mpvProc
        
        property string opts: ["loop", "panscan=1.0", VideoWallpaperService.isMuted ? "no-audio" : "volume=30"].join(" ")

        command: root.currentVideo && root.active && !root.transitioning 
            ? ["mpvpaper", "-o", opts, root.screenName, root.currentVideo] 
            : []

        running: root.active && root.currentVideo !== "" && !root.transitioning

        onStarted: { 
            root.videoReady = true; 
            root.hasError = false;
            root.videoStarted();
        }
        onExited: (code, status) => {
            root.videoReady = false;
            if (code !== 0 && root.active && !root.transitioning) root.hasError = true;
        }
    }

    // Reset all state
    function resetState() {
        transitioning = false;
        pendingVideo = "";
        currentVideo = "";
        currentThumbnail = "";
        videoReady = false;
        hasError = false;
        Logger.d("VideoWallpaper", "State reset")
    }

    // Get transition type from settings
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

    // Unified transition function
    function startTransition(videoPath, needsSync) {
        // Kill any running video
        if (mpvProc.running) mpvProc.signal(15);
        
        // If already transitioning, just update the target
        if (transitioning) {
            Logger.d("VideoWallpaper", "Already transitioning, updating target to:", videoPath)
            pendingVideo = videoPath;
            return;
        }
        
        transitioning = true;
        pendingVideo = videoPath;
        
        if (needsSync && root.previousSource !== "" && !root.previousWasVideo) {
            // Sync swww with previous image first
            Logger.d("VideoWallpaper", "Syncing swww with:", root.previousSource)
            swwwSyncProc.command = ["swww", "img", root.previousSource,
                "--transition-type", "none",
                "--outputs", root.screenName];
            swwwSyncProc.running = true;
        } else {
            // No sync needed, go directly to transition
            doThumbnailTransition();
        }
    }
    
    // Generate thumbnail and do swww transition
    function doThumbnailTransition() {
        // Double-check we're still active
        if (!root.active) {
            resetState();
            return;
        }
        
        var targetVideo = pendingVideo;
        
        VideoWallpaperService.generateThumbnail(targetVideo, function(thumb) {
            // Check if still active and target hasn't changed
            if (!root.active) {
                resetState();
                return;
            }
            
            if (thumb) {
                currentThumbnail = "file://" + thumb;
                thumbnailReady(currentThumbnail);
                
                var t = getTransitionType();
                var duration = (transitionDuration / 1000).toFixed(1);
                
                if (t === "none") {
                    swwwProc.command = ["swww", "img", thumb,
                        "--transition-type", "none",
                        "--outputs", root.screenName];
                } else {
                    swwwProc.command = ["swww", "img", thumb,
                        "--transition-type", t,
                        "--transition-duration", duration,
                        "--transition-fps", "60",
                        "--outputs", root.screenName];
                }
                
                Logger.d("VideoWallpaper", "swww transition to thumbnail:", thumb, "type:", t)
                swwwProc.running = true;
            } else {
                // Fallback: start video directly without thumbnail transition
                Logger.w("VideoWallpaper", "No thumbnail generated, starting video directly")
                root.currentVideo = root.pendingVideo;
                root.pendingVideo = "";
                root.transitioning = false;
            }
        }, "full");
    }

    onVideoSourceChanged: {
        if (!active) return;
        if (!videoSource || videoSource === "") return;
        if (videoSource === currentVideo && !transitioning) return;
        
        Logger.d("VideoWallpaper", "videoSource changed to:", videoSource, "current:", currentVideo, "transitioning:", transitioning)
        
        if (currentVideo === "" && !transitioning) {
            // First video - may need to sync with previous image
            startTransition(videoSource, true);
        } else {
            // Video to video or update during transition
            startTransition(videoSource, false);
        }
    }

    onActiveChanged: {
        Logger.d("VideoWallpaper", "active changed to:", active)
        
        if (!active) {
            // Becoming inactive - kill everything and reset
            if (mpvProc.running) mpvProc.signal(15);
            swwwProc.running = false;
            swwwSyncProc.running = false;
            resetState();
        } else if (videoSource && videoSource !== "" && !currentVideo && !transitioning) {
            // Becoming active with a video source
            startTransition(videoSource, true);
        }
    }

    Component.onCompleted: {
        if (active && videoSource && videoSource !== "") {
            startTransition(videoSource, true);
        }
    }

    Component.onDestruction: {
        if (mpvProc.running) mpvProc.signal(15);
        swwwProc.running = false;
        swwwSyncProc.running = false;
    }
}
