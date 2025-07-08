import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentValidationService {
  static const String _serverUrl = 'https://tu-servidor.com';
  
  /// Valida un pago con el servidor
  static Future<bool> validatePayment(String paymentId, String userId) async {
    try {
      print('🔍 Validando pago $paymentId para usuario $userId');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/validate-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'paymentId': paymentId,
          'userId': userId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] == true;
      }
      
      return false;
    } catch (e) {
      print('💥 Error validando pago: $e');
      return false;
    }
  }
  
  /// Verifica el estado de suscripción del usuario
  static Future<bool> verifyUserSubscription(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      final userType = data['userType'] as String?;
      final subscriptionDate = data['subscriptionDate'] as Timestamp?;
      
      if (userType != 'pro' || subscriptionDate == null) {
        return false;
      }
      
      // Verificar que la suscripción no haya expirado (para suscripciones mensuales)
      final subscriptionType = data['subscriptionType'] as String?;
      if (subscriptionType == 'monthly') {
        final daysSinceSubscription = DateTime.now()
            .difference(subscriptionDate.toDate())
            .inDays;
        
        if (daysSinceSubscription > 30) {
          // Suscripción expirada, revertir a free
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(userId)
              .update({'userType': 'free'});
          
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('💥 Error verificando suscripción: $e');
      return false;
    }
  }
}