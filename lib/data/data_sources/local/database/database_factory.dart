import 'package:myassistant/data/data_sources/local/database/database_interface.dart';
import 'package:myassistant/data/data_sources/local/database/app_database.dart';

/// Factory class to get the database implementation
/// Note: This application is Android-only and uses SQLite
class AppDatabaseFactory {
  /// Returns the database implementation for Android platform
  static DatabaseInterface getDatabaseInstance() {
    return AppDatabase.instance;
  }
}