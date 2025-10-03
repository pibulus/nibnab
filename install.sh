#!/bin/bash

# ===================================================================
# NibNab Install Script
# Builds and installs NibNab to Applications, kills old version
# ===================================================================

set -e

APP_NAME="NibNab"
BUILD_DIR="build"
INSTALL_PATH="/Applications"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ${YELLOW}✨ NibNab Installation${CYAN}  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# Kill any running instance
if pgrep -x "$APP_NAME" > /dev/null; then
    echo -e "${YELLOW}⚡ Stopping running $APP_NAME...${NC}"
    pkill -x "$APP_NAME"
    sleep 1
fi

# Build the app
echo -e "${YELLOW}🔨 Building $APP_NAME...${NC}"
./build.sh

if [ ! -d "$BUILD_DIR/${APP_NAME}.app" ]; then
    echo -e "${RED}❌ Build failed - ${APP_NAME}.app not found${NC}"
    exit 1
fi

# Remove old version if it exists
if [ -d "$INSTALL_PATH/${APP_NAME}.app" ]; then
    echo -e "${YELLOW}🗑️  Removing old version...${NC}"
    rm -rf "$INSTALL_PATH/${APP_NAME}.app"
fi

# Install new version
echo -e "${YELLOW}📦 Installing to $INSTALL_PATH...${NC}"
cp -r "$BUILD_DIR/${APP_NAME}.app" "$INSTALL_PATH/"

echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo -e "${CYAN}🎯 Quick Start:${NC}"
echo -e "  • Launch from Spotlight: ${YELLOW}Cmd+Space${NC} → type '${YELLOW}nibnab${NC}'"
echo -e "  • Global shortcut: ${YELLOW}Cmd+Shift+V${NC} to open anywhere"
echo -e "  • Look for ${YELLOW}highlighter icon${NC} in menubar"
echo ""
echo -e "${CYAN}⚙️  Settings in menubar:${NC}"
echo -e "  • ${YELLOW}Monitor${NC} - Watch clipboard for changes"
echo -e "  • ${YELLOW}Auto-copy${NC} - Capture text when you select it"
echo -e "  • ${YELLOW}Auto-launch${NC} - Start on login"
echo ""

# Ask if user wants to launch now
read -p "$(echo -e ${CYAN}Launch NibNab now? [Y/n]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo -e "${GREEN}🚀 Launching NibNab...${NC}"
    open "$INSTALL_PATH/${APP_NAME}.app"
    sleep 1
    echo ""
    echo -e "${YELLOW}👀 Check your menubar for the highlighter icon!${NC}"
else
    echo -e "${CYAN}Cool. Launch it from Spotlight when ready.${NC}"
fi

echo ""
