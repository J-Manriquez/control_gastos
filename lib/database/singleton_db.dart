// Importa Firebase y Firestore
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/notification_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/user_model.dart';
import 'package:control_gastos/services/firebase_interceptor_service.dart';
import 'package:control_gastos/services/shared_expense_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:control_gastos/firebase_options.dart';
import 'package:flutter/foundation.dart'; // Archivo de configuración de Firebase

// Clase que implementa el patrón Singleton para Firebase Firestore
class FirestoreService {
  // Campo estático para almacenar la instancia única
  static final FirestoreService _instance = FirestoreService._internal();

  // Proveedor del acceso global a la instancia
  factory FirestoreService() {
    return _instance;
  }

  // Variable para almacenar la instancia de FirebaseFirestore
  late FirebaseFirestore _firestore;

  // Añadir nueva propiedad
  late SharedExpenseService _sharedExpenseService;

  bool _isInitialized = false;
  bool _persistenceEnabled = false;

  // Constructor privado
  FirestoreService._internal();

  // Método de inicialización mejorado
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      CustomLogger().logInfo('Iniciando inicialización de Firebase...');

      // Inicializar Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Configurar Firestore
      _firestore = FirebaseFirestore.instance;

      // Asegurar que SharedExpenseService esté inicializado
      _sharedExpenseService = SharedExpenseService();

      // Configuración específica para web
      if (kIsWeb) {
        await _initializeWebFirestore();
      } else {
        await _initializeMobileFirestore();
      }

      _isInitialized = true;
      CustomLogger().logInfo('Firebase inicializado correctamente');
    } catch (e) {
      CustomLogger().logError('Error al inicializar Firebase: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  // Método para alternar el estado "archivado" de un grupo de gastos
  Future<void> toggleGroupArchivado(String userUid, String groupId) async {
    try {
      CustomLogger()
          .logInfo('Iniciando alternar estado archivado del grupo $groupId');

      // Obtener el documento del grupo
      DocumentSnapshot groupDoc = await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        throw Exception('Grupo de gastos no encontrado');
      }

      Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;

      // Alternar el estado de archivado
      bool currentStatus = groupData['archivado'] ?? false;
      groupData['archivado'] = !currentStatus;

      // Actualizar el documento en Firestore
      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .update({'archivado': !currentStatus});

      CustomLogger().logInfo(
          'Estado archivado del grupo $groupId actualizado correctamente');
    } catch (e) {
      CustomLogger()
          .logError('Error al alternar estado archivado del grupo: $e');
      rethrow;
    }
  }

  Future<void> _initializeWebFirestore() async {
    try {
      // Configurar settings específicos para web
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Solo habilitar persistencia si no está ya habilitada
      if (!_persistenceEnabled) {
        await _firestore
            .enablePersistence(const PersistenceSettings(
          synchronizeTabs: true,
        ))
            .then((_) {
          _persistenceEnabled = true;
        }).catchError((e) {
          if (e.code == 'failed-precondition') {
            CustomLogger().logInfo(
              'Multiple tabs open, persistence can only be enabled in one tab at a time.',
            );
          } else if (e.code == 'unimplemented') {
            CustomLogger().logInfo(
              'The current browser does not support persistence.',
            );
          }
        });
      }
    } catch (e) {
      CustomLogger().logError('Error en inicialización web: $e');
      // No relanzar el error para permitir que la app continúe funcionando
    }
  }

  Future<void> _initializeMobileFirestore() async {
    await _firestore.terminate();
    await _firestore.clearPersistence();
    await _firestore.enableNetwork();
  }

  // Método para reinicializar después de la autenticación
  Future<void> initializePostAuth() async {
    if (!_isInitialized) return;

    try {
      if (kIsWeb) {
        // En web, solo actualizar configuración si es necesario
        if (FirebaseAuth.instance.currentUser != null) {
          await _initializeWithAuth();
        }
      }
    } catch (e) {
      CustomLogger().logError('Error en initializePostAuth: $e');
    }
  }

  Future<void> debugSharedExpenses(String userUid) async {
    try {
      CustomLogger().logInfo('Iniciando debug de gastos compartidos');

      final QuerySnapshot snapshot = await _firestore
          .collection('sharedExpenses')
          .where('participants', arrayContains: {
        'userId': userUid,
        'status': ParticipantStatus.accepted.toString()
      }).get();

      CustomLogger().logInfo('Documentos encontrados: ${snapshot.docs.length}');

      for (var doc in snapshot.docs) {
        CustomLogger().logInfo('Documento ID: ${doc.id}');
        CustomLogger().logInfo('Datos: ${doc.data()}');
      }
    } catch (e) {
      CustomLogger().logError('Error en debug de gastos compartidos: $e');
    }
  }

  Future<void> createUserInFirestore(UserModel user) async {
    try {
      CustomLogger().logInfo('Creando usuario en Firestore...');

      // Verificar que el shortId esté disponible
      if (!await isShortIdAvailable(user.userShortId)) {
        throw Exception('ID corto no disponible');
      }

      // Crear el usuario
      await _firestore.collection('usuarios').doc(user.uid).set(user.toMap());

      // Registrar el shortId
      await registerShortId(user.userShortId, user.uid);

      CustomLogger().logInfo('Usuario creado correctamente');
    } catch (e) {
      CustomLogger().logError('Error al crear usuario: $e');
      rethrow;
    }
  }

  // Verificar si un shortId ya existe
  Future<bool> isShortIdAvailable(String shortId) async {
    final snapshot = await _firestore
        .collection('shortIds')
        .doc(shortId.toLowerCase())
        .get();
    return !snapshot.exists;
  }

  // Registrar un nuevo shortId
  Future<void> registerShortId(String shortId, String uid) async {
    final lowerId = shortId.toLowerCase();
    await _firestore.collection('shortIds').doc(lowerId).set({
      'uid': uid,
      'createdAt': DateTime.now(),
    });
  }

  // Generar un ID corto único
  Future<String> generateUniqueShortId() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String shortId;
    bool isAvailable = false;

    do {
      shortId = String.fromCharCodes(Iterable.generate(
        5,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ));
      isAvailable = await isShortIdAvailable(shortId);
    } while (!isAvailable);

    return shortId;
  }

  // Getter para verificar inicialización
  bool get isInitialized => _isInitialized;

  // Método para inicializar Firebase y Firestore

  Future<void> _initializeWithAuth() async {
    if (kIsWeb) {
      try {
        await _firestore.collection('appSettings').doc('webConfig').set({
          'platform': 'web',
          'lastInitialized': FieldValue.serverTimestamp(),
          'version': '1.0.0',
        }, SetOptions(merge: true));
      } catch (e) {
        CustomLogger().logError('Error al configurar web settings: $e');
        // No lanzar el error, continuar con la inicialización
      }
    }
  }

  Future<void> _initializeWithoutAuth() async {
    if (kIsWeb) {
      try {
        // Solo leer configuración, no escribir
        await _firestore.collection('appSettings').doc('webConfig').get();
      } catch (e) {
        CustomLogger().logError('Error al leer web settings: $e');
        // No lanzar el error, continuar con la inicialización
      }
    }
  }

  // Añadir métodos para gastos compartidos
  Future<String> createSharedExpenseGroup(
    String userUid,
    String groupName,
    List<Gasto> expenses,
    List<SubgroupModel> subgroups,
    List<String> participantIds,
    SharingPermissionType permissionType,
  ) async {
    try {
      CustomLogger()
          .logInfo('Iniciando creación de grupo de gastos compartido');

      final participants = participantIds
          .map((id) => ExpenseParticipant(
                userId: id,
                status: id == userUid
                    ? ParticipantStatus.accepted
                    : ParticipantStatus.pending,
              ))
          .toList();

      final sharedGroup = SharedExpenseGroup(
        id: '', // Se asignará en el servicio
        nombre: groupName,
        total: expenses.fold(0.0, (sum, exp) => sum + exp.valor) +
            subgroups.fold(0.0, (sum, sub) => sum + sub.subtotal),
        expenses: expenses,
        subgroups: subgroups,
        creationDate: DateTime.now(),
        creatorId: userUid,
        participants: participants,
        permissionType: permissionType,
        expenseDistributions: {}, // Inicializar como mapa vacío
        subgroupDistributions: {}, // Inicializar como mapa vacío
        totalDistribution: null, // Puede ser null inicialmente
        version: '1.0',
        lastModified: DateTime.now(),
      );

      CustomLogger().logInfo('Grupo preparado, enviando a crear...');
      final expenseId =
          await _sharedExpenseService.createSharedExpense(sharedGroup);
      CustomLogger().logInfo('Grupo creado exitosamente con ID: $expenseId');

      return expenseId;
    } catch (e) {
      CustomLogger().logError('Error al crear grupo de gastos compartido: $e');
      rethrow;
    }
  }

  // Getter para el servicio de gastos compartidos
  // SharedExpenseService get sharedExpenseService => _sharedExpenseService;
  SharedExpenseService get sharedExpenseService {
    if (!_isInitialized) {
      throw StateError('FirestoreService no ha sido inicializado');
    }
    return _sharedExpenseService;
  }

  // Método para obtener la instancia de Firestore
  FirebaseFirestore get firestore => _firestore;

  // Método para agregar un documento a una colección
  Future<void> addDocument(
      String collectionPath, Map<String, dynamic> data) async {
    return FirebaseInterceptor().runWithTokenVerification(() async {
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
    });
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
  Future addExpenseGroup(String userUid, String groupName, List<Gasto> expenses,
      List<SubgroupModel> subgroups,
      {required double total,
      GastoType type = GastoType.normal,
      bool archivado = false}) async {
    try {
      CustomLogger()
          .logInfo('Agregando grupo de gastos para el usuario $userUid');

      List<Map<String, dynamic>> expenseMaps =
          expenses.map((gasto) => gasto.toMap()).toList();

      List<Map<String, dynamic>> subgroupMaps =
          subgroups.map((subgroup) => subgroup.toMap()).toList();

      Map<String, dynamic> expenseGroup = {
        'groupName': groupName,
        'total': total,
        'expenses': expenseMaps,
        'subgroups': subgroupMaps,
        'creationDate': DateTime.now().toIso8601String(),
        'type': type.toString(), // Add the type field
        'archivado': archivado, // Add the archivado field
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

      // Usar directamente toMap() para cada subgrupo
      List<Map<String, dynamic>> subgroupMaps = 
          subgroups.map((subgroup) => subgroup.toMap()).toList();
      
      // Crear el mapa de datos siguiendo la estructura correcta del modelo
      Map<String, dynamic> groupData = {
        'groupName': groupName,
        'total': total,
        'expenses': expenses.map((e) => e.toMap()).toList(),
        'subgroups': subgroupMaps,
        'creationDate': DateTime.now().toIso8601String(),
      };
  
      CustomLogger().logInfo('Estructura de datos preparada para actualización');
      CustomLogger().logInfo('Subgrupos a guardar: ${subgroupMaps.length}');
      for (int i = 0; i < subgroupMaps.length; i++) {
        CustomLogger().logInfo('Subgrupo $i: ${subgroupMaps[i]}');
      }
  
      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .update(groupData);
  
      CustomLogger().logInfo('Grupo de gastos $groupId actualizado correctamente');
    } catch (e) {
      CustomLogger().logError('Error al actualizar grupo de gastos: $e');
      rethrow;
    }
  }

  Future<void> updateDistribution(String expenseId, String targetId,
      DistributionModule distribution) async {
    try {
      await FirebaseInterceptor().runWithTokenVerification(() async {
        final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(docRef);
          if (!doc.exists) {
            throw Exception('Gasto no encontrado');
          }

          final currentData = doc.data()!;
          Map<String, dynamic> distributions =
              Map.from(currentData['distributions'] ?? {});

          distributions[targetId] = distribution.toMap();

          transaction.update(docRef, {
            'distributions': distributions,
            'lastModified': FieldValue.serverTimestamp(),
          });
        });
      });
    } catch (e) {
      CustomLogger().logError('Error al actualizar distribución: $e');
      rethrow;
    }
  }

  Future<DistributionModule?> getDistribution(
      String expenseId, String targetId) async {
    try {
      final doc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();

      if (!doc.exists) return null;

      final distributions =
          doc.data()?['distributions'] as Map<String, dynamic>?;
      if (distributions == null || !distributions.containsKey(targetId)) {
        return null;
      }

      return DistributionModule.fromMap(distributions[targetId]);
    } catch (e) {
      CustomLogger().logError('Error al obtener distribución: $e');
      rethrow;
    }
  }

  Future<SharedExpenseGroup> getSharedExpenseGroup(String groupId) async {
    try {
      CustomLogger().logInfo('Obteniendo gasto compartido: $groupId');

      DocumentSnapshot doc =
          await _firestore.collection('sharedExpenses').doc(groupId).get();

      if (doc.exists) {
        CustomLogger().logInfo('Gasto compartido encontrado');
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return SharedExpenseGroup.fromMap(data);
      } else {
        CustomLogger().logError('Gasto compartido no encontrado');
        throw Exception('Gasto compartido no encontrado');
      }
    } catch (e) {
      CustomLogger().logError('Error al obtener gasto compartido: $e');
      rethrow;
    }
  }

  // Eliminar gasto normal
  Future<void> deleteNormalExpense(String userUid, String groupId) async {
    try {
      CustomLogger().logInfo('=== INICIO ELIMINACIÓN GASTO NORMAL ===');
      CustomLogger().logInfo('UserUID: $userUid');
      CustomLogger().logInfo('GroupID: $groupId');
      
      CustomLogger().logInfo('Eliminando documento de Firestore...');
      await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .delete();
      
      CustomLogger().logInfo('Documento eliminado exitosamente de Firestore');
      CustomLogger().logInfo('=== FIN ELIMINACIÓN GASTO NORMAL ===');
    } catch (e) {
      CustomLogger().logError('=== ERROR EN ELIMINACIÓN GASTO NORMAL ===');
      CustomLogger().logError('UserUID: $userUid, GroupID: $groupId');
      CustomLogger().logError('Error: $e');
      CustomLogger().logError('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }
}
