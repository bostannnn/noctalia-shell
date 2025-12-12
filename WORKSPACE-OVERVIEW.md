# Workspace Overview Integration

This integration adds a workspace overview feature from [quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview) to noctalia-shell, adapted for noctalia's theming system.

## Features

- **Grid View**: Shows workspaces in a configurable rows × columns grid (default: 2×5)
- **Live Window Previews**: Uses Wayland screencopy for real-time window captures
- **Drag & Drop**: Move windows between workspaces by dragging
- **Keyboard Navigation**: 
  - Arrow keys / hjkl: Navigate workspaces
  - Number keys (1-0): Jump to workspace
  - Escape / Enter: Close overview
- **Mouse Interaction**:
  - Left-click workspace: Switch to workspace
  - Left-click window: Focus window
  - Middle-click window: Close window
- **Theming**: Automatically uses noctalia's matugen-generated colors

## Usage

Toggle the overview via IPC:
```bash
quickshell ipc overview toggle
```

Or bind it to a key in your Hyprland config:
```conf
bind = $mainMod, Tab, exec, quickshell ipc overview toggle
```

## Configuration

Configuration is in `Services/UI/OverviewService.qml`:

```qml
property int rows: 2              // Number of rows
property int columns: 5           // Number of columns  
property real scale: 0.16         // Workspace preview scale
property int raceConditionDelay: 150  // Delay for focus grab
```

These can be moved to `Settings.qml` for user configuration if desired.

## Files Added/Modified

### New Files:
- `Modules/Overview/WorkspaceOverview.qml` - Main overview component
- `Modules/Overview/OverviewWidget.qml` - Workspace grid widget
- `Modules/Overview/OverviewWindow.qml` - Window preview component
- `Modules/Overview/qmldir` - Module registration
- `Services/UI/OverviewService.qml` - State management service
- `Services/Compositor/HyprlandDataService.qml` - Extended Hyprland data

### Modified Files:
- `shell.qml` - Added import and WorkspaceOverview instantiation

## Requirements

- Hyprland compositor (only active on Hyprland)
- QuickShell with Hyprland and Wayland support
- Screencopy protocol support (for window previews)

## Credits

Based on [quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview) by Shanu Kumawat, adapted for noctalia-shell's architecture and theming system.
