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

# Check if device is connected
if ! $ADB devices | grep -q "device$"; then
    echo -e "${RED}❌ Error: No Android device connected.${NC}"
    echo "   Please connect a device or start an emulator."
    exit 1
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

# Parse and import goals
GOAL_INDEX=0
declare -a GOAL_ID_MAP  # Array to map index to new goal ID
IMPORTED_GOALS=0

while read -r goal_json; do
    # Generate new UUID for goal
    NEW_GOAL_ID=$(generate_uuid)
    GOAL_ID_MAP+=("$NEW_GOAL_ID")  # Append to array

    # Extract goal fields
    TITLE=$(echo "$goal_json" | jq -r '.title')
    DESCRIPTION=$(echo "$goal_json" | jq -r '.description // ""')
    PRIORITY=$(echo "$goal_json" | jq -r '.priority // "medium"')
    TAGS=$(echo "$goal_json" | jq -c '.tags // []')
    STATUS=$(echo "$goal_json" | jq -r '.status // "active"')
    DEADLINE=$(echo "$goal_json" | jq -r '.deadline // ""')
    SUCCESS_CRITERIA=$(echo "$goal_json" | jq -r '.successCriteria // ""')

    # Escape values for SQL
    TITLE=$(sql_escape "$TITLE")
    DESCRIPTION=$(sql_escape "$DESCRIPTION")
    SUCCESS_CRITERIA=$(sql_escape "$SUCCESS_CRITERIA")

    # Build INSERT statement
    if [ -z "$DEADLINE" ] || [ "$DEADLINE" = "null" ]; then
        DEADLINE_VAL="NULL"
    else
        DEADLINE_VAL="'$DEADLINE'"
    fi

    # Insert into database
    sqlite3 "$TEMP_DB" <<EOF
INSERT INTO goals (id, user_id, title, description, priority, tags, status, deadline, success_criteria, created_at, updated_at)
VALUES ('$NEW_GOAL_ID', '$USER_ID', '$TITLE', '$DESCRIPTION', '$PRIORITY', '$TAGS', '$STATUS', $DEADLINE_VAL, '$SUCCESS_CRITERIA', $TIMESTAMP, $TIMESTAMP);
EOF

    echo -e "${GREEN}✓${NC} Imported goal: $TITLE (id: ${NEW_GOAL_ID:0:8}...)"
    ((GOAL_INDEX++))
    ((IMPORTED_GOALS++))
done < <(jq -c '.goals[]' "$TEMPLATE_FILE")

# Parse and import plans
PLAN_INDEX=0
IMPORTED_PLANS=0

while read -r plan_json; do
    # Generate new UUID for plan
    NEW_PLAN_ID=$(generate_uuid)

    # Extract plan fields
    GOAL_INDEX_REF=$(echo "$plan_json" | jq -r '.goal_index // 0')
    GOAL_TITLE=$(echo "$plan_json" | jq -r '.goal_title // ""')
    NAME=$(echo "$plan_json" | jq -r '.name')
    DESCRIPTION=$(echo "$plan_json" | jq -r '.description // ""')
    START_DATE=$(echo "$plan_json" | jq -r '.startDate // ""')
    END_DATE=$(echo "$plan_json" | jq -r '.endDate // ""')
    STATUS=$(echo "$plan_json" | jq -r '.status // "active"')

    # Extract repeat rule components
    REPEAT_TYPE=$(echo "$plan_json" | jq -r '.repeatRule.type // "oneTime"')
    CUSTOM_DAYS=$(echo "$plan_json" | jq -r '.repeatRule.customDays // null')

    # Use customDays directly (it's already a number or null)
    if [ "$CUSTOM_DAYS" != "null" ] && [ -n "$CUSTOM_DAYS" ]; then
        CUSTOM_DAYS_VAL="$CUSTOM_DAYS"
    else
        CUSTOM_DAYS_VAL="NULL"
    fi

    TASK_CONFIG=$(echo "$plan_json" | jq -c '.taskConfig // {}')

    # Get the corresponding goal ID
    if [ ! -z "$GOAL_TITLE" ] && [ "$GOAL_TITLE" != "null" ]; then
        # Find goal by title
        GOAL_TITLE_ESCAPED=$(sql_escape "$GOAL_TITLE")
        GOAL_ID=$(sqlite3 "$TEMP_DB" "SELECT id FROM goals WHERE user_id='$USER_ID' AND title='$GOAL_TITLE_ESCAPED' LIMIT 1;")
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
    NAME=$(sql_escape "$NAME")
    DESCRIPTION=$(sql_escape "$DESCRIPTION")

    # Insert into database
    sqlite3 "$TEMP_DB" <<EOF
INSERT INTO plans (id, user_id, goal_id, name, description, start_date, end_date, repeat_type, custom_days, task_config, status, created_at, updated_at, total_task_count, completed_task_count, skipped_task_count, completion_rate)
VALUES ('$NEW_PLAN_ID', '$USER_ID', '$GOAL_ID', '$NAME', '$DESCRIPTION', '$START_DATE', '$END_DATE', '$REPEAT_TYPE', $CUSTOM_DAYS_VAL, '$TASK_CONFIG', '$STATUS', $TIMESTAMP, $TIMESTAMP, 0, 0, 0, 0.0);
EOF

    echo -e "${GREEN}✓${NC} Imported plan: $NAME (id: ${NEW_PLAN_ID:0:8}...)"
    ((PLAN_INDEX++))
    ((IMPORTED_PLANS++))
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
echo -e "${GREEN}✓${NC} Imported $IMPORTED_GOALS goal(s)"
echo -e "${GREEN}✓${NC} Imported $IMPORTED_PLANS plan(s)"
echo ""
echo -e "${YELLOW}💡 Note:${NC} Please restart the app to see the imported data."
echo -e "   Tasks will be auto-generated based on plan repeat rules."
