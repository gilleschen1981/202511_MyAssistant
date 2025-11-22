#!/bin/bash
# Backup entire database from Android device to local machine
# Usage: ./backup_db.sh [output_name]

set -e  # Exit on error

PACKAGE_NAME="com.example.myassistant"
DB_NAME="myassistant.db"
BACKUP_DIR="./backups"
TEMP_DIR="./.temp_backup"
TEMP_DB="${TEMP_DIR}/${DB_NAME}"
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

echo -e "${BLUE}💾 Database Backup Tool${NC}"
echo ""

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

# Create directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# Export database from device
echo -e "${BLUE}📱 Exporting database from device...${NC}"
$ADB exec-out run-as $PACKAGE_NAME cat databases/$DB_NAME > "$TEMP_DB" 2>/dev/null

if [ ! -f "$TEMP_DB" ] || [ ! -s "$TEMP_DB" ]; then
    echo -e "${RED}❌ Failed to export database. Make sure:${NC}"
    echo "   1. Device/emulator is running"
    echo "   2. App is installed and has created the database"
    echo "   3. App is debuggable (debug build)"
    exit 1
fi

echo -e "${GREEN}✓ Database exported${NC}"
echo ""

# Get database statistics
echo -e "${BLUE}📊 Database Statistics:${NC}"

USER_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
GOAL_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM goals WHERE deleted_at IS NULL;" 2>/dev/null || echo "0")
PLAN_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM plans WHERE deleted_at IS NULL;" 2>/dev/null || echo "0")
TASK_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
EXECUTION_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM task_executions;" 2>/dev/null || echo "0")
NOTIFICATION_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM notifications;" 2>/dev/null || echo "0")

echo -e "  Users: ${GREEN}$USER_COUNT${NC}"
echo -e "  Goals: ${GREEN}$GOAL_COUNT${NC} (active)"
echo -e "  Plans: ${GREEN}$PLAN_COUNT${NC} (active)"
echo -e "  Tasks: ${GREEN}$TASK_COUNT${NC}"
echo -e "  Executions: ${GREEN}$EXECUTION_COUNT${NC}"
echo -e "  Notifications: ${GREEN}$NOTIFICATION_COUNT${NC}"
echo ""

# Get current user info for backup metadata
USER_INFO=$(sqlite3 "$TEMP_DB" "SELECT id, username FROM users LIMIT 1;" 2>/dev/null || echo "|")
USER_ID=$(echo "$USER_INFO" | cut -d'|' -f1)
USERNAME=$(echo "$USER_INFO" | cut -d'|' -f2)

if [ -z "$USER_ID" ]; then
    echo -e "${YELLOW}⚠ Warning: No user found in database${NC}"
    USERNAME="unknown"
fi

# Generate backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_NAME="$1"

if [ -z "$OUTPUT_NAME" ]; then
    OUTPUT_NAME="${USERNAME}_backup"
fi

BACKUP_FILE="${BACKUP_DIR}/${OUTPUT_NAME}_${TIMESTAMP}.db"
METADATA_FILE="${BACKUP_DIR}/${OUTPUT_NAME}_${TIMESTAMP}.json"

# Copy database to backup location
cp "$TEMP_DB" "$BACKUP_FILE"

# Create metadata file
cat > "$METADATA_FILE" <<EOF
{
  "backup_name": "$OUTPUT_NAME",
  "backup_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backup_date_local": "$(date +"%Y-%m-%d %H:%M:%S")",
  "user_id": "$USER_ID",
  "username": "$USERNAME",
  "database_version": "$(sqlite3 "$TEMP_DB" "PRAGMA user_version;" 2>/dev/null || echo "unknown")",
  "statistics": {
    "users": $USER_COUNT,
    "goals": $GOAL_COUNT,
    "plans": $PLAN_COUNT,
    "tasks": $TASK_COUNT,
    "task_executions": $EXECUTION_COUNT,
    "notifications": $NOTIFICATION_COUNT
  },
  "tables": [
    "users",
    "user_settings",
    "goals",
    "plans",
    "tasks",
    "task_executions",
    "notifications"
  ]
}
EOF

# Calculate file sizes
DB_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
METADATA_SIZE=$(ls -lh "$METADATA_FILE" | awk '{print $5}')

echo -e "${GREEN}✅ Backup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📁 Backup files:${NC}"
echo -e "  Database: ${GREEN}$BACKUP_FILE${NC} ($DB_SIZE)"
echo -e "  Metadata: ${GREEN}$METADATA_FILE${NC} ($METADATA_SIZE)"
echo ""
echo -e "${YELLOW}💡 To restore this backup, run:${NC}"
echo -e "   ${BLUE}./restore_db.sh $BACKUP_FILE${NC}"
echo ""

# Optional: List all backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.db 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -gt 1 ]; then
    echo -e "${BLUE}📋 Available backups in ${BACKUP_DIR}/:${NC}"
    ls -lht "$BACKUP_DIR"/*.db | head -5 | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        echo -e "  ${YELLOW}... and $((BACKUP_COUNT - 5)) more${NC}"
    fi
    echo ""
fi

# Suggest cleanup if too many backups
if [ "$BACKUP_COUNT" -gt 10 ]; then
    echo -e "${YELLOW}💡 Tip: You have $BACKUP_COUNT backups. Consider cleaning up old backups:${NC}"
    echo -e "   ${BLUE}ls -lt $BACKUP_DIR/*.db | tail -n +11 | awk '{print \$9}' | xargs rm${NC}"
    echo ""
fi
