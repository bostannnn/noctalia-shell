#!/usr/bin/env bash

# Script to sync and push dotfiles to GitHub
# Usage: ./sync-dots.sh [commit message]

set -e

REPO_DIR="/home/bostan/nixos_dots"
CONFIG_SOURCE="/home/bostan/.config"
NIXOS_SOURCE="/etc/nixos"
GITHUB_SSH="git@github.com:bostannnn/nixos_dots.git"

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cd "$REPO_DIR"

echo -e "${BLUE}==> Ensuring SSH remote for GitHub...${NC}"
git remote set-url origin "$GITHUB_SSH"

echo -e "${BLUE}==> Syncing /etc/nixos...${NC}"
rsync -av --delete "$NIXOS_SOURCE/" "$REPO_DIR/etc/nixos/"

echo -e "${BLUE}==> Syncing ~/.config...${NC}"
rsync -av --delete \
  --exclude='*cache*' \
  --exclude='*.log' \
  --exclude='AmneziaVPN.ORG' \
  --exclude='Electron' \
  --exclude='chromium' \
  --exclude='google-chrome' \
  --exclude='Code' \
  --exclude='discord' \
  --exclude='Slack' \
  --exclude='pulse' \
  --exclude='autostart' \
  --exclude='mgba-forwarder-tools/config.json' \
  --exclude='fragments/settings.json' \
  "$CONFIG_SOURCE/" "$REPO_DIR/.config/"

echo -e "${BLUE}==> Checking for changes...${NC}"
if [[ -z $(git status --porcelain) ]]; then
  echo -e "${GREEN}✓ No changes to commit${NC}"
  exit 0
fi

# Show status
git status --short

# Stage all changes
echo -e "${BLUE}==> Staging changes...${NC}"
git add -A

# Commit with custom or default message
if [ -n "$1" ]; then
  COMMIT_MSG="$1"
else
  COMMIT_MSG="Update dotfiles - $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo -e "${BLUE}==> Creating commit...${NC}"
git commit -m "$(cat <<EOF
$COMMIT_MSG

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

# Push to remote
echo -e "${BLUE}==> Pushing to GitHub...${NC}"
git push origin master

echo -e "${GREEN}✓ Dotfiles synced and pushed successfully!${NC}"
