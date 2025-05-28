import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class SharedExpenseMapMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomLogger _logger = CustomLogger();

  Future<void> migrateSharedExpensesListToMap(String userId) async {
    try {
      final userRef = _firestore.collection('usuarios').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          _logger.logError('Usuario no encontrado para migración: $userId');
          return;
        }
        
        // Verificar si ya tiene el nuevo formato
        if (userDoc.data()!.containsKey('sharedExpensesMap')) {
          _logger.logInfo('Usuario $userId ya tiene el nuevo formato de mapa');
          return;
        }
        
        // Obtener la lista antigua
        final List<String> oldList = List<String>.from(userDoc.data()?['sharedExpensesList'] ?? []);
        
        // Crear el nuevo mapa
        final Map<String, dynamic> newMap = {};
        for (String expenseId in oldList) {
          newMap[expenseId] = {'archivado': false};
        }
        
        // Actualizar el documento
        transaction.update(userRef, {
          'sharedExpensesMap': newMap,
        });
        
        _logger.logInfo('Migración completada para usuario $userId: ${oldList.length} gastos migrados');
      });
    } catch (e) {
      _logger.logError('Error en migración de gastos compartidos: $e');
      rethrow;
    }
  }
}

class SharedExpenseMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomLogger _logger = CustomLogger();

  Future<void> migrateExpenseGroups() async {
    try {
      // Obtener todos los grupos de gastos
      QuerySnapshot groupsSnapshot = await _firestore
          .collectionGroup('expenseGroups')
          .get();

      for (var doc in groupsSnapshot.docs) {
        await _firestore.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(doc.reference);
          
          if (snapshot.exists) {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
            
            // Verificar si ya tiene el campo type
            if (!data.containsKey('type')) {
              // Actualizar documento con el nuevo campo
              transaction.update(doc.reference, {
                'type': 'GastoType.normal',
              });
            }
          }
        });
      }

      _logger.logInfo('Migración de grupos de gastos completada');
    } catch (e) {
      _logger.logError('Error en la migración de grupos de gastos: $e');
      rethrow;
    }
  }
}