# Noctalia Shell Fork - Changes from Upstream

This fork adds video wallpaper support and wallpaper picker improvements.

## Features Added

### Video Wallpaper Support
- Play video files as wallpapers (MP4, WebM, MKV, AVI, MOV, OGV, M4V)
- Powered by `mpvpaper` for playback
- Random `swww` transitions between videos
- Mute toggle in wallpaper settings
- **Auto-pause when fullscreen app is active** (saves GPU resources when gaming)
- Matugen color extraction from video thumbnails

### Wallpaper Picker Improvements
- **Media filters**: Filter by All / Videos / Images
- **Delete wallpapers**: Right-click → Move to trash
- **Open folder**: Right-click → Open containing folder
- **Larger picker**: 50% width, 70% height
- **4 column grid** with smaller thumbnails
- **Videos sorted first** in the list
- **Video thumbnails** with play icon badge

## Requirements

Add to your NixOS configuration:

```nix
environment.systemPackages = with pkgs; [
  mpvpaper  # Video playback
  ffmpeg    # Thumbnail generation
  swww      # Transition animations
];
```

Add to Hyprland config:

```nix
wayland.windowManager.hyprland.settings = {
  exec-once = [ "swww-daemon" ];
};
```

## Files Changed

### New Files
- `Services/UI/VideoWallpaperService.qml` - Video state management & thumbnails
- `Modules/Background/VideoWallpaper.qml` - mpvpaper playback component

### Modified Files
- `Modules/Background/Background.qml` - Video wallpaper loader
- `Modules/Panels/Wallpaper/WallpaperPanel.qml` - Filters, delete, UI changes
- `Services/UI/WallpaperService.qml` - Video file detection
- `Services/Theming/AppThemeService.qml` - Video thumbnail colors
- `Assets/Translations/en.json` - New translations
- `Assets/Settings/settings-default.json` - Video settings
- `shell.qml` - VideoWallpaperService initialization

## Upstream Repository
https://github.com/noctalia-dev/noctalia-shell
