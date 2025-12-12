# Noctalia Shell Fork - Changes from Upstream

This fork adds video wallpaper support, Hyprland border theming, and wallpaper picker improvements.

## Features Added

### Video Wallpaper Support
- Play video files as wallpapers (MP4, WebM, MKV, AVI, MOV, OGV, M4V)
- Powered by `mpvpaper` for playback
- Random `swww` transitions between videos
- Mute toggle in wallpaper settings
- Matugen color extraction from video thumbnails

### Hyprland Border Theming
- Auto-generated border colors from wallpaper
- Gradient animated borders with primary/secondary colors
- **File auto-created** at `~/.config/hypr/noctalia.conf` when enabled
- Auto-reloads Hyprland when colors change
- Enable in Settings → Color Scheme → Compositors → Hyprland

#### Hyprland Setup

Add to your `hyprland.nix` (Home Manager):

```nix
wayland.windowManager.hyprland = {
  enable = true;
  extraConfig = ''
    source = ~/.config/hypr/noctalia.conf
  '';
  settings = {
    general = {
      # Fallback colors (noctalia.conf will override these)
      "col.active_border" = "rgba(bd93f9ee) rgba(ff79c6ee) 45deg";
      "col.inactive_border" = "rgba(595959aa)";
    };
    animations = {
      animation = [
        "borderangle,1,100,default,loop"  # Animated gradient
      ];
    };
  };
};
```

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
- `Services/Theming/AppThemeService.qml` - Video thumbnail colors, Hyprland init
- `Services/Theming/TemplateRegistry.qml` - Hyprland template with auto-reload
- `Services/System/ProgramCheckerService.qml` - Hyprland availability check
- `Modules/Panels/Settings/Tabs/ColorScheme/ColorSchemeTab.qml` - Hyprland toggle
- `Assets/Translations/en.json` - New translations
- `Assets/settings-default.json` - Video & Hyprland settings
- `shell.qml` - VideoWallpaperService initialization

## Upstream Repository
https://github.com/noctalia-dev/noctalia-shell
