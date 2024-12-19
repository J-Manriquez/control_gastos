import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class DistributionService {
  final CustomLogger _logger = CustomLogger();

  // Calcular distribución en partes iguales
  List<ParticipantShare> calculateEqualShares(
    List<String> participantIds,
    double totalAmount,
  ) {
    try {
      double shareAmount = totalAmount / participantIds.length;
      double sharePercentage = 100.0 / participantIds.length;

      return participantIds.map((userId) {
        return ParticipantShare(
          userId: userId,
          amount: shareAmount,
          percentage: sharePercentage,
        );
      }).toList();
    } catch (e) {
      _logger.logError('Error calculando partes iguales: $e');
      rethrow;
    }
  }

  // Calcular montos basados en porcentajes
  List<ParticipantShare> calculatePercentageShares(
    Map<String, double> percentages,
    double totalAmount,
  ) {
    try {
      return percentages.entries.map((entry) {
        return ParticipantShare(
          userId: entry.key,
          amount: (totalAmount * entry.value) / 100,
          percentage: entry.value,
        );
      }).toList();
    } catch (e) {
      _logger.logError('Error calculando shares por porcentaje: $e');
      rethrow;
    }
  }

  // Validar distribución
  bool validateDistribution(DistributionModule distribution) {
    try {
      if (distribution.type == DistributionType.percentage) {
        double totalPercentage = distribution.shares.fold(
            0, (sum, share) => sum + share.percentage);
        return (totalPercentage - 100.0).abs() < 0.01;
      }

      double totalShares = distribution.shares.fold(
          0, (sum, share) => sum + share.amount);
      return (totalShares - distribution.totalAmount).abs() < 0.01;
    } catch (e) {
      _logger.logError('Error validando distribución: $e');
      return false;
    }
  }

  // Recalcular distribución cuando cambia el monto total
  DistributionModule recalculateDistribution(
    DistributionModule distribution,
    double newTotal,
  ) {
    try {
      if (distribution.type == DistributionType.equalParts) {
        return DistributionModule.createEqualDistribution(
          targetId: distribution.targetId,
          targetType: distribution.targetType,
          participantIds: distribution.shares.map((s) => s.userId).toList(),
          totalAmount: newTotal,
        );
      }

      // Para distribución por porcentajes, mantener los mismos porcentajes
      List<ParticipantShare> newShares = distribution.shares.map((share) {
        return ParticipantShare(
          userId: share.userId,
          amount: (newTotal * share.percentage) / 100,
          percentage: share.percentage,
        );
      }).toList();

      return DistributionModule(
        id: distribution.id,
        targetId: distribution.targetId,
        targetType: distribution.targetType,
        type: distribution.type,
        shares: newShares,
        totalAmount: newTotal,
        lastModified: DateTime.now(),
      );
    } catch (e) {
      _logger.logError('Error recalculando distribución: $e');
      rethrow;
    }
  }
}