import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/widgets/distribution/distribution_type_selector.dart';
import 'package:control_gastos/widgets/distribution/participant_distribution_list.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class SharedGastoForm extends StatefulWidget {
  final Gasto? gasto;
  final List<String> participantIds;
  final VoidCallback? onCancel;
  final Function(Gasto, DistributionModule?) onGastoChanged;
  final DistributionModule? initialDistribution;

  const SharedGastoForm({
    super.key,
    this.gasto,
    required this.participantIds,
    this.onCancel,
    required this.onGastoChanged,
    this.initialDistribution,
  });

  @override
  _SharedGastoFormState createState() => _SharedGastoFormState();
}

class _SharedGastoFormState extends State<SharedGastoForm> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  bool _esAFavor = true;
  DateTime? _fecha;
  double _valorNumerico = 0.0;
  final NumberFormat _numberFormat = NumberFormat('#,###', 'fr_FR');
  String? _gastoId;
  bool _showDistribution = false;
  DistributionType _distributionType = DistributionType.equalParts;
  List<ParticipantShare> _shares = [];

  @override
  void initState() {
    super.initState();

    if (widget.gasto != null) {
      _gastoId = widget.gasto!.id;
      _nombreController.text = widget.gasto!.nombre;
      _valorNumerico = widget.gasto!.valor.abs();
      _valorController.text = _numberFormat.format(_valorNumerico);
      _fecha = widget.gasto!.fecha;
      _esAFavor = widget.gasto!.esAFavor;
    } else {
      _gastoId = DateTime.now().millisecondsSinceEpoch.toString();
      _fecha = DateTime.now();
    }

    if (widget.initialDistribution != null) {
      _showDistribution = true;
      _distributionType = widget.initialDistribution!.type;
      _shares = List.from(widget.initialDistribution!.shares);
    } else {
      _initializeEqualDistribution();
    }

    _nombreController.addListener(_notifyGastoChanged);
    _valorController.addListener(_notifyGastoChanged);
  }

  void _initializeEqualDistribution() {
    double shareAmount = _valorNumerico / widget.participantIds.length;
    double sharePercentage = 100.0 / widget.participantIds.length;

    _shares = widget.participantIds.map((userId) {
      return ParticipantShare(
        userId: userId,
        amount: shareAmount,
        percentage: sharePercentage,
      );
    }).toList();
  }

  void _notifyGastoChanged() {
    if (!mounted) return;

    final gasto = Gasto(
      id: _gastoId,
      nombre: _nombreController.text,
      valor: getValorConSigno(),
      fecha: _fecha ?? DateTime.now(),
      esAFavor: _esAFavor,
    );

    DistributionModule? distribution;
    if (_showDistribution) {
      distribution = DistributionModule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetId: gasto.id!,
        targetType: DistributionTarget.expense,
        type: _distributionType,
        shares: _shares,
        totalAmount: _valorNumerico,
        lastModified: DateTime.now(),
      );
    }

    widget.onGastoChanged(gasto, distribution);
  }

  double getValorConSigno() {
    return _esAFavor ? _valorNumerico : -_valorNumerico;
  }

  void _onValorChanged(String value) {
    try {
      String numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');

      if (numericValue.isNotEmpty) {
        _valorNumerico = double.parse(numericValue);
        String formattedValue = _numberFormat.format(_valorNumerico);

        if (_valorController.text != formattedValue) {
          _valorController.value = TextEditingValue(
            text: formattedValue,
            selection: TextSelection.collapsed(offset: formattedValue.length),
          );
        }

        if (_showDistribution) {
          _updateDistributionAmounts();
        }
      } else {
        _valorNumerico = 0.0;
      }

      _notifyGastoChanged();
    } catch (e) {
      print('Error en _onValorChanged: $e');
    }
  }

  void _updateDistributionAmounts() {
    if (_distributionType == DistributionType.equalParts) {
      _initializeEqualDistribution();
    } else {
      _shares = _shares.map((share) {
        double amount = (_valorNumerico * share.percentage) / 100;
        return ParticipantShare(
          userId: share.userId,
          amount: amount,
          percentage: share.percentage,
        );
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: colorProvider.colors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
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
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Descripción del Monto',
                      labelStyle: TextStyle(
                        color: colorProvider.colors.primaryTextColor,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorProvider.colors.appBarColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
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
                    Icons.calendar_today,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: () => _selectDate(context),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(
                      Icons.delete,
                      color: colorProvider.colors.negativeColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: _esAFavor
                        ? colorProvider.colors.positiveColor
                        : colorProvider.colors.primaryTextColor.withOpacity(0.3),
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _esAFavor = true;
                      _notifyGastoChanged();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle,
                    color: !_esAFavor
                        ? colorProvider.colors.negativeColor
                        : colorProvider.colors.primaryTextColor.withOpacity(0.3),
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _esAFavor = false;
                      _notifyGastoChanged();
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _valorController,
                    keyboardType: TextInputType.number,
                    onChanged: _onValorChanged,
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      labelStyle: TextStyle(
                        color: colorProvider.colors.primaryTextColor,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorProvider.colors.appBarColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distribuir monto',
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
                      _notifyGastoChanged();
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
                    _notifyGastoChanged();
                  });
                },
              ),
              const SizedBox(height: 16),
              ParticipantDistributionList(
                participantIds: widget.participantIds,
                totalAmount: _valorNumerico,
                distributionType: _distributionType,
                shares: _shares,
                onSharesChanged: (updatedShares) {
                  setState(() {
                    _shares = updatedShares;
                    _notifyGastoChanged();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    DateTime initialDate = _fecha ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorProvider.colors.appBarColor,
              onPrimary: colorProvider.colors.secondaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _fecha = picked;
        _notifyGastoChanged();
      });
    }
  }

  @override
  void dispose() {
    _nombreController.removeListener(_notifyGastoChanged);
    _valorController.removeListener(_notifyGastoChanged);
    _nombreController.dispose();
    _valorController.dispose();
    super.dispose();
  }
}