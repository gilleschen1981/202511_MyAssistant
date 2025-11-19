import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:myassistant/core/constants/app_constants.dart';

/// Reset database for development
Future<void> main() async {
  print('Resetting database...');

  final dbPath = await getDatabasesPath();
  final path = join(dbPath, AppConstants.databaseName);

  // Delete the database
  await deleteDatabase(path);

  print('Database deleted at: $path');
  print('The database will be recreated with demo user when you run the app next time.');
}