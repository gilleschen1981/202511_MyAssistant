import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/database_interface.dart';
import 'package:myassistant/data/data_sources/local/database/database_factory.dart';

/// Database provider - returns platform-specific implementation
final databaseProvider = Provider<DatabaseInterface>((ref) {
  return AppDatabaseFactory.getDatabaseInstance();
});

/// Initialize database provider - ensures database is created (Android only)
final databaseInitializerProvider = FutureProvider<Database?>((ref) async {
  print('[DatabaseProvider] Starting database initialization...');

  print('[DatabaseProvider] Getting database instance...');
  final appDatabase = ref.watch(databaseProvider);
  try {
    print('[DatabaseProvider] Awaiting database creation...');
    final db = await appDatabase.database;
    print('[DatabaseProvider] Database successfully initialized');
    return db;
  } catch (e) {
    // If database initialization fails, return null
    print('[DatabaseProvider] Database initialization failed: $e');
    return null;
  }
});