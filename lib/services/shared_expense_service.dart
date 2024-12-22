import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/models/notification_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/services/distribution_service.dart';
import 'package:control_gastos/services/firebase_interceptor_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:uuid/uuid.dart';

class SharedExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomLogger _logger = CustomLogger();
  final _uuid = const Uuid();
  final FirebaseInterceptor _interceptor = FirebaseInterceptor();

  // Crear un nuevo gasto compartido
  Future<String> createSharedExpense(SharedExpenseGroup group) async {
    try {
      _logger.logInfo('Creando nuevo gasto compartido');
      _logger.logInfo('Datos del grupo: ${group.toMap()}'); // Añadir este log

      final docRef = _firestore.collection('sharedExpenses').doc();
      final String expenseId = docRef.id;

      // Formatear los datos según las reglas
      final Map<String, dynamic> sharedExpenseData = {
        'id': expenseId,
        'groupName': group.nombre,
        'total': group.total,
        'creatorId': group.creatorId,
        'participants': group.participants
            .map((p) => {
                  'userId': p.userId,
                  'status': p.status.toString(),
                })
            .toList(),
        'expenses': group.expenses.map((e) => e.toMap()).toList(),
        'subgroups': group.subgroups.map((s) => s.toMap()).toList(),
        'creationDate': FieldValue.serverTimestamp(),
        'permissionType': group.permissionType.toString(),
        'version': '1.0',
        'status': 'active',
        'lastModified': FieldValue.serverTimestamp(),
      };

      // Crear el documento usando set() en lugar de transaction
      await docRef.set(sharedExpenseData);

      // Actualizar sharedExpensesList de todos los participantes
      final batch = _firestore.batch();

      // Actualizar creador
      final creatorRef = _firestore.collection('usuarios').doc(group.creatorId);
      batch.update(creatorRef, {
        'sharedExpensesList': FieldValue.arrayUnion([expenseId])
      });

      // Actualizar participantes
      for (var participant in group.participants) {
        if (participant.userId != group.creatorId) {
          final participantRef =
              _firestore.collection('usuarios').doc(participant.userId);
          batch.update(participantRef, {
            'sharedExpensesList': FieldValue.arrayUnion([expenseId])
          });
        }
      }

      await batch.commit();

      // Notificar a los participantes
      await _notifyParticipants(expenseId, group.participants);

      _logger.logInfo('Gasto compartido creado con ID: $expenseId');
      return expenseId;
    } catch (e) {
      _logger.logError('Error al crear gasto compartido: $e');
      rethrow;
    }
  }

  // Actualizar un gasto compartido existente
  Future<void> updateSharedExpense(
      String expenseId, SharedExpenseGroup updatedGroup) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final currentData = doc.data() as Map<String, dynamic>;
        final currentVersion = currentData['currentVersion'] as String;
        final newVersion = _incrementVersion(currentVersion);

        // Guardar nueva versión
        transaction.set(
          docRef.collection('versions').doc(newVersion),
          {
            'timestamp': FieldValue.serverTimestamp(),
            'data': updatedGroup.toMap(),
            'previousVersion': currentVersion,
          },
        );

        // Actualizar documento principal
        transaction.update(docRef, {
          ...updatedGroup.toMap(),
          'currentVersion': newVersion,
          'lastModified': FieldValue.serverTimestamp(),
        });
      });

      _logger.logInfo('Gasto compartido actualizado: $expenseId');
    } catch (e) {
      _logger.logError('Error al actualizar gasto compartido: $e');
      rethrow;
    }
  }

  // Añadir participantes a un gasto compartido
  Future<void> addParticipants(
      String expenseId, List<ExpenseParticipant> newParticipants) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final currentData =
            SharedExpenseGroup.fromMap(doc.data() as Map<String, dynamic>);
        final updatedParticipants = [
          ...currentData.participants,
          ...newParticipants
        ];

        transaction.update(docRef, {
          'participants': updatedParticipants.map((p) => p.toMap()).toList(),
        });
      });

      await _notifyParticipants(expenseId, newParticipants);
    } catch (e) {
      _logger.logError('Error al añadir participantes: $e');
      rethrow;
    }
  }

  // Actualizar módulo de distribución
  Future<void> updateDistributionModule(
    String expenseId,
    DistributionModule? module,
  ) async {
    if (module == null) return;

    await _interceptor.handleDistributionOperation(() async {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final currentData =
            SharedExpenseGroup.fromMap(doc.data() as Map<String, dynamic>);
        Map<String, DistributionModule> updatedModules =
            Map.from(currentData.expenseDistributions);

        // Actualizar o añadir nuevo módulo
        if (module.targetId != null) {
          updatedModules[module.targetId!] = module;
        }

        transaction.update(docRef, {
          'expenseDistributions': updatedModules.map(
            (key, value) => MapEntry(key, value.toMap()),
          ),
          'lastModified': FieldValue.serverTimestamp(),
        });
      });

      _logger.logInfo('Módulo de distribución actualizado para: $expenseId');
    });
  }

  // Obtener distribuciones de un gasto
  Future<Map<String, DistributionModule>> getExpenseDistributions(
    String expenseId,
  ) async {
    return await _interceptor.handleDistributionOperation(() async {
      final doc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();

      if (!doc.exists) {
        throw Exception('Gasto compartido no encontrado');
      }

      final data =
          SharedExpenseGroup.fromMap(doc.data() as Map<String, dynamic>);
      return data.expenseDistributions;
    });
  }

  // Actualizar distribución total
  Future<void> updateTotalDistribution(
    String expenseId,
    DistributionModule distribution,
  ) async {
    await _interceptor.handleDistributionOperation(() async {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        transaction.update(docRef, {
          'totalDistribution': distribution.toMap(),
          'lastModified': FieldValue.serverTimestamp(),
        });
      });

      _logger.logInfo('Distribución total actualizada para: $expenseId');
    });
  }

  // Validar y aplicar distribuciones
  Future<bool> validateAndApplyDistributions(
    String expenseId,
    List<DistributionModule> distributions,
  ) async {
    return await _interceptor.handleDistributionOperation(() async {
      try {
        final docRef = _firestore.collection('sharedExpenses').doc(expenseId);
        bool isValid = true;

        await _firestore.runTransaction((transaction) async {
          final doc = await transaction.get(docRef);
          if (!doc.exists) {
            throw Exception('Gasto compartido no encontrado');
          }

          final currentData =
              SharedExpenseGroup.fromMap(doc.data() as Map<String, dynamic>);
          double totalAssigned = 0;

          // Validar cada distribución
          for (var distribution in distributions) {
            if (!DistributionService().validateDistribution(distribution)) {
              isValid = false;
              break;
            }
            totalAssigned += distribution.totalAmount;
          }

          // Verificar que el total asignado no exceda el total del gasto
          if (totalAssigned > currentData.total) {
            isValid = false;
          }

          // Si todo es válido, aplicar las distribuciones
          if (isValid) {
            Map<String, DistributionModule> updatedDistributions = {};
            for (var distribution in distributions) {
              if (distribution.targetId != null) {
                updatedDistributions[distribution.targetId!] = distribution;
              }
            }

            transaction.update(docRef, {
              'expenseDistributions': updatedDistributions.map(
                (key, value) => MapEntry(key, value.toMap()),
              ),
              'lastModified': FieldValue.serverTimestamp(),
            });
          }
        });

        return isValid;
      } catch (e) {
        _logger.logError('Error en validación de distribuciones: $e');
        return false;
      }
    });
  }

  // Responder a una invitación
  Future<void> respondToInvitation(
    String expenseId,
    String userId,
    ParticipantStatus response,
  ) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final sharedExpense = SharedExpenseGroup.fromMap(doc.data()!);
        final updatedParticipants = [...sharedExpense.participants];

        final participantIndex =
            updatedParticipants.indexWhere((p) => p.userId == userId);

        if (participantIndex != -1) {
          updatedParticipants[participantIndex] = ExpenseParticipant(
            userId: userId,
            status: response,
            customPercentage:
                updatedParticipants[participantIndex].customPercentage,
          );

          // Actualizar el documento
          transaction.update(docRef, {
            'participants': updatedParticipants.map((p) => p.toMap()).toList(),
            'lastModified': FieldValue.serverTimestamp(),
          });

          // Eliminar la notificación original
          final notificationsQuery = await _firestore
              .collection('usuarios')
              .doc(userId)
              .collection('notifications')
              .where('sourceId', isEqualTo: expenseId)
              .get();

          for (var doc in notificationsQuery.docs) {
            transaction.delete(doc.reference);
          }

          // Crear nueva notificación para el creador
          if (response == ParticipantStatus.accepted) {
            final creatorNotificationRef = _firestore
                .collection('usuarios')
                .doc(sharedExpense.creatorId)
                .collection('notifications')
                .doc();

            final userDoc =
                await _firestore.collection('usuarios').doc(userId).get();
            final userData = userDoc.data();

            transaction.set(creatorNotificationRef, {
              'id': creatorNotificationRef.id,
              'title': 'Gasto compartido aceptado',
              'message':
                  '${userData?['username']} aceptó participar en el gasto "${sharedExpense.nombre}"',
              'type': NotificationType.sharedExpense.toString(),
              'sourceId': expenseId,
              'senderId': userId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
              'additionalData': {
                'status': 'accepted',
                'expenseName': sharedExpense.nombre,
                'total': sharedExpense.total,
              }
            });
          }
        }
      });

      _logger.logInfo('Respuesta a invitación procesada para: $expenseId');
    } catch (e) {
      _logger.logError('Error al procesar respuesta a invitación: $e');
      rethrow;
    }
  }

  // Obtener un gasto compartido
  Future<SharedExpenseGroup> getSharedExpense(String expenseId) async {
    try {
      final doc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();

      if (!doc.exists) {
        throw Exception('Gasto compartido no encontrado');
      }

      return SharedExpenseGroup.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      _logger.logError('Error al obtener gasto compartido: $e');
      rethrow;
    }
  }

  // Obtener todos los gastos compartidos de un usuario
  Stream<List<SharedExpenseGroup>> getUserSharedExpenses(String userId) {
    return _firestore
        .collection('sharedExpenses')
        .where('participants', arrayContains: {'userId': userId})
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedExpenseGroup.fromMap(doc.data()))
            .toList());
  }

  // Métodos privados de utilidad
  String _incrementVersion(String currentVersion) {
    final parts = currentVersion.split('.');
    final major = int.parse(parts[0]);
    final minor = int.parse(parts[1]);
    return '$major.${minor + 1}';
  }

  Future<void> _notifyParticipants(
    String expenseId,
    List<ExpenseParticipant> participants,
  ) async {
    try {
      final expenseDoc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();
      final expenseData = expenseDoc.data() as Map<String, dynamic>;
      final creatorDoc = await _firestore
          .collection('usuarios')
          .doc(expenseData['creatorId'])
          .get();
      final creatorData = creatorDoc.data() as Map<String, dynamic>;

      for (var participant in participants) {
        if (participant.userId != expenseData['creatorId']) {
          final notificationId = _uuid.v4();
          await _firestore
              .collection('usuarios')
              .doc(participant.userId)
              .collection('notifications')
              .doc(notificationId)
              .set({
            'id': notificationId,
            'title': 'Nuevo gasto compartido',
            'message':
                '${creatorData['username']} te ha invitado a un gasto compartido',
            'type': NotificationType.sharedExpense.toString(),
            'sourceId': expenseId,
            'senderId': expenseData['creatorId'],
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'additionalData': {
              'status': 'pending',
              'expenseName': expenseData['groupName'],
              'total': expenseData['total'],
            }
          });
        }
      }
    } catch (e) {
      _logger.logError('Error al enviar notificaciones: $e');
      rethrow;
    }
  }
}
