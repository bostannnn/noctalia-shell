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
- **Classic** - Traditional attached bar
- **Floating** - Detached bar with configurable margins
- **Framed** - Screen border frame with integrated bar (caelestia-style)

### Video Wallpaper Support
- Play video files as animated wallpapers
- Per-monitor video wallpaper configuration
- Seamless integration with the wallpaper picker

### Screen Border (Framed Mode)
- Configurable border thickness and rounding
- Theme-aware coloring
- Optimized single-pass GPU rendering with unified shadow system

### Other Improvements
- Hyprland theming template integration
- BorderExclusionZones for Wayland-native window spacing
- Optimized background rendering (AllBackgrounds unified Shape)

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

```nix
environment.systemPackages = with pkgs; [
  mpvpaper    # Plays video as wallpaper
  ffmpeg      # Creates thumbnail previews
  swww        # Handles smooth transitions
];
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

## Hyprland Configuration

Add these lines to your `hyprland.conf`:

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
    "~/.config/noctalia/hypr-gaps.conf"  # Bar gaps management
    "~/.config/hypr/noctalia.conf"       # Theme colors (optional)
  ];

  exec-once = [
    "swww-daemon"  # Required for video wallpaper
  ];
};
```

### What These Files Do

| File | Purpose |
|------|---------|
| `~/.config/noctalia/hypr-gaps.conf` | Auto-generated gaps config for bar modes. Updates when bar mode/position changes. |
| `~/.config/hypr/noctalia.conf` | Theme colors for window borders. Generated when Hyprland template is enabled in Settings > Color Schemes. |

---

## Configuration

### Bar Mode
Set in Settings > Bar > Mode:
- `classic` - Attached to screen edge
- `floating` - Floating with margins
- `framed` - Integrated with screen border

### Bar Gap
Set in Settings > Bar > Gap:
- Controls spacing between bar and windows
- Only affects classic and floating modes
- Framed mode uses BorderExclusionZones instead

### Screen Border (Framed Mode)
Configure in Settings > General:
- Border thickness
- Border rounding
- Theme color or custom color

### Video Wallpaper
1. Ensure `mpvpaper`, `ffmpeg`, and `swww` are installed
2. Start `swww-daemon` (add to exec-once)
3. Select video files in the wallpaper picker

Supported formats: `.mp4`, `.webm`, `.mkv`, `.avi`, `.mov`, `.ogv`, `.m4v`

### Hyprland Theme Colors
1. Go to Settings > Color Schemes > Templates
2. Enable "Hyprland"
3. Source `~/.config/hypr/noctalia.conf` in your hyprland.conf
4. Colors update automatically when wallpaper or theme changes

---

## Troubleshooting

### Bar gaps not working
1. Ensure `~/.config/noctalia/hypr-gaps.conf` is sourced in hyprland.conf
2. The file is auto-created on first run
3. Check with: `cat ~/.config/noctalia/hypr-gaps.conf`

### Video wallpaper not playing
1. Check mpvpaper is installed: `which mpvpaper`
2. Check swww-daemon is running: `pgrep swww-daemon`
3. Test manually: `mpvpaper -o "loop" DP-1 /path/to/video.mp4`

### Theme colors not updating
1. Enable Hyprland template in Settings > Color Schemes
2. Source noctalia.conf in hyprland.conf
3. Check file exists: `cat ~/.config/hypr/noctalia.conf`

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
