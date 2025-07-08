import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentPollingService {
  static StreamSubscription? _userSubscription;
  
  /// Escuchar cambios en el documento del usuario
  static void startListeningUserChanges(String userId, Function(bool) onAccessChange) {
    print('👂 Iniciando escucha de cambios para usuario: $userId');
    
    _userSubscription = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      
      if (snapshot.exists) {
        final userData = snapshot.data()!;
        final userType = userData['userType'] ?? 'free';
        
        print('📊 Estado actual del usuario: $userType');
        
        if (userType == 'pro') {
          print('🎉 Usuario actualizado a PRO!');
          onAccessChange(true);
          stopListening();
        }
      }
    });
  }
  
  static void stopListening() {
    _userSubscription?.cancel();
    _userSubscription = null;
    print('🛑 Detenida escucha de cambios');
  }
}