// shared_expense_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:control_gastos/models/distribution_module_model.dart';

enum SharingPermissionType { creatorOnly, allParticipants }

enum ParticipantStatus { pending, accepted, rejected }

class ExpenseParticipant {
  final String userId;
  ParticipantStatus status;
  double? customPercentage;

  ExpenseParticipant({
    required this.userId,
    this.status = ParticipantStatus.pending,
    this.customPercentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'status': status.toString(),
      'customPercentage': customPercentage,
    };
  }

  factory ExpenseParticipant.fromMap(Map<String, dynamic> map) {
    return ExpenseParticipant(
      userId: map['userId'],
      status: ParticipantStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => ParticipantStatus.pending,
      ),
      customPercentage: map['customPercentage'],
    );
  }
}

class SharedExpenseGroup extends GroupModel {
  final String creatorId;
  final List<ExpenseParticipant> participants;
  final SharingPermissionType permissionType;
  final String version;
  final DateTime lastModified;
  final Map<String, DistributionModule> expenseDistributions;
  final Map<String, DistributionModule> subgroupDistributions;
  final DistributionModule? totalDistribution;
  final bool archivado;
  final Map<String, Map<String, dynamic>>? imagenes;

  SharedExpenseGroup({
    required super.id,
    required super.nombre,
    required super.total,
    required super.expenses,
    required super.subgroups,
    required super.creationDate,
    required this.creatorId,
    required this.participants,
    required this.permissionType,
    required this.version,
    required this.lastModified,
    this.expenseDistributions = const {},
    this.subgroupDistributions = const {},
    this.totalDistribution,
    this.archivado = false,
    this.imagenes,
  });

  // Método para obtener la distribución de un gasto específico
  DistributionModule? getExpenseDistribution(String expenseId) {
    return expenseDistributions[expenseId];
  }

  // Método para obtener la distribución de un subgrupo específico
  DistributionModule? getSubgroupDistribution(String subgroupId) {
    return subgroupDistributions[subgroupId];
  }

  // Método para calcular el total asignado por usuario
  Map<String, double> calculateTotalsByUser() {
    Map<String, double> totals = {};

    // Inicializar totales para todos los participantes
    for (var participant in participants) {
      totals[participant.userId] = 0.0;
    }

    // Sumar distribuciones de gastos individuales
    expenseDistributions.forEach((_, distribution) {
      for (var share in distribution.shares) {
        totals[share.userId] = (totals[share.userId] ?? 0) + share.amount;
      }
    });

    // Sumar distribuciones de subgrupos
    subgroupDistributions.forEach((_, distribution) {
      for (var share in distribution.shares) {
        totals[share.userId] = (totals[share.userId] ?? 0) + share.amount;
      }
    });

    // Sumar distribución total si existe
    if (totalDistribution != null) {
      for (var share in totalDistribution!.shares) {
        totals[share.userId] = (totals[share.userId] ?? 0) + share.amount;
      }
    }

    return totals;
  }

  // Método para verificar si todos los montos están distribuidos
  bool isFullyDistributed() {
    double totalDistributed = 0.0;

    // Sumar todas las distribuciones
    expenseDistributions.forEach((_, distribution) {
      totalDistributed += distribution.totalAmount;
    });

    subgroupDistributions.forEach((_, distribution) {
      totalDistributed += distribution.totalAmount;
    });

    if (totalDistribution != null) {
      totalDistributed += totalDistribution!.totalAmount;
    }

    // Comparar con el total del grupo
    return (totalDistributed - total).abs() < 0.01;
  }

  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();

    // Filtrar distribuciones nulas o con claves nulas
    Map<String, dynamic> validExpenseDistributions = {};
    expenseDistributions.forEach((key, value) {
      if (key != null && key.isNotEmpty && value != null) {
        validExpenseDistributions[key] = value.toMap();
      }
    });

    Map<String, dynamic> validSubgroupDistributions = {};
    subgroupDistributions.forEach((key, value) {
      if (key != null && key.isNotEmpty && value != null) {
        validSubgroupDistributions[key] = value.toMap();
      }
    });

    return {
      ...baseMap,
      'creatorId': creatorId ?? '',
      'participants': participants.map((p) => p.toMap()).toList(),
      'permissionType': permissionType.toString(),
      'version': version ?? '1.0',
      'lastModified': lastModified.toIso8601String(),
      'expenseDistributions': validExpenseDistributions,
      'subgroupDistributions': validSubgroupDistributions,
      'totalDistribution': totalDistribution?.toMap(),
      'isShared': true,
      'archivado': archivado, // Include archivado in toMap
      'imagenes': imagenes,
    };
  }

  factory SharedExpenseGroup.fromMap(Map<String, dynamic> map) {
    try {
      CustomLogger()
          .logInfo('Iniciando conversión de SharedExpenseGroup: ${map['id']}');

      // Convertir las distribuciones
      Map<String, DistributionModule> expenseDistributions = {};
      if (map['expenseDistributions'] != null) {
        (map['expenseDistributions'] as Map<String, dynamic>)
            .forEach((key, value) {
          expenseDistributions[key] = DistributionModule.fromMap(value);
        });
      }

      Map<String, DistributionModule> subgroupDistributions = {};
      if (map['subgroupDistributions'] != null) {
        (map['subgroupDistributions'] as Map<String, dynamic>)
            .forEach((key, value) {
          subgroupDistributions[key] = DistributionModule.fromMap(value);
        });
      }

      DistributionModule? totalDistribution;
      if (map['totalDistribution'] != null) {
        totalDistribution =
            DistributionModule.fromMap(map['totalDistribution']);
      }

      // Función auxiliar para convertir timestamps
      DateTime convertToDateTime(dynamic value) {
        if (value is Timestamp) {
          return value.toDate();
        } else if (value is String) {
          return DateTime.parse(value);
        }
        return DateTime.now();
      }

      return SharedExpenseGroup(
        id: map['id'] ?? '',
        nombre: map['groupName'] ?? '',
        total: (map['total'] as num?)?.toDouble() ?? 0.0,
        expenses: (map['expenses'] as List<dynamic>?)
                ?.map((e) => Gasto.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        subgroups: (map['subgroups'] as List<dynamic>?)
                ?.map((s) => SubgroupModel.fromMap(s as Map<String, dynamic>))
                .toList() ??
            [],
        creationDate: convertToDateTime(map['creationDate']),
        creatorId: map['creatorId'] ?? '',
        participants: (map['participants'] as List<dynamic>?)
                ?.map((p) =>
                    ExpenseParticipant.fromMap(p as Map<String, dynamic>))
                .toList() ??
            [],
        permissionType: SharingPermissionType.values.firstWhere(
          (e) => e.toString() == map['permissionType'],
          orElse: () => SharingPermissionType.creatorOnly,
        ),
        version: map['version'] ?? '1.0',
        lastModified: convertToDateTime(map['lastModified']),
        expenseDistributions: expenseDistributions,
        subgroupDistributions: subgroupDistributions,
        totalDistribution: totalDistribution,
        archivado:
            map['archivado'] ?? false, // Leer el campo archivado del mapa
        imagenes: map['imagenes'] != null 
            ? Map<String, Map<String, dynamic>>.from(map['imagenes']) 
            : null,
      );
    } catch (e, stackTrace) {
      CustomLogger().logError(
          'Error en SharedExpenseGroup.fromMap: $e\nStack: $stackTrace');
      rethrow;
    }
  }

  SharedExpenseGroup copyWith({
    String? id,
    String? nombre,
    double? total,
    List<Gasto>? expenses,
    List<SubgroupModel>? subgroups,
    DateTime? creationDate,
    String? creatorId,
    List<ExpenseParticipant>? participants,
    SharingPermissionType? permissionType,
    String? version,
    DateTime? lastModified,
    Map<String, DistributionModule>? expenseDistributions,
    Map<String, DistributionModule>? subgroupDistributions,
    DistributionModule? totalDistribution,
    bool? archivado, // Add archivado to copyWith
  }) {
    return SharedExpenseGroup(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      total: total ?? this.total,
      expenses: expenses ?? this.expenses,
      subgroups: subgroups ?? this.subgroups,
      creationDate: creationDate ?? this.creationDate,
      creatorId: creatorId ?? this.creatorId,
      participants: participants ?? this.participants,
      permissionType: permissionType ?? this.permissionType,
      version: version ?? this.version,
      lastModified: lastModified ?? this.lastModified,
      expenseDistributions: expenseDistributions ?? this.expenseDistributions,
      subgroupDistributions:
          subgroupDistributions ?? this.subgroupDistributions,
      totalDistribution: totalDistribution ?? this.totalDistribution,
      archivado:
          archivado ?? this.archivado, // Use the provided or current value
    );
  }
}
