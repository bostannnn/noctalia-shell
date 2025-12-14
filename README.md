# Noctalia Shell Fork

This fork adds workspace overview, video wallpaper support, Hyprland border theming, random color schemes, screen border (caelestia-style), and wallpaper picker improvements.

## Features

### Screen Border (Caelestia-Style)
- Decorative colored border around the entire screen
- Uses matugen theme colors or custom color
- Configurable thickness, corner rounding, and window margin
- Automatically manages Hyprland gaps for proper window placement
- Settings → User Interface → Screen Border

### Workspace Overview
- 2×5 grid showing all workspaces with live window previews
- Fullscreen overlay with drag-and-drop between workspaces
- Middle-click to close windows
- Keyboard navigation: arrows/hjkl, 1-0 to jump, Escape/Enter to close

### Video Wallpaper
- Play video files as wallpapers (MP4, WebM, MKV, AVI, MOV, OGV, M4V)
- Powered by `mpvpaper` for playback
- Animated transitions via `swww`
- Mute toggle in wallpaper settings
- Color extraction from video thumbnails

### Hyprland Border Theming
- Auto-generated gradient borders from wallpaper colors
- Config file at `~/.config/hypr/noctalia.conf`
- Auto-reloads Hyprland when colors change
- Enable in Settings → Color Scheme → Compositors → Hyprland

### Random Color Scheme
- Picks a different matugen scheme with each wallpaper change
- Cycles through: Content, Expressive, Fidelity, Fruit Salad, Monochrome, Neutral, Rainbow, Tonal Spot
- Set in Settings → Color Scheme → Matugen scheme type → Random

### Wallpaper Picker
- Filter by All / Videos / Images
- Right-click to delete or open folder
- Video thumbnails with play icon badge

## Requirements

```nix
environment.systemPackages = with pkgs; [
  swww      # Required - wallpaper display and transitions
  mpvpaper  # Video playback
  ffmpeg    # Thumbnail generation
];
```

**Important:** `swww-daemon` must be running for wallpapers to work:

```nix
wayland.windowManager.hyprland.settings = {
  exec-once = [ "swww-daemon" ];
};
```

## Keybinds Setup

**NixOS** (using `noctalia-shell` wrapper):
```nix
wayland.windowManager.hyprland.settings = {
  bindr = [ "SUPER, SUPER_L, exec, noctalia-shell ipc call launcher toggle" ];
  bind = [
    "$mainMod, Tab, exec, noctalia-shell ipc call overview toggle"
    "$mainMod, W, exec, noctalia-shell ipc call wallpaper toggle"
  ];
};
```

**Non-NixOS** (using `qs -c`):
```bash
bindr = SUPER, SUPER_L, exec, qs -c noctalia-shell ipc call launcher toggle
bind = $mainMod, Tab, exec, qs -c noctalia-shell ipc call overview toggle
bind = $mainMod, W, exec, qs -c noctalia-shell ipc call wallpaper toggle
```

## Hyprland Setup

Add to `hyprland.nix`:

```nix
{ config, inputs, pkgs, lib, ... }:
{
  # Create noctalia gaps config if it doesn't exist (for screen border feature)
  home.activation.createNoctaliaGapsConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "$HOME/.config/noctalia/hypr-gaps.conf" ]; then
      mkdir -p "$HOME/.config/noctalia"
      echo "general:gaps_out = 0" > "$HOME/.config/noctalia/hypr-gaps.conf"
    fi
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
      source = ~/.config/hypr/noctalia.conf
      source = ~/.config/noctalia/hypr-gaps.conf
    '';
    settings = {
      general = {
        # Fallback colors (noctalia.conf will override these)
        "col.active_border" = "rgba(bd93f9ee) rgba(ff79c6ee) rgba(8be9fdee) rgba(50fa7bee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        # Note: gaps_out is managed by noctalia when screen border is enabled
      };
      animations.animation = [ "borderangle,1,100,default,loop" ];
    };
  };
}
```

## Screen Border Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `screenBorderEnabled` | bool | `false` | Enable caelestia-style screen border |
| `screenBorderThickness` | int | `10` | Border width in pixels |
| `screenBorderRounding` | int | `25` | Corner radius of the cutout |
| `screenBorderMargin` | int | `10` | Gap between border and windows |
| `screenBorderUseThemeColor` | bool | `true` | Use matugen theme color |
| `screenBorderColor` | string | `"#1e1e2e"` | Custom color (when theme color disabled) |

**Note:** When screen border is enabled:
- Shows warning if used with floating bar (not recommended)
- Shows warning if screen corners are disabled (recommended to enable)
- Hyprland gaps are managed via `~/.config/noctalia/hypr-gaps.conf`

## NixOS Home Manager Settings

Example `noctalia-settings.nix`:

```nix
{ pkgs, inputs, ... }:
{
  programs.noctalia-shell = {
    enable = true;
    settings = {
      general = {
        # Screen Border settings
        screenBorderEnabled = true;
        screenBorderThickness = 10;
        screenBorderRounding = 25;
        screenBorderMargin = 10;
        screenBorderUseThemeColor = true;
        screenBorderColor = "#1e1e2e";
        # ... other settings
      };
      # ... other sections
    };
  };
}
```

## Upstream

https://github.com/noctalia-dev/noctalia-shell
