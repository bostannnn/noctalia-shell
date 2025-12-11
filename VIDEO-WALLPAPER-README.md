# Video Wallpaper Feature for Noctalia Shell

## What is this?

This feature allows you to use **video files as your desktop wallpaper** instead of just static images. When you select a video in the wallpaper picker, it will play on loop as your desktop background.

### Features at a Glance

- ✅ **Video playback** - MP4, WebM, MKV, and other video formats work as wallpapers
- ✅ **Animated transitions** - When switching between videos, a smooth animation plays (fade, wipe, grow, etc.)
- ✅ **Thumbnail previews** - Videos show a preview image in the wallpaper picker
- ✅ **Videos shown first** - Video files appear at the top of the wallpaper list
- ✅ **Color scheme generation** - Your desktop colors can be generated from the video
- ✅ **Mute control** - Option to mute video audio in settings

---

## Requirements

You need these programs installed on your NixOS system:

```nix
environment.systemPackages = with pkgs; [
  mpvpaper    # Plays the video as wallpaper
  ffmpeg      # Creates thumbnail images from videos
  swww        # Handles smooth transitions between wallpapers
];
```

**Important:** The `swww-daemon` must be running. Add this to your Hyprland config:

```nix
wayland.windowManager.hyprland.settings = {
  exec-once = [
    "swww-daemon"
  ];
};
```

---

## Files Changed

Here's every file that was modified or created, with explanations of what each does:

### 1. NEW FILE: `Services/UI/VideoWallpaperService.qml`

**What it does:** This is the "brain" of the video wallpaper feature. It keeps track of which screen has which video, and handles creating thumbnail images.

**In simple terms:** Think of it like a manager that:
- Remembers "Screen 1 is playing video A, Screen 2 is playing video B"
- Creates small preview pictures from videos so you can see them before selecting
- Tells other parts of the program when a video changes

### 2. NEW FILE: `Modules/Background/VideoWallpaper.qml`

**What it does:** This is the actual video player component. When you select a video wallpaper, this file controls playing it.

**In simple terms:** Think of it like a TV that:
- Shows the video on your desktop
- Handles the cool transition animations when you switch videos
- Shows a loading spinner while the video is starting

### 3. MODIFIED: `Modules/Background/Background.qml`

**What changed:** Added code to load the video wallpaper component when a video is selected.

**In simple terms:** The background system now checks "Is this a video? If yes, use the video player. If no, use the normal image display."

### 4. MODIFIED: `Modules/Panels/Wallpaper/WallpaperPanel.qml`

**What changed:** 
- Videos now show thumbnail previews instead of a blank box
- Videos are sorted to appear first in the list
- A small play icon badge shows on video files

**In simple terms:** The wallpaper picker now understands video files and shows you a preview frame from the video.

### 5. MODIFIED: `Modules/Panels/Settings/Tabs/WallpaperTab.qml`

**What changed:** Added settings for video wallpapers (mute toggle, pause on fullscreen).

**In simple terms:** You can now control video settings like muting the sound.

### 6. MODIFIED: `Services/UI/WallpaperService.qml`

**What changed:** When you select a video, it now tells the VideoWallpaperService about it.

**In simple terms:** The wallpaper system now knows the difference between images and videos and handles them appropriately.

### 7. MODIFIED: `Services/Theming/AppThemeService.qml`

**What changed:** When generating colors from your wallpaper, if it's a video, it uses a thumbnail image instead.

**In simple terms:** Your desktop colors can still match your video wallpaper - it just uses a frame from the video to pick the colors.

### 8. MODIFIED: `Assets/settings-default.json`

**What changed:** Added default settings for video wallpapers.

**In simple terms:** Sets up the initial settings (video muted by default, etc.)

### 9. MODIFIED: `Assets/Translations/en.json`

**What changed:** Added text labels for the new video settings.

**In simple terms:** The buttons and labels in the settings panel have proper names.

### 10. MODIFIED: `shell.qml`

**What changed:** Added initialization of the VideoWallpaperService when the shell starts.

**In simple terms:** Tells the program to start the video wallpaper manager when you log in.

---

## How It Works (Step by Step)

### When you select a video wallpaper:

1. **You click on a video** in the wallpaper picker
2. **WallpaperService** sees it's a video file (ends in .mp4, .webm, etc.)
3. **WallpaperService** tells **VideoWallpaperService** "Hey, play this video on this screen"
4. **VideoWallpaperService** sends a signal saying "video changed!"
5. **Background.qml** receives the signal and loads the **VideoWallpaper** component
6. **VideoWallpaper** runs `mpvpaper` (the video player) to show the video

### When you switch from one video to another:

1. **VideoWallpaper** receives the new video path
2. It kills the current video player
3. It asks **VideoWallpaperService** to create a thumbnail of the new video
4. Once thumbnail is ready, it runs `swww` to animate from current screen to thumbnail
5. After animation, it starts `mpvpaper` with the new video

### When you open the wallpaper picker:

1. **WallpaperPanel** loads the list of files
2. For each video file, it asks **VideoWallpaperService** to create a small thumbnail
3. **VideoWallpaperService** runs `ffmpeg` to extract frame 1 from the video
4. The thumbnail is saved to `~/.cache/noctalia/video-thumbnails/`
5. The picker shows the thumbnail with a small play icon badge

---

## File-by-File Code Explanation

Below is each new/modified file with detailed comments explaining every part.

---

## VideoWallpaperService.qml - The Manager

```qml
pragma Singleton  // This means only ONE instance of this exists (like a global manager)

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
    id: root  // A name we can use to refer to this component

    // ═══════════════════════════════════════════════════════════════════
    // CONFIGURATION - What video file types we support
    // ═══════════════════════════════════════════════════════════════════
    
    // List of file extensions that are videos
    // When checking if a file is a video, we look for these endings
    readonly property var videoExtensions: [".mp4", ".webm", ".mkv", ".avi", ".mov", ".ogv", ".m4v"]

    // ═══════════════════════════════════════════════════════════════════
    // STATE - Information the service keeps track of
    // ═══════════════════════════════════════════════════════════════════
    
    // A dictionary storing which screen has which video
    // Example: { "DP-1": "/home/user/video.mp4", "HDMI-1": "/home/user/other.mp4" }
    property var videoWallpapers: ({})
    
    // Is the video sound muted? (default: yes, muted)
    property bool isMuted: Settings.data.wallpaper.videoMuted ?? true
    
    // Should video pause when a window is fullscreen? (default: yes)
    property bool pauseOnFullscreen: Settings.data.wallpaper.videoPauseOnFullscreen ?? true
    
    // Is video currently playing or paused?
    property bool isPlaying: true
    
    // Has this service finished setting up?
    property bool isInitialized: false

    // Where to save thumbnail images
    // Example: "/home/user/.cache/noctalia/video-thumbnails"
    readonly property string thumbnailCacheDir: Settings.cacheDir + "video-thumbnails"

    // ═══════════════════════════════════════════════════════════════════
    // SIGNALS - Events we tell other parts of the program about
    // ═══════════════════════════════════════════════════════════════════
    
    // Sent when a video wallpaper changes on any screen
    // Other components listen for this to update themselves
    signal videoWallpaperChanged(string screenName, string path)
    
    // Sent when play/pause state changes
    signal playbackStateChanged(bool playing)

    // ═══════════════════════════════════════════════════════════════════
    // INITIALIZATION - Runs once when the program starts
    // ═══════════════════════════════════════════════════════════════════
    
    function init() {
        Logger.i("VideoWallpaper", "Service init")
        // Create the thumbnail folder if it doesn't exist
        // "mkdir -p" means "make directory, and create parent folders if needed"
        Quickshell.execDetached(["mkdir", "-p", thumbnailCacheDir])
        isInitialized = true
    }

    // ═══════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS - Small tools used by other functions
    // ═══════════════════════════════════════════════════════════════════
    
    // Check if a file path is a video file
    // Example: isVideoFile("/home/user/cat.mp4") returns true
    // Example: isVideoFile("/home/user/cat.jpg") returns false
    function isVideoFile(path) {
        // Safety check - make sure we got valid text
        if (!path || typeof path !== 'string') return false
        
        // Convert to lowercase so ".MP4" and ".mp4" both work
        var lower = path.toLowerCase()
        
        // Check if the path ends with any of our video extensions
        for (var i = 0; i < videoExtensions.length; i++) {
            if (lower.endsWith(videoExtensions[i])) return true
        }
        return false
    }

    // Get the video path for a specific screen
    // Returns empty string if no video is set
    function getVideoWallpaper(screenName) {
        return videoWallpapers[screenName] || ""
    }

    // Check if a screen has a video wallpaper
    function hasVideoWallpaper(screenName) {
        var path = videoWallpapers[screenName]
        return path && path !== "" && isVideoFile(path)
    }

    // ═══════════════════════════════════════════════════════════════════
    // MAIN FUNCTIONS - The important stuff
    // ═══════════════════════════════════════════════════════════════════
    
    // Set a video wallpaper for a screen
    // Called when user selects a video in the wallpaper picker
    function setVideoWallpaper(screenName, path) {
        if (isVideoFile(path)) {
            // It's a video - save it and tell everyone
            videoWallpapers[screenName] = path
            isPlaying = true
            videoWallpaperChanged(screenName, path)  // Send signal!
        } else if (videoWallpapers[screenName]) {
            // It's not a video but we had one before - clear it
            delete videoWallpapers[screenName]
            videoWallpaperChanged(screenName, "")  // Send signal with empty path
        }
    }

    // Remove video wallpaper from a screen
    function clearVideoWallpaper(screenName) {
        if (videoWallpapers[screenName]) {
            delete videoWallpapers[screenName]
            videoWallpaperChanged(screenName, "")
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // PLAYBACK CONTROLS - Mute, play, pause
    // ═══════════════════════════════════════════════════════════════════
    
    function toggleMute() { setMuted(!isMuted) }
    
    function setMuted(m) { 
        isMuted = m
        Settings.data.wallpaper.videoMuted = m  // Save to settings file
    }
    
    function setPauseOnFullscreen(p) { 
        pauseOnFullscreen = p
        Settings.data.wallpaper.videoPauseOnFullscreen = p 
    }
    
    function play() { 
        isPlaying = true
        playbackStateChanged(true) 
    }
    
    function pause() { 
        isPlaying = false
        playbackStateChanged(false) 
    }
    
    function togglePlayback() { 
        isPlaying ? pause() : play() 
    }

    // ═══════════════════════════════════════════════════════════════════
    // THUMBNAIL GENERATION - Creating preview images from videos
    // ═══════════════════════════════════════════════════════════════════
    
    // Storage for callback functions waiting for thumbnails
    // When someone requests a thumbnail, we save their callback here
    // and call it when the thumbnail is ready
    property var pendingCallbacks: ({})

    // Generate a thumbnail image from a video file
    // Parameters:
    //   videoPath - the video file to extract from
    //   callback - function to call when done (receives the thumbnail path)
    //   size - "preview" (small, for picker) or "full" (large, for transitions)
    function generateThumbnail(videoPath, callback, size) {
        // Safety check
        if (!videoPath) {
            if (callback) callback(null)
            return
        }
        
        // Determine size settings
        var sz = size || "preview"  // Default to preview size
        var suffix = sz === "full" ? "_full" : ""  // Full size gets "_full" in filename
        
        // Create a unique filename using a hash of the video path
        // This way the same video always gets the same thumbnail name
        var hash = Qt.md5(videoPath)
        var outPath = thumbnailCacheDir + "/" + hash + suffix + ".jpg"
        
        // Create a unique key for this callback
        // We add timestamp so multiple requests for same video don't overwrite each other
        var callbackKey = hash + suffix + "_" + Date.now()
        
        // Save the callback so we can call it later
        if (callback) {
            pendingCallbacks[callbackKey] = callback
        }
        
        // Create a process to run ffmpeg and extract a frame
        var proc = procComponent.createObject(root, {
            videoPath: videoPath,
            outPath: outPath,
            callbackKey: callbackKey,
            scale: sz === "full" ? "-1:-1" : "320:-1"  // -1:-1 = original size, 320:-1 = 320px wide
        })
        proc.running = true  // Start the process!
    }
    
    // This is a template for creating thumbnail extraction processes
    Component {
        id: procComponent
        
        Process {
            // Properties set when creating this process
            property string videoPath   // Input video
            property string outPath     // Output thumbnail path
            property string callbackKey // Key to find callback
            property string scale       // Size scaling
            
            // The command to run
            // This is a bash script that:
            // 1. Checks if thumbnail already exists (skip if it does)
            // 2. Runs ffmpeg to extract frame at 1 second, scaled appropriately
            command: ["bash", "-c", 
                '[ -f "' + outPath + '" ] && exit 0; ' +  // If file exists, exit with success
                'ffmpeg -y -i "' + videoPath + '" -ss 00:00:01 -vframes 1 -vf scale=' + scale + ' -q:v 2 "' + outPath + '" 2>/dev/null'
            ]
            
            // When the process finishes (either success or failure)
            onExited: (code, status) => {
                // Find and call the callback
                var cb = root.pendingCallbacks[callbackKey]
                if (cb) {
                    delete root.pendingCallbacks[callbackKey]  // Clean up
                    cb(code === 0 ? outPath : null)  // Call with path if success, null if failed
                }
                destroy()  // Clean up this process object
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SETTINGS SYNC - Keep our state in sync with settings changes
    // ═══════════════════════════════════════════════════════════════════
    
    Connections {
        target: Settings.data.wallpaper
        function onVideoMutedChanged() { 
            root.isMuted = Settings.data.wallpaper.videoMuted ?? true 
        }
        function onVideoPauseOnFullscreenChanged() { 
            root.pauseOnFullscreen = Settings.data.wallpaper.videoPauseOnFullscreen ?? true 
        }
    }
}
```

---

## VideoWallpaper.qml - The Video Player

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

// This component displays a video as the desktop wallpaper
// It handles playing videos and animating transitions between them
Item {
    id: root

    // ═══════════════════════════════════════════════════════════════════
    // PROPERTIES - Settings passed in from parent component
    // ═══════════════════════════════════════════════════════════════════
    
    required property string screenName  // Which monitor this is for (e.g., "DP-1")
    property string videoSource: ""      // Path to the video file to play
    property bool active: false          // Whether this component should be running

    // ═══════════════════════════════════════════════════════════════════
    // INTERNAL STATE - Things we keep track of internally
    // ═══════════════════════════════════════════════════════════════════
    
    property string currentVideo: ""     // The video currently playing
    property string pendingVideo: ""     // The video we're transitioning TO
    property bool transitioning: false   // Are we in the middle of a transition animation?
    property bool videoReady: false      // Has the video started playing?
    property bool hasError: false        // Did something go wrong?

    // Get transition duration from settings (default 800 milliseconds)
    readonly property int transitionDuration: Settings.data.wallpaper.transitionDuration || 800
    
    // All possible transition animation types
    // When switching videos, one of these is picked randomly
    readonly property var transitionTypes: [
        "fade",    // Fade to new image
        "left",    // Wipe from left
        "right",   // Wipe from right
        "top",     // Wipe from top
        "bottom",  // Wipe from bottom
        "wipe",    // Diagonal wipe
        "grow",    // Grow from center
        "center",  // Shrink to center
        "outer",   // Expand from edges
        "wave"     // Wavy transition
    ]

    // Only show this component when active and has a video
    visible: active && (currentVideo !== "" || transitioning)

    // ═══════════════════════════════════════════════════════════════════
    // LOADING INDICATOR - Shows while video is starting or if there's an error
    // ═══════════════════════════════════════════════════════════════════
    
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface  // Background color from theme
        // Show when: there's an error, OR video isn't ready yet (but we have one and aren't transitioning)
        visible: root.hasError || (!root.videoReady && root.currentVideo !== "" && !root.transitioning)
        opacity: 0.9
        z: 50  // Make sure it's on top

        // Icon in the center - either error icon or spinning loader
        NIcon {
            anchors.centerIn: parent
            icon: root.hasError ? "alert-triangle" : "refresh"
            pointSize: 48
            color: Color.mOnSurfaceVariant
            
            // Spinning animation for the loading icon
            RotationAnimation on rotation {
                running: !root.hasError && !root.videoReady  // Only spin when loading
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SWWW PROCESS - Handles the transition animation
    // ═══════════════════════════════════════════════════════════════════
    
    // swww is a program that can smoothly animate between wallpaper images
    // We use it to transition from the old video to a thumbnail of the new video
    Process {
        id: swwwProc
        
        // When the transition animation finishes:
        onExited: (code, status) => {
            // Now switch to the new video
            root.currentVideo = root.pendingVideo
            root.pendingVideo = ""
            root.transitioning = false
            // mpvpaper will automatically start because currentVideo changed
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // MPVPAPER PROCESS - The actual video player
    // ═══════════════════════════════════════════════════════════════════
    
    // mpvpaper is a program that plays videos as your wallpaper
    Process {
        id: mpvProc
        
        // Build the options string for mpvpaper
        property string opts: [
            "loop",           // Loop the video forever
            "panscan=1.0",    // Fill the screen (crop if needed)
            VideoWallpaperService.isMuted ? "no-audio" : "volume=30"  // Mute or set volume
        ].join(" ")

        // The command to run - only set when we have a video and aren't transitioning
        command: root.currentVideo && root.active && !root.transitioning 
            ? ["mpvpaper", "-o", opts, root.screenName, root.currentVideo] 
            : []

        // Should the process be running?
        running: root.active && root.currentVideo !== "" && !root.transitioning

        // When video starts playing:
        onStarted: { 
            root.videoReady = true
            root.hasError = false 
        }
        
        // When video stops:
        onExited: (code, status) => {
            root.videoReady = false
            // If it crashed (non-zero exit code) and we're supposed to be playing, show error
            if (code !== 0 && root.active && !root.transitioning) {
                root.hasError = true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // TRANSITION FUNCTION - Smoothly switch from one video to another
    // ═══════════════════════════════════════════════════════════════════
    
    function doTransition(newVideo) {
        // Stop the current video
        if (mpvProc.running) {
            mpvProc.signal(15)  // 15 = SIGTERM = "please stop gracefully"
        }
        
        transitioning = true
        pendingVideo = newVideo
        
        // Request a full-size thumbnail of the new video
        VideoWallpaperService.generateThumbnail(newVideo, function(thumb) {
            if (thumb) {
                // Pick a random transition type
                var t = transitionTypes[Math.floor(Math.random() * transitionTypes.length)]
                
                // Run swww to animate to the thumbnail
                swwwProc.command = [
                    "swww", "img", thumb,
                    "--transition-type", t,
                    "--transition-duration", (transitionDuration / 1000).toFixed(1),  // Convert ms to seconds
                    "--transition-fps", "60",
                    "--outputs", root.screenName
                ]
                swwwProc.running = true
            } else {
                // Couldn't get thumbnail - just switch directly
                root.currentVideo = newVideo
                root.pendingVideo = ""
                root.transitioning = false
            }
        }, "full")  // "full" = full resolution thumbnail
    }

    // ═══════════════════════════════════════════════════════════════════
    // EVENT HANDLERS - React to changes
    // ═══════════════════════════════════════════════════════════════════
    
    // When the videoSource property changes (new video selected)
    onVideoSourceChanged: {
        // Ignore if empty or same as current
        if (!videoSource || videoSource === currentVideo) return
        
        // If we're already transitioning, just update the target
        if (transitioning) {
            pendingVideo = videoSource
            return
        }
        
        // First video ever - just start it directly
        if (currentVideo === "") {
            currentVideo = videoSource
        } else {
            // We have a video playing - do a nice transition
            doTransition(videoSource)
        }
    }

    // When active state changes (component enabled/disabled)
    onActiveChanged: {
        if (!active && mpvProc.running) {
            mpvProc.signal(15)  // Stop the video
        }
        if (active && videoSource && !currentVideo) {
            currentVideo = videoSource
        }
    }

    // When this component is first created
    Component.onCompleted: {
        if (active && videoSource) {
            currentVideo = videoSource
        }
    }

    // When this component is destroyed (cleanup)
    Component.onDestruction: {
        if (mpvProc.running) {
            mpvProc.signal(15)
        }
    }
}
```

---

## Summary of Changes to Existing Files

### Background.qml

**Added:** A Loader that creates VideoWallpaper when a video is selected.

```qml
// NEW: Video wallpaper overlay
Loader {
    id: videoWallpaperLoader
    anchors.fill: parent
    active: VideoWallpaperService.hasVideoWallpaper(modelData.name)  // Only load if there's a video
    z: 10  // Above the normal wallpaper

    property string videoPath: VideoWallpaperService.getVideoWallpaper(modelData.name)

    // Listen for video changes
    Connections {
        target: VideoWallpaperService
        function onVideoWallpaperChanged(screenName, path) {
            if (screenName === modelData.name) {
                videoWallpaperLoader.active = (path && path !== "")
                videoWallpaperLoader.videoPath = path || ""
            }
        }
    }

    // Create the video player component
    sourceComponent: Background.VideoWallpaper {
        screenName: modelData.name
        active: videoWallpaperLoader.active
        videoSource: videoWallpaperLoader.videoPath
    }
}
```

### WallpaperPanel.qml

**Added:** 
1. Videos sorted to top of list
2. Thumbnail generation for video files
3. Play icon badge on video thumbnails

```qml
// In refreshWallpaperScreenData() - Sort videos first:
var videos = [];
var images = [];
for (var i = 0; i < rawList.length; i++) {
    if (VideoWallpaperService.isVideoFile(rawList[i])) {
        videos.push(rawList[i]);
    } else {
        images.push(rawList[i]);
    }
}
wallpapersList = videos.concat(images);  // Videos first, then images

// In the wallpaper grid delegate - Thumbnail loading:
Component.onCompleted: {
    if (isVideo && VideoWallpaperService.isInitialized) {
        VideoWallpaperService.generateThumbnail(wallpaperPath, function(path) {
            if (path) {
                thumbnailPath = "file://" + path
                thumbnailReady = true
            }
        }, "preview")
    }
}
```

### WallpaperService.qml

**Added:** Detection of video files and delegation to VideoWallpaperService.

```qml
// In setWallpaper():
if (VideoWallpaperService.isVideoFile(path)) {
    VideoWallpaperService.setVideoWallpaper(screenName, path);
} else {
    VideoWallpaperService.clearVideoWallpaper(screenName);
}
```

### AppThemeService.qml

**Added:** Use thumbnail instead of video file for color generation.

```qml
// In generateFromWallpaper():
if (VideoWallpaperService.isVideoFile(wp)) {
    // Can't extract colors from video directly - use thumbnail
    VideoWallpaperService.generateThumbnail(wp, function(thumbnailPath) {
        if (thumbnailPath) {
            TemplateProcessor.processWallpaperColors(thumbnailPath, mode);
        }
    });
} else {
    TemplateProcessor.processWallpaperColors(wp, mode);
}
```

---

## Troubleshooting

### Video doesn't play
1. Make sure `mpvpaper` is installed
2. Check if the video file is a supported format
3. Try playing the video with: `mpvpaper -o "loop" DP-1 /path/to/video.mp4`

### No transition animation
1. Make sure `swww-daemon` is running: `pgrep swww-daemon || swww-daemon &`
2. Check swww is installed: `which swww`

### No thumbnails showing
1. Make sure `ffmpeg` is installed: `which ffmpeg`
2. Clear thumbnail cache: `rm -rf ~/.cache/noctalia/video-thumbnails`
3. Restart noctalia

### Video has no sound
- By default, videos are muted. Go to Settings → Wallpaper → Video Settings to unmute.

---

## Technical Flow Diagram

```
User clicks video in picker
         │
         ▼
┌─────────────────────────┐
│    WallpaperService     │
│  Detects it's a video   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  VideoWallpaperService  │
│  Stores video path      │
│  Emits signal           │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│     Background.qml      │
│  Receives signal        │
│  Updates VideoWallpaper │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│    VideoWallpaper.qml   │
│  If first video:        │
│    → Start mpvpaper     │
│  If switching videos:   │
│    → Kill mpvpaper      │
│    → Generate thumbnail │
│    → Run swww animation │
│    → Start new mpvpaper │
└─────────────────────────┘
```
