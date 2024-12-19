import 'package:flutter/material.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DistributionSummaryWidget extends StatelessWidget {
  final DistributionModule distribution;
  final bool showDetails;

  const DistributionSummaryWidget({
    Key? key,
    required this.distribution,
    this.showDetails = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '',
      decimalDigits: 0,
    );

    return Card(
      color: colorProvider.colors.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distribución',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                Text(
                  distribution.type == DistributionType.equalParts
                      ? 'Partes Iguales'
                      : 'Porcentajes',
                  style: TextStyle(
                    color: colorProvider.colors.appBarColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              ...distribution.shares.map((share) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FutureBuilder(
                        future: _getUserName(share.userId),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Usuario',
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          );
                        },
                      ),
                      Text(
                        '${currencyFormat.format(share.amount)} (${share.percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                Text(
                  currencyFormat.format(distribution.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getUserName(String userId) async {
    // TODO: Implementar obtención del nombre de usuario
    return 'Usuario $userId';
  }
}