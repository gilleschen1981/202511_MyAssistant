import 'package:logger/logger.dart';

/// Unified logging utility for the application.
///
/// Usage:
/// ```dart
/// AppLogger.d('Debug message');
/// AppLogger.i('Info message');
/// AppLogger.w('Warning message');
/// AppLogger.e('Error message', error: exception, stackTrace: stackTrace);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // Number of method calls to be displayed
      errorMethodCount: 8, // Number of method calls for errors
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.debug, // Set log level (debug, info, warning, error)
  );

  static final Logger _simpleLogger = Logger(
    printer: SimplePrinter(
      colors: true,
      printTime: true,
    ),
    level: Level.debug,
  );

  /// Log a debug message
  static void d(dynamic message, {String? tag}) {
    _logger.d(_formatMessage(message, tag));
  }

  /// Log an info message
  static void i(dynamic message, {String? tag}) {
    _logger.i(_formatMessage(message, tag));
  }

  /// Log a warning message
  static void w(dynamic message, {String? tag}) {
    _logger.w(_formatMessage(message, tag));
  }

  /// Log an error message
  static void e(
    dynamic message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.e(_formatMessage(message, tag), error: error, stackTrace: stackTrace);
  }

  /// Log a verbose message (for detailed debugging)
  static void v(dynamic message, {String? tag}) {
    _logger.t(_formatMessage(message, tag));
  }

  /// Simple log without formatting (for quick debugging)
  static void simple(dynamic message) {
    _simpleLogger.i(message);
  }

  /// Format message with optional tag
  static String _formatMessage(dynamic message, String? tag) {
    if (tag != null) {
      return '[$tag] $message';
    }
    return message.toString();
  }

  /// Set log level dynamically
  static void setLevel(Level level) {
    // Note: Logger doesn't support changing level after initialization
    // This is a placeholder for future implementation if needed
  }
}
