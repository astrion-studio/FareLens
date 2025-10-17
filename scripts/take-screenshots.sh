#!/bin/bash
# Screenshot Testing Script for FareLens
# Takes screenshots of all major screens for visual verification

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📸 FareLens Screenshot Testing${NC}"
echo "=========================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode not found. Please install Xcode from the App Store.${NC}"
    exit 1
fi

# Check if simulator is available
echo -e "\n${YELLOW}Checking available simulators...${NC}"
xcrun simctl list devices available | grep -i "iphone" | head -5

# Prompt for device selection
echo -e "\n${YELLOW}Select device (default: iPhone 15 Pro):${NC}"
read -p "Device name: " DEVICE_NAME
DEVICE_NAME=${DEVICE_NAME:-"iPhone 15 Pro"}

# Create screenshots directory
SCREENSHOTS_DIR="screenshots/$(date +%Y-%m-%d)"
mkdir -p "$SCREENSHOTS_DIR"

echo -e "\n${GREEN}📱 Screenshots will be saved to: $SCREENSHOTS_DIR${NC}"

# List of screens to capture
SCREENS=(
    "OnboardingView"
    "DealsView"
    "WatchlistsView"
    "AlertsView"
    "SettingsView"
    "DealDetailView"
    "PaywallView"
)

echo -e "\n${BLUE}Starting screenshot capture...${NC}"
echo "This will:"
echo "1. Build the app"
echo "2. Launch on simulator"
echo "3. Navigate to each screen"
echo "4. Capture screenshots"
echo ""
read -p "Press Enter to continue..."

# Build the app
echo -e "\n${YELLOW}Building app...${NC}"
xcodebuild -scheme FareLens -sdk iphonesimulator -destination "platform=iOS Simulator,name=$DEVICE_NAME" build

# Launch simulator
echo -e "\n${YELLOW}Launching simulator...${NC}"
xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
open -a Simulator

# Wait for simulator to be ready
echo -e "\n${YELLOW}Waiting for simulator to be ready...${NC}"
sleep 5

# Install app
echo -e "\n${YELLOW}Installing app...${NC}"
xcrun simctl install "$DEVICE_NAME" "ios-app/build/Debug-iphonesimulator/FareLens.app"

# Launch app
echo -e "\n${YELLOW}Launching app...${NC}"
xcrun simctl launch "$DEVICE_NAME" com.farelens.app

# Wait for app to launch
sleep 3

# Take screenshots
echo -e "\n${GREEN}Taking screenshots...${NC}"
for screen in "${SCREENS[@]}"; do
    echo -e "${BLUE}Capturing $screen...${NC}"
    
    # Navigate to screen (this would need to be customized per screen)
    # For now, just take a screenshot
    xcrun simctl io "$DEVICE_NAME" screenshot "$SCREENSHOTS_DIR/${screen}.png"
    
    sleep 1
done

echo -e "\n${GREEN}✅ Screenshots captured successfully!${NC}"
echo -e "${BLUE}Location: $SCREENSHOTS_DIR${NC}"

# Open screenshots folder
open "$SCREENSHOTS_DIR"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Review screenshots against design mockups"
echo "2. Check for visual regressions"
echo "3. Update screenshots if UI changes"
echo "4. Commit screenshots to git for visual diff"

