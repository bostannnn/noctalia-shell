#!/usr/bin/env bash

# Video upscaler using Real-ESRGAN for wallpaper videos
# Dependencies: ffmpeg, realesrgan-ncnn-vulkan

set -e

# Configuration
SCALE=${SCALE:-4}
MODEL=${MODEL:-realesrgan-x4plus}  # or realesrgan-x4plus-anime for anime content
TEMP_DIR="/tmp/video-upscale-$$"
THREADS=${THREADS:-4}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <input_video> [output_video]"
    echo ""
    echo "Environment variables:"
    echo "  SCALE=4          Upscale factor (2, 3, or 4)"
    echo "  MODEL=realesrgan-x4plus   Model to use"
    echo "  THREADS=4        Parallel processing threads"
    echo ""
    echo "Available models:"
    echo "  realesrgan-x4plus        - General purpose (default)"
    echo "  realesrgan-x4plus-anime  - Optimized for anime"
    echo "  realesr-animevideov3     - Video-optimized anime model"
    exit 1
}

cleanup() {
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# Check arguments
if [ -z "$1" ]; then
    usage
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
    echo -e "${RED}Error: Input file not found: $INPUT${NC}"
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

echo -e "${GREEN}Video Upscaler${NC}"
echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo "Scale:  ${SCALE}x"
echo "Model:  $MODEL"
echo ""

# Create temp directories
mkdir -p "$TEMP_DIR/frames" "$TEMP_DIR/upscaled"

# Get video info
echo -e "${YELLOW}Analyzing video...${NC}"
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT" | bc -l | xargs printf "%.2f")
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
FRAME_COUNT=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "$INPUT" 2>/dev/null || echo "unknown")

echo "FPS: $FPS"
echo "Duration: ${DURATION}s"
echo "Frames: $FRAME_COUNT"
echo ""

# Extract frames
echo -e "${YELLOW}Extracting frames...${NC}"
ffmpeg -i "$INPUT" -qscale:v 1 -vsync 0 "$TEMP_DIR/frames/%08d.png" -y 2>/dev/null

ACTUAL_FRAMES=$(ls "$TEMP_DIR/frames" | wc -l)
echo "Extracted $ACTUAL_FRAMES frames"
echo ""

# Upscale frames
echo -e "${YELLOW}Upscaling frames with Real-ESRGAN...${NC}"
echo "This may take a while..."

realesrgan-ncnn-vulkan \
    -i "$TEMP_DIR/frames" \
    -o "$TEMP_DIR/upscaled" \
    -n "$MODEL" \
    -s "$SCALE" \
    -f png \
    -j "$THREADS:$THREADS:$THREADS"

echo ""

# Check if audio exists
HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$INPUT" 2>/dev/null | head -1)

# Reassemble video
echo -e "${YELLOW}Reassembling video...${NC}"
if [ -n "$HAS_AUDIO" ]; then
    echo "Including audio track..."
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

# Get final file size
INPUT_SIZE=$(du -h "$INPUT" | cut -f1)
OUTPUT_SIZE=$(du -h "$OUTPUT" | cut -f1)

echo ""
echo -e "${GREEN}Done!${NC}"
echo "Input:  $INPUT ($INPUT_SIZE)"
echo "Output: $OUTPUT ($OUTPUT_SIZE)"
