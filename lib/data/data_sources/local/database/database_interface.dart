import 'package:sqflite/sqflite.dart';

/// Abstract interface for database operations
/// This allows us to have different implementations for different platforms
abstract class DatabaseInterface {
  Future<Database> get database;
  Future<void> close();
}