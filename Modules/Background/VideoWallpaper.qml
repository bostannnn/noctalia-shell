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

    // Internal state
    property string currentVideo: ""
    property string pendingVideo: ""
    property bool transitioning: false
    property bool videoReady: false
    property bool hasError: false

    readonly property int transitionDuration: Settings.data.wallpaper.transitionDuration || 800
    readonly property var transitionTypes: ["fade", "left", "right", "top", "bottom", "wipe", "grow", "center", "outer", "wave"]

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

    // swww transition process
    Process {
        id: swwwProc
        onExited: (code, status) => {
            root.currentVideo = root.pendingVideo
            root.pendingVideo = ""
            root.transitioning = false
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

        onStarted: { root.videoReady = true; root.hasError = false }
        onExited: (code, status) => {
            root.videoReady = false
            if (code !== 0 && root.active && !root.transitioning) root.hasError = true
        }
    }

    function doTransition(newVideo) {
        if (mpvProc.running) mpvProc.signal(15)
        
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
        if (!active && mpvProc.running) mpvProc.signal(15)
        if (active && videoSource && !currentVideo) currentVideo = videoSource
    }

    Component.onCompleted: {
        if (active && videoSource) currentVideo = videoSource
    }

    Component.onDestruction: {
        if (mpvProc.running) mpvProc.signal(15)
    }
}
