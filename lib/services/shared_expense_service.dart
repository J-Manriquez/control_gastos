import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/notification_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/version_vote_model.dart';
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

      // En el método createSharedExpense, modificar la parte donde se actualiza sharedExpensesList

      // Actualizar creador
      final creatorRef = _firestore.collection('usuarios').doc(group.creatorId);
      batch.update(creatorRef, {
        'sharedExpensesMap.$expenseId': {'archivado': false}
      });

      // Actualizar participantes
      for (var participant in group.participants) {
        if (participant.userId != group.creatorId) {
          final participantRef =
              _firestore.collection('usuarios').doc(participant.userId);
          batch.update(participantRef, {
            'sharedExpensesMap.$expenseId': {'archivado': false}
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

  Future<void> toggleArchiveSharedExpense(
      String expenseId, String userId) async {
    try {
      final userRef = _firestore.collection('usuarios').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception('Usuario no encontrado');
        }

        // Obtener el mapa actual de gastos compartidos
        Map<String, dynamic> sharedExpensesMap = Map<String, dynamic>.from(
            userDoc.data()?['sharedExpensesMap'] ?? {});

        // Si el gasto no está en el mapa, inicializarlo
        if (!sharedExpensesMap.containsKey(expenseId)) {
          sharedExpensesMap[expenseId] = {'archivado': false};
        }

        // Cambiar el estado de archivado
        bool currentArchivadoStatus =
            sharedExpensesMap[expenseId]['archivado'] ?? false;
        sharedExpensesMap[expenseId]['archivado'] = !currentArchivadoStatus;

        // Actualizar el documento del usuario
        transaction.update(userRef, {
          'sharedExpensesMap': sharedExpensesMap,
        });
      });

      _logger.logInfo(
          'Estado de archivado del gasto compartido $expenseId para el usuario $userId actualizado');
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
  Future<void> updateSharedExpense(String expenseId,
      SharedExpenseGroup updatedGroup, String modifierId) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final currentData = doc.data() as Map<String, dynamic>;
        final currentGroup = SharedExpenseGroup.fromMap(currentData);
        final currentVersion =
            (currentData['currentVersion'] as String?) ?? '0.0';
        final newVersion = _incrementVersion(currentVersion);
        final permissionType = SharingPermissionType.values.firstWhere(
          (e) => e.toString() == currentData['permissionType'],
          orElse: () => SharingPermissionType.creatorOnly,
        );

        // Detectar cambios detallados
        Map<String, dynamic> detailedChanges =
            _detectDetailedChanges(currentGroup, updatedGroup);

        // Inicializar votos (el modificador automáticamente acepta)
        List<Map<String, dynamic>> initialVotes = [
          VersionVoteModel(
            userId: modifierId,
            status: VoteStatus.accepted,
            timestamp: DateTime.now(),
          ).toMap(),
        ];

        // Determinar estado inicial de la versión - SIEMPRE pending hasta aprobación
        String versionStatus = 'pending';

        // Guardar nueva versión con información detallada de cambios
        transaction.set(
          docRef.collection('versions').doc(newVersion),
          {
            'timestamp': FieldValue.serverTimestamp(),
            'data': updatedGroup.toMap(),
            'previousVersion': currentVersion,
            'modifierId': modifierId,
            'votes': initialVotes,
            'status': versionStatus,
            'changeTypes': detailedChanges['types'],
            'changeDetails':
                detailedChanges['details'], // Nuevo campo con detalles
          },
        );

        // NO actualizar documento principal - solo versión pendiente
        transaction.update(docRef, {
          'pendingVersion': newVersion,
        });

        // Notificar a los participantes sobre el cambio
        await _notifyVersionChange(
          expenseId,
          newVersion,
          modifierId,
          permissionType,
          updatedGroup.nombre,
          List<String>.from(detailedChanges['types']),
        );
      });

      _logger.logInfo('Versión de gasto compartido creada: $expenseId');
    } catch (e) {
      _logger.logError('Error al actualizar gasto compartido: $e');
      rethrow;
    }
  }

  // Método mejorado para detectar tipos de cambios con detalles específicos
  Map<String, dynamic> _detectDetailedChanges(
      SharedExpenseGroup original, SharedExpenseGroup updated) {
    Map<String, dynamic> changes = {
      'types': <String>[],
      'details': <String, dynamic>{}
    };

    // Detectar cambios en nombre del grupo
    if (original.nombre != updated.nombre) {
      changes['types'].add('name_change');
      changes['details']
          ['name_change'] = {'old': original.nombre, 'new': updated.nombre};
    }

    // Detectar cambios en total
    if (original.total != updated.total) {
      changes['types'].add('amount_change');
      changes['details']
          ['amount_change'] = {'old': original.total, 'new': updated.total};
    }

    // Detectar cambios detallados en gastos individuales
    Map<String, dynamic> expenseChanges =
        _detectExpenseChanges(original.expenses, updated.expenses);
    if (expenseChanges['hasChanges']) {
      changes['types'].add('expense_change');
      changes['details']['expense_changes'] = expenseChanges['changes'];
    }

    // Detectar cambios detallados en subgrupos
    Map<String, dynamic> subgroupChanges =
        _detectSubgroupChanges(original.subgroups, updated.subgroups);
    if (subgroupChanges['hasChanges']) {
      changes['types'].add('subgroup_change');
      changes['details']['subgroup_changes'] = subgroupChanges['changes'];
    }

    // Detectar cambios en participantes
    Map<String, dynamic> participantChanges =
        _detectParticipantChanges(original.participants, updated.participants);
    if (participantChanges['hasChanges']) {
      changes['types'].add('participant_change');
      changes['details']['participant_changes'] = participantChanges['changes'];
    }

    // Detectar cambios en distribuciones
    Map<String, dynamic> distributionChanges = _detectDistributionChanges(
        original.expenseDistributions,
        updated.expenseDistributions,
        original.subgroupDistributions,
        updated.subgroupDistributions);
    if (distributionChanges['hasChanges']) {
      changes['types'].add('distribution_change');
      changes['details']['distribution_changes'] =
          distributionChanges['changes'];
    }

    return changes;
  }

  // Detectar cambios específicos en gastos
  Map<String, dynamic> _detectExpenseChanges(
      List<Gasto> original, List<Gasto> updated) {
    Map<String, dynamic> result = {
      'hasChanges': false,
      'changes': {
        'added': <Map<String, dynamic>>[],
        'removed': <Map<String, dynamic>>[],
        'modified': <Map<String, dynamic>>[]
      }
    };

    // Crear mapas para comparación eficiente
    Map<String, Gasto> originalMap = {
      for (var expense in original) expense.id!: expense
    };
    Map<String, Gasto> updatedMap = {
      for (var expense in updated) expense.id!: expense
    };

    // Detectar gastos añadidos
    for (var expense in updated) {
      if (!originalMap.containsKey(expense.id)) {
        result['hasChanges'] = true;
        result['changes']['added'].add({
          'id': expense.id,
          'nombre': expense.nombre,
          'valor': expense.valor,
          'esAFavor': expense.esAFavor,
          'fecha': expense.fecha.toIso8601String()
        });
      }
    }

    // Detectar gastos eliminados
    for (var expense in original) {
      if (!updatedMap.containsKey(expense.id)) {
        result['hasChanges'] = true;
        result['changes']['removed'].add({
          'id': expense.id,
          'nombre': expense.nombre,
          'valor': expense.valor,
          'esAFavor': expense.esAFavor,
          'fecha': expense.fecha.toIso8601String()
        });
      }
    }

    // Detectar gastos modificados
    for (var expense in updated) {
      if (originalMap.containsKey(expense.id)) {
        var originalExpense = originalMap[expense.id]!;
        Map<String, dynamic> modifications = {};

        if (originalExpense.nombre != expense.nombre) {
          modifications['nombre'] = {
            'old': originalExpense.nombre,
            'new': expense.nombre
          };
        }

        if (originalExpense.valor != expense.valor) {
          modifications['valor'] = {
            'old': originalExpense.valor,
            'new': expense.valor
          };
        }

        if (originalExpense.esAFavor != expense.esAFavor) {
          modifications['esAFavor'] = {
            'old': originalExpense.esAFavor,
            'new': expense.esAFavor
          };
        }

        if (originalExpense.fecha != expense.fecha) {
          modifications['fecha'] = {
            'old': originalExpense.fecha.toIso8601String(),
            'new': expense.fecha.toIso8601String()
          };
        }

        if (modifications.isNotEmpty) {
          result['hasChanges'] = true;
          result['changes']['modified'].add({
            'id': expense.id,
            'nombre': expense.nombre,
            'modifications': modifications
          });
        }
      }
    }

    return result;
  }

  // Detectar cambios específicos en subgrupos
  Map<String, dynamic> _detectSubgroupChanges(
      List<SubgroupModel> original, List<SubgroupModel> updated) {
    Map<String, dynamic> result = {
      'hasChanges': false,
      'changes': {
        'added': <Map<String, dynamic>>[],
        'removed': <Map<String, dynamic>>[],
        'modified': <Map<String, dynamic>>[]
      }
    };

    // Crear mapas para comparación eficiente
    Map<String, SubgroupModel> originalMap = {
      for (var subgroup in original) subgroup.id: subgroup
    };
    Map<String, SubgroupModel> updatedMap = {
      for (var subgroup in updated) subgroup.id: subgroup
    };

    // Detectar subgrupos añadidos
    for (var subgroup in updated) {
      if (!originalMap.containsKey(subgroup.id)) {
        result['hasChanges'] = true;
        result['changes']['added'].add({
          'id': subgroup.id,
          'nombre': subgroup.subgroupName,
          'gastos': subgroup.expenses
              .map((e) => {
                    'id': e.id,
                    'nombre': e.nombre,
                    'valor': e.valor,
                    'esAFavor': e.esAFavor
                  })
              .toList()
        });
      }
    }

    // Detectar subgrupos eliminados
    for (var subgroup in original) {
      if (!updatedMap.containsKey(subgroup.id)) {
        result['hasChanges'] = true;
        result['changes']['removed'].add({
          'id': subgroup.id,
          'nombre': subgroup.subgroupName,
          'gastos': subgroup.expenses
              .map((e) => {
                    'id': e.id,
                    'nombre': e.nombre,
                    'valor': e.valor,
                    'esAFavor': e.esAFavor
                  })
              .toList()
        });
      }
    }

    // Detectar subgrupos modificados
    for (var subgroup in updated) {
      if (originalMap.containsKey(subgroup.id)) {
        var originalSubgroup = originalMap[subgroup.id]!;
        Map<String, dynamic> modifications = {};

        // Cambio en nombre del subgrupo
        if (originalSubgroup.subgroupName != subgroup.subgroupName) {
          modifications['nombre'] = {
            'old': originalSubgroup.subgroupName,
            'new': subgroup.subgroupName
          };
        }

        // Cambios en gastos del subgrupo
        Map<String, dynamic> subgroupExpenseChanges =
            _detectExpenseChanges(originalSubgroup.expenses, subgroup.expenses);

        if (subgroupExpenseChanges['hasChanges']) {
          modifications['gastos'] = subgroupExpenseChanges['changes'];
        }

        if (modifications.isNotEmpty) {
          result['hasChanges'] = true;
          result['changes']['modified'].add({
            'id': subgroup.id,
            'nombre': subgroup.subgroupName,
            'modifications': modifications
          });
        }
      }
    }

    return result;
  }

  // Detectar cambios en participantes
  Map<String, dynamic> _detectParticipantChanges(
      List<ExpenseParticipant> original, List<ExpenseParticipant> updated) {
    Map<String, dynamic> result = {
      'hasChanges': false,
      'changes': {
        'added': <String>[],
        'removed': <String>[],
        'status_changed': <Map<String, dynamic>>[]
      }
    };

    Set<String> originalIds = original.map((p) => p.userId).toSet();
    Set<String> updatedIds = updated.map((p) => p.userId).toSet();

    // Participantes añadidos
    for (String userId in updatedIds) {
      if (!originalIds.contains(userId)) {
        result['hasChanges'] = true;
        result['changes']['added'].add(userId);
      }
    }

    // Participantes eliminados
    for (String userId in originalIds) {
      if (!updatedIds.contains(userId)) {
        result['hasChanges'] = true;
        result['changes']['removed'].add(userId);
      }
    }

    // Cambios de estado
    Map<String, ExpenseParticipant> originalMap = {
      for (var p in original) p.userId: p
    };
    Map<String, ExpenseParticipant> updatedMap = {
      for (var p in updated) p.userId: p
    };

    for (String userId in originalIds.intersection(updatedIds)) {
      var originalParticipant = originalMap[userId]!;
      var updatedParticipant = updatedMap[userId]!;

      if (originalParticipant.status != updatedParticipant.status) {
        result['hasChanges'] = true;
        result['changes']['status_changed'].add({
          'userId': userId,
          'oldStatus': originalParticipant.status.toString(),
          'newStatus': updatedParticipant.status.toString()
        });
      }
    }

    return result;
  }

  // Detectar cambios detallados en distribuciones
  Map<String, dynamic> _detectDistributionChanges(
      Map<String, DistributionModule> originalExpense,
      Map<String, DistributionModule> updatedExpense,
      Map<String, DistributionModule> originalSubgroup,
      Map<String, DistributionModule> updatedSubgroup) {
    Map<String, dynamic> result = {
      'hasChanges': false,
      'changes': {
        'expense_distributions': <Map<String, dynamic>>[],
        'subgroup_distributions': <Map<String, dynamic>>[]
      }
    };

    // Comparar distribuciones de gastos
    var expenseDistChanges =
        _compareDistributionMaps(originalExpense, updatedExpense, 'expense');
    if (expenseDistChanges.isNotEmpty) {
      result['hasChanges'] = true;
      result['changes']['expense_distributions'] = expenseDistChanges;
    }

    // Comparar distribuciones de subgrupos
    var subgroupDistChanges =
        _compareDistributionMaps(originalSubgroup, updatedSubgroup, 'subgroup');
    if (subgroupDistChanges.isNotEmpty) {
      result['hasChanges'] = true;
      result['changes']['subgroup_distributions'] = subgroupDistChanges;
    }

    return result;
  }

  // Comparar mapas de distribución
  List<Map<String, dynamic>> _compareDistributionMaps(
      Map<String, DistributionModule> original,
      Map<String, DistributionModule> updated,
      String type) {
    List<Map<String, dynamic>> changes = [];

    // Distribuciones añadidas
    for (String targetId in updated.keys) {
      if (!original.containsKey(targetId)) {
        changes.add({
          'type': 'added',
          'targetId': targetId,
          'targetType': type,
          'distribution': _serializeDistributionModule(updated[targetId]!)
        });
      }
    }

    // Distribuciones eliminadas
    for (String targetId in original.keys) {
      if (!updated.containsKey(targetId)) {
        changes.add({
          'type': 'removed',
          'targetId': targetId,
          'targetType': type,
          'distribution': _serializeDistributionModule(original[targetId]!)
        });
      }
    }

    // Distribuciones modificadas
    for (String targetId in original.keys) {
      if (updated.containsKey(targetId)) {
        var originalDist = original[targetId]!;
        var updatedDist = updated[targetId]!;

        Map<String, dynamic> modifications = {};

        // Comparar tipo de distribución
        if (originalDist.type != updatedDist.type) {
          modifications['type'] = {
            'old': originalDist.type.toString(),
            'new': updatedDist.type.toString()
          };
        }

        // Comparar total
        if (originalDist.totalAmount != updatedDist.totalAmount) {
          modifications['totalAmount'] = {
            'old': originalDist.totalAmount,
            'new': updatedDist.totalAmount
          };
        }

        // Comparar shares detalladamente
        var shareChanges =
            _compareDistributionShares(originalDist.shares, updatedDist.shares);
        if (shareChanges.isNotEmpty) {
          modifications['shares'] = shareChanges;
        }

        if (modifications.isNotEmpty) {
          changes.add({
            'type': 'modified',
            'targetId': targetId,
            'targetType': type,
            'modifications': modifications
          });
        }
      }
    }

    return changes;
  }

  // Comparar shares de distribución
  Map<String, dynamic> _compareDistributionShares(
      List<ParticipantShare> original, List<ParticipantShare> updated) {
    Map<String, dynamic> changes = {
      'added': <Map<String, dynamic>>[],
      'removed': <Map<String, dynamic>>[],
      'modified': <Map<String, dynamic>>[]
    };

    Map<String, ParticipantShare> originalMap = {
      for (var share in original) share.userId: share
    };
    Map<String, ParticipantShare> updatedMap = {
      for (var share in updated) share.userId: share
    };

    // Shares añadidos
    for (var share in updated) {
      if (!originalMap.containsKey(share.userId)) {
        changes['added'].add({
          'userId': share.userId,
          'amount': share.amount,
          'percentage': share.percentage
        });
      }
    }

    // Shares eliminados
    for (var share in original) {
      if (!updatedMap.containsKey(share.userId)) {
        changes['removed'].add({
          'userId': share.userId,
          'amount': share.amount,
          'percentage': share.percentage
        });
      }
    }

    // Shares modificados
    for (var share in updated) {
      if (originalMap.containsKey(share.userId)) {
        var originalShare = originalMap[share.userId]!;
        Map<String, dynamic> modifications = {};

        if (originalShare.amount != share.amount) {
          modifications['amount'] = {
            'old': originalShare.amount,
            'new': share.amount
          };
        }

        if (originalShare.percentage != share.percentage) {
          modifications['percentage'] = {
            'old': originalShare.percentage,
            'new': share.percentage
          };
        }

        if (modifications.isNotEmpty) {
          changes['modified']
              .add({'userId': share.userId, 'modifications': modifications});
        }
      }
    }

    return changes;
  }

  // Serializar módulo de distribución
  Map<String, dynamic> _serializeDistributionModule(DistributionModule module) {
    return {
      'id': module.id,
      'type': module.type.toString(),
      'totalAmount': module.totalAmount,
      'shares': module.shares
          .map((share) => {
                'userId': share.userId,
                'amount': share.amount,
                'percentage': share.percentage
              })
          .toList()
    };
  }

  // Método auxiliar para comparar distribuciones
  bool _areDistributionsEqual(Map<String, DistributionModule> dist1,
      Map<String, DistributionModule> dist2) {
    if (dist1.length != dist2.length) return false;

    for (String key in dist1.keys) {
      if (!dist2.containsKey(key)) return false;

      final module1 = dist1[key]!;
      final module2 = dist2[key]!;

      // Comparar distribuciones individuales
      if (module1.shares.length != module2.shares.length) return false;

      for (int i = 0; i < module1.shares.length; i++) {
        final d1 = module1.shares[i];
        final d2 = module2.shares[i];

        if (d1.userId != d2.userId ||
            d1.amount != d2.amount ||
            d1.percentage != d2.percentage) {
          return false;
        }
      }
    }

    return true;
  }

  // Añadir participantes a un gasto compartido (requiere aprobación)
  Future<void> addParticipants(String expenseId,
      List<ExpenseParticipant> newParticipants, String requesterId) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);

      // Declarar permissionType fuera del bloque de transacción
      late SharingPermissionType permissionType;
      late String newVersion;

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw Exception('Gasto compartido no encontrado');
        }

        final currentData = doc.data() as Map<String, dynamic>;
        final currentVersion =
            (currentData['currentVersion'] as String?) ?? '0.0';
        newVersion = _incrementVersion(currentVersion);
        permissionType = SharingPermissionType.values.firstWhere(
          (e) => e.toString() == currentData['permissionType'],
          orElse: () => SharingPermissionType.creatorOnly,
        );

        final currentGroup = SharedExpenseGroup.fromMap(currentData);
        final updatedParticipants = [
          ...currentGroup.participants,
          ...newParticipants
        ];

        // Crear grupo actualizado con nuevos participantes
        final updatedGroup = currentGroup.copyWith(
          participants: updatedParticipants,
        );

        // Inicializar votos
        List<Map<String, dynamic>> initialVotes = [
          VersionVoteModel(
            userId: requesterId,
            status: VoteStatus.accepted,
            timestamp: DateTime.now(),
          ).toMap(),
        ];

        // Guardar nueva versión para añadir participantes
        transaction.set(
          docRef.collection('versions').doc(newVersion),
          {
            'timestamp': FieldValue.serverTimestamp(),
            'data': updatedGroup.toMap(),
            'previousVersion': currentVersion,
            'modifierId': requesterId,
            'votes': initialVotes,
            'status': 'pending',
            'changeTypes': ['participant_addition'],
            'newParticipants': newParticipants.map((p) => p.toMap()).toList(),
          },
        );

        // Solo actualizar versión pendiente
        transaction.update(docRef, {
          'pendingVersion': newVersion,
        });
      });

      // Notificar sobre la adición de participantes
      await _notifyParticipantAddition(
        expenseId,
        newVersion,
        requesterId,
        newParticipants,
        permissionType,
      );
    } catch (e) {
      _logger.logError('Error al solicitar adición de participantes: $e');
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
      print(
          'DEBUG: Iniciando respondToInvitation para expenseId: $expenseId, userId: $userId, response: $response');

      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);
      final userRef = _firestore.collection('usuarios').doc(userId);

      // Primero, obtener las notificaciones para eliminarlas después
      late QuerySnapshot notifications;
      try {
        final notificationsRef = _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('notifications')
            .where('sourceId', isEqualTo: expenseId);

        print('DEBUG: Obteniendo notificaciones para sourceId: $expenseId');
        notifications = await notificationsRef.get();
        print(
            'DEBUG: Notificaciones obtenidas: ${notifications.docs.length} documentos.');
      } catch (e) {
        _logger.logError('Error al obtener notificaciones: $e');
        print(
            'DEBUG: Stack trace error al obtener notificaciones: ${StackTrace.current}');
        rethrow;
      }

      try {
        await _firestore.runTransaction((transaction) async {
          print('DEBUG: Iniciando transacción para docRef: ${docRef.path}');

          // PRIMERO: Realizar TODAS las lecturas necesarias
          final doc = await transaction.get(docRef);
          if (!doc.exists) {
            throw Exception(
                'Gasto compartido no encontrado para expenseId: $expenseId');
          }
          print(
              'DEBUG: Documento de gasto compartido encontrado. Data: ${doc.data()}');

          // Obtener el documento del usuario ANTES de cualquier escritura
          final userDoc = await transaction.get(userRef);
          print(
              'DEBUG: Documento de usuario obtenido. Existe: ${userDoc.exists}');

          // SEGUNDO: Procesar los datos leídos
          SharedExpenseGroup sharedExpense;
          try {
            sharedExpense = SharedExpenseGroup.fromMap(doc.data()!);
            print('DEBUG: SharedExpenseGroup parseado correctamente.');
          } catch (e) {
            _logger.logError(
                'Error al parsear SharedExpenseGroup desde doc.data(): $e');
            print(
                'DEBUG: Stack trace error al parsear SharedExpenseGroup: ${StackTrace.current}');
            throw Exception(
                'Error al procesar los datos del gasto compartido.');
          }

          final participants = [...sharedExpense.participants];
          final index = participants.indexWhere((p) => p.userId == userId);

          if (index == -1) {
            print(
                'DEBUG: Participante $userId no encontrado en el gasto compartido $expenseId.');
            throw Exception(
                'Usuario $userId no es un participante del gasto $expenseId.');
          }

          // Actualizar el participante en la lista
          participants[index] = ExpenseParticipant(
            userId: userId,
            status: response,
            customPercentage: participants[index].customPercentage,
          );

          print(
              'DEBUG: Actualizando participante en la lista: ${participants[index].toMap()}');

          // TERCERO: Realizar TODAS las escrituras después de todas las lecturas

          // Actualizar el documento del gasto compartido
          try {
            transaction.update(docRef, {
              'participants': participants.map((p) => p.toMap()).toList(),
              'lastModified': FieldValue.serverTimestamp(),
            });
            print(
                'DEBUG: Actualización de participantes y lastModified programada en la transacción.');
          } catch (e) {
            _logger.logError(
                'Error al programar la actualización de sharedExpenses: $e');
            print(
                'DEBUG: Stack trace error al programar sharedExpenses update: ${StackTrace.current}');
            rethrow;
          }

          // Si el usuario acepta la invitación, actualizar su sharedExpensesMap
          if (response == ParticipantStatus.accepted && userDoc.exists) {
            print(
                'DEBUG: El usuario aceptó la invitación. Actualizando sharedExpensesMap del usuario.');

            try {
              transaction.update(userRef, {
                'sharedExpensesMap.$expenseId': {'archivado': false}
              });
              print(
                  'DEBUG: sharedExpensesMap del usuario programado para actualizarse.');
            } catch (e) {
              _logger.logError(
                  'Error al programar la actualización de sharedExpensesMap del usuario: $e');
              print(
                  'DEBUG: Stack trace error al programar user sharedExpensesMap update: ${StackTrace.current}');
              rethrow;
            }
          }
        });
        print('DEBUG: Transacción de Firestore completada exitosamente.');
      } catch (e) {
        _logger.logError('Error durante la transacción de Firestore: $e');
        print(
            'DEBUG: Stack trace error en la transacción: ${StackTrace.current}');
        rethrow;
      }

      // Eliminar las notificaciones después de completar la transacción
      try {
        print('DEBUG: Eliminando notificaciones...');
        for (var doc in notifications.docs) {
          print('DEBUG: Eliminando notificación con ID: ${doc.id}');
          await doc.reference.delete();
          print('DEBUG: Notificación ${doc.id} eliminada.');
        }
        print('DEBUG: Todas las notificaciones eliminadas.');
      } catch (e) {
        _logger.logError('Error al eliminar notificaciones: $e');
        print(
            'DEBUG: Stack trace error al eliminar notificaciones: ${StackTrace.current}');
        // No rethrow aquí si la eliminación de notificaciones no es crítica para el éxito de la operación principal
      }

      _logger.logInfo('Respuesta a invitación procesada: $expenseId');
    } catch (e) {
      _logger.logError('Error general al procesar respuesta a invitación: $e');
      print('DEBUG: Stack trace error general: ${StackTrace.current}');
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







// Notificar a los participantes sobre un cambio de versión
  Future<void> _notifyVersionChange(
    String expenseId,
    String version,
    String modifierId,
    SharingPermissionType permissionType,
    String expenseName,
    List<String> changeTypes,
  ) async {
    try {
      final expenseDoc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();
      final expenseData = expenseDoc.data() as Map<String, dynamic>;

      // Obtener información del modificador
      final modifierDoc =
          await _firestore.collection('usuarios').doc(modifierId).get();
      final modifierData = modifierDoc.data() as Map<String, dynamic>;
      final modifierName = modifierData['username'] ?? 'Un usuario';

      // Crear mensaje descriptivo basado en tipos de cambios
      String changeDescription = _getChangeDescription(changeTypes);

      String title = 'Cambios en gasto compartido';
      String message =
          '$modifierName ha realizado $changeDescription en "$expenseName" que requiere aprobación';

      // Obtener participantes
      List<dynamic> participantsData = expenseData['participants'] ?? [];

      // Enviar notificación a cada participante (excepto al modificador)
      for (var participantData in participantsData) {
        String userId = participantData['userId'];

        if (userId != modifierId) {
          final notificationId = _uuid.v4();
          await _firestore
              .collection('usuarios')
              .doc(userId)
              .collection('notifications')
              .doc(notificationId)
              .set({
            'id': notificationId,
            'title': title,
            'message': message,
            'type': NotificationType.sharedExpense.toString(),
            'sourceId': expenseId,
            'senderId': modifierId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'additionalData': {
              'status': 'pending', // Siempre pending hasta aprobación
              'expenseName': expenseName,
              'version': version,
              'modifierId': modifierId,
              'modifierName': modifierName,
              'permissionType': permissionType.toString(),
              'changeTypes': changeTypes,
            }
          });
        }
      }
    } catch (e) {
      print('Error al enviar notificaciones de cambio de versión: $e');
    }
  }

  // Método auxiliar para describir tipos de cambios
  String _getChangeDescription(List<String> changeTypes) {
    if (changeTypes.isEmpty) return 'cambios';

    List<String> descriptions = [];

    if (changeTypes.contains('amount_change')) {
      descriptions.add('cambios en montos');
    }
    if (changeTypes.contains('distribution_change')) {
      descriptions.add('cambios en distribución');
    }
    if (changeTypes.contains('name_change')) {
      descriptions.add('cambios en el nombre');
    }
    if (changeTypes.contains('expense_change')) {
      descriptions.add('cambios en gastos');
    }
    if (changeTypes.contains('subgroup_change')) {
      descriptions.add('cambios en subgrupos');
    }
    if (changeTypes.contains('participant_change')) {
      descriptions.add('cambios en participantes');
    }
    if (changeTypes.contains('participant_addition')) {
      descriptions.add('adición de participantes');
    }

    if (descriptions.length == 1) {
      return descriptions.first;
    } else if (descriptions.length == 2) {
      return '${descriptions[0]} y ${descriptions[1]}';
    } else {
      return '${descriptions.sublist(0, descriptions.length - 1).join(", ")} y ${descriptions.last}';
    }
  }

  // Responder a una votación de versión
  Future<void> respondToVersionVote(
    String expenseId,
    String version,
    String userId,
    VoteStatus voteStatus,
  ) async {
    try {
      final docRef = _firestore.collection('sharedExpenses').doc(expenseId);
      final versionRef = docRef.collection('versions').doc(version);

      await _firestore.runTransaction((transaction) async {
        final expenseDoc = await transaction.get(docRef);
        final versionDoc = await transaction.get(versionRef);

        if (!expenseDoc.exists || !versionDoc.exists) {
          throw Exception('Gasto compartido o versión no encontrada');
        }

        final expenseData = expenseDoc.data() as Map<String, dynamic>;
        final versionData = versionDoc.data() as Map<String, dynamic>;

        // Verificar si la versión ya está aceptada o rechazada
        String currentStatus = versionData['status'] ?? 'pending';
        if (currentStatus != 'pending') {
          throw Exception('Esta versión ya ha sido $currentStatus');
        }

        // Obtener votos actuales
        List<dynamic> currentVotes = versionData['votes'] ?? [];

        // Verificar si el usuario ya votó
        bool userAlreadyVoted =
            currentVotes.any((vote) => vote['userId'] == userId);

        // Actualizar o agregar voto
        if (userAlreadyVoted) {
          currentVotes = currentVotes.map((vote) {
            if (vote['userId'] == userId) {
              return VersionVoteModel(
                userId: userId,
                status: voteStatus,
                timestamp: DateTime.now(),
              ).toMap();
            }
            return vote;
          }).toList();
        } else {
          currentVotes.add(VersionVoteModel(
            userId: userId,
            status: voteStatus,
            timestamp: DateTime.now(),
          ).toMap());
        }

        // Actualizar votos en la versión
        transaction.update(versionRef, {
          'votes': currentVotes,
        });

        // Determinar si la versión debe ser aceptada o rechazada
        SharingPermissionType permissionType =
            SharingPermissionType.values.firstWhere(
          (e) => e.toString() == expenseData['permissionType'],
          orElse: () => SharingPermissionType.creatorOnly,
        );

        bool shouldApplyChanges = false;
        String newStatus = 'pending';

        if (permissionType == SharingPermissionType.creatorOnly) {
          // Si el creador vota, su voto determina el resultado
          if (userId == expenseData['creatorId']) {
            newStatus =
                voteStatus == VoteStatus.accepted ? 'accepted' : 'rejected';
            shouldApplyChanges = (newStatus == 'accepted');
          }
        } else {
          // TODOS los participantes deben votar y aceptar
          List<dynamic> participants = expenseData['participants'] ?? [];
          int totalParticipants = participants.length;
          int votedParticipants = currentVotes.length;

          // Contar solo votos aceptados
          int acceptedVotes = currentVotes
              .where((vote) => vote['status'] == VoteStatus.accepted.toString())
              .length;

          // Si hay algún rechazo, rechazar inmediatamente
          bool hasRejection = currentVotes
              .any((vote) => vote['status'] == VoteStatus.rejected.toString());

          if (hasRejection) {
            newStatus = 'rejected';
          } else if (acceptedVotes == totalParticipants) {
            // Solo aceptar si TODOS han aceptado
            newStatus = 'accepted';
            shouldApplyChanges = true;
          }
        }

        // Actualizar estado si cambió
        if (newStatus != 'pending') {
          transaction.update(versionRef, {'status': newStatus});

          if (shouldApplyChanges) {
            // Aplicar cambios al documento principal
            transaction.update(docRef, {
              ...versionData['data'],
              'currentVersion': version,
              'lastModified': FieldValue.serverTimestamp(),
              'pendingVersion': FieldValue.delete(),
            });

            // Notificar a todos sobre la aplicación de cambios
            await _notifyChangesApplied(
                expenseId, version, versionData['changeTypes'] ?? []);
          } else {
            // Si es rechazada, eliminar la versión pendiente
            transaction.update(docRef, {
              'pendingVersion': FieldValue.delete(),
            });

            // Notificar sobre el rechazo
            await _notifyChangesRejected(
                expenseId, version, versionData['changeTypes'] ?? []);
          }
        }
      });

      print('Respuesta a votación procesada: $expenseId, versión: $version');
    } catch (e) {
      print('Error al procesar respuesta a votación: $e');
      rethrow;
    }
  }

// Notificar que los cambios fueron aplicados
  Future<void> _notifyChangesApplied(
    String expenseId,
    String version,
    List<dynamic> changeTypes,
  ) async {
    try {
      final expenseDoc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();
      final expenseData = expenseDoc.data() as Map<String, dynamic>;

      String changeDescription =
          _getChangeDescription(List<String>.from(changeTypes));
      String title = 'Cambios aplicados';
      String message =
          'Los $changeDescription en "${expenseData['groupName']}" han sido aprobados y aplicados';

      List<dynamic> participantsData = expenseData['participants'] ?? [];

      for (var participantData in participantsData) {
        String userId = participantData['userId'];

        final notificationId = _uuid.v4();
        await _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .set({
          'id': notificationId,
          'title': title,
          'message': message,
          'type': NotificationType.sharedExpense.toString(),
          'sourceId': expenseId,
          'senderId': 'system',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'additionalData': {
            'status': 'applied',
            'expenseName': expenseData['groupName'],
            'version': version,
            'changeTypes': changeTypes,
          }
        });
      }
    } catch (e) {
      print('Error al notificar cambios aplicados: $e');
    }
  }

// Notificar que los cambios fueron rechazados
  Future<void> _notifyChangesRejected(
    String expenseId,
    String version,
    List<dynamic> changeTypes,
  ) async {
    try {
      final expenseDoc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();
      final expenseData = expenseDoc.data() as Map<String, dynamic>;

      String changeDescription =
          _getChangeDescription(List<String>.from(changeTypes));
      String title = 'Cambios rechazados';
      String message =
          'Los $changeDescription en "${expenseData['groupName']}" han sido rechazados';

      List<dynamic> participantsData = expenseData['participants'] ?? [];

      for (var participantData in participantsData) {
        String userId = participantData['userId'];

        final notificationId = _uuid.v4();
        await _firestore
            .collection('usuarios')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .set({
          'id': notificationId,
          'title': title,
          'message': message,
          'type': NotificationType.sharedExpense.toString(),
          'sourceId': expenseId,
          'senderId': 'system',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'additionalData': {
            'status': 'rejected',
            'expenseName': expenseData['groupName'],
            'version': version,
            'changeTypes': changeTypes,
          }
        });
      }
    } catch (e) {
      print('Error al notificar cambios rechazados: $e');
    }
  }

  // Manejar la aprobación de adición de participantes
  Future<void> _handleParticipantAdditionApproval(
    String expenseId,
    Map<String, dynamic> versionData,
    Transaction transaction,
  ) async {
    try {
      // Obtener nuevos participantes de la versión
      List<dynamic> newParticipantsData = versionData['newParticipants'] ?? [];
      List<ExpenseParticipant> newParticipants = newParticipantsData
          .map((data) => ExpenseParticipant.fromMap(data))
          .toList();

      // Actualizar sharedExpensesMap para cada nuevo participante
      for (var participant in newParticipants) {
        final participantRef =
            _firestore.collection('usuarios').doc(participant.userId);
        transaction.update(participantRef, {
          'sharedExpensesMap.$expenseId': {'archivado': false}
        });
      }

      // Notificar a los nuevos participantes
      await _notifyParticipants(expenseId, newParticipants);
    } catch (e) {
      _logger.logError('Error al manejar aprobación de participantes: $e');
      // No rethrow para no interrumpir la transacción principal
    }
  }

  // Notificar sobre la adición de participantes
  Future<void> _notifyParticipantAddition(
    String expenseId,
    String version,
    String requesterId,
    List<ExpenseParticipant> newParticipants,
    SharingPermissionType permissionType,
  ) async {
    try {
      final expenseDoc =
          await _firestore.collection('sharedExpenses').doc(expenseId).get();
      final expenseData = expenseDoc.data() as Map<String, dynamic>;

      // Obtener información del solicitante
      final requesterDoc =
          await _firestore.collection('usuarios').doc(requesterId).get();
      final requesterData = requesterDoc.data() as Map<String, dynamic>;
      final requesterName = requesterData['username'] ?? 'Un usuario';

      // Obtener nombres de nuevos participantes
      List<String> newParticipantNames = [];
      for (var participant in newParticipants) {
        final userDoc = await _firestore
            .collection('usuarios')
            .doc(participant.userId)
            .get();
        final userData = userDoc.data() as Map<String, dynamic>;
        newParticipantNames.add(userData['username'] ?? 'Usuario');
      }

      String title = 'Solicitud de nuevos participantes';
      String message =
          '$requesterName quiere añadir a ${newParticipantNames.join(", ")} al gasto "${expenseData['groupName']}"';

      // Obtener participantes actuales
      List<dynamic> participantsData = expenseData['participants'] ?? [];

      // Enviar notificación a cada participante actual (excepto al solicitante)
      for (var participantData in participantsData) {
        String userId = participantData['userId'];

        if (userId != requesterId) {
          final notificationId = _uuid.v4();
          await _firestore
              .collection('usuarios')
              .doc(userId)
              .collection('notifications')
              .doc(notificationId)
              .set({
            'id': notificationId,
            'title': title,
            'message': message,
            'type': NotificationType.sharedExpense.toString(),
            'sourceId': expenseId,
            'senderId': requesterId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'additionalData': {
              'status': 'pending',
              'expenseName': expenseData['groupName'],
              'version': version,
              'modifierId': requesterId,
              'modifierName': requesterName,
              'permissionType': permissionType.toString(),
              'changeTypes': ['participant_addition'],
              'newParticipants': newParticipantNames,
            }
          });
        }
      }
    } catch (e) {
      print('Error al enviar notificaciones de adición de participantes: $e');
    }
  }
}
