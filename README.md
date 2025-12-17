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

**Key Features:**
- Native support for Niri, Hyprland, Sway and MangoWC
- Built on Quickshell for performance
- Minimalist design philosophy
- Easily customizable to match your style
- Many color schemes available

---

## Requirements

- Wayland compositor (Hyprland recommended for full feature support)
- Quickshell
- Additional dependencies listed in [upstream documentation](https://docs.noctalia.dev)

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

## Configuration

### Bar Mode
Set in Settings > Bar > Mode:
- `classic` - Attached to screen edge
- `floating` - Floating with margins
- `framed` - Integrated with screen border

### Screen Border (Framed Mode)
Configure in Settings > General:
- Border thickness
- Border rounding
- Theme color or custom color

### Video Wallpaper
Select video files in the wallpaper picker. Supported formats depend on your Qt/GStreamer installation.

---

## Upstream

This fork is based on [noctalia-dev/noctalia-shell](https://github.com/noctalia-dev/noctalia-shell).

- [Upstream Documentation](https://docs.noctalia.dev)
- [Upstream Discord](https://discord.noctalia.dev)

---

## License

MIT License - see [LICENSE](./LICENSE) for details.
