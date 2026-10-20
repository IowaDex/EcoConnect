import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message) {
    debugPrint('[APP][INFO] $message');
  }

  static void error(String message, [Object? error]) {
    debugPrint('[APP][ERROR] $message${error == null ? '' : ': $error'}');
  }
}
