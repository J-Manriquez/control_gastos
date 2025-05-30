import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ExpenseDetailsWidget extends StatelessWidget {
  final GroupModel group;
  
  const ExpenseDetailsWidget({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return buildGroupDetails(context, group);
  }

  Widget buildGroupDetails(BuildContext context, GroupModel group) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastos Principales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorProvider.colors.appBarColor,
            ),
          ),
          Divider(color: colorProvider.colors.appBarColor),
          ...group.expenses.map((expense) => buildExpenseItem(
                context,
                expense.nombre,
                expense.valor,
                expense.esAFavor,
                currencyFormat,
              )),
          const SizedBox(height: 16),
          if (group.subgroups.isNotEmpty) ...[  
            Text(
              'Subgrupos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            ...group.subgroups.map((subgroup) => buildSubgroupSection(
                  context,
                  subgroup.expenses,
                  subgroup.subgroupName,
                  currencyFormat,
                )),
          ],
          if (group is SharedExpenseGroup &&
              group.totalDistribution != null) ...[  
            const SizedBox(height: 16),
            Text(
              'Distribución',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(color: colorProvider.colors.appBarColor),
            ...group.totalDistribution!.shares.map((share) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(share.userId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final username = userData['username'] ?? 'Usuario';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          username,
                          style: TextStyle(
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                        Text(
                          '\$${share.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorProvider.colors.primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ],
          if (group is SharedExpenseGroup) ...[  
            const SizedBox(height: 16),
            Text(
              'Participantes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(color: colorProvider.colors.appBarColor),
            ...group.participants
                .map((participant) => FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(participant.userId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                userData['username'] ?? 'Usuario',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
                                ),
                              ),
                              Text(
                                'Estado: ${participant.status.toString().split('.').last}',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )),
          ],
        ],
      ),
    );
  }

  Widget buildExpenseItem(BuildContext context, String name, double value, bool isIncome, NumberFormat currencyFormat) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 16,
              color: isIncome
                  ? colorProvider.colors.positiveColor
                  : colorProvider.colors.negativeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSubgroupSection(BuildContext context, List<Gasto> gastos, String subgroupName, NumberFormat currencyFormat) {
    final colorProvider = Provider.of<ColorProvider>(context);
    double subtotal =
        gastos.fold(0, (subtotalValue, gasto) => subtotalValue + gasto.valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subgroupName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.appBarColor,
                ),
              ),
              Text(
                'Subtotal: ${currencyFormat.format(subtotal)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.primaryTextColor,
                ),
              ),
            ],
          ),
        ),
        Divider(color: colorProvider.colors.appBarColor),
        ...gastos.map((gasto) => buildExpenseItem(
              context,
              gasto.nombre,
              gasto.valor,
              gasto.esAFavor,
              currencyFormat,
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}