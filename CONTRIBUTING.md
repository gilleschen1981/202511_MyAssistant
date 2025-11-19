# Contributing to MyAssistant

Thank you for your interest in contributing to MyAssistant! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our code of conduct:
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Respect differing viewpoints and experiences

## Getting Started

### Development Setup

1. **Fork the Repository**
   ```bash
   # Clone your fork
   git clone https://github.com/YOUR_USERNAME/myassistant.git
   cd myassistant

   # Add upstream remote
   git remote add upstream https://github.com/ORIGINAL_OWNER/myassistant.git
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

### Development Workflow

1. Make your changes
2. Write/update tests
3. Run tests locally
4. Commit your changes
5. Push to your fork
6. Create a Pull Request

## Contribution Guidelines

### Code Style

#### Dart/Flutter Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter format` to format your code
- Run `flutter analyze` to check for issues

#### Naming Conventions

```dart
// Classes: PascalCase
class TaskModel {}

// Files: snake_case
task_model.dart

// Variables/Functions: camelCase
final taskName = 'Study';
void executeTask() {}

// Constants: lowerCamelCase or SCREAMING_SNAKE_CASE
const defaultTimeout = 30;
const API_BASE_URL = 'https://api.example.com';

// Private members: prefix with underscore
String _privateField;
void _privateMethod() {}
```

#### File Organization

```dart
// Order of imports
import 'dart:async';  // Dart SDK
import 'dart:convert';

import 'package:flutter/material.dart';  // Flutter packages
import 'package:riverpod/riverpod.dart';  // Third-party packages

import 'package:myassistant/core/constants.dart';  // Project imports
import 'package:myassistant/data/models/task.dart';

// Class organization
class TaskCard extends StatelessWidget {
  // 1. Static fields
  static const defaultPadding = 16.0;

  // 2. Instance fields
  final TaskModel task;
  final VoidCallback? onTap;

  // 3. Constructor
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
  });

  // 4. Override methods
  @override
  Widget build(BuildContext context) {}

  // 5. Public methods
  void executeTask() {}

  // 6. Private methods
  void _handleTap() {}
}
```

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions or fixes
- `chore`: Maintenance tasks
- `perf`: Performance improvements

#### Examples
```bash
feat(tasks): add timer pause functionality

fix(auth): resolve login session timeout issue

docs(readme): update installation instructions

test(goals): add unit tests for goal completion
```

### Testing

#### Writing Tests

1. **Unit Tests** (test/unit/)
   ```dart
   void main() {
     group('TaskModel', () {
       test('should calculate progress correctly', () {
         final task = TaskModel(
           config: TaskConfiguration(repeatCount: 10),
           currentCount: 5,
         );
         expect(task.progress, 0.5);
       });
     });
   }
   ```

2. **Widget Tests** (test/widget/)
   ```dart
   testWidgets('TaskCard displays task name', (tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: TaskCard(task: mockTask),
       ),
     );
     expect(find.text('Test Task'), findsOneWidget);
   });
   ```

3. **Integration Tests** (integration_test/)
   ```dart
   testWidgets('Complete task flow', (tester) async {
     app.main();
     await tester.pumpAndSettle();

     // Test user flow
     await tester.tap(find.byIcon(Icons.add));
     await tester.pumpAndSettle();
     // ... continue test
   });
   ```

#### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/task_model_test.dart

# Run with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/
```

### Pull Request Process

#### Before Submitting

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation is updated
- [ ] Commit messages follow conventions
- [ ] Branch is up-to-date with main

#### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Widget tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings
```

### Documentation

#### Code Documentation

```dart
/// Represents a user task with configurable execution modes.
///
/// Tasks can be simple checkboxes, timers, counters, or evaluations.
/// Each task belongs to a [PlanModel] and can be executed multiple
/// times within its time window.
class TaskModel {
  /// Unique identifier for the task
  final String id;

  /// Calculates the completion progress as a percentage.
  ///
  /// Returns a value between 0.0 and 1.0.
  /// For counter tasks, this is currentCount / repeatCount.
  /// For other tasks, returns 0.0 or 1.0 based on completion.
  double get progress {
    // Implementation
  }
}
```

#### README Updates

Update relevant sections when adding features:
- Features list
- API documentation
- Installation steps
- Configuration options

## Project Structure

### Adding New Features

1. **Create Feature Module**
   ```
   lib/presentation/features/new_feature/
   ├── screens/
   │   └── new_feature_screen.dart
   ├── widgets/
   │   └── new_feature_widget.dart
   └── providers/
       └── new_feature_provider.dart
   ```

2. **Add Route**
   ```dart
   // In app_router.dart
   GoRoute(
     path: '/new-feature',
     builder: (context, state) => NewFeatureScreen(),
   ),
   ```

3. **Create Provider**
   ```dart
   final newFeatureProvider = StateNotifierProvider<NewFeatureNotifier, NewFeatureState>((ref) {
     return NewFeatureNotifier(ref);
   });
   ```

### Adding Models

1. Create model in `lib/data/models/`
2. Add JSON serialization
3. Run code generation
4. Write unit tests
5. Update repositories

### Database Changes

1. Update schema in `database_helper.dart`
2. Increment database version
3. Add migration logic
4. Test migration thoroughly
5. Document schema changes

## Review Process

### Code Review Checklist

Reviewers will check:
- [ ] Code quality and style
- [ ] Test coverage
- [ ] Documentation completeness
- [ ] Performance impact
- [ ] Security considerations
- [ ] Backward compatibility

### Review Timeline

- Small PRs (< 100 lines): 1-2 days
- Medium PRs (100-500 lines): 2-3 days
- Large PRs (> 500 lines): 3-5 days

## Getting Help

### Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

### Communication Channels

- GitHub Issues: Bug reports and feature requests
- Discussions: General questions and ideas
- Pull Requests: Code contributions

### Common Issues

#### Build Issues
```bash
# Clean build
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### Database Issues
```bash
# Reset database (development only)
flutter pub run sqflite:clean
```

#### State Management Issues
- Check provider dependencies
- Verify provider disposal
- Review StateNotifier implementation

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing to MyAssistant!