import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/models/user_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class MigrationService {
  final FirestoreService _firestoreService = FirestoreService();
  final CustomLogger _logger = CustomLogger();

  Future<void> migrateUserIfNeeded(String uid) async {
    try {
      // Obtener documento del usuario
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        _logger.logError('Usuario no encontrado: $uid');
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Verificar si el usuario necesita migración
      if (!userData.containsKey('userShortId') || userData['userShortId'] == null || userData['userShortId'].toString().isEmpty) {
        _logger.logInfo('Iniciando migración para usuario: $uid');

        // Generar nuevo shortId
        String newShortId = await _firestoreService.generateUniqueShortId();

        // Crear modelo de usuario actualizado
        UserModel updatedUser = UserModel(
          uid: uid,
          username: userData['username'] ?? '',
          email: userData['email'] ?? '',
          userShortId: newShortId,
          creationDate: userData['creationDate']?.toDate() ?? DateTime.now(),
          userType: userData['userType'] ?? 'free',
        );

        // Actualizar documento del usuario
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update(updatedUser.toMap());

        // Registrar el shortId en la colección de shortIds
        await _firestoreService.registerShortId(newShortId, uid);

        _logger.logInfo('Migración completada para usuario: $uid con shortId: $newShortId');
      } else {
        _logger.logInfo('Usuario ya tiene shortId, no requiere migración: $uid');
      }
    } catch (e) {
      _logger.logError('Error durante la migración del usuario: $e');
      throw Exception('Error durante la migración: $e');
    }
  }
}