import 'dart:io'; // Importa la librería para manejar archivos
import 'package:logger/logger.dart'; // Importa el paquete de logger para manejar logs
import 'package:path_provider/path_provider.dart'; // Importa path_provider para obtener el directorio de la aplicación

class CustomLogger {
  // Instancia privada de CustomLogger
  static final CustomLogger _instance = CustomLogger._internal();

  // Instancia de Logger del paquete logger
  final Logger logger;

  // Constructor privado
  CustomLogger._internal() : logger = Logger();

  // Método estático para acceder a la instancia
  factory CustomLogger() {
    return _instance; // Retorna la instancia única
  }

  // Método para registrar un mensaje en un archivo
  Future<void> logToFile(String message) async {
    final directory = await getApplicationDocumentsDirectory(); // Obtiene el directorio de documentos
    final file = File('${directory.path}/app_logs.txt'); // Define el archivo de log
    await file.writeAsString('$message\n', mode: FileMode.append); // Escribe el mensaje en el archivo
  }

  // Método para registrar información
  void logInfo(String message) {
    logger.i(message); // Registra el mensaje usando Logger
    logToFile(message); // También registra el mensaje en el archivo
  }

  // Método para registrar errores
  void logError(String message, [dynamic error]) {
    logger.e(message, error); // Registra el mensaje de error usando Logger
    logToFile(message); // También registra el mensaje en el archivo
  }
}
