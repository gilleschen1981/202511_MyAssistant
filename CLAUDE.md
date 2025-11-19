# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Platform Support

**This application is Android-only.** All development, testing, and deployment targets Android devices exclusively. iOS and other platforms are not supported.

### Android Requirements
- Minimum SDK: API 21 (Android 5.0 Lollipop)
- Target SDK: Latest stable Android version
- Testing: Android Emulator or physical Android device
- Development: Android Studio with Android SDK

## Project Overview

MyAssistant is an Android-focused Flutter personal task management application that uses Clean Architecture principles. It helps users organize goals, create actionable plans, and track tasks with multiple execution modes (simple checkbox, timer-based, counter, evaluation). The application is designed specifically for Android devices and tested on Android emulators.

## Key Commands

### Development Setup
```bash
# Install dependencies
flutter pub get

# Generate code for JSON serialization and dependency injection
flutter pub run build_runner build --delete-conflicting-outputs

# Run the application on Android
flutter run -d android

# List available Android devices/emulators
flutter devices

# Run on specific Android device
flutter run -d <device-id>
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/task_model_test.dart

# Run tests with coverage
flutter test --coverage

# Run integration tests on Android emulator
# Note: Ensure Android emulator is running first
flutter test integration_test/ -d android

# Run integration tests on specific Android device
flutter test integration_test/ -d <device-id>
```

### Database Management
```bash
# Reset database (development only)
flutter pub run sqflite:clean
```

### Code Quality
```bash
# Format code
flutter format lib/ test/

# Analyze code
flutter analyze
```

## Architecture Overview

The application follows Clean Architecture with three distinct layers:

### 1. Data Layer (`lib/data/`)
- **Models**: JSON-serializable data models with `.g.dart` generated files
- **Repositories**: Concrete implementations of domain repository interfaces
- **Data Sources**:
  - Local: SQLite database via `AppDatabase` singleton, DAOs for each entity
  - Services: Business services like `NotificationService`, `AuthService`

### 2. Domain Layer (`lib/domain/`)
- **Entities**: Pure business objects without dependencies
- **Repository Interfaces**: Abstract contracts for data operations
- **Use Cases**: Business logic implementation, one use case per business operation

### 3. Presentation Layer (`lib/presentation/`)
- **State Management**: Riverpod with StateNotifier pattern
- **Navigation**: GoRouter with declarative routing
- **Features**: Modular feature organization (auth, tasks, goals, plans, profile)
- **Providers**: Located in `presentation/providers/` for each feature

## Database Schema

SQLite database with 7 core tables:
- `users`: User accounts with authentication
- `user_settings`: User preferences and configuration
- `goals`: High-level objectives with status tracking
- `plans`: Action plans linked to goals (UUID primary keys, immutable names)
- `tasks`: Individual tasks with flexible configuration (no deletion support)
- `task_executions`: Execution history for tasks
- `notifications`: Scheduled notifications

Key constraints:
- Foreign key relationships enforced via PRAGMA
- Plans have unique names that cannot be changed after creation
- Tasks cannot be deleted, only marked as completed/skipped
- Tasks support unlimited re-execution within their time window

## State Management

Riverpod providers organized by feature:
- **Authentication**: `authStateProvider`, `userProvider`
- **Data Access**: Repository providers in `di/providers/`
- **Database**: `databaseInitializerProvider` for initialization
- **Navigation**: `routerProvider` with `RouterNotifier`
- **Feature-specific**: Each feature has its own StateNotifier providers

## Task Configuration System

Tasks support multiple execution modes via `TaskConfiguration`:
- **Simple**: Basic checkbox tasks
- **Timer**: Tasks with duration tracking (`durationMinutes`)
- **Counter**: Repetitive action tracking (`repeatCount`)
- **Evaluation**: Quality assessment (`evaluationOptions`)
- **Combined**: Timer+Counter or Counter+Evaluation

## Code Generation

The project uses build_runner for:
- JSON serialization (`@JsonSerializable`)
- Freezed for immutable models (`@freezed`)
- Injectable for dependency injection (`@injectable`)

Always run code generation after modifying:
- Models in `lib/data/models/`
- Any file with `@JsonSerializable`, `@freezed`, or `@injectable` annotations

## Critical Design Decisions

1. **UUID for Plans**: Plans use UUIDs as primary keys instead of auto-increment
2. **Immutable Plan Names**: Once created, plan names cannot be modified (database constraint)
3. **No Task Deletion**: Tasks can only be marked complete/skipped, never deleted
4. **Soft Delete**: Goals and plans support soft delete via `deleted_at` timestamp
5. **Task Execution Windows**: Tasks have specific time windows for execution
6. **Repeat Execution**: Tasks can be executed multiple times within their window

## Testing Strategy

Tests are organized in three categories:
- `test/unit/`: Model and service unit tests
- `test/widget/`: UI component tests
- `integration_test/`: End-to-end user flow tests

Focus areas for testing:
- Database operations and migrations
- State management with providers
- Task execution logic and status transitions
- Navigation flows and authentication

## Common Patterns

### Adding a New Feature
1. Create feature module in `lib/presentation/features/[feature_name]/`
2. Add route in `lib/presentation/routes/app_router.dart`
3. Create StateNotifier and Provider in feature's `providers/` directory
4. Add repository interface in `lib/domain/repositories/`
5. Implement repository in `lib/data/repositories/`
6. Create DAO if database access needed in `lib/data/data_sources/local/dao/`

### Database Migrations
When modifying the database schema:
1. Update `AppDatabase._onCreate()` in `app_database.dart`
2. Increment `AppConstants.databaseVersion`
3. Add migration logic in `_onUpgrade()` method
4. Test migration from previous version thoroughly