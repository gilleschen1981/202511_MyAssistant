#!/bin/bash
# Clear database - Remove all data from Android device
# This will delete the entire database directory

set -e  # Exit on error

PACKAGE_NAME="com.example.myassistant"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

# Fallback if adb is in PATH
if ! [ -x "$ADB" ]; then
    ADB="adb"
fi

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🗑️  Database Clear Tool${NC}"
echo ""

# Check devices and select one if multiple
DEVICE_COUNT=$($ADB devices 2>/dev/null | grep -c "device$")

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ Error: No Android device connected.${NC}"
    echo "   Please connect a device or start an emulator."
    exit 1
elif [ "$DEVICE_COUNT" -gt 1 ]; then
    echo -e "${YELLOW}⚠ Multiple devices detected:${NC}"
    echo ""
    $ADB devices -l | grep "device$"
    echo ""
    read -p "Enter device ID (e.g., emulator-5554): " DEVICE_ID
    ADB="$ADB -s $DEVICE_ID"
    echo ""
fi

# Warning and confirmation
echo -e "${RED}⚠️  WARNING: This will permanently delete all data!${NC}"
echo ""
echo "   This will remove:"
echo "   • All users"
echo "   • All goals"
echo "   • All plans"
echo "   • All tasks"
echo "   • All executions"
echo "   • All notifications"
echo ""
read -p "Are you sure you want to clear the database? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}❌ Operation cancelled.${NC}"
    exit 0
fi

# Stop the app if running
echo -e "${YELLOW}📱 Stopping app...${NC}"
pkill -f "flutter run" 2>/dev/null || true
$ADB shell am force-stop $PACKAGE_NAME 2>/dev/null || true

# Clear database
echo -e "${YELLOW}🗑️  Clearing database...${NC}"
$ADB shell run-as $PACKAGE_NAME rm -rf /data/user/0/$PACKAGE_NAME/databases/ 2>/dev/null

echo ""
echo -e "${GREEN}✅ Database cleared successfully!${NC}"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "   1. Restart the app: flutter run -d <device-id>"
echo "   2. Or restore a backup: ./restore_db.sh <backup-file>"
echo ""
