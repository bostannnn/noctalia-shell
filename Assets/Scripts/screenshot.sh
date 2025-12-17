#!/usr/bin/env bash

# macOS-like screenshot script for Wayland (Hyprland)
# Dependencies: grim, slurp, satty (or swappy), wl-copy, notify-send (with action support)

# Configuration
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
TEMP_DIR="/tmp/screenshots"
ANNOTATION_TOOL="satty"  # or "swappy"
PREVIEW_TIMEOUT=5000     # ms before auto-saving without annotation
COPY_TO_CLIPBOARD=true

# Create directories
mkdir -p "$SCREENSHOT_DIR" "$TEMP_DIR"

# Generate filename
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEMP_FILE="$TEMP_DIR/screenshot-$TIMESTAMP.png"
FINAL_FILE="$SCREENSHOT_DIR/screenshot-$TIMESTAMP.png"

# Parse arguments
MODE="${1:-region}"  # region, screen, window

take_screenshot() {
    case "$MODE" in
        region)
            grim -g "$(slurp -d)" "$TEMP_FILE" 2>/dev/null
            ;;
        screen)
            grim "$TEMP_FILE"
            ;;
        window)
            # Get active window geometry from hyprctl
            GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
            if [ -n "$GEOM" ] && [ "$GEOM" != "null,null nullxnull" ]; then
                grim -g "$GEOM" "$TEMP_FILE"
            else
                grim "$TEMP_FILE"
            fi
            ;;
    esac
}

# Take the screenshot
take_screenshot

# Check if screenshot was taken
if [ ! -f "$TEMP_FILE" ]; then
    notify-send "Screenshot" "Cancelled or failed" -t 2000
    exit 1
fi

# Copy to clipboard if enabled
if [ "$COPY_TO_CLIPBOARD" = true ]; then
    wl-copy < "$TEMP_FILE"
fi

# Function to save without annotation
save_screenshot() {
    mv "$TEMP_FILE" "$FINAL_FILE"
    notify-send "Screenshot Saved" "$FINAL_FILE" -t 2000
}

# Function to open annotation tool
annotate_screenshot() {
    case "$ANNOTATION_TOOL" in
        satty)
            satty --filename "$TEMP_FILE" --output-filename "$FINAL_FILE" --copy-command "wl-copy"
            ;;
        swappy)
            swappy -f "$TEMP_FILE" -o "$FINAL_FILE"
            ;;
    esac

    # Clean up temp file if annotation tool saved to final location
    [ -f "$TEMP_FILE" ] && rm "$TEMP_FILE"

    # Copy annotated version to clipboard
    if [ -f "$FINAL_FILE" ] && [ "$COPY_TO_CLIPBOARD" = true ]; then
        wl-copy < "$FINAL_FILE"
    fi
}

# Show notification with preview and action
# Using notify-send with action (requires libnotify with action support and compatible daemon)
ACTION=$(notify-send "Screenshot Captured" "Click to annotate" \
    --icon="$TEMP_FILE" \
    --action="annotate=Edit" \
    --action="save=Save" \
    -t "$PREVIEW_TIMEOUT" \
    2>/dev/null)

case "$ACTION" in
    "annotate")
        annotate_screenshot
        ;;
    "save"|"")
        # Empty means timeout or dismissed - just save
        if [ -f "$TEMP_FILE" ]; then
            save_screenshot
        fi
        ;;
esac
