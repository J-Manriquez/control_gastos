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
    SharingPermissionType permissionType, {
    Map<String, Map<String, dynamic>>? imagenes,
    List<String>? expenseOrder,
    List<String>? subgroupOrder,
    List<String>? imageOrder,
    Map<String, List<String>>? subgroupExpenseOrder,
  }) async {
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
        imagenes: imagenes ?? {}, // Usar las imágenes pasadas o mapa vacío
        expenseOrder: expenseOrder ?? [],
        subgroupOrder: subgroupOrder ?? [],
        imageOrder: imageOrder ?? [],
        subgroupExpenseOrder: subgroupExpenseOrder ?? {},
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
      bool archivado = false,
      Map<String, Map<String, dynamic>>? imagenes,
      List<String>? expenseOrder,
      List<String>? subgroupOrder,
      List<String>? imageOrder}) async {
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
      
      // Siempre incluir el campo imagenes para permitir eliminación
      expenseGroup['imagenes'] = imagenes ?? {};
      
      // Incluir campos de orden si están disponibles
      if (expenseOrder != null) expenseGroup['expenseOrder'] = expenseOrder;
      if (subgroupOrder != null) expenseGroup['subgroupOrder'] = subgroupOrder;
      if (imageOrder != null) expenseGroup['imageOrder'] = imageOrder;

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
      
      // Ejecutar migración de imágenes fragmentadas externas si es necesario
      await migrarImagenesFragmentadasExternas(userUid, groupId);
      DocumentSnapshot doc = await _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .get();

      if (doc.exists) {
        CustomLogger().logInfo('Grupo de gastos $groupId obtenido');
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Agregar el ID del documento
        
        // Procesar imágenes fragmentadas externas
        if (data['imagenes'] != null) {
          final Map<String, dynamic> imagenes = Map<String, dynamic>.from(data['imagenes']);
          Map<String, dynamic> imagenesReconstruidas = {};
          
          for (String imageId in imagenes.keys) {
            final imageData = imagenes[imageId];
            
            if (imageData['tipo'] == 'fragmentada_externa') {
              // Para imágenes fragmentadas externas, solo pasar los metadatos
              // La carga real se hará de forma asíncrona en el widget
              imagenesReconstruidas[imageId] = {
                'tipo': 'fragmentada_externa',
                'descripcion': imageData['descripcion'],
                'fecha': imageData['fecha'],
                'valor': imageData['valor'] ?? 0.0,
                'esAFavor': imageData['esAFavor'] ?? true,
                'totalFragments': imageData['totalFragments'],
                'header': imageData['header'],
                'imageId': imageId,
              };
            } else {
              // Imagen normal
              imagenesReconstruidas[imageId] = imageData;
            }
          }
          
          data['imagenes'] = imagenesReconstruidas;
        }
        
        return GroupModel.fromMap(data);
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
    {Map<String, Map<String, dynamic>>? imagenes,
    List<String>? expenseOrder,
    List<String>? subgroupOrder,
    List<String>? imageOrder}
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

      // Procesar imágenes fragmentadas por separado
      Map<String, dynamic> imagenesOptimizadas = {};
      if (imagenes != null && imagenes.isNotEmpty) {
        CustomLogger().logInfo('Procesando imágenes para optimización...');
        CustomLogger().logInfo('Total de imágenes: ${imagenes.length}');
        
        for (String imageId in imagenes.keys) {
          final imageData = imagenes[imageId]!;
          
          // Si la imagen está fragmentada, almacenar fragmentos por separado
          if (imageData['tipo'] == 'fragmentada') {
            await _almacenarFragmentosEnDocumentosSeparados(
              userUid: userUid,
              groupId: groupId,
              imageId: imageId,
              fragmentedData: imageData,
            );
            
            // Solo guardar metadatos en el documento principal
            imagenesOptimizadas[imageId] = {
              'descripcion': imageData['descripcion'] ?? '',
              'fecha': imageData['fecha'] ?? DateTime.now().toIso8601String(),
              'tipo': 'fragmentada_externa',
              'imageId': imageId, // Agregar imageId para recuperación
              'totalFragments': imageData['totalFragments'],
              'totalLength': imageData['totalLength'],
              'header': imageData['header'],
              'valor': imageData['valor'] ?? 0.0,
              'esAFavor': imageData['esAFavor'] ?? true,
            };
            
            CustomLogger().logInfo('Imagen $imageId marcada como fragmentada_externa con ${imageData['totalFragments']} fragmentos');
          } else {
            // Imagen normal, mantener como está
            imagenesOptimizadas[imageId] = imageData;
          }
        }
      }

      // Crear el mapa de datos siguiendo la estructura correcta del modelo
      Map<String, dynamic> groupData = {
        'groupName': groupName,
        'total': total,
        'expenses': expenses.map((e) => e.toMap()).toList(),
        'subgroups': subgroupMaps,
        'creationDate': DateTime.now().toIso8601String(),
        'imagenes': imagenesOptimizadas,
      };
      
      // Incluir campos de orden si están disponibles
      if (expenseOrder != null) groupData['expenseOrder'] = expenseOrder;
      if (subgroupOrder != null) groupData['subgroupOrder'] = subgroupOrder;
      if (imageOrder != null) groupData['imageOrder'] = imageOrder;

      CustomLogger().logInfo('Estructura de datos preparada para actualización');
       CustomLogger().logInfo('Subgrupos a guardar: ${subgroupMaps.length}');
       CustomLogger().logInfo('Imágenes optimizadas: ${imagenesOptimizadas.length}');

       await _firestore
           .collection('usuarios')
           .doc(userUid)
           .collection('expenseGroups')
           .doc(groupId)
           .update(groupData);

       // Limpiar fragmentos huérfanos después de la actualización exitosa
       await _limpiarFragmentosHuerfanos(
         userUid: userUid,
         groupId: groupId,
         imagenesActuales: imagenesOptimizadas.keys.toSet(),
       );

       CustomLogger().logInfo('Grupo de gastos $groupId actualizado correctamente');
    } catch (e) {
      CustomLogger().logError('Error al actualizar grupo de gastos: $e');
      rethrow;
    }
  }

  /// Almacena los fragmentos de imagen en documentos separados
  Future<void> _almacenarFragmentosEnDocumentosSeparados({
    required String userUid,
    required String groupId,
    required String imageId,
    required Map<String, dynamic> fragmentedData,
  }) async {
    try {
      final Map<String, dynamic> fragments = fragmentedData['fragments'] ?? {};
      final int totalFragments = fragmentedData['totalFragments'] ?? 0;
      
      CustomLogger().logInfo('Almacenando $totalFragments fragmentos para imagen $imageId');
      CustomLogger().logInfo('Fragmentos disponibles: ${fragments.keys.toList()}');
      
      // Crear una colección específica para los fragmentos de esta imagen
      final fragmentsCollection = _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .collection('imageFragments')
          .doc(imageId)
          .collection('fragments');
      
      // Verificar que tenemos todos los fragmentos necesarios antes de almacenar
      List<String> fragmentosFaltantes = [];
      for (int i = 0; i < totalFragments; i++) {
        final String fragmentKey = 'fragment_$i';
        if (!fragments.containsKey(fragmentKey)) {
          fragmentosFaltantes.add(fragmentKey);
        }
      }
      
      if (fragmentosFaltantes.isNotEmpty) {
        throw Exception('Fragmentos faltantes antes del almacenamiento: $fragmentosFaltantes');
      }
      
      // Almacenar cada fragmento en un documento separado
      List<Future<void>> fragmentTasks = [];
      
      for (int i = 0; i < totalFragments; i++) {
        final String fragmentKey = 'fragment_$i';
        fragmentTasks.add(
          fragmentsCollection.doc(fragmentKey).set({
            'data': fragments[fragmentKey],
            'index': i,
            'timestamp': DateTime.now().toIso8601String(),
          })
        );
      }
      
      // Ejecutar todas las operaciones de fragmentos en paralelo
      await Future.wait(fragmentTasks);
      
      CustomLogger().logInfo('Fragmentos almacenados correctamente para imagen $imageId');
      
    } catch (e) {
      CustomLogger().logError('Error al almacenar fragmentos: $e');
      rethrow;
    }
  }

  // Método para migrar imágenes fragmentadas externas sin imageId en gastos compartidos
  Future<void> migrarImagenesFragmentadasExternasShared(String groupId) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(groupId);
      
      final doc = await docRef.get();
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final imagenes = data['imagenes'] as Map<String, dynamic>? ?? {};
      bool needsUpdate = false;
      
      for (String imageId in imagenes.keys) {
        final imageData = imagenes[imageId] as Map<String, dynamic>;
        if (imageData['tipo'] == 'fragmentada_externa' && !imageData.containsKey('imageId')) {
          imageData['imageId'] = imageId;
          needsUpdate = true;
          CustomLogger().logInfo('Agregando imageId a imagen fragmentada externa en gasto compartido: $imageId');
        }
      }
      
      if (needsUpdate) {
        await docRef.update({'imagenes': imagenes});
        CustomLogger().logInfo('Migración de imágenes fragmentadas externas completada para gasto compartido: $groupId');
      }
    } catch (e) {
      CustomLogger().logError('Error en migración de imágenes fragmentadas externas en gasto compartido: $e');
    }
  }

  // Método para migrar imágenes fragmentadas externas sin imageId
  Future<void> migrarImagenesFragmentadasExternas(String userUid, String groupId) async {
    try {
      final docRef = _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId);
      
      final doc = await docRef.get();
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final imagenes = data['imagenes'] as Map<String, dynamic>? ?? {};
      bool needsUpdate = false;
      
      for (String imageId in imagenes.keys) {
        final imageData = imagenes[imageId] as Map<String, dynamic>;
        if (imageData['tipo'] == 'fragmentada_externa' && !imageData.containsKey('imageId')) {
          imageData['imageId'] = imageId;
          needsUpdate = true;
          CustomLogger().logInfo('Agregando imageId a imagen fragmentada externa: $imageId');
        }
      }
      
      if (needsUpdate) {
        await docRef.update({'imagenes': imagenes});
        CustomLogger().logInfo('Migración de imágenes fragmentadas externas completada para grupo: $groupId');
      }
    } catch (e) {
      CustomLogger().logError('Error en migración de imágenes fragmentadas externas: $e');
    }
  }

  // Método para recuperar fragmentos desde gastos compartidos
   Future<Map<String, dynamic>> _recuperarFragmentosDesdeSharedExpenses({
     required String groupId,
     required String imageId,
     required int totalFragments,
     required String header,
   }) async {
     try {
       CustomLogger().logInfo('Recuperando fragmentos de imagen $imageId desde gasto compartido $groupId');
       
       final imageFragmentsCollection = _firestore
           .collection('sharedExpenses')
           .doc(groupId)
           .collection('imageFragments');
       
       List<String> fragments = [];
       
       for (int i = 0; i < totalFragments; i++) {
         final fragmentDoc = await imageFragmentsCollection
             .doc('${imageId}_fragment_$i')
             .get();
         
         if (fragmentDoc.exists) {
           final fragmentData = fragmentDoc.data()!;
           fragments.add(fragmentData['data'] as String);
         } else {
           throw Exception('Fragmento $i de imagen $imageId no encontrado');
         }
       }
       
       CustomLogger().logInfo('Fragmentos recuperados: ${fragments.length}/$totalFragments');
       
       return {
         'fragments': fragments,
         'totalFragments': totalFragments,
         'header': header,
         'tipo': 'fragmentada',
       };
     } catch (e) {
       CustomLogger().logError('Error recuperando fragmentos desde gasto compartido: $e');
       rethrow;
     }
   }

   /// Recupera los fragmentos de imagen desde gastos compartidos
   Future<Map<String, dynamic>> recuperarFragmentosDesdeSharedExpenses({
     required String groupId,
     required String imageId,
     required int totalFragments,
     required String header,
   }) async {
     return await _recuperarFragmentosDesdeSharedExpenses(
       groupId: groupId,
       imageId: imageId,
       totalFragments: totalFragments,
       header: header,
     );
   }

   /// Recupera los fragmentos de imagen desde documentos separados
   Future<Map<String, dynamic>> recuperarFragmentosDesdeDocumentosSeparados({
    required String userUid,
    required String groupId,
    required String imageId,
    required int totalFragments,
    required String header,
  }) async {
    try {
      CustomLogger().logInfo('Recuperando $totalFragments fragmentos para imagen $imageId');
      
      final fragmentsCollection = _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId)
          .collection('imageFragments')
          .doc(imageId)
          .collection('fragments');
      
      // Primero verificar qué fragmentos existen
      final querySnapshot = await fragmentsCollection.get();
      CustomLogger().logInfo('Fragmentos encontrados en Firestore: ${querySnapshot.docs.length}');
      
      Map<String, String> fragments = {};
      List<String> fragmentosEncontrados = [];
      
      // Recuperar todos los fragmentos disponibles
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        fragments[doc.id] = data['data'] ?? '';
        fragmentosEncontrados.add(doc.id);
      }
      
      CustomLogger().logInfo('Fragmentos recuperados: $fragmentosEncontrados');
      
      // Verificar que tenemos todos los fragmentos necesarios
      List<String> fragmentosFaltantes = [];
      for (int i = 0; i < totalFragments; i++) {
        final String fragmentKey = 'fragment_$i';
        if (!fragments.containsKey(fragmentKey)) {
          fragmentosFaltantes.add(fragmentKey);
        }
      }
      
      if (fragmentosFaltantes.isNotEmpty) {
        CustomLogger().logError('Fragmentos faltantes para imagen $imageId: $fragmentosFaltantes');
        CustomLogger().logError('Total esperado: $totalFragments, encontrados: ${fragments.length}');
        throw Exception('Fragmentos faltantes para imagen $imageId: $fragmentosFaltantes');
      }
      
      // Reconstruir la estructura de imagen fragmentada
      return {
        'header': header,
        'totalFragments': totalFragments,
        'fragments': fragments,
        'tipo': 'fragmentada',
      };
      
    } catch (e) {
       CustomLogger().logError('Error al recuperar fragmentos: $e');
       rethrow;
     }
   }

   /// Elimina los fragmentos de imagen de documentos separados
   Future<void> _eliminarFragmentosDeDocumentosSeparados({
     required String userUid,
     required String groupId,
     required String imageId,
   }) async {
     try {
       CustomLogger().logInfo('Eliminando fragmentos para imagen $imageId');
       
       // Eliminar toda la colección de fragmentos para esta imagen
       final fragmentsCollection = _firestore
           .collection('usuarios')
           .doc(userUid)
           .collection('expenseGroups')
           .doc(groupId)
           .collection('imageFragments')
           .doc(imageId)
           .collection('fragments');
       
       // Obtener todos los documentos de fragmentos
       final querySnapshot = await fragmentsCollection.get();
       
       // Eliminar cada fragmento
       List<Future<void>> deleteTasks = [];
       for (var doc in querySnapshot.docs) {
         deleteTasks.add(doc.reference.delete());
       }
       
       await Future.wait(deleteTasks);
       
       // Eliminar el documento contenedor de la imagen
       await _firestore
           .collection('usuarios')
           .doc(userUid)
           .collection('expenseGroups')
           .doc(groupId)
           .collection('imageFragments')
           .doc(imageId)
           .delete();
       
       CustomLogger().logInfo('Fragmentos eliminados correctamente para imagen $imageId');
       
     } catch (e) {
       CustomLogger().logError('Error al eliminar fragmentos: $e');
       // No relanzar el error para no interrumpir la eliminación principal
     }
   }

   /// Limpia fragmentos huérfanos cuando se actualiza un grupo
   Future<void> _limpiarFragmentosHuerfanos({
     required String userUid,
     required String groupId,
     required Set<String> imagenesActuales,
   }) async {
     try {
       // Obtener todos los fragmentos existentes
       final imageFragmentsCollection = _firestore
           .collection('usuarios')
           .doc(userUid)
           .collection('expenseGroups')
           .doc(groupId)
           .collection('imageFragments');
       
       final querySnapshot = await imageFragmentsCollection.get();
       
       // Eliminar fragmentos de imágenes que ya no existen
       List<Future<void>> cleanupTasks = [];
       for (var doc in querySnapshot.docs) {
         final imageId = doc.id;
         if (!imagenesActuales.contains(imageId)) {
           CustomLogger().logInfo('Limpiando fragmentos huérfanos para imagen $imageId');
           cleanupTasks.add(_eliminarFragmentosDeDocumentosSeparados(
             userUid: userUid,
             groupId: groupId,
             imageId: imageId,
           ));
         }
       }
       
       await Future.wait(cleanupTasks);
       
     } catch (e) {
       CustomLogger().logError('Error al limpiar fragmentos huérfanos: $e');
       // No relanzar el error para no interrumpir la operación principal
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
      
      // Ejecutar migración de imágenes fragmentadas externas si es necesario
      await migrarImagenesFragmentadasExternasShared(groupId);

      DocumentSnapshot doc =
          await _firestore.collection('sharedExpenses').doc(groupId).get();

      if (doc.exists) {
        CustomLogger().logInfo('Gasto compartido encontrado');
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Procesar imágenes fragmentadas externas
        if (data['imagenes'] != null) {
          final Map<String, dynamic> imagenes = Map<String, dynamic>.from(data['imagenes']);
          Map<String, dynamic> imagenesReconstruidas = {};
          
          for (String imageId in imagenes.keys) {
            final imageData = imagenes[imageId];
            
            if (imageData['tipo'] == 'fragmentada_externa') {
              // Para imágenes fragmentadas externas, solo pasar los metadatos
              // La carga real se hará de forma asíncrona en el widget
              imagenesReconstruidas[imageId] = {
                'tipo': 'fragmentada_externa',
                'descripcion': imageData['descripcion'],
                'fecha': imageData['fecha'],
                'valor': imageData['valor'] ?? 0.0,
                'esAFavor': imageData['esAFavor'] ?? true,
                'totalFragments': imageData['totalFragments'],
                'header': imageData['header'],
                'imageId': imageId,
                'isSharedExpense': true, // Indicador para usar la colección correcta
              };
            } else {
              // Imagen normal
              imagenesReconstruidas[imageId] = imageData;
            }
          }
          
          data['imagenes'] = imagenesReconstruidas;
        }
        
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

  // Método para actualizar el seguimiento de un gasto específico
  Future<void> updateExpenseTracking(
      String userUid, String groupId, String expenseId, bool isTracked) async {
    try {
      final groupRef = _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId);

      final groupDoc = await groupRef.get();
      if (!groupDoc.exists) {
        throw Exception('Grupo no encontrado');
      }

      final data = groupDoc.data()!;
      final List<dynamic> expenses = data['expenses'] ?? [];

      // Buscar y actualizar el gasto específico
      for (int i = 0; i < expenses.length; i++) {
        if (expenses[i]['id'] == expenseId) {
          expenses[i]['isTracked'] = isTracked;
          break;
        }
      }

      await groupRef.update({'expenses': expenses});
      CustomLogger().logInfo(
          'Seguimiento de gasto actualizado: $expenseId -> $isTracked');
    } catch (e) {
      CustomLogger().logError('Error al actualizar seguimiento de gasto: $e');
      rethrow;
    }
  }

  // Método para actualizar el seguimiento de un subgrupo
  Future<void> updateSubgroupTracking(
      String userUid, String groupId, String subgroupId, bool isTracked) async {
    try {
      final groupRef = _firestore
          .collection('usuarios')
          .doc(userUid)
          .collection('expenseGroups')
          .doc(groupId);

      final groupDoc = await groupRef.get();
      if (!groupDoc.exists) {
        throw Exception('Grupo no encontrado');
      }

      final data = groupDoc.data()!;
      final List<dynamic> subgroups = data['subgroups'] ?? [];

      // Buscar y actualizar el subgrupo específico
      for (int i = 0; i < subgroups.length; i++) {
        if (subgroups[i]['id'] == subgroupId) {
          subgroups[i]['isTracked'] = isTracked;
          break;
        }
      }

      await groupRef.update({'subgroups': subgroups});
      CustomLogger().logInfo(
          'Seguimiento de subgrupo actualizado: $subgroupId -> $isTracked');
    } catch (e) {
      CustomLogger()
          .logError('Error al actualizar seguimiento de subgrupo: $e');
      rethrow;
    }
  }

  // Corregir el método para actualizar seguimiento de gastos en subgrupos
  Future<void> updateSubgroupExpenseTracking(String userId, String groupId,
      String subgroupId, String expenseId, bool isTracked) async {
    try {
      // Cambiar de 'grupos_gastos' a 'expenseGroups'
      final docRef = _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('expenseGroups')
          .doc(groupId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data()!;
        final subgroups =
            List<Map<String, dynamic>>.from(data['subgroups'] ?? []);

        // Encontrar el subgrupo
        final subgroupIndex =
            subgroups.indexWhere((sg) => sg['id'] == subgroupId);
        if (subgroupIndex != -1) {
          final expenses = List<Map<String, dynamic>>.from(
              subgroups[subgroupIndex]['expenses'] ?? []);

          // Encontrar el gasto específico
          final expenseIndex =
              expenses.indexWhere((exp) => exp['id'] == expenseId);
          if (expenseIndex != -1) {
            // Actualizar el campo isTracked del gasto
            if (isTracked) {
              expenses[expenseIndex]['isTracked'] = isTracked;
            } else {
              // Remover el campo si es false para mantener la estructura limpia
              expenses[expenseIndex].remove('isTracked');
            }
            subgroups[subgroupIndex]['expenses'] = expenses;

            // Actualizar el documento
            await docRef.update({'subgroups': subgroups});
            CustomLogger().logInfo(
                'Seguimiento actualizado para gasto $expenseId en subgrupo $subgroupId: $isTracked');
          } else {
            throw Exception(
                'Gasto con ID $expenseId no encontrado en el subgrupo');
          }
        } else {
          throw Exception('Subgrupo con ID $subgroupId no encontrado');
        }
      } else {
        throw Exception('Grupo con ID $groupId no encontrado');
      }
    } catch (e) {
      CustomLogger().logError(
          'Error al actualizar seguimiento del gasto en subgrupo: $e');
      throw Exception(
          'Error al actualizar seguimiento del gasto en subgrupo: $e');
    }
  }
}
