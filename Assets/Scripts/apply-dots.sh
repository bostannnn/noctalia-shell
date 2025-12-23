#!/usr/bin/env bash

# Script to pull and apply dotfiles from GitHub
# Usage: ./apply-dots.sh

set -e

REPO_DIR="/home/bostan/nixos_dots"
CONFIG_DEST="/home/bostan/.config"
NIXOS_DEST="/etc/nixos"
GITHUB_SSH="git@github.com:bostannnn/nixos_dots.git"

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

cd "$REPO_DIR"

echo -e "${BLUE}==> Ensuring SSH remote for GitHub...${NC}"
git remote set-url origin "$GITHUB_SSH"

echo -e "${BLUE}==> Pulling latest changes from GitHub...${NC}"
git pull origin master

echo ""
echo -e "${YELLOW}This will overwrite your current configuration files:${NC}"
echo -e "  • /etc/nixos"
echo -e "  • ~/.config"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${RED}Aborted.${NC}"
  exit 1
fi

echo -e "${BLUE}==> Syncing ~/.config from repository...${NC}"
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
  "$REPO_DIR/.config/" "$CONFIG_DEST/"

echo -e "${BLUE}==> Syncing /etc/nixos from repository (requires sudo)...${NC}"
sudo rsync -av --delete "$REPO_DIR/etc/nixos/" "$NIXOS_DEST/"

echo -e "${GREEN}✓ Dotfiles applied successfully!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} If you changed NixOS configuration, run:"
echo -e "  sudo nixos-rebuild switch"
