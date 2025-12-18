# Noctalia Shell (Fork)

**_quiet by design_**

<p align="center">
  <img src="https://assets.noctalia.dev/noctalia-logo.svg?v=2" alt="Noctalia Logo" style="width: 192px" />
</p>

> Personal fork of [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) with additional features and customizations.

---

## Fork Features

This fork includes the following additions:

### Bar Modes
Three bar display modes for different aesthetics:
- **Classic** - Traditional attached bar at screen edge
- **Floating** - Detached bar with configurable margins
- **Framed** - Screen border frame with integrated bar (caelestia-style)

### Video Wallpaper Support
- Play video files as animated wallpapers (mp4, webm, mkv, avi, mov, ogv, m4v)
- Per-monitor video wallpaper configuration
- Automatic thumbnail generation
- Seamless transitions between videos
- Color scheme generation from video frames

### AI Upscaling
- Image upscaling with Real-ESRGAN models
- Video upscaling with Real-ESR-AnimVideoV3
- Multiple scale options (2x, 3x, 4x)
- Progress tracking with stage indicators

### Screen Border (Framed Mode)
- Configurable border thickness and rounding
- Theme-aware coloring with shadow support
- Unified GPU-optimized rendering
- BorderExclusionZones for Wayland-native window spacing

### Pywalfox Integration
- Automatic Firefox theming via pywalfox
- Full 16-color palette generation
- Auto-update on wallpaper/theme change

---

## What is Noctalia?

A beautiful, minimal desktop shell for Wayland that actually gets out of your way. Built on Quickshell with a warm lavender aesthetic that you can easily customize to match your vibe.

**✨ Key Features:**
- 🪟 Native support for Niri, Hyprland, Sway, MangoWC and labwc
- ⚡ Built on Quickshell for performance
- 🎯 Minimalist design philosophy
- 🔧 Easily customizable to match your style
- 🎨 Many color schemes available

---

## Preview

https://github.com/user-attachments/assets/bf46f233-8d66-439a-a1ae-ab0446270f2d

<details>
<summary>Screenshots</summary>

![Dark 1](/Assets/Screenshots/noctalia-dark-1.png)
![Dark 2](/Assets/Screenshots/noctalia-dark-2.png)
![Dark 3](/Assets/Screenshots/noctalia-dark-3.png)

![Light 1](/Assets/Screenshots/noctalia-light-1.png)
![Light 2](/Assets/Screenshots/noctalia-light-2.png)
![Light 3](/Assets/Screenshots/noctalia-light-3.png)

</details>

---

## Requirements

- Wayland compositor (Niri, Hyprland, Sway, MangoWC or labwc recommended)
- Quickshell
- Additional dependencies listed in [upstream documentation](https://docs.noctalia.dev)

### Video Wallpaper Requirements

```bash
mpvpaper    # Plays video as wallpaper
ffmpeg      # Creates thumbnail previews
swww        # Handles smooth transitions
```

### AI Upscaling Requirements (Optional)

```bash
realesrgan-ncnn-vulkan  # For image/video upscaling
```

---

## Installation

1. Clone this fork:
```bash
git clone https://github.com/bostannnn/noctalia-shell.git
cd noctalia-shell
```

2. Run with Quickshell:
```bash
quickshell -c .
```

For full installation instructions, see the [upstream documentation](https://docs.noctalia.dev/getting-started/installation).

---

## Bar System

### Bar Modes

| Mode | Description | Key Settings |
|------|-------------|--------------|
| **Classic** | Attached to screen edge | `bar.exclusive`, `bar.outerCorners` |
| **Floating** | Detached with margins | `bar.marginVertical`, `bar.marginHorizontal` |
| **Framed** | Integrated with screen border | `general.screenBorderThickness`, `general.screenBorderRounding` |

### Bar Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `bar.mode` | string | "classic" | Bar display mode |
| `bar.position` | string | "top" | Position: top, bottom, left, right |
| `bar.density` | string | "default" | Density: compact, default, comfortable |
| `bar.transparent` | bool | false | Transparent background |
| `bar.showOutline` | bool | false | Show outline border |
| `bar.showCapsule` | bool | false | Capsule styling |
| `bar.capsuleOpacity` | float | 0.5 | Capsule opacity (0.0-1.0) |
| `bar.exclusive` | bool | true | Reserve space with compositor |
| `bar.outerCorners` | bool | false | Inverted corners (classic mode) |
| `bar.marginVertical` | float | 0.15 | Vertical margin (floating mode) |
| `bar.marginHorizontal` | float | 0.25 | Horizontal margin (floating mode) |
| `bar.gap` | int | 10 | Gap between bar and windows |
| `bar.monitors` | array | [] | Per-monitor visibility |

---

## Bar Widgets (33 Available)

### System Information
| Widget | Description | Key Settings |
|--------|-------------|--------------|
| **Clock** | Time/date display | `formatHorizontal`, `formatVertical`, `useCustomFont` |
| **SystemMonitor** | CPU, Memory, GPU, Disk, Network | Warning/critical thresholds, polling intervals |
| **Battery** | Battery status & power profiles | `displayMode`, warning threshold |
| **ActiveWindow** | Focused window title | `hideMode`, `maxWidth`, `iconColorization` |

### Media
| Widget | Description | Key Settings |
|--------|-------------|--------------|
| **MediaMini** | Compact media controls | Album art, progress ring, visualizer |
| **AudioVisualizer** | Real-time spectrum | `width`, `colorName` |

### Controls
| Widget | Description | Key Settings |
|--------|-------------|--------------|
| **Volume** | Audio volume | `displayMode` |
| **Brightness** | Screen brightness | `displayMode`, DDC support |
| **CustomButton** | Programmable button | Click handlers, command execution, JSON parsing |
| **ControlCenter** | Quick settings access | Custom icon, colorization |
| **DarkMode** | Theme toggle | - |
| **NightLight** | Blue light filter | - |
| **PowerProfile** | CPU power profile | - |
| **KeepAwake** | Prevent sleep | - |
| **ScreenRecorder** | Recording toggle | - |

### Connectivity
| Widget | Description | Key Settings |
|--------|-------------|--------------|
| **WiFi** | Network manager | `displayMode` |
| **Bluetooth** | Device manager | `displayMode` |
| **VPN** | VPN status | `displayMode` |
| **Microphone** | Input control | `displayMode` |
| **KeyboardLayout** | Layout switcher | `displayMode` |
| **LockKeys** | Caps/Num/Scroll Lock | Per-key icons and enable |

### Navigation
| Widget | Description | Key Settings |
|--------|-------------|--------------|
| **Workspace** | Workspace switcher | `labelMode`, `followFocusedScreen`, `hideUnoccupied` |
| **Taskbar** | Window list | `perOutput`, `activeWorkspaceOnly`, pinned apps |
| **Tray** | System tray | Blacklist, pinning, drawer mode |

### Informational
| Widget | Description | Key Settings |
|--------|-------------|--------------|
| **NotificationHistory** | Recent notifications | `hideWhenEmpty`, unread badge |
| **NoctaliaPerformance** | Shell metrics | Render time display |
| **RandomWallpaper** | Quick random button | - |
| **WallpaperSelector** | Wallpaper access | - |
| **TodoList** | Task list | `hideWhenEmpty`, `displayMode` |

### Special
| Widget | Description | Key Settings |
|--------|-------------|--------------|
| **Spacer** | Empty space | `width` |
| **SessionMenu** | Power controls | Error color styling |
| **Screenshot** | Screenshot tool | - |

---

## Panels (18 Types)

### Quick Access
- **Audio Panel** - Volume and input controls
- **Battery Panel** - Power management details
- **Brightness Panel** - Screen brightness adjustment
- **Clock Panel** - Calendar and time information
- **WiFi Panel** - Network connection manager
- **Bluetooth Panel** - Device connection manager
- **Tray Panel** - System tray drawer

### Feature Panels
- **Launcher Panel** - Application launcher with clipboard history
- **Wallpaper Panel** - Wallpaper selector with Wallhaven integration
- **ControlCenter Panel** - Comprehensive quick settings
- **Settings Panel** - Main settings interface (24 tabs)
- **SetupWizard Panel** - Initial configuration
- **SessionMenu Panel** - Power options with countdown
- **NotificationHistory Panel** - Notification archive
- **TodoList Panel** - Task management
- **Changelog Panel** - Version history
- **Plugins Panel** - Plugin management

---

## Control Center

### Cards (6 Configurable)
1. **Profile Card** - User avatar and info
2. **Audio Card** - Device selection and volume
3. **Brightness Card** - Brightness slider
4. **Weather Card** - Current conditions
5. **Shortcuts Card** - 8 quick action buttons
6. **Media Card** - Media player / System monitor

### Shortcut Buttons (8 Total)
Left: WiFi, Bluetooth, ScreenRecorder, WallpaperSelector
Right: Notifications, PowerProfile, KeepAwake, NightLight

---

## Color Schemes & Theming

### Built-in Schemes (10)
Ayu, Catppuccin, Dracula, Eldritch, Gruvbox, Kanagawa, Nord, Rosepine, Tokyo-Night, Noctalia

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `colorSchemes.useWallpaperColors` | bool | true | Generate from wallpaper (Matugen) |
| `colorSchemes.predefinedScheme` | string | "Noctalia" | Predefined scheme name |
| `colorSchemes.darkMode` | bool | true | Dark/light mode |
| `colorSchemes.schedulingMode` | string | "off" | Auto dark mode: off, auto, manual |
| `colorSchemes.manualSunrise` | string | "06:00" | Manual sunrise time |
| `colorSchemes.manualSunset` | string | "18:00" | Manual sunset time |
| `colorSchemes.matugenSchemeType` | string | "scheme-fruit-salad" | Matugen algorithm |

### Template Targets (24+)

#### Terminal Emulators
- Alacritty, Foot, Ghostty, Kitty, Wezterm

#### UI Frameworks
- GTK (3.0, 4.0), Qt (5ct, 6ct), KColorScheme

#### Application Launchers
- Fuzzel, Vicinae, Walker

#### Applications
- Discord (Vesktop, Webcord, OpenAsar), Telegram, Spicetify, Zed, VSCode

#### Other
- Pywalfox (Firefox), Cava, Emacs, Yazi

#### Compositors
- Hyprland, Niri

---

## Wallpaper System

### Basic Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `wallpaper.enabled` | bool | true | Enable wallpaper service |
| `wallpaper.directory` | string | "~/Pictures" | Wallpaper directory |
| `wallpaper.recursiveSearch` | bool | true | Search subdirectories |
| `wallpaper.setWallpaperOnAllMonitors` | bool | true | Same wallpaper on all monitors |

### Fill Modes
- `crop` - Crop to fit
- `fit` - Fit within bounds
- `fill` - Fill entire screen
- `stretch` - Stretch to bounds
- `tile` - Tile pattern

### Transitions

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `wallpaper.transitionDuration` | int | 1500 | Duration in ms |
| `wallpaper.transitionType` | string | "random" | Type: none, fade, wipe, grow, outer, wave |
| `wallpaper.transitionEdgeSmoothness` | float | 0.05 | Smoothing factor |

### Random Wallpaper

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `wallpaper.randomEnabled` | bool | false | Enable random rotation |
| `wallpaper.randomIntervalSec` | int | 300 | Interval in seconds |

### Video Wallpaper (Fork Feature)

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `wallpaper.videoMuted` | bool | true | Mute video audio |
| `wallpaper.videoPauseOnFullscreen` | bool | true | Pause on fullscreen apps |

### Upscaling (Fork Feature)

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `wallpaper.imageUpscaleModel` | string | "realesrgan-x4plus" | Image upscale model |
| `wallpaper.videoUpscaleModel` | string | "realesr-animevideov3" | Video upscale model |
| `wallpaper.videoUpscaleScale` | int | 2 | Video scale: 2, 3, or 4 |

### Wallhaven Integration

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `wallpaper.useWallhaven` | bool | false | Enable Wallhaven |
| `wallpaper.wallhavenQuery` | string | "" | Search query |
| `wallpaper.wallhavenSorting` | string | "relevance" | Sort order |
| `wallpaper.wallhavenCategories` | string | "111" | Categories filter |
| `wallpaper.wallhavenPurity` | string | "100" | Purity filter (SFW) |

---

## Screen Border (Fork Feature)

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `general.screenBorderThickness` | int | 10 | Border thickness in pixels |
| `general.screenBorderRounding` | int | 25 | Corner radius |

---

## Notifications

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `notifications.enabled` | bool | true | Enable notifications |
| `notifications.location` | string | "top_right" | Position on screen |
| `notifications.backgroundOpacity` | float | 0.9 | Background opacity |
| `notifications.lowDuration` | int | 3000 | Low urgency duration (ms) |
| `notifications.normalDuration` | int | 8000 | Normal urgency duration (ms) |
| `notifications.criticalDuration` | int | 15000 | Critical urgency duration (ms) |

### Notification Sounds

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `notifications.sound.enabled` | bool | false | Enable sounds |
| `notifications.sound.volume` | float | 0.5 | Sound volume |
| `notifications.sound.appBlacklist` | array | [...] | Apps to ignore |

---

## OSD (On-Screen Display)

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `osd.enabled` | bool | true | Enable OSD |
| `osd.location` | string | "top_right" | Position |
| `osd.autoHideMs` | int | 2000 | Auto-hide delay |
| `osd.backgroundOpacity` | float | 0.9 | Background opacity |
| `osd.enabledTypes` | array | [...] | Enabled types: Volume, InputVolume, Brightness, CustomText |

---

## Lock Screen

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `general.compactLockScreen` | bool | false | Compact layout |
| `general.lockOnSuspend` | bool | true | Lock on suspend |
| `general.showSessionButtonsOnLockScreen` | bool | true | Show power buttons |
| `general.showHibernateOnLockScreen` | bool | false | Show hibernate option |

---

## Desktop Widgets (3 Types)

1. **Desktop Clock** - Customizable clock display
2. **Desktop Media Player** - Media controls with visualizer
3. **Desktop Weather** - Weather conditions

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `desktopWidgets.enabled` | bool | false | Enable desktop widgets |
| `desktopWidgets.editMode` | bool | false | Drag/drop positioning |

---

## Session Menu

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `sessionMenu.enableCountdown` | bool | false | Enable countdown timer |
| `sessionMenu.countdownDuration` | int | 10000 | Countdown duration (ms) |
| `sessionMenu.position` | string | "center" | Menu position |
| `sessionMenu.showHeader` | bool | true | Show header |
| `sessionMenu.largeButtonsStyle` | bool | false | Large buttons layout |

---

## Application Launcher

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `appLauncher.enableClipboardHistory` | bool | true | Enable clipboard |
| `appLauncher.enableClipPreview` | bool | true | Clipboard preview |
| `appLauncher.position` | string | "center" | Launcher position |
| `appLauncher.viewMode` | string | "list" | View: list, grid |
| `appLauncher.sortByMostUsed` | bool | false | Sort by usage |
| `appLauncher.showCategories` | bool | true | Show app categories |
| `appLauncher.terminalCommand` | string | "xterm -e" | Terminal command |

---

## Hooks System

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `hooks.enabled` | bool | false | Enable hooks |
| `hooks.wallpaperChange` | string | "" | Wallpaper change script |
| `hooks.darkModeChange` | string | "" | Dark mode change script |
| `hooks.screenLock` | string | "" | Screen lock script |
| `hooks.screenUnlock` | string | "" | Screen unlock script |

---

## Compositor Configuration

### Hyprland

Add to `hyprland.conf`:

```bash
# Source Noctalia-generated configs
source = ~/.config/noctalia/hypr-gaps.conf   # Bar gaps (auto-managed)
source = ~/.config/hypr/noctalia.conf        # Theme colors (if template enabled)

# Required for video wallpaper transitions
exec-once = swww-daemon
```

### NixOS (Home Manager)

```nix
wayland.windowManager.hyprland.settings = {
  source = [
    "~/.config/noctalia/hypr-gaps.conf"
    "~/.config/hypr/noctalia.conf"
  ];
  exec-once = [ "swww-daemon" ];
};
```

### Generated Files

| File | Purpose |
|------|---------|
| `~/.config/noctalia/hypr-gaps.conf` | Auto-generated gaps for bar modes |
| `~/.config/hypr/noctalia.conf` | Theme colors for window borders |

---

## Plugin System

Noctalia supports custom plugins for:
- **Bar Widgets** - Register via `BarWidgetRegistry.registerPluginWidget()`
- **Desktop Widgets** - Register via `DesktopWidgetRegistry.registerPluginWidget()`

### Hot Reload

Enable plugin hot reload with:
```bash
NOCTALIA_DEBUG=1 quickshell -c .
```

---

## Troubleshooting

### Bar gaps not working
1. Ensure `~/.config/noctalia/hypr-gaps.conf` is sourced in hyprland.conf
2. Check with: `cat ~/.config/noctalia/hypr-gaps.conf`

### Video wallpaper not playing
1. Check mpvpaper: `which mpvpaper`
2. Check swww-daemon: `pgrep swww-daemon`
3. Test: `mpvpaper -o "loop" DP-1 /path/to/video.mp4`

### Theme colors not updating
1. Enable template in Settings > Color Schemes > Templates
2. Source noctalia.conf in compositor config
3. Check: `cat ~/.config/hypr/noctalia.conf`

### Pywalfox not updating Firefox
1. Ensure pywalfox is installed and extension is active
2. Check: `pywalfox update`
3. Remove stale socket: `rm /tmp/pywalfox_socket`

---

## Upstream

This fork is based on [noctalia-dev/noctalia-shell](https://github.com/noctalia-dev/noctalia-shell).

- [Upstream Documentation](https://docs.noctalia.dev)
- [Upstream Discord](https://discord.noctalia.dev)

<a href="https://ko-fi.com/lysec">
  <img src="https://img.shields.io/badge/donate-ko--fi-A8AEFF?style=for-the-badge&logo=kofi&logoColor=FFFFFF&labelColor=0C0D11" alt="Ko-Fi" />
</a>

### Thank you to everyone who supports the project 💜!
* Gohma
* DiscoCevapi
* <a href="https://pika-os.com/" target="_blank">PikaOS</a>
* LionHeartP
* Nyxion ツ
* RockDuck
* Eynix
* MrDowntempo
* Tempus Thales
* Raine
* JustCurtis
* llego
* Grune

---

## License

MIT License - see [LICENSE](./LICENSE) for details.
