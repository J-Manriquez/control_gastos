import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/migrations/notification_migration.dart';
import 'package:control_gastos/migrations/shared_expense_migration.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class MigrationsManager {
  final FirestoreService _firestoreService = FirestoreService();
  final CustomLogger _logger = CustomLogger();

  // Actualizar la versión para incluir la nueva migración
  static const int CURRENT_MIGRATION_VERSION = 4; // Incrementado a 4 para la nueva migración

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
        if (currentVersion < 4) await migrateArchivadoAttribute(uid); // Nueva migración

        // Actualizar versión después de migraciones exitosas
        await updateMigrationVersion(uid);
      }

      _logger.logInfo('Proceso de migraciones completado para usuario: $uid');
    } catch (e) {
      _logger.logError('Error durante el proceso de migraciones: $e');
      throw Exception('Error durante las migraciones: $e');
    }
  }

  // Migración 1: ShortId (código existente)
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

  // Migración 3: Lista de gastos compartidos
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

  // Migración 4: Atributo 'archivado' para gastos existentes
  Future<void> migrateArchivadoAttribute(String uid) async {
    try {
      _logger.logInfo('Iniciando migración de atributo archivado para usuario: $uid');
      
      // 1. Migrar grupos de gastos personales
      QuerySnapshot personalExpensesSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('expenseGroups')
          .get();
      
      int personalGroupsCount = 0;
      for (DocumentSnapshot doc in personalExpensesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Verificar si el documento ya tiene el campo 'archivado'
        if (!data.containsKey('archivado')) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .collection('expenseGroups')
              .doc(doc.id)
              .update({'archivado': false});
          
          personalGroupsCount++;
        }
      }
      
      // 2. Migrar gastos compartidos donde el usuario es participante
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        List<dynamic> sharedExpenseIds = userData['sharedExpensesList'] ?? [];
        
        int sharedGroupsCount = 0;
        for (String expenseId in sharedExpenseIds) {
          DocumentSnapshot sharedExpenseDoc = await FirebaseFirestore.instance
              .collection('sharedExpenses')
              .doc(expenseId)
              .get();
          
          if (sharedExpenseDoc.exists) {
            Map<String, dynamic> expenseData = sharedExpenseDoc.data() as Map<String, dynamic>;
            
            // Verificar si el documento ya tiene el campo 'archivado'
            if (!expenseData.containsKey('archivado')) {
              await FirebaseFirestore.instance
                  .collection('sharedExpenses')
                  .doc(expenseId)
                  .update({'archivado': false});
              
              sharedGroupsCount++;
            }
          }
        }
        
        _logger.logInfo(
            'Migración de atributo archivado completada. Grupos personales actualizados: $personalGroupsCount, Grupos compartidos actualizados: $sharedGroupsCount');
      }
    } catch (e) {
      _logger.logError('Error en migración de atributo archivado: $e');
      rethrow;
    }
  }
}