#!/bin/bash
# Export database from Android emulator to local machine

PACKAGE_NAME="com.example.myassistant"
DB_NAME="myassistant.db"
OUTPUT_DIR="./debug_db"
OUTPUT_PATH="${OUTPUT_DIR}/${DB_NAME}"

echo "🔍 Exporting database from $PACKAGE_NAME..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Export database using run-as (works for debuggable apps)
adb exec-out run-as $PACKAGE_NAME cat databases/$DB_NAME > "$OUTPUT_PATH"

# Check if export was successful
if [ -f "$OUTPUT_PATH" ] && [ -s "$OUTPUT_PATH" ]; then
    FILE_SIZE=$(ls -lh "$OUTPUT_PATH" | awk '{print $5}')
    echo "✅ Database exported successfully!"
    echo "📁 Location: $OUTPUT_PATH"
    echo "📊 Size: $FILE_SIZE"

    # List tables in the database
    echo ""
    echo "📋 Tables in database:"
    sqlite3 "$OUTPUT_PATH" ".tables"

    # Optional: Open with DB Browser if installed
    if command -v "db-browser-for-sqlite" &> /dev/null; then
        echo ""
        read -p "Open with DB Browser for SQLite? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open -a "DB Browser for SQLite" "$OUTPUT_PATH"
        fi
    else
        echo ""
        echo "💡 Tip: Install DB Browser for SQLite with:"
        echo "   brew install --cask db-browser-for-sqlite"
    fi
else
    echo "❌ Export failed. Make sure:"
    echo "   1. Emulator is running"
    echo "   2. App is installed and has created the database"
    echo "   3. App is debuggable (debug build)"
fi
