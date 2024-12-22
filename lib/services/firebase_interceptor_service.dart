import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class FirebaseInterceptor {
  static final FirebaseInterceptor _instance = FirebaseInterceptor._internal();
  final AuthService _authService = AuthService();
  final CustomLogger _logger = CustomLogger();

  factory FirebaseInterceptor() {
    return _instance;
  }

  FirebaseInterceptor._internal();

  Future<T> runWithTokenVerification<T>(Future<T> Function() operation) async {
    int retries = 3;
    while (retries > 0) {
      try {
        bool isValid = await _authService.verifyAndRefreshToken();
        if (!isValid) {
          throw Exception('Token inválido o expirado');
        }
        return await operation();
      } catch (e) {
        retries--;
        if (e.toString().contains('failed-precondition') && retries > 0) {
          _logger.logInfo(
              'Reintentando operación... intentos restantes: $retries');
          await Future.delayed(Duration(seconds: 1));
          continue;
        }
        _logger.logError('Error en operación Firebase: $e');
        rethrow;
      }
    }
    throw Exception('Máximo de reintentos alcanzado');
  }

  Future<T> handleDistributionOperation<T>(
    Future<T> Function() operation,
  ) async {
    return runWithTokenVerification(() async {
      try {
        return await operation();
      } catch (e) {
        CustomLogger().logError('Error en operación de distribución: $e');
        rethrow;
      }
    });
  }
}
