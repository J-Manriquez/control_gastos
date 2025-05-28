import 'dart:math';

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

      // Asegurar que el creador esté en la lista de participantes
      List<ExpenseParticipant> allParticipants = [];

      // Agregar al creador si no está en la lista
      if (!group.participants.any((p) => p.userId == group.creatorId)) {
        allParticipants.add(ExpenseParticipant(
          userId: group.creatorId,
          status: ParticipantStatus.accepted,
        ));
      }

      // Agregar el resto de participantes
      allParticipants.addAll(group.participants);

      // Formatear los datos según las reglas
      final Map<String, dynamic> sharedExpenseData = {
        'id': expenseId,
        'groupName': group.nombre,
        'total': group.total,
        'creatorId': group.creatorId,
        'participants': allParticipants
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
        'currentVersion': '1.0', // Inicializar currentVersion
        'archivado': false, // Añadir este campo
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

  Future<void> toggleArchiveSharedExpense(String expenseId, String id) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final currentData = doc.data() as Map<String, dynamic>;
        final currentArchivadoStatus = currentData['archivado'] ?? false;
        final newArchivadoStatus = !currentArchivadoStatus;

        transaction.update(docRef, {
          'archivado': newArchivadoStatus,
          'lastModified': FieldValue
              .serverTimestamp(), // Opcional: actualizar la fecha de modificación
        });
      });

      _logger.logInfo(
          'Estado de archivado del gasto compartido $expenseId cambiado a: ${await _getArchiveStatus(expenseId)}');
    } catch (e) {
      _logger.logError(
          'Error al cambiar el estado de archivado del gasto compartido: $e');
      rethrow;
    }
  }

  // Helper function to get the current archive status for logging
  Future<bool> _getArchiveStatus(String expenseId) async {
    final doc =
        await _firestore.collection('sharedExpenses').doc(expenseId).get();
    return (doc.data()?['archivado'] as bool?) ?? false;
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
        final currentVersion =
            (currentData['currentVersion'] as String?) ?? '0.0';
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
        final participants = [...sharedExpense.participants];

        final index = participants.indexWhere((p) => p.userId == userId);
        if (index != -1) {
          participants[index] = ExpenseParticipant(
            userId: userId,
            status: response,
            customPercentage: participants[index].customPercentage,
          );

          // Actualizar el documento
          transaction.update(docRef, {
            'participants': participants.map((p) => p.toMap()).toList(),
            'lastModified': FieldValue.serverTimestamp(),
          });

          // Eliminar la notificación original
          final notificationsRef = _firestore
              .collection('usuarios')
              .doc(userId)
              .collection('notifications')
              .where('sourceId', isEqualTo: expenseId);

          final notifications = await notificationsRef.get();
          for (var doc in notifications.docs) {
            await doc.reference.delete();
          }
        }
      });

      _logger.logInfo('Respuesta a invitación procesada: $expenseId');
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

  Future<void> synchronizeDistributions(String expenseId) async {
    try {
      final expense = await getSharedExpense(expenseId);
      if (expense == null) return;

      // Obtener todas las distribuciones
      final distributions = [
        ...expense.expenseDistributions.values,
        ...expense.subgroupDistributions.values,
        if (expense.totalDistribution != null) expense.totalDistribution!,
      ];

      // Verificar y resolver conflictos
      await _resolveDistributionConflicts(expenseId, distributions);

      // Actualizar totales
      await _updateDistributionTotals(expenseId, distributions);
    } catch (e) {
      CustomLogger().logError('Error en sincronización: $e');
      rethrow;
    }
  }

  Future<void> _resolveDistributionConflicts(
    String expenseId,
    List<DistributionModule> distributions,
  ) async {
    // Implementar lógica de resolución de conflictos
    // Por ejemplo: si hay múltiples distribuciones para el mismo target
    Map<String, List<DistributionModule>> distributionsByTarget = {};

    for (var dist in distributions) {
      distributionsByTarget.putIfAbsent(dist.targetId, () => []).add(dist);
    }

    // Resolver conflictos por cada target
    for (var entry in distributionsByTarget.entries) {
      if (entry.value.length > 1) {
        // Mantener la distribución más reciente
        final latestDist = entry.value
            .reduce((a, b) => a.lastModified.isAfter(b.lastModified) ? a : b);

        await updateDistributionModule(expenseId, latestDist);
      }
    }
  }

  Future<void> _updateDistributionTotals(
    String expenseId,
    List<DistributionModule> distributions,
  ) async {
    // Calcular y actualizar totales por participante
    Map<String, double> totalsByParticipant = {};

    for (var dist in distributions) {
      for (var share in dist.shares) {
        totalsByParticipant[share.userId] =
            (totalsByParticipant[share.userId] ?? 0) + share.amount;
      }
    }

    // Actualizar documento principal
    await _firestore.collection('sharedExpenses').doc(expenseId).update({
      'participantTotals': totalsByParticipant,
      'lastSyncTimestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina un participante de un gasto compartido
  Future<void> removeParticipant(String expenseId, String userId) async {
    try {
      CustomLogger().logInfo(
          'Iniciando eliminación de participante del gasto: $expenseId');

      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final sharedExpense = SharedExpenseGroup.fromMap(doc.data()!);

        // Verificar que el usuario no sea el creador
        if (sharedExpense.creatorId == userId) {
          throw Exception('El creador no puede ser eliminado del gasto');
        }

        // Verificar que el usuario sea participante
        if (!sharedExpense.participants.any((p) => p.userId == userId)) {
          throw Exception('El usuario no es participante de este gasto');
        }

        // Eliminar el participante
        final updatedParticipants = sharedExpense.participants
            .where((p) => p.userId != userId)
            .toList();

        // Actualizar las distribuciones si existen
        Map<String, DistributionModule> updatedExpenseDistributions =
            Map.from(sharedExpense.expenseDistributions);
        Map<String, DistributionModule> updatedSubgroupDistributions =
            Map.from(sharedExpense.subgroupDistributions);
        DistributionModule? updatedTotalDistribution =
            sharedExpense.totalDistribution;

        // Función auxiliar para actualizar distribución
        DistributionModule? updateDistributionModule(
            DistributionModule distribution) {
          final updatedShares = distribution.shares
              .where((share) => share.userId != userId)
              .toList();

          if (updatedShares.isEmpty) return null;

          // Redistribuir el monto del participante eliminado
          final removedShare =
              distribution.shares.firstWhere((share) => share.userId == userId);
          final amountPerShare = removedShare.amount / updatedShares.length;
          final percentagePerShare = 100.0 / updatedShares.length;

          final newShares = updatedShares
              .map((share) => ParticipantShare(
                    userId: share.userId,
                    amount: share.amount + amountPerShare,
                    percentage: percentagePerShare,
                  ))
              .toList();

          return DistributionModule(
            id: distribution.id,
            targetId: distribution.targetId,
            targetType: distribution.targetType,
            type: distribution.type,
            shares: newShares,
            totalAmount: distribution.totalAmount,
            lastModified: DateTime.now(),
          );
        }

        // Actualizar distribuciones de gastos individuales
        updatedExpenseDistributions = Map.fromEntries(
          updatedExpenseDistributions.entries.map((entry) {
            final updated = updateDistributionModule(entry.value);
            return updated != null
                ? MapEntry(entry.key, updated)
                : MapEntry(entry.key, entry.value);
          }),
        );

        // Actualizar distribuciones de subgrupos
        updatedSubgroupDistributions = Map.fromEntries(
          updatedSubgroupDistributions.entries.map((entry) {
            final updated = updateDistributionModule(entry.value);
            return updated != null
                ? MapEntry(entry.key, updated)
                : MapEntry(entry.key, entry.value);
          }),
        );

        // Actualizar distribución total
        if (updatedTotalDistribution != null) {
          final updated = updateDistributionModule(updatedTotalDistribution);
          updatedTotalDistribution = updated;
        }

        // Actualizar el documento
        final updateData = {
          'participants': updatedParticipants.map((p) => p.toMap()).toList(),
          'expenseDistributions': updatedExpenseDistributions.map(
            (key, value) => MapEntry(key, value.toMap()),
          ),
          'subgroupDistributions': updatedSubgroupDistributions.map(
            (key, value) => MapEntry(key, value.toMap()),
          ),
          'lastModified': FieldValue.serverTimestamp(),
        };

        if (updatedTotalDistribution != null) {
          updateData['totalDistribution'] = updatedTotalDistribution.toMap();
        }

        transaction.update(docRef, updateData);

        // Actualizar la lista de gastos compartidos del usuario
        final userRef = _firestore.collection('usuarios').doc(userId);
        transaction.update(userRef, {
          'sharedExpensesList': FieldValue.arrayRemove([expenseId])
        });

        // Crear notificación para el creador
        final userDoc = await transaction
            .get(_firestore.collection('usuarios').doc(userId));

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final creatorNotificationRef = _firestore
              .collection('usuarios')
              .doc(sharedExpense.creatorId)
              .collection('notifications')
              .doc();

          transaction.set(creatorNotificationRef, {
            'id': creatorNotificationRef.id,
            'title': 'Participante abandonó el gasto',
            'message':
                '${userData['username']} ha abandonado el gasto "${sharedExpense.nombre}"',
            'type': NotificationType.sharedExpense.toString(),
            'sourceId': expenseId,
            'senderId': userId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'additionalData': {
              'status': 'left',
              'expenseName': sharedExpense.nombre,
              'total': sharedExpense.total,
            }
          });
        }
      });

      CustomLogger()
          .logInfo('Participante eliminado exitosamente del gasto: $expenseId');
    } catch (e) {
      CustomLogger().logError('Error al eliminar participante del gasto: $e');
      rethrow;
    }
  }
}
