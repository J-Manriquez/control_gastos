// Importa Firebase y Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:control_gastos/firebase_options.dart'; // Archivo de configuración de Firebase

// Clase que implementa el patrón Singleton para Firebase Firestore
class FirestoreService {
  // Campo estático para almacenar la instancia única
  static final FirestoreService _instance = FirestoreService._internal();

  // Constructor privado
  FirestoreService._internal();

  // Proveedor del acceso global a la instancia
  factory FirestoreService() {
    return _instance;
  }

  // Variable para almacenar la instancia de FirebaseFirestore
  late FirebaseFirestore _firestore;

  // Método para inicializar Firebase y Firestore
  Future<void> initialize() async {
    try {
      CustomLogger().logInfo('Inicializando Firebase...');
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      _firestore = FirebaseFirestore.instance;
      CustomLogger().logInfo('Firebase inicializado correctamente');
    } catch (e) {
      CustomLogger().logError('Error al inicializar Firebase: $e');
      rethrow;
    }
  }

  // Método para obtener la instancia de Firestore
  FirebaseFirestore get firestore => _firestore;

  // Método para agregar un documento a una colección
  Future<void> addDocument(
      String collectionPath, Map<String, dynamic> data) async {
    try {
      CustomLogger().logInfo('Agregando documento a $collectionPath');
      await _firestore.collection(collectionPath).add(data);
      CustomLogger()
          .logInfo('Documento agregado exitosamente a $collectionPath');
    } catch (e) {
      CustomLogger()
          .logError('Error al agregar documento a $collectionPath: $e');
      rethrow;
    }
  }

  // Método para obtener todos los documentos de una colección
  Future<QuerySnapshot> getCollection(String collectionPath) async {
    try {
      CustomLogger()
          .logInfo('Obteniendo documentos de la colección $collectionPath');
      return await _firestore.collection(collectionPath).get();
    } catch (e) {
      CustomLogger()
          .logError('Error al obtener documentos de $collectionPath: $e');
      rethrow;
    }
  }

  // Método para actualizar un documento por su ID
  Future<void> updateDocument(
      String collectionPath, String docId, Map<String, dynamic> data) async {
    try {
      CustomLogger()
          .logInfo('Actualizando documento $docId en $collectionPath');
      await _firestore.collection(collectionPath).doc(docId).update(data);
      CustomLogger().logInfo(
          'Documento $docId actualizado correctamente en $collectionPath');
    } catch (e) {
      CustomLogger().logError(
          'Error al actualizar documento $docId en $collectionPath: $e');
      rethrow;
    }
  }

  // Método para eliminar un documento por su ID
  Future<void> deleteDocument(String collectionPath, String docId) async {
    try {
      CustomLogger().logInfo('Eliminando documento $docId en $collectionPath');
      await _firestore.collection(collectionPath).doc(docId).delete();
      CustomLogger().logInfo(
          'Documento $docId eliminado correctamente en $collectionPath');
    } catch (e) {
      CustomLogger().logError(
          'Error al eliminar documento $docId en $collectionPath: $e');
      rethrow;
    }
  }

  // Método para agregar un grupo de gastos a un usuario
  Future<void> addExpenseGroup(String userUid, String groupName,
      List<Gasto> expenses, List<SubgroupModel> subgroups,
      {required double total}) async {
    try {
      CustomLogger()
          .logInfo('Agregando grupo de gastos para el usuario $userUid');
      List<Map<String, dynamic>> expenseMaps =
          expenses.map((gasto) => gasto.toMap()).toList();
      List<Map<String, dynamic>> subgroupMaps = subgroups
          .map((subgroup) => {
                'subgroupName': subgroup.nombre,
                'expenses':
                    subgroup.expenses.map((gasto) => gasto.toMap()).toList(),
              })
          .toList();

      Map<String, dynamic> expenseGroup = {
        'groupName': groupName,
        'total': total,
        'expenses': expenseMaps,
        'subgroups': subgroupMaps,
        'creationDate': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .add(expenseGroup);
      CustomLogger()
          .logInfo('Grupo de gastos agregado para el usuario $userUid');
    } catch (e) {
      CustomLogger().logError(
          'Error al agregar grupo de gastos para el usuario $userUid: $e');
      rethrow;
    }
  }

  // Stream para obtener los grupos de gastos de un usuario específico
  Stream<QuerySnapshot> getExpenseGroups(String userUid) {
    CustomLogger().logInfo(
        'Obteniendo stream de grupos de gastos para el usuario $userUid');
    return _firestore
        .collection('usuarios')
        .doc(userUid)
        .collection('expenseGroups')
        .snapshots();
  }

  // Método para eliminar un grupo de gastos
  Future<void> deleteExpenseGroup(String userUid, String groupId) async {
    try {
      CustomLogger().logInfo(
          'Eliminando grupo de gastos $groupId para el usuario $userUid');
      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .delete();
      CustomLogger().logInfo(
          'Grupo de gastos $groupId eliminado para el usuario $userUid');
    } catch (e) {
      CustomLogger().logError(
          'Error al eliminar grupo de gastos $groupId para el usuario $userUid: $e');
      rethrow;
    }
  }

  // Stream<QuerySnapshot> getExpenseGroupsStream(String userUid) {
  //   return _firestore.collection('expense_groups')
  //      .where('userUid', isEqualTo: userUid)
  //      .snapshots();
  // }
  // Obtener el grupo de gastos con su ID
  Future<GroupModel> getExpenseGroup(String userUid, String groupId) async {
    try {
      CustomLogger().logInfo(
          'Obteniendo grupo de gastos $groupId para el usuario $userUid');
      DocumentSnapshot doc = await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .get();

      if (doc.exists) {
        CustomLogger().logInfo('Grupo de gastos $groupId obtenido');
        return GroupModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        CustomLogger().logError('Grupo no encontrado');
        throw Exception('Grupo no encontrado');
      }
    } catch (e) {
      CustomLogger().logError('Error al obtener grupo de gastos: $e');
      rethrow;
    }
  }

  // Actualizar un grupo de gastos
  Future<void> updateExpenseGroup(
    String userUid,
    String groupId,
    String groupName,
    List<Gasto> expenses,
    List<SubgroupModel> subgroups,
  ) async {
    try {
      CustomLogger().logInfo(
          'Iniciando actualización del grupo de gastos $groupId para el usuario $userUid');

      // Calcular el total
      double total = expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
      for (var subgroup in subgroups) {
        total += subgroup.expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
      }

      CustomLogger().logInfo('Total calculado: $total');

      // Crear el mapa de datos siguiendo la estructura correcta del modelo
      Map<String, dynamic> groupData = {
        'groupName': groupName,
        'total': total,
        'expenses': expenses.map((e) => e.toMap()).toList(),
        'subgroups': subgroups
            .map((subgroup) => {
                  'subgroupName': subgroup.nombre,
                  'expenses': subgroup.expenses.map((e) => e.toMap()).toList(),
                })
            .toList(),
        'creationDate': DateTime.now().toIso8601String(),
      };

      CustomLogger()
          .logInfo('Estructura de datos preparada para actualización');

      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .update(groupData);

      CustomLogger()
          .logInfo('Grupo de gastos $groupId actualizado correctamente');
    } catch (e) {
      CustomLogger().logError('Error al actualizar grupo de gastos: $e');
      rethrow;
    }
  }
}
