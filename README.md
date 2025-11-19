# MyAssistant

A comprehensive personal task management Flutter application for Android that helps users organize their goals, create actionable plans, and track daily tasks with various execution modes.

## Quick Start Guide

For experienced developers who want to run the project quickly:

```bash
# 1. Ensure Android emulator is running
flutter emulators --launch <emulator_name>

# 2. Navigate to project directory
cd myassistant

# 3. Install dependencies and generate code
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Run the app
flutter run -d android
```

## Features

### Core Functionality

- **Goal Management**: Create and track personal goals with deadlines and progress monitoring
- **Plan Creation**: Design detailed plans with scheduled tasks to achieve your goals
- **Task Execution**: Multiple task types for different tracking needs:
  - Simple checkbox tasks
  - Timer-based tasks with countdown
  - Counter tasks for repetitive actions
  - Evaluation tasks for quality assessment
  - Combined timer + counter tasks
  - Combined counter + evaluation tasks
- **Progress Tracking**: Visual progress indicators and statistics
- **Notifications**: Local notifications for task reminders
- **Authentication**: Secure user authentication with session management

### Key Design Decisions

- **Immutable Plan Names**: Once created, plan names cannot be changed (unique constraint)
- **UUID-based IDs**: Plans use UUIDs as primary identifiers
- **No Task Deletion**: Tasks cannot be deleted, only marked as completed or skipped
- **Unlimited Re-execution**: Tasks can be repeated unlimited times within their time window
- **Soft Delete**: Goals and plans support soft delete (but not tasks)

## Architecture

The application follows Clean Architecture principles with clear separation of concerns:

```
lib/
├── core/               # Core utilities and constants
│   ├── constants/      # App-wide constants
│   ├── theme/         # Material Design 3 theming
│   ├── utils/         # Utility functions
│   └── errors/        # Error handling
│
├── data/              # Data layer
│   ├── models/        # Data models with JSON serialization
│   │   └── enums/     # Status and type enumerations
│   ├── repositories/  # Repository implementations
│   ├── data_sources/  # Local and remote data sources
│   │   ├── local/     # SQLite database and preferences
│   │   └── remote/    # API integrations (future)
│   └── services/      # Business services
│
├── domain/            # Domain layer
│   ├── entities/      # Business entities
│   ├── repositories/  # Repository interfaces
│   └── use_cases/     # Business logic use cases
│
├── presentation/      # Presentation layer
│   ├── common/        # Shared UI components
│   ├── features/      # Feature modules
│   │   ├── auth/      # Authentication screens
│   │   ├── tasks/     # Task management
│   │   ├── goals/     # Goal management
│   │   ├── plans/     # Plan management
│   │   └── profile/   # User profile
│   ├── providers/     # Riverpod state management
│   └── routes/        # Navigation configuration
│
└── di/               # Dependency injection
    └── modules/      # DI module definitions
```

## Tech Stack

- **Framework**: Flutter 3.x
- **Platform**: Android only
- **State Management**: Riverpod 2.x with StateNotifier pattern
- **Navigation**: GoRouter for declarative routing
- **Database**: SQLite with sqflite
- **Serialization**: json_annotation with build_runner
- **Authentication**: Local authentication with secure storage
- **Notifications**: flutter_local_notifications
- **Testing**: flutter_test with mockito

## Installation

### Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher
- Android Studio with Android SDK
- Android Emulator or physical Android device for testing
- Minimum Android API level: 21 (Android 5.0)
- Java 11 or higher

### Android Studio Setup

1. **Download and Install Android Studio**:
   - Download from: https://developer.android.com/studio
   - Install Android Studio following the setup wizard
   - Accept Android SDK licenses during installation

2. **Configure Android SDK**:
   - Open Android Studio → Preferences/Settings → Appearance & Behavior → System Settings → Android SDK
   - Install the following:
     - Android SDK Platform-Tools
     - Android SDK Build-Tools
     - Android API 34 (or latest)
     - Android Emulator
     - Android SDK Command-line Tools

3. **Set Environment Variables** (if not automatically set):
   ```bash
   # Add to ~/.bashrc, ~/.zshrc, or ~/.bash_profile
   export ANDROID_HOME=$HOME/Library/Android/sdk  # macOS
   # export ANDROID_HOME=$HOME/Android/Sdk        # Linux
   export PATH=$PATH:$ANDROID_HOME/emulator
   export PATH=$PATH:$ANDROID_HOME/platform-tools
   export PATH=$PATH:$ANDROID_HOME/tools
   export PATH=$PATH:$ANDROID_HOME/tools/bin
   ```

### Creating and Starting Android Emulator

1. **Create an Android Virtual Device (AVD)**:

   **Option A: Using Android Studio GUI**
   - Open Android Studio
   - Click "Virtual Device Manager" icon or go to Tools → AVD Manager
   - Click "Create Virtual Device"
   - Select a device (e.g., Pixel 6)
   - Select system image (API 34 or latest)
   - Name your emulator (e.g., "MyAssistant_Emulator")
   - Click "Finish"

   **Option B: Using Command Line**
   ```bash
   # List available system images
   sdkmanager --list | grep system-images

   # Download a system image (example for API 34)
   sdkmanager "system-images;android-34;google_apis;x86_64"

   # Create AVD
   avdmanager create avd -n MyAssistant_Emulator -k "system-images;android-34;google_apis;x86_64"
   ```

2. **Start the Android Emulator**:

   **Option A: From Android Studio**
   - Open Android Studio
   - Click Virtual Device Manager
   - Click the play button next to your emulator

   **Option B: From Command Line**
   ```bash
   # List available emulators
   emulator -list-avds

   # Start specific emulator
   emulator -avd MyAssistant_Emulator

   # Or use Flutter to list and launch
   flutter emulators
   flutter emulators --launch MyAssistant_Emulator
   ```

### Project Setup Steps

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd myassistant
   ```

2. **Verify Flutter installation**:
   ```bash
   flutter doctor
   # Ensure all checkmarks are green for Android development
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Generate code for JSON serialization**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Running the Application

1. **Ensure emulator is running**:
   ```bash
   # Check if emulator is detected
   flutter devices
   # Should show your running Android emulator
   ```

2. **Run the application**:
   ```bash
   # Run on any available Android device
   flutter run

   # Run on specific Android emulator
   flutter run -d android

   # Run on specific device by ID
   flutter run -d emulator-5554  # Replace with your device ID
   ```

3. **Hot Reload and Hot Restart**:
   - While the app is running:
     - Press `r` for hot reload (quick UI updates)
     - Press `R` for hot restart (full app restart)
     - Press `q` to quit

### Troubleshooting

**Emulator not starting?**
```bash
# Kill any hanging emulator processes
pkill -f qemu-system

# Cold boot the emulator
emulator -avd MyAssistant_Emulator -no-snapshot-load
```

**ADB connection issues?**
```bash
# Restart ADB server
adb kill-server
adb start-server
adb devices
```

**Flutter not detecting emulator?**
```bash
# Clean Flutter and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter devices
```

**Build errors?**
```bash
# Analyze code for issues
flutter analyze

# Auto-fix issues
dart fix --apply

# Clean and rebuild
flutter clean
flutter pub get
```

## Development Workflow

### Daily Development Commands

```bash
# Start your development session
flutter emulators --launch <your_emulator>  # Start emulator
flutter pub get                             # Get dependencies
flutter run                                  # Run the app

# During development
r                                           # Hot reload (in terminal while app is running)
R                                           # Hot restart
q                                           # Quit the app

# Code generation (after modifying models)
flutter pub run build_runner build --delete-conflicting-outputs

# Check code quality
flutter analyze                             # Analyze code
dart fix --apply                            # Auto-fix issues
flutter format lib/ test/                   # Format code
```

### Database Inspection and Management

#### Quick Database Export (Recommended)

The easiest way to inspect the SQLite database:

```bash
# Export database from emulator to local machine
./scripts/export_db.sh
```

This script will:
- Export the database to `debug_db/myassistant.db`
- Show database size and table list
- Optionally open with DB Browser for SQLite

#### Install DB Browser for SQLite

```bash
# macOS
brew install --cask db-browser-for-sqlite

# Then open the exported database
open -a "DB Browser for SQLite" debug_db/myassistant.db
```

#### Manual Database Export

If you prefer manual export:

```bash
# Export database file
adb exec-out run-as com.example.myassistant cat databases/myassistant.db > myassistant.db

# Verify export was successful
ls -lh myassistant.db

# View tables using sqlite3
sqlite3 myassistant.db ".tables"

# Query data
sqlite3 myassistant.db "SELECT * FROM tasks;"
```

#### Using Android Studio Database Inspector

For real-time database inspection:

1. **Start your app on emulator**:
   ```bash
   flutter run -d android
   ```

2. **Open Android Studio**:
   - View → Tool Windows → App Inspection
   - Select the "Database Inspector" tab
   - Choose your app process from the dropdown
   - Browse tables and run SQL queries

**Advantages**:
- Real-time data updates
- Visual table browser
- Direct data editing
- SQL query execution

#### Common Database Operations

```bash
# List all tables
sqlite3 debug_db/myassistant.db ".tables"

# Show table schema
sqlite3 debug_db/myassistant.db ".schema tasks"

# Count records
sqlite3 debug_db/myassistant.db "SELECT COUNT(*) FROM tasks;"

# Export as CSV
sqlite3 debug_db/myassistant.db ".mode csv" ".output tasks.csv" "SELECT * FROM tasks;"

# View recent tasks
sqlite3 debug_db/myassistant.db "SELECT id, name, status FROM tasks ORDER BY created_at DESC LIMIT 10;"
```

#### Database Reset (Development Only)

```bash
# WARNING: This will delete all data!

# Method 1: Clear app data via ADB
adb shell pm clear com.example.myassistant

# Method 2: Uninstall and reinstall
adb uninstall com.example.myassistant
flutter run -d android

# Method 3: Delete database file directly
adb shell run-as com.example.myassistant rm databases/myassistant.db
```

### Useful ADB Commands

```bash
# Device management
adb devices                                 # List connected devices
adb connect 127.0.0.1:5555                 # Connect to emulator

# App management
adb uninstall com.example.myassistant      # Uninstall app
adb shell pm clear com.example.myassistant # Clear app data

# Debugging
adb logcat | grep Flutter                   # View Flutter logs
adb shell dumpsys package com.example.myassistant  # App info

# Database inspection (alternative method)
adb shell "run-as com.example.myassistant ls -la databases/"  # List database files
adb pull /data/data/com.example.myassistant/databases/myassistant.db  # Pull database (requires root)
```

### Performance Tips

1. **Use Cold Boot for Fresh Start**:
   ```bash
   emulator -avd <avd_name> -no-snapshot-load
   ```

2. **Speed Up Emulator**:
   - Enable hardware acceleration (HAXM on Intel, Hypervisor on ARM)
   - Allocate more RAM to emulator (4GB recommended)
   - Use x86_64 images when possible

3. **Development Best Practices**:
   - Keep emulator running between sessions
   - Use hot reload for UI changes
   - Run `flutter clean` if encountering strange build errors
   - Regularly run `flutter doctor` to check environment

## Database Schema

### Core Tables

- **users**: User account information
- **goals**: Personal goals with deadlines
- **plans**: Action plans linked to goals
- **tasks**: Individual tasks with configurations
- **task_executions**: Task completion history

### Key Relationships

- Goals → Plans (one-to-many)
- Plans → Tasks (one-to-many)
- Tasks → Task Executions (one-to-many)
- Users → All entities (ownership)

## Testing

Run unit tests:
```bash
flutter test
```

Run tests with coverage:
```bash
flutter test --coverage
```

Run integration tests on Android Emulator:
```bash
# Ensure Android emulator is running first
flutter test integration_test/ -d android
```

## Project Structure Details

### Task Configuration

Tasks support multiple execution modes through the `TaskConfiguration` class:

```dart
TaskConfiguration(
  durationMinutes: 25,        // Timer tasks
  repeatCount: 10,            // Counter tasks
  evaluationOptions: [...],    // Evaluation tasks
)
```

### State Management

The app uses Riverpod providers for state management:

- `authStateProvider`: Authentication state
- `taskListProvider`: Active tasks management
- `goalListProvider`: Goals state
- `planListProvider`: Plans state
- `userProvider`: User profile data

### Navigation Flow

```
Splash Screen
    ↓
Login Screen ← → Home Screen
                    ↓
              Bottom Navigation
              ├── Tasks Tab
              ├── Goals Tab
              ├── Plans Tab
              └── Profile Tab
```

## Development Guidelines

### Code Style

- Follow Flutter's official style guide
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep widgets small and focused

### State Management Patterns

- Use StateNotifier for complex state
- Keep business logic in use cases
- Separate UI state from domain state
- Handle loading and error states properly

### Testing Strategy

- Unit tests for models and services
- Widget tests for UI components
- Integration tests for critical user flows
- Mock external dependencies

## Roadmap

### Phase 1 (Current)
- ✅ Core data models
- ✅ Database setup
- ✅ Authentication
- ✅ Basic CRUD operations
- ✅ Task execution dialogs
- ✅ Navigation structure

### Phase 2 (Next)
- [ ] Data synchronization
- [ ] Cloud backup
- [ ] Advanced statistics
- [ ] Data export/import
- [ ] Recurring task templates

### Phase 3 (Future)
- [ ] Social features
- [ ] Team collaboration
- [ ] AI-powered suggestions
- [ ] Analytics dashboard
- [ ] Third-party integrations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write/update tests
5. Submit a pull request

## License

This project is proprietary software. All rights reserved.

## Contact

For questions or support, please contact the development team.
