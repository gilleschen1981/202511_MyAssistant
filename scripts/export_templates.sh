#!/bin/bash
# Export Goal and Plan templates from Android device
# Usage: ./export_templates.sh [goal_id] [output_name]

set -e  # Exit on error

PACKAGE_NAME="com.example.myassistant"
DB_NAME="myassistant.db"
TEMP_DIR="./.temp_export"
TEMP_DB="${TEMP_DIR}/${DB_NAME}"
OUTPUT_DIR="./templates"
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

echo -e "${BLUE}🔍 Goal & Plan Template Exporter${NC}"
echo ""

# Check devices and select one if multiple
DEVICE_COUNT=$($ADB devices 2>/dev/null | grep -c "device$")
if [ "$DEVICE_COUNT" -gt 1 ]; then
    echo -e "${YELLOW}⚠ Multiple devices detected:${NC}"
    echo ""
    $ADB devices -l | grep "device$"
    echo ""
    read -p "Enter device ID (e.g., emulator-5554): " DEVICE_ID
    ADB="$ADB -s $DEVICE_ID"
    echo ""
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

# Create temp directory
mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# Export database
echo -e "${BLUE}📱 Exporting database from device...${NC}"
$ADB exec-out run-as $PACKAGE_NAME cat databases/$DB_NAME > "$TEMP_DB" 2>/dev/null

if [ ! -f "$TEMP_DB" ] || [ ! -s "$TEMP_DB" ]; then
    echo -e "${RED}❌ Failed to export database. Make sure:${NC}"
    echo "   1. Device/emulator is running"
    echo "   2. App is installed"
    echo "   3. App is debuggable (debug build)"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✓ Database exported${NC}"
echo ""

# Get current user (assuming first user for now)
USER_ID=$(sqlite3 "$TEMP_DB" "SELECT id FROM users LIMIT 1" 2>/dev/null || echo "")

if [ -z "$USER_ID" ]; then
    echo -e "${RED}❌ No user found in database${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# List available goals
echo -e "${BLUE}📋 Available Goals:${NC}"
echo ""

GOALS_LIST=$(sqlite3 "$TEMP_DB" <<EOF
SELECT
    id,
    title,
    (SELECT COUNT(*) FROM plans WHERE goal_id = goals.id AND status != 'deleted') as plan_count
FROM goals
WHERE user_id = '$USER_ID' AND status != 'deleted'
ORDER BY created_at DESC;
EOF
)

if [ -z "$GOALS_LIST" ]; then
    echo -e "${YELLOW}⚠ No goals found in database${NC}"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Display goals with numbers
counter=1
declare -a goal_ids
declare -a goal_titles

while IFS='|' read -r id title plan_count; do
    echo -e "${GREEN}${counter}.${NC} $title ${BLUE}($plan_count plans)${NC}"
    goal_ids+=("$id")
    goal_titles+=("$title")
    ((counter++))
done <<< "$GOALS_LIST"

echo ""

# Get user input
GOAL_ID="$1"
OUTPUT_NAME="$2"

if [ -z "$GOAL_ID" ]; then
    read -p "Select goal number (or 'all' for all goals): " selection

    if [ "$selection" = "all" ]; then
        GOAL_ID="all"
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$counter" ]; then
        idx=$((selection - 1))
        GOAL_ID="${goal_ids[$idx]}"
        GOAL_TITLE="${goal_titles[$idx]}"
    else
        echo -e "${RED}❌ Invalid selection${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# Export selected goal(s)
echo ""
echo -e "${BLUE}📤 Exporting templates...${NC}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

if [ "$GOAL_ID" = "all" ]; then
    OUTPUT_FILE="${OUTPUT_DIR}/all_templates_${TIMESTAMP}.json"
    TEMPLATE_NAME="All Goals and Plans"

    # Export all goals
    GOALS_JSON=$(sqlite3 "$TEMP_DB" <<EOF
SELECT json_group_array(
    json_object(
        'title', title,
        'description', description,
        'priority', priority,
        'tags', json(tags),
        'status', status,
        'deadline', deadline,
        'successCriteria', success_criteria
    )
)
FROM goals
WHERE user_id = '$USER_ID' AND status != 'deleted';
EOF
)

    # Export all plans
    PLANS_JSON=$(sqlite3 "$TEMP_DB" <<EOF
SELECT json_group_array(
    json_object(
        'goal_title', (SELECT title FROM goals WHERE id = plans.goal_id),
        'name', name,
        'description', description,
        'startDate', start_date,
        'endDate', end_date,
        'status', status,
        'repeatRule', json_object('type', repeat_type, 'customDays', custom_days),
        'taskConfig', json(task_config)
    )
)
FROM plans
WHERE user_id = '$USER_ID' AND status != 'deleted';
EOF
)
else
    if [ -z "$OUTPUT_NAME" ]; then
        OUTPUT_NAME="${GOAL_TITLE// /_}"
    fi
    OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}_${TIMESTAMP}.json"
    TEMPLATE_NAME="${GOAL_TITLE}"

    # Export single goal
    GOALS_JSON=$(sqlite3 "$TEMP_DB" <<EOF
SELECT json_group_array(
    json_object(
        'title', title,
        'description', description,
        'priority', priority,
        'tags', json(tags),
        'status', status,
        'deadline', deadline,
        'successCriteria', success_criteria
    )
)
FROM goals
WHERE id = '$GOAL_ID';
EOF
)

    # Export plans for this goal
    PLANS_JSON=$(sqlite3 "$TEMP_DB" <<EOF
SELECT json_group_array(
    json_object(
        'goal_index', 0,
        'name', name,
        'description', description,
        'startDate', start_date,
        'endDate', end_date,
        'status', status,
        'repeatRule', json_object('type', repeat_type, 'customDays', custom_days),
        'taskConfig', json(task_config)
    )
)
FROM plans
WHERE goal_id = '$GOAL_ID' AND status != 'deleted';
EOF
)
fi

# Create final JSON
cat > "$OUTPUT_FILE" <<EOF
{
  "template_name": "$TEMPLATE_NAME",
  "description": "Exported from MyAssistant app",
  "version": "1.0",
  "exported_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "goals": $GOALS_JSON,
  "plans": $PLANS_JSON
}
EOF

# Clean up
rm -rf "$TEMP_DIR"

# Count exported items
GOAL_COUNT=$(echo "$GOALS_JSON" | grep -o '"title"' | wc -l | tr -d ' ')
PLAN_COUNT=$(echo "$PLANS_JSON" | grep -o '"name"' | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}✅ Export successful!${NC}"
echo -e "${GREEN}✓${NC} Exported $GOAL_COUNT goal(s)"
echo -e "${GREEN}✓${NC} Exported $PLAN_COUNT plan(s)"
echo ""
echo -e "${BLUE}📁 Saved to:${NC} $OUTPUT_FILE"
echo ""
echo -e "${YELLOW}💡 Tip:${NC} You can import this template using:"
echo -e "   ${BLUE}./import_templates.sh $OUTPUT_FILE${NC}"
