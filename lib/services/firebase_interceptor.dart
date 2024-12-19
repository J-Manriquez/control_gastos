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
    try {
      // Verificar token antes de cada operación
      bool isValid = await _authService.verifyAndRefreshToken();
      if (!isValid) {
        throw Exception('Token inválido o expirado');
      }

      return await operation();
    } catch (e) {
      _logger.logError('Error en operación Firebase: $e');
      rethrow;
    }
  }
}