import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ParticipantDistributionList extends StatefulWidget {
  final List<String> participantIds;
  final double totalAmount;
  final DistributionType distributionType;
  final List<ParticipantShare> shares;
  final Function(List<ParticipantShare>) onSharesChanged;

  const ParticipantDistributionList({
    super.key,
    required this.participantIds,
    required this.totalAmount,
    required this.distributionType,
    required this.shares,
    required this.onSharesChanged,
  });

  @override
  State<ParticipantDistributionList> createState() =>
      _ParticipantDistributionListState();
}

class _ParticipantDistributionListState
    extends State<ParticipantDistributionList> {
  final Map<String, TextEditingController> _controllers = {};
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(ParticipantDistributionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.distributionType != oldWidget.distributionType ||
        widget.totalAmount != oldWidget.totalAmount) {
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    // Limpiar controladores existentes
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    // Inicializar nuevos controladores
    for (var share in widget.shares) {
      String value = widget.distributionType == DistributionType.percentage
          ? share.percentage.toStringAsFixed(2)
          : _currencyFormat.format(share.amount);
      _controllers[share.userId] = TextEditingController(text: value);
    }
  }

  void _handleValueChange(String userId, String value) {
    try {
      List<ParticipantShare> updatedShares = List.from(widget.shares);
      int index = updatedShares.indexWhere((share) => share.userId == userId);

      if (index == -1) return;

      if (widget.distributionType == DistributionType.percentage) {
        double percentage =
            double.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
        double amount = (widget.totalAmount * percentage) / 100;

        updatedShares[index] = ParticipantShare(
          userId: userId,
          amount: amount,
          percentage: percentage,
        );
      } else {
        double amount = double.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
        double percentage = (amount / widget.totalAmount) * 100;

        updatedShares[index] = ParticipantShare(
          userId: userId,
          amount: amount,
          percentage: percentage,
        );
      }

      widget.onSharesChanged(updatedShares);
    } catch (e) {
      print('Error al procesar valor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

// Calcular el total de porcentajes ingresados
    double totalPercentage = widget.shares.fold(
      0.0,
      (sum, share) => sum + share.percentage,
    );

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.participantIds.length,
          itemBuilder: (context, index) {
            final userId = widget.participantIds[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(userId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 60);
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final username = userData['username'] ?? 'Usuario';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          username,
                          style: TextStyle(
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _controllers[userId],
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: colorProvider.colors.primaryTextColor,
                          ),
                          decoration: InputDecoration(
                            suffix: Text(
                              widget.distributionType ==
                                      DistributionType.percentage
                                  ? '%'
                                  : '',
                              style: TextStyle(
                                color: colorProvider.colors.primaryTextColor,
                              ),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: colorProvider.colors.appBarColor,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: colorProvider.colors.appBarColor,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) =>
                              _handleValueChange(userId, value),
                        ),
                      ),
                      if (widget.distributionType ==
                          DistributionType.percentage)
                        Expanded(
                          flex: 2,
                          child: Text(
                            _currencyFormat.format((widget.totalAmount *
                                double.parse(_controllers[userId]!
                                    .text
                                    .replaceAll(RegExp(r'[^0-9.]'), '')) /
                                100)),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        if (totalPercentage < 100)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Falta distribuir \$${(widget.totalAmount * ((100 - totalPercentage) / 100)).toStringAsFixed(0)} correspondiente a ${(100 - totalPercentage).round()}%',
              style: TextStyle(
                color: colorProvider.colors.negativeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else if (totalPercentage >
            100) // Solo se ejecuta si totalPercentage es mayor a 100
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              ' \$${(widget.totalAmount * ((totalPercentage - 100) / 100)).toStringAsFixed(0)} correspondiente a ${(totalPercentage - 100).round()}% distribuido en exceso',
              style: TextStyle(
                color: colorProvider
                    .colors.negativeColor, // O un color para indicar exceso
                fontWeight: FontWeight.bold,
              ),
            ),
          )
      ],
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
