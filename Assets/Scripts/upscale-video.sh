#!/usr/bin/env bash

# Video upscaler using Real-ESRGAN for wallpaper videos
# Dependencies: ffmpeg, realesrgan-ncnn-vulkan
# Outputs progress in format: PROGRESS:<0.0-1.0>:<stage>
# Usage: upscale-video.sh <input> [output] [model] [scale]

set -e

# Configuration - can be overridden by arguments or env vars
SCALE=${4:-${SCALE:-4}}
MODEL=${3:-${MODEL:-realesrgan-x4plus-anime}}
TEMP_DIR="/tmp/video-upscale-$$"
THREADS=${THREADS:-4}
# Use input file hash for predictable progress file path (echo -n for no newline)
INPUT_HASH=$(echo -n "$1" | md5sum | cut -d' ' -f1)
PROGRESS_FILE="/tmp/video-upscale-progress-${INPUT_HASH}"

# Progress output function (parseable by QML)
emit_progress() {
    local current=$1
    local total=$2
    local stage=$3
    if [ "$total" -gt 0 ]; then
        local ratio=$(awk "BEGIN {printf \"%.4f\", $current / $total}")
        echo "PROGRESS:$ratio:$stage"
        # Also write to progress file for real-time polling
        echo "$ratio:$stage" > "$PROGRESS_FILE"
    fi
}

cleanup() {
    rm -rf "$TEMP_DIR"
    rm -f "$PROGRESS_FILE"
}

trap cleanup EXIT

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <input_video> [output_video]"
    exit 1
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

# Generate output filename
if [ -n "$2" ]; then
    OUTPUT="$2"
else
    BASENAME=$(basename "$INPUT")
    DIRNAME=$(dirname "$INPUT")
    NAME="${BASENAME%.*}"
    EXT="${BASENAME##*.}"
    OUTPUT="$DIRNAME/${NAME}_upscaled.${EXT}"
fi

# Create temp directories
mkdir -p "$TEMP_DIR/frames" "$TEMP_DIR/upscaled"

# Stage 1: Analyze video
emit_progress 0 100 "analyzing"

# Get FPS as fraction (e.g., 30000/1001) and calculate with awk
FPS_FRAC=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT")
FPS=$(echo "$FPS_FRAC" | awk -F'/' '{if(NF==2) printf "%.2f", $1/$2; else print $1}')

# Stage 2: Extract frames (0-10%)
emit_progress 0 100 "extracting"
ffmpeg -i "$INPUT" -qscale:v 1 -vsync 0 "$TEMP_DIR/frames/%08d.png" -y 2>/dev/null

ACTUAL_FRAMES=$(ls "$TEMP_DIR/frames" | wc -l)
emit_progress 10 100 "extracting"

if [ "$ACTUAL_FRAMES" -eq 0 ]; then
    echo "Error: No frames extracted"
    exit 1
fi

# Stage 3: Upscale frames (10-90%)
# Run realesrgan in background and monitor progress
emit_progress 10 100 "upscaling"

realesrgan-ncnn-vulkan \
    -i "$TEMP_DIR/frames" \
    -o "$TEMP_DIR/upscaled" \
    -n "$MODEL" \
    -s "$SCALE" \
    -f png \
    -j "$THREADS:$THREADS:$THREADS" 2>/dev/null &

UPSCALE_PID=$!

# Monitor progress by counting output files
while kill -0 $UPSCALE_PID 2>/dev/null; do
    DONE_FRAMES=$(ls "$TEMP_DIR/upscaled" 2>/dev/null | wc -l)
    # Map to 10-90% range
    if [ "$ACTUAL_FRAMES" -gt 0 ]; then
        PROGRESS=$(awk "BEGIN {printf \"%.4f\", 0.10 + (0.80 * $DONE_FRAMES / $ACTUAL_FRAMES)}")
        echo "PROGRESS:$PROGRESS:upscaling"
        echo "$PROGRESS:upscaling" > "$PROGRESS_FILE"
    fi
    sleep 1
done

# Wait for upscale process to finish and get exit code
wait $UPSCALE_PID
UPSCALE_EXIT=$?

if [ $UPSCALE_EXIT -ne 0 ]; then
    echo "Error: Upscaling failed"
    exit 1
fi

emit_progress 90 100 "upscaling"

# Stage 4: Reassemble video (90-100%)
emit_progress 90 100 "encoding"

HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$INPUT" 2>/dev/null | head -1)

if [ -n "$HAS_AUDIO" ]; then
    ffmpeg -framerate "$FPS" -i "$TEMP_DIR/upscaled/%08d.png" -i "$INPUT" \
        -map 0:v -map 1:a? \
        -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p \
        -c:a copy \
        -shortest \
        "$OUTPUT" -y 2>/dev/null
else
    ffmpeg -framerate "$FPS" -i "$TEMP_DIR/upscaled/%08d.png" \
        -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p \
        "$OUTPUT" -y 2>/dev/null
fi

emit_progress 100 100 "done"
echo "COMPLETE:$OUTPUT"
