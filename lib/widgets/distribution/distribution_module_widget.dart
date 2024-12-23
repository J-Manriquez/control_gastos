import 'dart:async';

import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/firebase_interceptor_service.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/services/distribution_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DistributionModuleWidget extends StatefulWidget {
  final String targetId;
  final DistributionTarget targetType;
  final double totalAmount;
  final List<String> participantIds;
  final DistributionModule? initialDistribution;
  final Function(DistributionModule) onDistributionChanged;

  const DistributionModuleWidget({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.totalAmount,
    required this.participantIds,
    this.initialDistribution,
    required this.onDistributionChanged,
  });

  @override
  _DistributionModuleWidgetState createState() =>
      _DistributionModuleWidgetState();
}

class _DistributionModuleWidgetState extends State<DistributionModuleWidget> {
  late DistributionType _distributionType;
  late List<ParticipantShare> _shares;
  final DistributionService _distributionService = DistributionService();
  final _currencyFormat =
      NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);

  Map<String, TextEditingController> _percentageControllers = {};
  Timer? _debounceTimer;
  @override
  void initState() {
    super.initState();
    _initializeDistribution();
  }

  void _initializeDistribution() {
    if (widget.initialDistribution != null) {
      _distributionType = widget.initialDistribution!.type;
      _shares = List.from(widget.initialDistribution!.shares);
    } else {
      _distributionType = DistributionType.equalParts;
      _shares = _distributionService.calculateEqualShares(
        widget.participantIds,
        widget.totalAmount,
      );
    }

    // Inicializar controladores para porcentajes
    _initializeControllers();
  }

  void _initializeControllers() {
    _percentageControllers.clear();
    for (var share in _shares) {
      _percentageControllers[share.userId] = TextEditingController(
        text: share.percentage.toStringAsFixed(2),
      );
    }
  }

  void _updateDistribution() {
    final distribution = DistributionModule(
      id: widget.initialDistribution?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      targetId: widget.targetId,
      targetType: widget.targetType,
      type: _distributionType,
      shares: _shares,
      totalAmount: widget.totalAmount,
      lastModified: DateTime.now(),
    );

    if (_distributionService.validateDistribution(distribution)) {
      widget.onDistributionChanged(distribution);
    }
  }

  void _handleTypeChange(DistributionType? newType) {
    if (newType != null && newType != _distributionType) {
      setState(() {
        _distributionType = newType;
        if (newType == DistributionType.equalParts) {
          _shares = _distributionService.calculateEqualShares(
            widget.participantIds,
            widget.totalAmount,
          );
        }
        _initializeControllers();
        _updateDistribution();
      });
    }
  }

  void _handlePercentageChange(String userId, String value) {
    try {
      final double percentage = double.parse(value);
      final double amount = (widget.totalAmount * percentage) / 100;

      setState(() {
        final index = _shares.indexWhere((share) => share.userId == userId);
        if (index != -1) {
          _shares[index] = ParticipantShare(
            userId: userId,
            amount: amount,
            percentage: percentage,
          );
        }
        _updateDistribution();
      });

      // Guardar automáticamente después de un delay
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
        _saveDistribution();
      });
    } catch (e) {
      // Manejar error de parsing
    }
  }

  // Añadir esta función para validar la distribución actual
  bool _validateDistribution() {
    if (_distributionType == DistributionType.percentage) {
      final totalPercentage =
          _shares.fold(0.0, (sum, share) => sum + share.percentage);
      return (totalPercentage - 100.0).abs() < 0.01;
    }

    final totalAssigned = _shares.fold(0.0, (sum, share) => sum + share.amount);
    return (totalAssigned - widget.totalAmount).abs() < 0.01;
  }

  void _resetToEqualParts() {
    setState(() {
      _distributionType = DistributionType.equalParts;

      // Asegurar que el creador esté incluido
      List<String> allParticipants = widget.participantIds;

      double shareAmount = widget.totalAmount / allParticipants.length;
      double sharePercentage = 100.0 / allParticipants.length;

      _shares = allParticipants.map((userId) {
        return ParticipantShare(
          userId: userId,
          amount: shareAmount,
          percentage: sharePercentage,
        );
      }).toList();

      // Reiniciar controladores de porcentaje
      _initializeControllers();

      // Notificar cambio
      _updateDistribution();
    });
  }

  void _initializeEqualDistribution() {
    // Asegurar que el creador esté incluido
    List<String> allParticipants = widget.participantIds;

    double shareAmount = widget.totalAmount / allParticipants.length;
    double sharePercentage = 100.0 / allParticipants.length;

    _shares = allParticipants.map((userId) {
      return ParticipantShare(
        userId: userId,
        amount: shareAmount,
        percentage: sharePercentage,
      );
    }).toList();
  }

  void _recalculateAmounts() {
    setState(() {
      // Recalcular montos basados en porcentajes actuales
      _shares = _shares.map((share) {
        // Calcular nuevo monto basado en el porcentaje
        final double amount = (widget.totalAmount * share.percentage) / 100;

        return ParticipantShare(
          userId: share.userId,
          amount: amount,
          percentage: share.percentage,
        );
      }).toList();

      // Actualizar controladores si es necesario
      if (_distributionType == DistributionType.percentage) {
        for (var share in _shares) {
          _percentageControllers[share.userId]?.text =
              share.percentage.toStringAsFixed(2);
        }
      }

      // Notificar cambio
      _updateDistribution();
    });
  }

  Future<void> _saveDistribution() async {
    try {
      // Validar la distribución antes de guardar
      if (!_validateDistribution()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La distribución no es válida. Verifica los montos.'),
          ),
        );
        return;
      }

      // Crear objeto de distribución
      final distribution = DistributionModule(
        id: widget.initialDistribution?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        targetId: widget.targetId,
        targetType: widget.targetType,
        type: _distributionType,
        shares: _shares,
        totalAmount: widget.totalAmount,
        lastModified: DateTime.now(),
      );

      // Guardar usando el interceptor de Firebase
      await FirebaseInterceptor().handleDistributionOperation(() async {
        await FirestoreService()
            .sharedExpenseService
            .updateDistributionModule(widget.targetId, distribution);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Distribución guardada exitosamente')),
          );
          widget.onDistributionChanged(distribution);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar distribución: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Card(
      color: colorProvider.colors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución del monto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildTypeSelector(colorProvider),
            const SizedBox(height: 16),
            _buildDistributionList(colorProvider),
            const SizedBox(height: 8),
            _buildTotal(colorProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ColorProvider colorProvider) {
    return SegmentedButton<DistributionType>(
      segments: [
        ButtonSegment<DistributionType>(
          value: DistributionType.equalParts,
          label: Text(
            'Partes Iguales',
            style: TextStyle(
              color: _distributionType == DistributionType.equalParts
                  ? colorProvider.colors.secondaryTextColor
                  : colorProvider.colors.primaryTextColor,
            ),
          ),
        ),
        ButtonSegment<DistributionType>(
          value: DistributionType.percentage,
          label: Text(
            'Porcentajes',
            style: TextStyle(
              color: _distributionType == DistributionType.percentage
                  ? colorProvider.colors.secondaryTextColor
                  : colorProvider.colors.primaryTextColor,
            ),
          ),
        ),
      ],
      selected: {_distributionType},
      onSelectionChanged: (Set<DistributionType> newSelection) {
        _handleTypeChange(newSelection.first);
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return colorProvider.colors.appBarColor;
            }
            return colorProvider.colors.backgroundColor;
          },
        ),
      ),
    );
  }

  Widget _buildDistributionList(ColorProvider colorProvider) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _shares.length,
      itemBuilder: (context, index) {
        final share = _shares[index];
        return _buildParticipantRow(share, colorProvider);
      },
    );
  }

  Widget _buildParticipantRow(
      ParticipantShare share, ColorProvider colorProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: FutureBuilder(
              future: _getUserName(share.userId),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? 'Usuario',
                  style:
                      TextStyle(color: colorProvider.colors.primaryTextColor),
                );
              },
            ),
          ),
          Expanded(
            flex: _distributionType == DistributionType.percentage ? 1 : 2,
            child: _distributionType == DistributionType.percentage
                ? TextField(
                    controller: _percentageControllers[share.userId],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffix: Text(
                        '%',
                        style: TextStyle(
                            color: colorProvider.colors.primaryTextColor),
                      ),
                    ),
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                    onChanged: (value) =>
                        _handlePercentageChange(share.userId, value),
                  )
                : Text(
                    _currencyFormat.format(share.amount),
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                    textAlign: TextAlign.end,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotal(ColorProvider colorProvider) {
    final totalAssigned = _shares.fold<double>(
      0,
      (sum, share) => sum + share.amount,
    );

    final isValid = (totalAssigned - widget.totalAmount).abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isValid
            ? colorProvider.colors.positiveColor.withOpacity(0.1)
            : colorProvider.colors.negativeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total asignado:',
            style: TextStyle(
              color: colorProvider.colors.primaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _currencyFormat.format(totalAssigned),
            style: TextStyle(
              color: isValid
                  ? colorProvider.colors.positiveColor
                  : colorProvider.colors.negativeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getUserName(String userId) async {
    // TODO: Implementar obtención del nombre de usuario
    // Por ahora retornamos el ID como placeholder
    return 'Usuario $userId';
  }

  @override
  void dispose() {
    for (var controller in _percentageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
