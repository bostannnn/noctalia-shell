# Current Status

## Summary
- Wallpaper picker: live desktop preview (Hyprland window hide/restore), preview modal via context menu, and panel close now cancels preview.
- Outpainting: new OutpaintService (edge extend + ComfyUI), auto-outpaint queue, and settings UI.
- Smart rotation: shuffle queues, history navigation, and persisted rotation state.
- Liquid Glass: theme settings + overlay widgets; backgrounds can render glass effects (UI toggle still hidden).
- Misc: reduced wallpaper cache log spam and added KDE color scheme post-process.

## New Files
- Commons/Theme.qml
- Services/UI/OutpaintService.qml
- Modules/Panels/Wallpaper/WallpaperPreviewModal.qml
- Widgets/LiquidGlass/GlassOverlay.qml
- Widgets/LiquidGlass/NGlassBackground.qml
- Widgets/LiquidGlass/NGlowBorder.qml
- Widgets/LiquidGlass/NReflectionOverlay.qml

## Settings/Translations
- Added UI theme defaults and outpaint defaults in `Assets/settings-default.json`.
- Added strings for Liquid Glass, outpainting, preview modal, and context menu in `Assets/Translations/en.json`.

## Known Issues / Notes
- Auto-outpaint requires ImageMagick; ComfyUI is optional.
- Preview modal is only accessible from the wallpaper context menu.
- Live preview window hide/restore is Hyprland-only.
- Liquid Glass controls are still commented out in settings UI.

## Testing
- No automated test suite found; tests not run.
