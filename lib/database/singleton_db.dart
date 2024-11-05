// Importa Firebase y Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/grupo_gastos_model.dart';
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
    // Inicializa Firebase si no está inicializado
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Asigna la instancia de FirebaseFirestore a _firestore
    _firestore = FirebaseFirestore.instance;
  }

  // Método para obtener la instancia de Firestore
  FirebaseFirestore get firestore => _firestore;

  // Método para agregar un documento a una colección
  Future<void> addDocument(
      String collectionPath, Map<String, dynamic> data) async {
    await _firestore.collection(collectionPath).add(data);
  }

  // Método para obtener todos los documentos de una colección
  Future<QuerySnapshot> getCollection(String collectionPath) async {
    return await _firestore.collection(collectionPath).get();
  }

  // Método para actualizar un documento por su ID
  Future<void> updateDocument(
      String collectionPath, String docId, Map<String, dynamic> data) async {
    await _firestore.collection(collectionPath).doc(docId).update(data);
  }

  // Método para eliminar un documento por su ID
  Future<void> deleteDocument(String collectionPath, String docId) async {
    await _firestore.collection(collectionPath).doc(docId).delete();
  }

  // Método para agregar un grupo de gastos a un usuario
Future<void> addExpenseGroup(
  String userUid,
  String groupName,
  List<Gasto> expenses,
  List<List<Gasto>> subgroups, // Corregido: falta una coma aquí
  {required double total,} // Corregido: añadida la coma
) async {
  // Convierte cada objeto Gasto a un Map para almacenarlo en Firestore
  List<Map<String, dynamic>> expenseMaps =
      expenses.map((gasto) => gasto.toMap()).toList();

  // Convierte cada subgrupo y sus gastos a Map
  List<Map<String, dynamic>> subgroupMaps = subgroups.map((subgroup) {
    // Asignamos un nombre al subgrupo usando el índice de la lista
    return {
      'subgroupName': 'Subgrupo ${subgroups.indexOf(subgroup) + 1}',
      'expenses': subgroup.map((gasto) => gasto.toMap()).toList(), // Lista de gastos del subgrupo en formato Map
    };
  }).toList();

  // Crea un mapa para el grupo de gastos
  Map<String, dynamic> expenseGroup = {
    'groupName': groupName,
    'total': total, // Guardar el total calculado
    'expenses': expenseMaps, // Lista de gastos en formato Map
    'subgroups': subgroupMaps, // Lista de subgrupos en formato Map
    'creationDate': DateTime.now().toIso8601String(), // Fecha de creación del grupo en formato ISO
  };

  // Agrega el grupo de gastos a la colección 'expenseGroups' del usuario
  await _firestore
      .collection('usuarios')
      .doc(userUid)
      .collection('expenseGroups')
      .add(expenseGroup);
}



  // Stream para obtener los grupos de gastos de un usuario específico
  Stream<QuerySnapshot> getExpenseGroups(String userUid) {
    return _firestore
        .collection('usuarios') // Asegúrate de que sea 'usuarios'
        .doc(userUid)
        .collection('expenseGroups') // Asegúrate de que esto sea correcto
        .snapshots();
  }

  // Método para obtener un grupo de gastos específico por su ID
  Future<GroupModel> getExpenseGroup(String userUid, String groupId) async {
    DocumentSnapshot doc = await _firestore
        .collection('usuarios') // Asegúrate de que sea 'usuarios'
        .doc(userUid)
        .collection('expenseGroups') // Asegúrate de que esto sea correcto
        .doc(groupId)
        .get();

    if (doc.exists) {
      return GroupModel.fromMap(doc.data() as Map<String, dynamic>); // Asume que tienes un método `fromMap` en tu modelo
    } else {
      throw Exception('Grupo no encontrado');
    }
  }

  // Función para eliminar un grupo de gastos
  Future<void> deleteExpenseGroup(String userUid, String groupId) async {
    // Elimina el grupo de gastos del subcolección del usuario
    await _firestore
        .collection('usuarios')
        .doc(userUid)
        .collection('expenseGroups')
        .doc(groupId)
        .delete();
  }

  // Método para actualizar un grupo de gastos
  Future<void> updateExpenseGroup(String userUid, String groupId, String groupName, List<Gasto> expenses, List<List<Gasto>> subgroupExpenses) async {
    // Estructura los datos que se van a actualizar
    Map<String, dynamic> groupData = {
      'nombre': groupName,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'subgroupExpenses': subgroupExpenses.map((subgroup) => subgroup.map((e) => e.toMap()).toList()).toList(),
    };

    // Actualiza el grupo en Firestore
    await _firestore.collection('users').doc(userUid).collection('gastos').doc(groupId).update(groupData);
  }

}
