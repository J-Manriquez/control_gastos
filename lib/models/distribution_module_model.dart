import 'package:cloud_firestore/cloud_firestore.dart';

enum DistributionType {
  equalParts,    // Partes iguales
  percentage,    // Porcentajes personalizados
}

// Define el tipo de elemento al que se aplica la distribución
enum DistributionTarget {
  expense,       // Gasto individual
  subgroup,      // Subgrupo de gastos
  total,         // Total del grupo
}

class ParticipantShare {
  final String userId;
  final double amount;      // Monto asignado
  final double percentage;  // Porcentaje asignado (si aplica)

  ParticipantShare({
    required this.userId,
    required this.amount,
    this.percentage = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'percentage': percentage,
    };
  }

  factory ParticipantShare.fromMap(Map<String, dynamic> map) {
    return ParticipantShare(
      userId: map['userId'],
      amount: (map['amount'] as num).toDouble(),
      percentage: (map['percentage'] as num).toDouble(),
    );
  }
}

class DistributionModule {
  final String id;
  final String targetId;              // ID del gasto o subgrupo
  final DistributionTarget targetType;
  final DistributionType type;
  final List<ParticipantShare> shares;
  final double totalAmount;
  final DateTime lastModified;

  DistributionModule({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.type,
    required this.shares,
    required this.totalAmount,
    required this.lastModified,
  });

  // Método copyWith para crear una copia con algunos valores modificados
  DistributionModule copyWith({
    String? id,
    String? targetId,
    DistributionTarget? targetType,
    DistributionType? type,
    List<ParticipantShare>? shares,
    double? totalAmount,
    DateTime? lastModified,
  }) {
    return DistributionModule(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      type: type ?? this.type,
      shares: shares ?? this.shares,
      totalAmount: totalAmount ?? this.totalAmount,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  // Verificar si la distribución es válida
  bool isValid() {
    if (type == DistributionType.percentage) {
      double totalPercentage = shares.fold(
          0, (sum, share) => sum + share.percentage);
      return (totalPercentage - 100.0).abs() < 0.01; // Permitir pequeño margen de error
    }
    
    double totalShares = shares.fold(
        0, (sum, share) => sum + share.amount);
    return (totalShares - totalAmount).abs() < 0.01;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'targetId': targetId,
      'targetType': targetType.toString(),
      'type': type.toString(),
      'shares': shares.map((share) => share.toMap()).toList(),
      'totalAmount': totalAmount,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  factory DistributionModule.fromMap(Map<String, dynamic> map) {
    return DistributionModule(
      id: map['id'],
      targetId: map['targetId'],
      targetType: DistributionTarget.values.firstWhere(
        (e) => e.toString() == map['targetType'],
        orElse: () => DistributionTarget.expense,
      ),
      type: DistributionType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => DistributionType.equalParts,
      ),
      shares: (map['shares'] as List<dynamic>)
          .map((share) => ParticipantShare.fromMap(share))
          .toList(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      lastModified: DateTime.parse(map['lastModified']),
    );
  }

  // Método para crear una distribución en partes iguales
  static DistributionModule createEqualDistribution({
    required String targetId,
    required DistributionTarget targetType,
    required List<String> participantIds,
    required double totalAmount,
  }) {
    final double shareAmount = totalAmount / participantIds.length;
    final shares = participantIds.map((userId) {
      return ParticipantShare(
        userId: userId,
        amount: shareAmount,
        percentage: 100.0 / participantIds.length,
      );
    }).toList();

    return DistributionModule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetId: targetId,
      targetType: targetType,
      type: DistributionType.equalParts,
      shares: shares,
      totalAmount: totalAmount,
      lastModified: DateTime.now(),
    );
  }
}