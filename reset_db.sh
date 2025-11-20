#!/bin/bash
# Reset database script

echo "Stopping Flutter app..."
pkill -f "flutter run"

echo "Clearing database..."
adb shell run-as com.example.myassistant rm -rf /data/user/0/com.example.myassistant/databases/

echo "Database cleared. You can now restart the app with 'flutter run -d emulator-5554'"
