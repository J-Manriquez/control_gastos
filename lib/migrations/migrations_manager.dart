import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/migrations/shared_expense_migration.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class MigrationsManager {
  final FirestoreService _firestoreService = FirestoreService();
  final CustomLogger _logger = CustomLogger();

  // Método principal que ejecuta todas las migraciones necesarias
  Future<void> runMigrations(String uid) async {
    try {
      _logger.logInfo('Iniciando proceso de migraciones para usuario: $uid');
      
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

      // Ejecutar migraciones en orden
      await migrateShortId(uid, userData);
      await migrateFriendsSystem(uid, userData);
      await SharedExpenseMigration().migrateExpenseGroups();

      _logger.logInfo('Proceso de migraciones completado para usuario: $uid');
    } catch (e) {
      _logger.logError('Error durante el proceso de migraciones: $e');
      throw Exception('Error durante las migraciones: $e');
    }
  }

  // Migración 1: ShortId (código existente movido aquí)
  Future<void> migrateShortId(String uid, Map<String, dynamic> userData) async {
    try {
      if (!userData.containsKey('userShortId') || 
          userData['userShortId'] == null || 
          userData['userShortId'].toString().isEmpty) {
        _logger.logInfo('Iniciando migración de shortId para usuario: $uid');

        String newShortId = await _firestoreService.generateUniqueShortId();

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({'userShortId': newShortId});

        await _firestoreService.registerShortId(newShortId, uid);

        _logger.logInfo('Migración de shortId completada para usuario: $uid');
      }
    } catch (e) {
      _logger.logError('Error en migración de shortId: $e');
      rethrow;
    }
  }

  // Migración 2: Sistema de Amigos
  Future<void> migrateFriendsSystem(String uid, Map<String, dynamic> userData) async {
    try {
      if (!userData.containsKey('friendsList')) {
        _logger.logInfo('Iniciando migración del sistema de amigos para usuario: $uid');

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({
          'friendsList': {
            'accepted': [],
            'pending': [],
            'blocked': []
          }
        });

        _logger.logInfo('Migración del sistema de amigos completada para usuario: $uid');
      }
    } catch (e) {
      _logger.logError('Error en migración del sistema de amigos: $e');
      rethrow;
    }
  }

}