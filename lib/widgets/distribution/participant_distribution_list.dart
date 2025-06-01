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

  // Parámetro para modo de solo lectura
  final bool isReadOnly;

  const ParticipantDistributionList({
    Key? key,
    required this.participantIds,
    required this.totalAmount,
    required this.distributionType,
    required this.shares,
    required this.onSharesChanged,
    this.isReadOnly = false,
  }) : super(key: key);

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
        widget.totalAmount != oldWidget.totalAmount ||
        widget.shares.length != oldWidget.shares.length) {
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
    if (widget.isReadOnly) return; // No permitir cambios en modo solo lectura

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

    return Container(
      margin: const EdgeInsets.all(0),
      color: Colors.white,
      child: Column(
        children: [
          if (!widget.isReadOnly) ...{
            if (totalPercentage < 100 && totalPercentage != 0) ...{
              Container(
                color: colorProvider.colors.negativeColor,
                margin: const EdgeInsets.all(0),
                width: double
                    .infinity, // Asegura que el SizedBox ocupe todo el ancho disponible
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Text(
                    'Falta distribuir \$${(widget.totalAmount * ((100 - totalPercentage) / 100)).toStringAsFixed(0)} correspondiente a ${(100 - totalPercentage).round()}%',
                    textAlign: TextAlign.center, // <--- Esto justifica el texto
                    style: TextStyle(
                      color: Colors.white,
                      // fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            } else if (totalPercentage > 100 && totalPercentage != 0) ...{
              Container(
                color: colorProvider.colors.negativeColor,
                margin: const EdgeInsets.all(0),
                width: double
                    .infinity, // Asegura que el SizedBox ocupe todo el ancho disponible
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  child: Text(
                    ' \$${(widget.totalAmount * ((totalPercentage - 100) / 100)).toStringAsFixed(0)} correspondiente a ${(totalPercentage - 100).round()}% distribuido en exceso',
                    textAlign: TextAlign.center, // <--- Esto justifica el texto
                    style: TextStyle(
                      color: Colors.white,
                      // fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            },
          },
          Container(
            margin: const EdgeInsets.all(0),
            padding: const EdgeInsets.all(0),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.participantIds.length,
              itemBuilder: (context, index) {
                // Verificar si hay suficientes shares para este índice
                if (index >= widget.shares.length) {
                  return const SizedBox.shrink();
                }

                final share = widget.shares[index];
                final userId = widget.participantIds[index];
                final isUndistributed = userId == 'undistributed';

                // Para el participante especial 'undistributed'
                if (isUndistributed) {
                  return Padding(
                    padding: const EdgeInsets.all(0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'No distribuido',
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${share.percentage.toStringAsFixed(2)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _currencyFormat.format(share.amount),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(userId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(height: 60);
                    }

                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final username = userData['username'] ?? 'Usuario';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
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
                            child: widget.isReadOnly
                                ? Text(
                                    '${share.percentage.toStringAsFixed(2)}%',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color:
                                          colorProvider.colors.primaryTextColor,
                                    ),
                                  )
                                : TextField(
                                    controller: _controllers[userId],
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color:
                                          colorProvider.colors.primaryTextColor,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true, // <-- Agrega esto
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 0),
                                      suffix: Text(
                                        widget.distributionType ==
                                                DistributionType.percentage
                                            ? '%'
                                            : '',
                                        style: TextStyle(
                                          color: colorProvider
                                              .colors.primaryTextColor,
                                        ),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color:
                                              colorProvider.colors.appBarColor,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color:
                                              colorProvider.colors.appBarColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) =>
                                        _handleValueChange(userId, value),
                                  ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _currencyFormat.format(share.amount),
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
          ),
        ],
      ),
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
