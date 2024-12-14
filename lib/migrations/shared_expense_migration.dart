import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/utils/custom_logger.dart';

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