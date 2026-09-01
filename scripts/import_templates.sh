#!/bin/bash
# Import Goal and Plan templates to Android device
# Usage: ./import_templates.sh <template_file.json>

set -e  # Exit on error

PACKAGE_NAME="com.example.myassistant"
DB_NAME="myassistant.db"
TEMP_DIR="./.temp_import"
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

echo -e "${BLUE}📥 Goal & Plan Template Importer${NC}"
echo ""

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Error: No template file specified${NC}"
    echo ""
    echo "Usage: $0 <template_file.json>"
    echo ""
    echo "Example:"
    echo "  $0 templates/fitness_plan.json"
    exit 1
fi

TEMPLATE_FILE="$1"

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}❌ Error: Template file not found: $TEMPLATE_FILE${NC}"
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

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ Error: jq is required for importing templates${NC}"
    echo "   Please install jq: brew install jq"
    exit 1
fi

# Check devices and select one
DEVICE_LIST=$("$ADB" devices 2>&1 | grep -E "device$|emulator")
DEVICE_COUNT=$(echo "$DEVICE_LIST" | wc -l | tr -d ' ')

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ Error: No Android device connected.${NC}"
    echo "   Please connect a device or start an emulator."
    exit 1
elif [ "$DEVICE_COUNT" -gt 1 ]; then
    echo -e "${YELLOW}⚠ Multiple devices detected:${NC}"
    echo ""
    "$ADB" devices -l
    echo ""
    read -p "Enter device ID (e.g., emulator-5554): " DEVICE_ID
    if [ -n "$DEVICE_ID" ]; then
        ADB="$ADB -s $DEVICE_ID"
    fi
    echo ""
fi

echo -e "${BLUE}📄 Validating template file...${NC}"

# Validate JSON format and extract info
if ! jq empty "$TEMPLATE_FILE" 2>/dev/null; then
    echo -e "${RED}❌ Error: Invalid JSON format${NC}"
    exit 1
fi

TEMPLATE_NAME=$(jq -r '.template_name // "Unknown"' "$TEMPLATE_FILE")
GOAL_COUNT=$(jq '.goals | length' "$TEMPLATE_FILE")
PLAN_COUNT=$(jq '.plans | length' "$TEMPLATE_FILE")

echo -e "${GREEN}✓ Valid JSON format${NC}"
echo ""
echo -e "${BLUE}📋 Template Information:${NC}"
echo -e "  Name: ${GREEN}$TEMPLATE_NAME${NC}"
echo -e "  Goals: ${GREEN}$GOAL_COUNT${NC}"
echo -e "  Plans: ${GREEN}$PLAN_COUNT${NC}"
echo ""

# Export database from device
echo -e "${BLUE}📱 Exporting database from device...${NC}"
mkdir -p "$TEMP_DIR"
$ADB exec-out run-as $PACKAGE_NAME cat databases/$DB_NAME > "$TEMP_DB" 2>/dev/null

if [ ! -f "$TEMP_DB" ] || [ ! -s "$TEMP_DB" ]; then
    echo -e "${RED}❌ Failed to export database${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Database exported${NC}"

# Get current user ID
USER_ID=$(sqlite3 "$TEMP_DB" "SELECT id FROM users LIMIT 1;" 2>/dev/null || echo "")

if [ -z "$USER_ID" ]; then
    echo -e "${RED}❌ Error: No user found in database${NC}"
    echo "   Make sure the app has been set up with a user account."
    exit 1
fi

echo -e "${GREEN}✓ User ID: $USER_ID${NC}"
echo ""

# Confirm import
echo -e "${YELLOW}⚠ This will import:${NC}"
echo -e "  • ${GREEN}$GOAL_COUNT${NC} goal(s)"
echo -e "  • ${GREEN}$PLAN_COUNT${NC} plan(s)"
echo ""
read -p "Continue with import? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Import cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}📥 Importing templates...${NC}"

# Function to generate UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        echo $(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        python3 -c "import uuid; print(str(uuid.uuid4()))"
    fi
}

# Function to escape single quotes for SQL
sql_escape() {
    echo "$1" | sed "s/'/''/g"
}

# Get current timestamp in milliseconds
TIMESTAMP=$(date +%s)000

# Default timestamps for template imports
# Use current time (in seconds, not milliseconds) for startDate
IMPORT_START_DATE=$(date +%s)

# Use a far future date for endDate and deadline (2050-01-01)
# This is approximately 2524608000 seconds since epoch (Jan 1, 2050)
DEFAULT_END_DATE=2524608000
DEFAULT_DEADLINE=2524608000

# Parse and import goals
GOAL_INDEX=0
declare -a GOAL_ID_MAP  # Array to map index to new goal ID
IMPORTED_GOALS=0
UPDATED_GOALS=0

while read -r goal_json; do
    # Extract goal fields
    TITLE=$(echo "$goal_json" | jq -r '.title')
    DESCRIPTION=$(echo "$goal_json" | jq -r '.description // ""')
    PRIORITY=$(echo "$goal_json" | jq -r '.priority // "medium"')
    TAGS=$(echo "$goal_json" | jq -c '.tags // []')
    STATUS=$(echo "$goal_json" | jq -r '.status // "active"')
    SUCCESS_CRITERIA=$(echo "$goal_json" | jq -r '.successCriteria // ""')

    # Escape values for SQL
    TITLE_ESCAPED=$(sql_escape "$TITLE")
    DESCRIPTION=$(sql_escape "$DESCRIPTION")
    SUCCESS_CRITERIA=$(sql_escape "$SUCCESS_CRITERIA")

    # Use default deadline for templates (far future date)
    DEADLINE_VAL="$DEFAULT_DEADLINE"

    # Check if goal with same title already exists
    EXISTING_GOAL_ID=$(sqlite3 "$TEMP_DB" "SELECT id FROM goals WHERE user_id='$USER_ID' AND title='$TITLE_ESCAPED' AND status!='deleted' LIMIT 1;")

    if [ -n "$EXISTING_GOAL_ID" ]; then
        # Update existing goal
        GOAL_ID_MAP+=("$EXISTING_GOAL_ID")  # Use existing ID

        sqlite3 "$TEMP_DB" <<EOF
UPDATE goals
SET description='$DESCRIPTION',
    priority='$PRIORITY',
    tags='$TAGS',
    status='$STATUS',
    deadline=$DEADLINE_VAL,
    success_criteria='$SUCCESS_CRITERIA',
    updated_at=$TIMESTAMP
WHERE id='$EXISTING_GOAL_ID';
EOF

        echo -e "${BLUE}🔄${NC} Updated goal: $TITLE (id: ${EXISTING_GOAL_ID:0:8}...)"
        UPDATED_GOALS=$((UPDATED_GOALS + 1))
    else
        # Create new goal
        NEW_GOAL_ID=$(generate_uuid)
        GOAL_ID_MAP+=("$NEW_GOAL_ID")  # Append to array

        sqlite3 "$TEMP_DB" <<EOF
INSERT INTO goals (id, user_id, title, description, priority, tags, status, deadline, success_criteria, created_at, updated_at)
VALUES ('$NEW_GOAL_ID', '$USER_ID', '$TITLE_ESCAPED', '$DESCRIPTION', '$PRIORITY', '$TAGS', '$STATUS', $DEADLINE_VAL, '$SUCCESS_CRITERIA', $TIMESTAMP, $TIMESTAMP);
EOF

        echo -e "${GREEN}✓${NC} Imported goal: $TITLE (id: ${NEW_GOAL_ID:0:8}...)"
        IMPORTED_GOALS=$((IMPORTED_GOALS + 1))
    fi

    GOAL_INDEX=$((GOAL_INDEX + 1))
done < <(jq -c '.goals[]' "$TEMPLATE_FILE")

# Parse and import plans
PLAN_INDEX=0
IMPORTED_PLANS=0
UPDATED_PLANS=0

while read -r plan_json; do
    # Extract plan fields
    GOAL_INDEX_REF=$(echo "$plan_json" | jq -r '.goal_index // 0')
    GOAL_TITLE=$(echo "$plan_json" | jq -r '.goal_title // ""')
    NAME=$(echo "$plan_json" | jq -r '.name')
    DESCRIPTION=$(echo "$plan_json" | jq -r '.description // ""')
    STATUS=$(echo "$plan_json" | jq -r '.status // "active"')

    # Use import time for startDate and far future for endDate
    START_DATE="$IMPORT_START_DATE"
    END_DATE="$DEFAULT_END_DATE"

    # Extract repeat rule components
    REPEAT_TYPE=$(echo "$plan_json" | jq -r '.repeatRule.type // "oneTime"')
    CUSTOM_DAYS=$(echo "$plan_json" | jq -r '.repeatRule.customDays // null')
    SELECTED_DAYS=$(echo "$plan_json" | jq -c '.repeatRule.selectedDaysOfWeek // null')

    # Use customDays directly (it's already a number or null)
    if [ "$CUSTOM_DAYS" != "null" ] && [ -n "$CUSTOM_DAYS" ]; then
        CUSTOM_DAYS_VAL="$CUSTOM_DAYS"
    else
        CUSTOM_DAYS_VAL="NULL"
    fi

    # Handle selectedDaysOfWeek (it's already JSON or null)
    if [ "$SELECTED_DAYS" != "null" ] && [ -n "$SELECTED_DAYS" ]; then
        SELECTED_DAYS_VAL="'$SELECTED_DAYS'"
    else
        SELECTED_DAYS_VAL="NULL"
    fi

    TASK_CONFIG=$(echo "$plan_json" | jq -c '.taskConfig // {}')

    # Get the corresponding goal ID
    if [ ! -z "$GOAL_TITLE" ] && [ "$GOAL_TITLE" != "null" ]; then
        # Find goal by title
        GOAL_TITLE_ESCAPED=$(sql_escape "$GOAL_TITLE")
        GOAL_ID=$(sqlite3 "$TEMP_DB" "SELECT id FROM goals WHERE user_id='$USER_ID' AND title='$GOAL_TITLE_ESCAPED' AND status!='deleted' LIMIT 1;")
    else
        # Use goal index mapping
        GOAL_ID="${GOAL_ID_MAP[$GOAL_INDEX_REF]}"
    fi

    if [ -z "$GOAL_ID" ]; then
        echo -e "${YELLOW}⚠${NC} Skipping plan '$NAME': goal not found"
        ((PLAN_INDEX++))
        continue
    fi

    # Escape values for SQL
    NAME_ESCAPED=$(sql_escape "$NAME")
    DESCRIPTION=$(sql_escape "$DESCRIPTION")

    # Check if plan with same name already exists
    EXISTING_PLAN_ID=$(sqlite3 "$TEMP_DB" "SELECT id FROM plans WHERE user_id='$USER_ID' AND name='$NAME_ESCAPED' AND status!='deleted' LIMIT 1;")

    if [ -n "$EXISTING_PLAN_ID" ]; then
        # Update existing plan (DO NOT update start_date, DO update end_date)
        sqlite3 "$TEMP_DB" <<EOF
UPDATE plans
SET description='$DESCRIPTION',
    goal_id='$GOAL_ID',
    end_date=$END_DATE,
    repeat_type='$REPEAT_TYPE',
    custom_days=$CUSTOM_DAYS_VAL,
    selected_days_of_week=$SELECTED_DAYS_VAL,
    task_config='$TASK_CONFIG',
    status='$STATUS',
    updated_at=$TIMESTAMP
WHERE id='$EXISTING_PLAN_ID';
EOF

        echo -e "${BLUE}🔄${NC} Updated plan: $NAME (id: ${EXISTING_PLAN_ID:0:8}...)"
        UPDATED_PLANS=$((UPDATED_PLANS + 1))
    else
        # Create new plan
        NEW_PLAN_ID=$(generate_uuid)

        sqlite3 "$TEMP_DB" <<EOF
INSERT INTO plans (id, user_id, goal_id, name, description, start_date, end_date, repeat_type, custom_days, selected_days_of_week, task_config, status, created_at, updated_at, total_task_count, completed_task_count, skipped_task_count, completion_rate)
VALUES ('$NEW_PLAN_ID', '$USER_ID', '$GOAL_ID', '$NAME_ESCAPED', '$DESCRIPTION', '$START_DATE', '$END_DATE', '$REPEAT_TYPE', $CUSTOM_DAYS_VAL, $SELECTED_DAYS_VAL, '$TASK_CONFIG', '$STATUS', $TIMESTAMP, $TIMESTAMP, 0, 0, 0, 0.0);
EOF

        echo -e "${GREEN}✓${NC} Imported plan: $NAME (id: ${NEW_PLAN_ID:0:8}...)"
        IMPORTED_PLANS=$((IMPORTED_PLANS + 1))
    fi

    PLAN_INDEX=$((PLAN_INDEX + 1))
done < <(jq -c '.plans[]' "$TEMPLATE_FILE")

echo ""

# Push database back to device
echo -e "${BLUE}📤 Uploading modified database to device...${NC}"

# Stop the app first (to avoid database lock)
$ADB shell am force-stop $PACKAGE_NAME 2>/dev/null || true

# Push the database back
$ADB push "$TEMP_DB" /data/local/tmp/$DB_NAME > /dev/null 2>&1
$ADB shell "run-as $PACKAGE_NAME cp /data/local/tmp/$DB_NAME databases/$DB_NAME" 2>/dev/null
$ADB shell rm /data/local/tmp/$DB_NAME 2>/dev/null || true

echo -e "${GREEN}✓ Database updated on device${NC}"
echo ""

echo -e "${GREEN}✅ Import completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Import Summary:${NC}"
echo -e "${GREEN}  Goals:${NC}"
echo -e "    • Imported: $IMPORTED_GOALS"
echo -e "    • Updated:  $UPDATED_GOALS"
echo -e "${GREEN}  Plans:${NC}"
echo -e "    • Imported: $IMPORTED_PLANS"
echo -e "    • Updated:  $UPDATED_PLANS"
echo ""
echo -e "${YELLOW}💡 Note:${NC} Please restart the app to see the imported/updated data."
echo -e "   Tasks will be auto-generated based on plan repeat rules."
