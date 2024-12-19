import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/migrations/notification_migration.dart';
import 'package:control_gastos/migrations/shared_expense_migration.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class MigrationsManager {
  final FirestoreService _firestoreService = FirestoreService();
  final CustomLogger _logger = CustomLogger();

// Añadir esta propiedad
  static const int CURRENT_MIGRATION_VERSION =
      1; // Incrementar con cada nueva migración

  // Añadir este método
  Future<void> updateMigrationVersion(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'migrationVersion': CURRENT_MIGRATION_VERSION,
        'lastMigration': FieldValue.serverTimestamp(),
      });
      _logger.logInfo(
          'Versión de migración actualizada a: $CURRENT_MIGRATION_VERSION');
    } catch (e) {
      _logger.logError('Error al actualizar versión de migración: $e');
      rethrow;
    }
  }

  // Modificar el método runMigrations existente
  Future<void> runMigrations(String uid) async {
    try {
      _logger.logInfo('Iniciando proceso de migraciones para usuario: $uid');

      // Obtener versión actual de migración del usuario
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        _logger.logError('Usuario no encontrado: $uid');
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      int currentVersion = userData['migrationVersion'] ?? 0;

      if (currentVersion < CURRENT_MIGRATION_VERSION) {
        // Ejecutar migraciones en orden
        if (currentVersion < 1) await migrateShortId(uid, userData);
        if (currentVersion < 2) await migrateFriendsSystem(uid, userData);
        if (currentVersion < 3) await migrateSharedExpensesList(uid, userData);

        // Actualizar versión después de migraciones exitosas
        await updateMigrationVersion(uid);
      }

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
  Future<void> migrateFriendsSystem(
      String uid, Map<String, dynamic> userData) async {
    try {
      if (!userData.containsKey('friendsList')) {
        _logger.logInfo(
            'Iniciando migración del sistema de amigos para usuario: $uid');

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({
          'friendsList': {'accepted': [], 'pending': [], 'blocked': []}
        });

        _logger.logInfo(
            'Migración del sistema de amigos completada para usuario: $uid');
      }
    } catch (e) {
      _logger.logError('Error en migración del sistema de amigos: $e');
      rethrow;
    }
  }

  Future<void> migrateSharedExpensesList(
      String uid, Map<String, dynamic> userData) async {
    try {
      if (!userData.containsKey('sharedExpensesList')) {
        _logger.logInfo(
            'Iniciando migración de sharedExpensesList para usuario: $uid');

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({'sharedExpensesList': []});

        _logger.logInfo(
            'Migración de sharedExpensesList completada para usuario: $uid');
      }
    } catch (e) {
      _logger.logError('Error en migración de sharedExpensesList: $e');
      rethrow;
    }
  }
}
