import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
class MercadoPagoService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  /// Crear preferencia usando Firebase Functions
  static Future<Map<String, dynamic>?> createPaymentPreference({
    required String title,
    required double price,
    required String userEmail,
    required String userId,
    required String planType,
  }) async {
    try {
      print('🎯 Llamando a Firebase Function para crear preferencia...');
      
      final HttpsCallable callable = _functions.httpsCallable('createPaymentPreference');
      
      final result = await callable.call({
        'title': title,
        'price': price,
        'userEmail': userEmail,
        'userId': userId,
        'planType': planType,
      });
      
      print('✅ Preferencia creada: ${result.data}');
      return Map<String, dynamic>.from(result.data);
      
    } catch (e) {
      print('❌ Error creando preferencia: $e');
      return null;
    }
  }
  
  /// Verificar estado del pago
  static Future<Map<String, dynamic>?> checkPaymentStatus(String paymentId) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('checkPaymentStatus');
      
      final result = await callable.call({
        'paymentId': paymentId,
      });
      
      return Map<String, dynamic>.from(result.data);
      
    } catch (e) {
      print('❌ Error verificando pago: $e');
      return null;
    }
  }
}