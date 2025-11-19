import 'package:sqflite/sqflite.dart';
import 'package:myassistant/data/data_sources/local/database/database_interface.dart';

/// Web platform stub for database operations
/// This is a temporary solution until proper web database support is implemented
/// You could replace this with IndexedDB, Hive for web, or drift
class WebDatabaseStub implements DatabaseInterface {
  static final WebDatabaseStub instance = WebDatabaseStub._internal();
  factory WebDatabaseStub() => instance;
  WebDatabaseStub._internal();

  @override
  Future<Database> get database async {
    // For web platform, we throw an error indicating it's not supported yet
    // In a real implementation, you would use IndexedDB or another web-compatible database
    throw UnsupportedError(
      'Database operations are not yet supported on web platform. '
      'Please use the mobile or desktop app for full functionality.'
    );
  }

  @override
  Future<void> close() async {
    // No-op for web
  }

  /// Get current timestamp
  static int getCurrentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  /// Convert DateTime to Unix timestamp
  static int dateTimeToTimestamp(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch ~/ 1000;
  }

  /// Convert Unix timestamp to DateTime
  static DateTime timestampToDateTime(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }
}