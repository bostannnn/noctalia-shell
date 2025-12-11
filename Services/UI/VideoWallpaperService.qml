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

    // Thumbnail generation with callbacks stored by unique key
    property var pendingCallbacks: ({})

    function generateThumbnail(videoPath, callback, size) {
        if (!videoPath) {
            if (callback) callback(null)
            return
        }
        
        var sz = size || "preview"
        var suffix = sz === "full" ? "_full" : ""
        var hash = Qt.md5(videoPath)
        var outPath = thumbnailCacheDir + "/" + hash + suffix + ".jpg"
        
        // Unique key includes a timestamp to prevent callback overwrites
        var callbackKey = hash + suffix + "_" + Date.now()
        
        if (callback) {
            pendingCallbacks[callbackKey] = callback
        }
        
        var proc = procComponent.createObject(root, {
            videoPath: videoPath,
            outPath: outPath,
            callbackKey: callbackKey,
            scale: sz === "full" ? "-1:-1" : "320:-1"
        })
        proc.running = true
    }
    
    Component {
        id: procComponent
        
        Process {
            property string videoPath
            property string outPath
            property string callbackKey
            property string scale
            
            command: ["bash", "-c", 
                '[ -f "' + outPath + '" ] && exit 0; ' +
                'ffmpeg -y -i "' + videoPath + '" -ss 00:00:01 -vframes 1 -vf scale=' + scale + ' -q:v 2 "' + outPath + '" 2>/dev/null'
            ]
            
            onExited: (code, status) => {
                var cb = root.pendingCallbacks[callbackKey]
                if (cb) {
                    delete root.pendingCallbacks[callbackKey]
                    cb(code === 0 ? outPath : null)
                }
                destroy()
            }
        }
    }

    Connections {
        target: Settings.data.wallpaper
        function onVideoMutedChanged() { root.isMuted = Settings.data.wallpaper.videoMuted ?? true }
        function onVideoPauseOnFullscreenChanged() { root.pauseOnFullscreen = Settings.data.wallpaper.videoPauseOnFullscreen ?? true }
    }
}
