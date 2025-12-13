# Noctalia Shell Fork - Changes from Upstream

This fork adds workspace overview, video wallpaper support, Hyprland border theming, random color schemes, and wallpaper picker improvements.

## Features Added

### Workspace Overview (NEW)
- 2×5 grid showing all workspaces with live window previews
- Live window capture using ScreencopyView
- Fullscreen background overlay (covers entire screen including bar)
- Drag windows between workspaces
- Middle-click to close windows
- Keyboard navigation: arrows/hjkl to move, 1-0 to jump, Escape/Enter to close

#### Keybinds Setup

**NixOS users** - use `noctalia-shell` wrapper:
```nix
wayland.windowManager.hyprland.settings = {
  bindr = [
    "SUPER, SUPER_L, exec, noctalia-shell ipc call launcher toggle"
  ];
  bind = [
    "$mainMod, Tab, exec, noctalia-shell ipc call overview toggle"
    "$mainMod, W, exec, noctalia-shell ipc call wallpaper toggle"
  ];
};
```

**Non-NixOS users** - use `qs -c`:
```bash
# In your hyprland.conf
bindr = SUPER, SUPER_L, exec, qs -c noctalia-shell ipc call launcher toggle
bind = $mainMod, Tab, exec, qs -c noctalia-shell ipc call overview toggle
bind = $mainMod, W, exec, qs -c noctalia-shell ipc call wallpaper toggle
```

#### Available IPC Commands
- `overview toggle` / `overview open` / `overview close` - Workspace overview
- `launcher toggle` - App launcher
- `wallpaper toggle` - Wallpaper picker

### Video Wallpaper Support
- Play video files as wallpapers (MP4, WebM, MKV, AVI, MOV, OGV, M4V)
- Powered by `mpvpaper` for playback
- Random `swww` transitions between videos
- Mute toggle in wallpaper settings
- Matugen color extraction from video thumbnails

### Hyprland Border Theming
- Auto-generated border colors from wallpaper
- 4-color gradient animated borders (primary → secondary → tertiary → primary_container)
- **File auto-created** at `~/.config/hypr/noctalia.conf` on startup
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
      "col.active_border" = "rgba(bd93f9ee) rgba(ff79c6ee) rgba(8be9fdee) rgba(50fa7bee) 45deg";
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

### Random Color Scheme
- Select "Random" as matugen scheme type
- Automatically picks a different scheme with each wallpaper change
- Cycles through: Content, Expressive, Fidelity, Fruit Salad, Monochrome, Neutral, Rainbow, Tonal Spot
- Set in Settings → Color Scheme → Matugen scheme type → Random

In NixOS config:
```nix
programs.noctalia.settings.colorSchemes.matugenSchemeType = "random";
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
- `Services/UI/OverviewService.qml` - Workspace overview state management
- `Services/Compositor/HyprlandDataService.qml` - Hyprland window/monitor data provider
- `Modules/Background/VideoWallpaper.qml` - mpvpaper playback component
- `Modules/Overview/WorkspaceOverview.qml` - Main overview module with dual-layer architecture
- `Modules/Overview/OverviewWidget.qml` - Workspace grid with window previews
- `Modules/Overview/OverviewWindow.qml` - Individual window preview component
- `Modules/Overview/qmldir` - Module definition

### Modified Files
- `Modules/Background/Background.qml` - Video wallpaper loader
- `Modules/Panels/Wallpaper/WallpaperPanel.qml` - Filters, delete, UI changes
- `Services/UI/WallpaperService.qml` - Video file detection
- `Services/UI/BarService.qml` - Fixed null widget instance errors
- `Services/Theming/AppThemeService.qml` - Video thumbnail colors, Hyprland init, debounce
- `Services/Theming/TemplateProcessor.qml` - Random scheme selection, concurrent guard
- `Services/Theming/TemplateRegistry.qml` - Hyprland template with auto-reload
- `Services/System/ProgramCheckerService.qml` - Hyprland availability check
- `Modules/Panels/Settings/Tabs/ColorScheme/ColorSchemeTab.qml` - Hyprland toggle, Random scheme option
- `Assets/Translations/en.json` - New translations
- `Assets/settings-default.json` - Video & Hyprland settings
- `shell.qml` - VideoWallpaperService and Overview initialization

## Upstream Repository
https://github.com/noctalia-dev/noctalia-shell
