#!/bin/bash
# Restore database backup to Android device
# Usage: ./restore_db.sh <backup_file.db>

set -e  # Exit on error

PACKAGE_NAME="com.example.myassistant"
DB_NAME="myassistant.db"
TEMP_DIR="./.temp_restore"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

# Fallback if adb is in PATH
if ! [ -x "$ADB" ]; then
    ADB="adb"
fi

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Register cleanup on exit
trap cleanup EXIT

echo -e "${BLUE}🔄 Database Restore Tool${NC}"
echo ""

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Error: No backup file specified${NC}"
    echo ""
    echo "Usage: $0 <backup_file.db>"
    echo ""
    echo "Example:"
    echo "  $0 backups/username_backup_20251122_120000.db"
    echo ""

    # List available backups
    if [ -d "./backups" ] && [ "$(ls -A ./backups/*.db 2>/dev/null)" ]; then
        echo -e "${BLUE}📋 Available backups:${NC}"
        ls -lht ./backups/*.db | head -10 | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
        echo ""
    fi
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

# Check if adb is available
if ! command -v "$ADB" &> /dev/null && ! [ -x "$ADB" ]; then
    echo -e "${RED}❌ Error: adb not found. Please install Android SDK Platform-Tools.${NC}"
    exit 1
fi

# Check if sqlite3 is available
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${RED}❌ Error: sqlite3 not found. Please install sqlite3.${NC}"
    exit 1
fi

# Check if device is connected
if ! $ADB devices | grep -q "device$"; then
    echo -e "${RED}❌ Error: No Android device connected.${NC}"
    echo "   Please connect a device or start an emulator."
    exit 1
fi

echo -e "${BLUE}📄 Validating backup file...${NC}"

# Validate that it's a valid SQLite database
if ! sqlite3 "$BACKUP_FILE" "SELECT 1;" &> /dev/null; then
    echo -e "${RED}❌ Error: Invalid SQLite database file${NC}"
    exit 1
fi

# Get backup statistics
USER_COUNT=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
GOAL_COUNT=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM goals WHERE deleted_at IS NULL;" 2>/dev/null || echo "0")
PLAN_COUNT=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM plans WHERE deleted_at IS NULL;" 2>/dev/null || echo "0")
TASK_COUNT=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
EXECUTION_COUNT=$(sqlite3 "$BACKUP_FILE" "SELECT COUNT(*) FROM task_executions;" 2>/dev/null || echo "0")
DB_VERSION=$(sqlite3 "$BACKUP_FILE" "PRAGMA user_version;" 2>/dev/null || echo "unknown")

echo -e "${GREEN}✓ Valid database file${NC}"
echo ""

echo -e "${BLUE}📊 Backup Information:${NC}"
echo -e "  File: ${GREEN}$(basename "$BACKUP_FILE")${NC}"
echo -e "  Size: ${GREEN}$(ls -lh "$BACKUP_FILE" | awk '{print $5}')${NC}"
echo -e "  Database Version: ${GREEN}$DB_VERSION${NC}"
echo ""
echo -e "${BLUE}📈 Data Statistics:${NC}"
echo -e "  Users: ${GREEN}$USER_COUNT${NC}"
echo -e "  Goals: ${GREEN}$GOAL_COUNT${NC} (active)"
echo -e "  Plans: ${GREEN}$PLAN_COUNT${NC} (active)"
echo -e "  Tasks: ${GREEN}$TASK_COUNT${NC}"
echo -e "  Executions: ${GREEN}$EXECUTION_COUNT${NC}"
echo ""

# Look for metadata file
METADATA_FILE="${BACKUP_FILE%.db}.json"
if [ -f "$METADATA_FILE" ]; then
    echo -e "${BLUE}📋 Backup Metadata:${NC}"

    if command -v jq &> /dev/null; then
        BACKUP_DATE=$(jq -r '.backup_date_local // "Unknown"' "$METADATA_FILE" 2>/dev/null || echo "Unknown")
        USERNAME=$(jq -r '.username // "Unknown"' "$METADATA_FILE" 2>/dev/null || echo "Unknown")
        echo -e "  Created: ${GREEN}$BACKUP_DATE${NC}"
        echo -e "  User: ${GREEN}$USERNAME${NC}"
    else
        echo -e "  ${YELLOW}(Install jq to see detailed metadata)${NC}"
    fi
    echo ""
fi

# Export current database for safety backup
SAFETY_BACKUP_DIR="./.temp_restore/safety_backup"
mkdir -p "$SAFETY_BACKUP_DIR"

echo -e "${BLUE}📱 Creating safety backup of current database...${NC}"
SAFETY_BACKUP_FILE="${SAFETY_BACKUP_DIR}/pre_restore_$(date +%Y%m%d_%H%M%S).db"
$ADB exec-out run-as $PACKAGE_NAME cat databases/$DB_NAME > "$SAFETY_BACKUP_FILE" 2>/dev/null || true

if [ -f "$SAFETY_BACKUP_FILE" ] && [ -s "$SAFETY_BACKUP_FILE" ]; then
    echo -e "${GREEN}✓ Safety backup created: $SAFETY_BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}⚠ Could not create safety backup (database might not exist yet)${NC}"
fi
echo ""

# Final confirmation
echo -e "${RED}⚠ WARNING: This will replace the current database!${NC}"
echo -e "${YELLOW}  All current data on the device will be overwritten.${NC}"
if [ -f "$SAFETY_BACKUP_FILE" ] && [ -s "$SAFETY_BACKUP_FILE" ]; then
    echo -e "${GREEN}  A safety backup has been created at:${NC}"
    echo -e "  $SAFETY_BACKUP_FILE"
fi
echo ""
read -p "Are you sure you want to restore this backup? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Restore cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🔄 Restoring database...${NC}"

# Stop the app first to avoid database lock
echo -e "${BLUE}⏹  Stopping application...${NC}"
$ADB shell am force-stop $PACKAGE_NAME 2>/dev/null || true
sleep 1

# Push the database to device
echo -e "${BLUE}📤 Uploading database to device...${NC}"

# Method 1: Direct push to temp location, then move with run-as
$ADB push "$BACKUP_FILE" /data/local/tmp/$DB_NAME > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to push database to device${NC}"
    exit 1
fi

# Copy from temp to app's private directory
$ADB shell "run-as $PACKAGE_NAME cp /data/local/tmp/$DB_NAME databases/$DB_NAME" 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to copy database to app directory${NC}"
    $ADB shell rm /data/local/tmp/$DB_NAME 2>/dev/null || true
    exit 1
fi

# Clean up temp file
$ADB shell rm /data/local/tmp/$DB_NAME 2>/dev/null || true

echo -e "${GREEN}✓ Database uploaded successfully${NC}"

# Set proper permissions
echo -e "${BLUE}🔐 Setting database permissions...${NC}"
$ADB shell "run-as $PACKAGE_NAME chmod 660 databases/$DB_NAME" 2>/dev/null || true

# Verify the restore
echo -e "${BLUE}✅ Verifying restore...${NC}"
TEMP_VERIFY_DB="${TEMP_DIR}/verify.db"
mkdir -p "$TEMP_DIR"
$ADB exec-out run-as $PACKAGE_NAME cat databases/$DB_NAME > "$TEMP_VERIFY_DB" 2>/dev/null

if [ ! -f "$TEMP_VERIFY_DB" ] || [ ! -s "$TEMP_VERIFY_DB" ]; then
    echo -e "${RED}❌ Verification failed: Could not read restored database${NC}"
    exit 1
fi

VERIFY_USERS=$(sqlite3 "$TEMP_VERIFY_DB" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
VERIFY_GOALS=$(sqlite3 "$TEMP_VERIFY_DB" "SELECT COUNT(*) FROM goals WHERE deleted_at IS NULL;" 2>/dev/null || echo "0")
VERIFY_PLANS=$(sqlite3 "$TEMP_VERIFY_DB" "SELECT COUNT(*) FROM plans WHERE deleted_at IS NULL;" 2>/dev/null || echo "0")

if [ "$VERIFY_USERS" = "$USER_COUNT" ] && [ "$VERIFY_GOALS" = "$GOAL_COUNT" ] && [ "$VERIFY_PLANS" = "$PLAN_COUNT" ]; then
    echo -e "${GREEN}✓ Verification successful${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Data counts don't match perfectly${NC}"
    echo -e "  Expected - Users: $USER_COUNT, Goals: $GOAL_COUNT, Plans: $PLAN_COUNT"
    echo -e "  Actual   - Users: $VERIFY_USERS, Goals: $VERIFY_GOALS, Plans: $VERIFY_PLANS"
fi

echo ""
echo -e "${GREEN}✅ Restore completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Restored Data:${NC}"
echo -e "  Users: ${GREEN}$VERIFY_USERS${NC}"
echo -e "  Goals: ${GREEN}$VERIFY_GOALS${NC} (active)"
echo -e "  Plans: ${GREEN}$VERIFY_PLANS${NC} (active)"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "  1. Launch the app on your device"
echo "  2. Verify that all data has been restored correctly"
echo "  3. Check that tasks are generated properly"
echo ""

if [ -f "$SAFETY_BACKUP_FILE" ] && [ -s "$SAFETY_BACKUP_FILE" ]; then
    echo -e "${BLUE}💾 Safety backup location:${NC}"
    echo -e "  $SAFETY_BACKUP_FILE"
    echo -e "${YELLOW}  (Keep this file until you've verified the restore)${NC}"
    echo ""
fi
