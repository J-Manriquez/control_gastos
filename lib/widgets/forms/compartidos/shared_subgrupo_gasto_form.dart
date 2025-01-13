import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_gasto_form.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/widgets/distribution/distribution_type_selector.dart';
import 'package:control_gastos/widgets/distribution/participant_distribution_list.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class SharedSubgrupoGastoForm extends StatefulWidget {
  final String subgrupoNombre;
  final Function(String) onNombreChanged;
  final List<Gasto> gastos;
  final List<String> participantIds;
  final Function(List<Gasto>, DistributionModule?) onGastosChanged;
  final VoidCallback? onEliminar;
  final DistributionModule? initialDistribution;
  final SharedExpenseGroup group;

  const SharedSubgrupoGastoForm({
    super.key,
    required this.subgrupoNombre,
    required this.onNombreChanged,
    required this.gastos,
    required this.participantIds,
    required this.onGastosChanged,
    this.onEliminar,
    this.initialDistribution,
    required this.group,
  });

  @override
  _SharedSubgrupoGastoFormState createState() => _SharedSubgrupoGastoFormState();
}

class _SharedSubgrupoGastoFormState extends State<SharedSubgrupoGastoForm> {
  late final TextEditingController _nombreSubgrupoController;
  late Map<String, Gasto> _gastosMap;
  bool _showDistribution = false;
  DistributionType _distributionType = DistributionType.equalParts;
  List<ParticipantShare> _shares = [];
  double _subtotal = 0.0;

  @override
  void initState() {
    super.initState();
    _nombreSubgrupoController = TextEditingController(text: widget.subgrupoNombre);
    _nombreSubgrupoController.addListener(_notifyNombreChanged);
    _initializeGastosMap();

    if (widget.initialDistribution != null) {
      _showDistribution = true;
      _distributionType = widget.initialDistribution!.type;
      _shares = List.from(widget.initialDistribution!.shares);
    }

    _calculateSubtotal();
  }

  void _initializeGastosMap() {
    _gastosMap = {
      for (var gasto in widget.gastos)
        gasto.id ?? DateTime.now().millisecondsSinceEpoch.toString(): gasto,
    };
  }

  void _calculateSubtotal() {
    _subtotal = _gastosMap.values.fold(
      0.0,
      (sum, gasto) => sum + gasto.valor,
    );

    if (_showDistribution) {
      _updateDistributionAmounts();
    }
  }

  void _notifyNombreChanged() {
    widget.onNombreChanged(_nombreSubgrupoController.text);
  }

  void _updateDistributionAmounts() {
    if (_distributionType == DistributionType.equalParts) {
      _initializeEqualDistribution();
    } else {
      _shares = _shares.map((share) {
        double amount = (_subtotal * share.percentage) / 100;
        return ParticipantShare(
          userId: share.userId,
          amount: amount,
          percentage: share.percentage,
        );
      }).toList();
    }
  }

  void _initializeEqualDistribution() {
    double shareAmount = _subtotal / widget.participantIds.length;
    double sharePercentage = 100.0 / widget.participantIds.length;

    _shares = widget.participantIds.map((userId) {
      return ParticipantShare(
        userId: userId,
        amount: shareAmount,
        percentage: sharePercentage,
      );
    }).toList();
  }

  void _agregarGasto() {
    final newGasto = Gasto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: '',
      valor: 0,
      fecha: DateTime.now(),
      esAFavor: true,
    );

    setState(() {
      _gastosMap[newGasto.id!] = newGasto;
      _notifyGastosChanged();
    });
  }

  void _handleDeleteGasto(String? gastoId) {
    if (gastoId == null) return;
    
    setState(() {
      _gastosMap.remove(gastoId);
      _notifyGastosChanged();
    });
  }

  void _handleGastoChanged(String? gastoId, Gasto updatedGasto) {
    if (gastoId == null) return;

    setState(() {
      _gastosMap[gastoId] = updatedGasto;
      _calculateSubtotal();
      _notifyGastosChanged();
    });
  }

  void _notifyGastosChanged() {
    DistributionModule? distribution;
    if (_showDistribution) {
      distribution = DistributionModule(
        id: widget.initialDistribution?.id ?? 
            DateTime.now().millisecondsSinceEpoch.toString(),
        targetId: _nombreSubgrupoController.text,
        targetType: DistributionTarget.subgroup,
        type: _distributionType,
        shares: _shares,
        totalAmount: _subtotal,
        lastModified: DateTime.now(),
      );
    }

    widget.onGastosChanged(_gastosMap.values.toList(), distribution);
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: colorProvider.colors.backgroundColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nombreSubgrupoController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del subgrupo',
                      labelStyle: TextStyle(
                        color: colorProvider.colors.primaryTextColor,
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: colorProvider.colors.appBarColor,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: _agregarGasto,
                ),
                if (widget.onEliminar != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: colorProvider.colors.negativeColor,
                    ),
                    onPressed: widget.onEliminar,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._gastosMap.entries.map((entry) {
              return SharedGastoForm(
                key: ValueKey(entry.key),
                gasto: entry.value,
                participantIds: widget.group.participants.map((p) => p.userId).toList(),
                onCancel: () => _handleDeleteGasto(entry.key),
                onGastoChanged: (updatedGasto, _) => 
                    _handleGastoChanged(entry.key, updatedGasto), group: widget.group,
              );
            }).toList(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distribuir subtotal',
                  style: TextStyle(
                    color: colorProvider.colors.primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: _showDistribution,
                  onChanged: (value) {
                    setState(() {
                      _showDistribution = value;
                      if (value && _shares.isEmpty) {
                        _initializeEqualDistribution();
                      }
                      _notifyGastosChanged();
                    });
                  },
                  activeColor: colorProvider.colors.appBarColor,
                ),
              ],
            ),
            if (_showDistribution) ...[
              const SizedBox(height: 16),
              DistributionTypeSelector(
                selectedType: _distributionType,
                onTypeChanged: (type) {
                  setState(() {
                    _distributionType = type;
                    if (type == DistributionType.equalParts) {
                      _initializeEqualDistribution();
                    }
                    _notifyGastosChanged();
                  });
                },
              ),
              const SizedBox(height: 16),
              ParticipantDistributionList(
                participantIds: widget.group.participants.map((p) => p.userId).toList(),
                totalAmount: _subtotal,
                distributionType: _distributionType,
                shares: _shares,
                onSharesChanged: (updatedShares) {
                  setState(() {
                    _shares = updatedShares;
                    _notifyGastosChanged();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreSubgrupoController.removeListener(_notifyNombreChanged);
    _nombreSubgrupoController.dispose();
    super.dispose();
  }
}