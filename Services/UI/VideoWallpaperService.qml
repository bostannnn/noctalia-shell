pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
    id: root

    // Supported extensions
    readonly property var videoExtensions: [".mp4", ".webm", ".mkv", ".avi", ".mov", ".ogv", ".m4v"]

    // State
    property var videoWallpapers: ({})
    property bool isMuted: Settings.data.wallpaper.videoMuted ?? true
    property bool pauseOnFullscreen: Settings.data.wallpaper.videoPauseOnFullscreen ?? true
    property bool isPlaying: true
    property bool isInitialized: false

    readonly property string thumbnailCacheDir: Settings.cacheDir + "video-thumbnails"

    // Signals
    signal videoWallpaperChanged(string screenName, string path)
    signal playbackStateChanged(bool playing)

    function init() {
        Logger.i("VideoWallpaper", "Service init")
        Quickshell.execDetached(["mkdir", "-p", thumbnailCacheDir])
        isInitialized = true
    }

    function isVideoFile(path) {
        if (!path || typeof path !== 'string') return false
        var lower = path.toLowerCase()
        for (var i = 0; i < videoExtensions.length; i++) {
            if (lower.endsWith(videoExtensions[i])) return true
        }
        return false
    }

    function getVideoWallpaper(screenName) {
        return videoWallpapers[screenName] || ""
    }

    function hasVideoWallpaper(screenName) {
        var path = videoWallpapers[screenName]
        return path && path !== "" && isVideoFile(path)
    }

    function setVideoWallpaper(screenName, path) {
        if (isVideoFile(path)) {
            videoWallpapers[screenName] = path
            isPlaying = true
            videoWallpaperChanged(screenName, path)
        } else if (videoWallpapers[screenName]) {
            delete videoWallpapers[screenName]
            videoWallpaperChanged(screenName, "")
        }
    }

    function clearVideoWallpaper(screenName) {
        if (videoWallpapers[screenName]) {
            delete videoWallpapers[screenName]
            videoWallpaperChanged(screenName, "")
        }
    }

    // Playback controls
    function toggleMute() { setMuted(!isMuted) }
    function setMuted(m) { isMuted = m; Settings.data.wallpaper.videoMuted = m }
    function setPauseOnFullscreen(p) { pauseOnFullscreen = p; Settings.data.wallpaper.videoPauseOnFullscreen = p }
    function play() { isPlaying = true; playbackStateChanged(true) }
    function pause() { isPlaying = false; playbackStateChanged(false) }
    function togglePlayback() { isPlaying ? pause() : play() }

    // Thumbnail generation with queue to prevent file descriptor exhaustion
    property var pendingCallbacks: ({})
    property var thumbnailCache: ({})  // Cache of known existing thumbnails
    property var thumbnailQueue: []    // Queue of pending thumbnail requests
    property int activeProcesses: 0
    readonly property int maxConcurrentProcesses: 4  // Limit concurrent ffmpeg processes

    function getThumbnailPath(videoPath, size) {
        var sz = size || "preview"
        var suffix = sz === "full" ? "_full" : ""
        var hash = Qt.md5(videoPath)
        return thumbnailCacheDir + "/" + hash + suffix + ".jpg"
    }

    function generateThumbnail(videoPath, callback, size) {
        if (!videoPath) {
            if (callback) callback(null)
            return
        }

        var outPath = getThumbnailPath(videoPath, size)

        // Check cache first - if we know it exists, return immediately
        if (thumbnailCache[outPath]) {
            if (callback) callback(outPath)
            return
        }

        // Add to queue
        thumbnailQueue.push({
            videoPath: videoPath,
            outPath: outPath,
            callback: callback,
            scale: (size === "full") ? "-1:-1" : "320:-1"
        })

        // Process queue
        processQueue()
    }

    function processQueue() {
        // Don't exceed max concurrent processes
        while (activeProcesses < maxConcurrentProcesses && thumbnailQueue.length > 0) {
            var item = thumbnailQueue.shift()
            startThumbnailProcess(item)
        }
    }

    function startThumbnailProcess(item) {
        activeProcesses++

        var proc = procComponent.createObject(root, {
            videoPath: item.videoPath,
            outPath: item.outPath,
            callback: item.callback,
            scale: item.scale
        })
        proc.running = true
    }

    Component {
        id: procComponent

        Process {
            property string videoPath
            property string outPath
            property var callback
            property string scale

            command: ["bash", "-c",
                '[ -f "' + outPath + '" ] && exit 0; ' +
                'ffmpeg -y -i "' + videoPath + '" -ss 00:00:01 -vframes 1 -vf scale=' + scale + ' -q:v 2 "' + outPath + '" 2>/dev/null'
            ]

            onExited: (code, status) => {
                root.activeProcesses--

                if (code === 0) {
                    // Cache the result
                    root.thumbnailCache[outPath] = true
                    if (callback) callback(outPath)
                } else {
                    if (callback) callback(null)
                }

                // Process next item in queue
                root.processQueue()

                destroy()
            }
        }
    }

    // Settings sync - watch for external changes via property bindings
    Binding {
        target: root
        property: "isMuted"
        value: Settings.data.wallpaper.videoMuted ?? true
    }
    
    Binding {
        target: root
        property: "pauseOnFullscreen"
        value: Settings.data.wallpaper.videoPauseOnFullscreen ?? true
    }
}


