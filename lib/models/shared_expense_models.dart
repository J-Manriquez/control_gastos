import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';

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

class DistributionModule {
  final String id;
  final String targetId; // ID del gasto o subgrupo al que se aplica
  final String targetType; // 'expense', 'subgroup', 'total'
  final Map<String, double> distributions; // userId -> percentage/amount
  final bool isEqualParts;

  DistributionModule({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.distributions,
    this.isEqualParts = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetId': targetId,
      'targetType': targetType,
      'distributions': distributions,
      'isEqualParts': isEqualParts,
    };
  }

  factory DistributionModule.fromMap(Map<String, dynamic> map) {
    return DistributionModule(
      id: map['id'],
      targetId: map['targetId'],
      targetType: map['targetType'],
      distributions: Map<String, double>.from(map['distributions']),
      isEqualParts: map['isEqualParts'] ?? true,
    );
  }
}

class SharedExpenseGroup extends GroupModel {
  final String creatorId;
  final List<ExpenseParticipant> participants;
  final SharingPermissionType permissionType;
  final List<DistributionModule> distributionModules;
  final String version;
  final DateTime lastModified;

  SharedExpenseGroup({
    required String id,
    required String nombre,
    required double total,
    required List<Gasto> expenses,
    required List<SubgroupModel> subgroups,
    required DateTime creationDate,
    required this.creatorId,
    required this.participants,
    required this.permissionType,
    required this.distributionModules,
    required this.version,
    required this.lastModified,
  }) : super(
          id: id,
          nombre: nombre,
          total: total,
          expenses: expenses,
          subgroups: subgroups,
          creationDate: creationDate,
        );

  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();
    return {
      ...baseMap,
      'id': id,
      'creatorId': creatorId,
      'participants': participants.map((p) => p.toMap()).toList(),
      'permissionType': permissionType.toString(),
      'distributionModules': distributionModules.map((d) => d.toMap()).toList(),
      'version': version,
      'lastModified': lastModified.toIso8601String(),
      'isShared': true,
    };
  }

  factory SharedExpenseGroup.fromMap(Map<String, dynamic> map) {
  try {
    CustomLogger().logInfo('Iniciando conversión de SharedExpenseGroup: ${map['id']}');
    
    // Función auxiliar para convertir timestamps
    DateTime convertToDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now(); // valor por defecto
    }

    final group = SharedExpenseGroup(
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
              ?.map((p) => ExpenseParticipant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      permissionType: SharingPermissionType.values.firstWhere(
        (e) => e.toString() == map['permissionType'],
        orElse: () => SharingPermissionType.creatorOnly,
      ),
      distributionModules: (map['distributionModules'] as List<dynamic>?)
              ?.map((d) => DistributionModule.fromMap(d as Map<String, dynamic>))
              .toList() ??
          [],
      version: map['version'] ?? '1.0',
      lastModified: convertToDateTime(map['lastModified']),
    );

    CustomLogger().logInfo('SharedExpenseGroup convertido exitosamente: ${map['id']}');
    return group;
  } catch (e, stackTrace) {
    CustomLogger().logError('Error en SharedExpenseGroup.fromMap: $e\nStack: $stackTrace');
    rethrow;
  }
}
}
