# Video Wallpaper Support for Noctalia Shell

This archive contains noctalia-shell with integrated video wallpaper support.

## Changes Summary

### New Files Added

1. **Services/UI/VideoWallpaperService.qml**
   - Singleton service managing video wallpaper state
   - Video file detection (mp4, webm, mkv, avi, mov, ogv, m4v)
   - Thumbnail generation via FFmpeg
   - Mute/pause controls with settings persistence
   - Per-screen video wallpaper tracking

2. **Modules/Background/VideoWallpaper.qml**
   - Qt6 MediaPlayer with VideoOutput component
   - Infinite looping playback
   - Fallback overlay during loading/errors
   - Integration with VideoWallpaperService for state sync

### Modified Files

1. **Modules/Background/Background.qml**
   - Added import for local Background module
   - Added VideoWallpaper Loader component after shader effects
   - Added Binding to hide static wallpaper when video is active

2. **Services/UI/WallpaperService.qml**
   - Updated `_setWallpaper()` to notify VideoWallpaperService for video files
   - Updated recursive scan find command to include video extensions
   - Updated FolderListModel nameFilters to include video files

3. **Modules/Panels/Settings/Tabs/WallpaperTab.qml**
   - Added video wallpaper settings section with:
     - Mute audio toggle
     - Pause on fullscreen toggle
     - Info text about GPU usage

4. **Assets/settings-default.json**
   - Added `videoMuted: true` to wallpaper section
   - Added `videoPauseOnFullscreen: true` to wallpaper section

5. **Assets/Translations/en.json**
   - Added `video-wallpaper.error` and `video-wallpaper.loading` strings
   - Added `settings.wallpaper.video.*` translation strings
   - Updated `wallpaper.configure-directory` to mention videos

6. **shell.qml**
   - Added `VideoWallpaperService.init()` call after WallpaperService init

## Supported Video Formats

- MP4 (.mp4)
- WebM (.webm)
- MKV (.mkv)
- AVI (.avi)
- MOV (.mov)
- OGV (.ogv)
- M4V (.m4v)

## NixOS Dependencies

For video playback, ensure GStreamer plugins are installed:

```nix
environment.systemPackages = with pkgs; [
  gst_all_1.gstreamer
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-good
  gst_all_1.gst-plugins-bad
  gst_all_1.gst-plugins-ugly
  gst_all_1.gst-libav
  gst_all_1.gst-vaapi  # Hardware acceleration
  ffmpeg               # Thumbnail generation
];
```

## Usage

1. Place video files in your wallpaper directory
2. Open the wallpaper selector - videos will appear alongside images
3. Select a video to set it as your wallpaper
4. Configure playback in Settings > Wallpaper > Video Wallpaper section

## Features

- Seamless looping video playback
- Mute/unmute audio (default: muted)
- Option to pause when fullscreen app is active
- Per-monitor video wallpaper support
- Automatic thumbnail generation for video picker
- Hardware-accelerated playback (when GStreamer VAAPI is available)


