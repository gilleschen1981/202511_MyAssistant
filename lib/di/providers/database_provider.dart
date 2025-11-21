import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/database_interface.dart';
import 'package:myassistant/data/data_sources/local/database/database_factory.dart';
import 'package:myassistant/core/utils/app_logger.dart';

/// Database provider - returns platform-specific implementation
final databaseProvider = Provider<DatabaseInterface>((ref) {
  return AppDatabaseFactory.getDatabaseInstance();
});

/// Initialize database provider - ensures database is created (Android only)
final databaseInitializerProvider = FutureProvider<Database?>((ref) async {
  AppLogger.i('Starting database initialization...', tag: 'DatabaseProvider');

  final appDatabase = ref.watch(databaseProvider);
  try {
    AppLogger.d('Awaiting database creation...', tag: 'DatabaseProvider');
    final db = await appDatabase.database;
    AppLogger.i('Database successfully initialized', tag: 'DatabaseProvider');
    return db;
  } catch (e) {
    // If database initialization fails, return null
    AppLogger.e('Database initialization failed: $e', tag: 'DatabaseProvider', error: e);
    return null;
  }
});