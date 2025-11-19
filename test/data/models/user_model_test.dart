import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/data/models/user_model.dart';
import 'package:myassistant/data/models/enums/status.dart';

void main() {
  group('UserModel', () {
    test('should create a UserModel with required fields', () {
      final user = UserModel(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hash123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
      );

      expect(user.id, '123');
      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
      expect(user.passwordHash, 'hash123');
      expect(user.status, UserStatus.active);
      expect(user.displayName, null);
      expect(user.avatarUrl, null);
    });

    test('should create a UserModel with all fields', () {
      final user = UserModel(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hash123',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
        totalGoals: 10,
        completedGoals: 5,
        activePlans: 3,
        completedTasks: 25,
      );

      expect(user.displayName, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.totalGoals, 10);
      expect(user.completedGoals, 5);
      expect(user.activePlans, 3);
      expect(user.completedTasks, 25);
    });

    test('should serialize to JSON correctly', () {
      final user = UserModel(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hash123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
      );

      final json = user.toJson();

      expect(json['id'], '123');
      expect(json['username'], 'testuser');
      expect(json['email'], 'test@example.com');
      expect(json['passwordHash'], 'hash123');
      expect(json['status'], 'active');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': '123',
        'username': 'testuser',
        'email': 'test@example.com',
        'passwordHash': 'hash123',
        'displayName': 'Test User',
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2024, 1, 2).toIso8601String(),
        'status': 'active',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, '123');
      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.status, UserStatus.active);
    });

    test('copyWith should create a new instance with updated fields', () {
      final original = UserModel(
        id: '123',
        username: 'testuser',
        email: 'original@example.com',
        passwordHash: 'hash123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
      );

      final updated = original.copyWith(
        email: 'new@example.com',
        displayName: 'Updated User',
      );

      expect(updated.id, original.id);
      expect(updated.username, original.username);
      expect(updated.email, 'new@example.com');
      expect(updated.displayName, 'Updated User');
      expect(identical(original, updated), false);
    });

    test('should correctly identify active status', () {
      final activeUser = UserModel(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hash123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
      );

      final deactivatedUser = activeUser.copyWith(
        status: UserStatus.deactivated,
      );

      expect(activeUser.isActive, true);
      expect(deactivatedUser.isActive, false);
    });

    test('Equatable props should work correctly', () {
      final user1 = UserModel(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hash123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
      );

      final user2 = UserModel(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hash123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
      );

      final user3 = UserModel(
        id: '456',
        username: 'otheruser',
        email: 'other@example.com',
        passwordHash: 'hash456',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        status: UserStatus.active,
      );

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
    });
  });
}