import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class CustomLogger {
  static final CustomLogger _instance = CustomLogger._internal();
  final Logger logger;

  CustomLogger._internal() : logger = Logger();

  factory CustomLogger() {
    return _instance;
  }

  Future<void> logToFile(String message) async {
    if (!kIsWeb) {  // Solo ejecutar en plataformas no web
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = io.File('${directory.path}/app_logs.txt');
        await file.writeAsString('$message\n', mode: io.FileMode.append);
      } catch (e) {
        print('Error writing to log file: $e');
      }
    }
  }

  void logInfo(String message) {
    if (kIsWeb) {
      print('INFO: $message');  // Versión simplificada para web
    } else {
      logger.i(message);
      logToFile(message);
    }
  }

  void logError(String message, [dynamic error]) {
    if (kIsWeb) {
      print('ERROR: $message');  // Versión simplificada para web
      if (error != null) print(error);
    } else {
      logger.e(message, error);
      logToFile('ERROR: $message${error != null ? '\n$error' : ''}');
    }
  }
}
