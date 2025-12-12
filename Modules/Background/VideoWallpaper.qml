import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    required property string screenName
    property string videoSource: ""
    property bool active: false

    // Internal state
    property string currentVideo: ""
    property string pendingVideo: ""
    property bool transitioning: false
    property bool videoReady: false
    property bool hasError: false
    
    // Desktop focus detection - true when a window is focused on this screen
    property bool hasWindowFocused: false

    readonly property int transitionDuration: Settings.data.wallpaper.transitionDuration || 800
    readonly property var transitionTypes: ["fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "wave"]
    
    // Check if video should be playing
    readonly property bool shouldPlay: root.active && root.currentVideo !== "" && !root.transitioning && !root.isPaused
    readonly property bool isPaused: VideoWallpaperService.pauseOnFullscreen && root.hasWindowFocused

    visible: active && (currentVideo !== "" || transitioning)

    // Check if any fullscreen window exists
    function checkFullscreen() {
        fullscreenCheckProc.running = true
    }
    
    Process {
        id: fullscreenCheckProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var json = JSON.parse(data)
                    // fullscreen: 0 = not fullscreen, 1 = fullscreen, 2 = maximized
                    if (json && json.fullscreen && json.fullscreen > 0) {
                        root.hasWindowFocused = true
                    } else {
                        root.hasWindowFocused = false
                    }
                } catch (e) {
                    root.hasWindowFocused = false
                }
            }
        }
    }
    
    // Check periodically
    Timer {
        interval: 1000
        running: root.active && VideoWallpaperService.pauseOnFullscreen
        repeat: true
        onTriggered: root.checkFullscreen()
    }

    // Loading/error indicator
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        visible: root.hasError || (!root.videoReady && root.currentVideo !== "" && !root.transitioning && !root.isPaused)
        opacity: 0.9
        z: 50

        NIcon {
            anchors.centerIn: parent
            icon: root.hasError ? "alert-triangle" : "refresh"
            pointSize: 48
            color: Color.mOnSurfaceVariant
            RotationAnimation on rotation {
                running: !root.hasError && !root.videoReady && !root.isPaused
                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
            }
        }
    }

    // swww transition process
    Process {
        id: swwwProc
        onExited: (code, status) => {
            root.currentVideo = root.pendingVideo
            root.pendingVideo = ""
            root.transitioning = false
        }
    }

    // mpvpaper playback - use Loader to properly restart process
    Loader {
        id: mpvLoader
        active: root.shouldPlay && root.currentVideo !== ""
        
        sourceComponent: Process {
            id: mpvProc
            
            property string opts: ["loop", "panscan=1.0", VideoWallpaperService.isMuted ? "no-audio" : "volume=30"].join(" ")

            command: ["mpvpaper", "-o", opts, root.screenName, root.currentVideo]
            running: true

            onStarted: { root.videoReady = true; root.hasError = false }
            onExited: (code, status) => {
                root.videoReady = false
                if (code !== 0 && root.active && !root.transitioning && !root.isPaused) root.hasError = true
            }
        }
    }
    
    // Kill mpvpaper when loader deactivates
    onShouldPlayChanged: {
        if (!shouldPlay && mpvLoader.item && mpvLoader.item.running) {
            mpvLoader.item.signal(15)
        }
    }

    function doTransition(newVideo) {
        if (mpvLoader.item && mpvLoader.item.running) mpvLoader.item.signal(15)
        
        transitioning = true
        pendingVideo = newVideo
        
        VideoWallpaperService.generateThumbnail(newVideo, function(thumb) {
            if (thumb) {
                var t = transitionTypes[Math.floor(Math.random() * transitionTypes.length)]
                swwwProc.command = ["swww", "img", thumb,
                    "--transition-type", t,
                    "--transition-duration", (transitionDuration / 1000).toFixed(1),
                    "--transition-fps", "60",
                    "--outputs", root.screenName]
                swwwProc.running = true
            } else {
                // Fallback: switch directly without transition
                root.currentVideo = newVideo
                root.pendingVideo = ""
                root.transitioning = false
            }
        }, "full")
    }

    onVideoSourceChanged: {
        if (!videoSource || videoSource === currentVideo) return
        
        if (transitioning) {
            // Update target, current transition will complete then mpvpaper plays this
            pendingVideo = videoSource
            return
        }
        
        if (currentVideo === "") {
            currentVideo = videoSource
        } else {
            doTransition(videoSource)
        }
    }

    onActiveChanged: {
        if (!active && mpvLoader.item && mpvLoader.item.running) mpvLoader.item.signal(15)
        if (active && videoSource && !currentVideo) currentVideo = videoSource
        if (active) checkFullscreen()
    }

    Component.onCompleted: {
        if (active && videoSource) currentVideo = videoSource
        checkFullscreen()
    }

    Component.onDestruction: {
        if (mpvLoader.item && mpvLoader.item.running) mpvLoader.item.signal(15)
    }
}
