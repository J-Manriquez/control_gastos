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
          if (group is SharedExpenseGroup &&
              group.totalDistribution != null) ...[
            Text(
              'Distribución',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(
              color: colorProvider.colors.appBarColor,
              height: 0,
            ),
            ...group.totalDistribution!.shares.map((share) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(share.userId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  // Verificar si los datos existen y no son nulos
                  final userData = snapshot.data!.data();
                  if (userData == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monto no distribuido',
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
                  }

                  // Ahora es seguro hacer el cast
                  final userDataMap = userData as Map<String, dynamic>;
                  final username = userDataMap['username'] ?? 'Usuario';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0.5),
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
          const SizedBox(height: 5),
          Text(
            'Gastos Principales',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: colorProvider.colors.appBarColor,
            ),
          ),
          Divider(
            color: colorProvider.colors.appBarColor,
            height: 0,
          ),
          ...group.expenses.map((expense) => buildExpenseItem(
                context,
                expense.nombre,
                expense.valor,
                expense.esAFavor,
                currencyFormat,
              )),
          const SizedBox(height: 5),
          if (group.subgroups.isNotEmpty) ...[
            ...group.subgroups.map((subgroup) => buildSubgroupSection(
                  context,
                  subgroup.expenses,
                  subgroup.subgroupName,
                  currencyFormat,
                )),
          ],
          if (group is SharedExpenseGroup) ...[
            Text(
              'Participantes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(
              color: colorProvider.colors.appBarColor,
              height: 0,
            ),
            ...group.participants
                .map((participant) => FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(participant.userId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();

                        // Verificar si los datos existen y no son nulos
                        final userData = snapshot.data!.data();
                        if (userData == null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 0.5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Monto no distribuido',
                                  style: TextStyle(
                                    color:
                                        colorProvider.colors.primaryTextColor,
                                  ),
                                ),
                                Text(
                                  '${_getStatusText(participant.status)}',
                                  style: TextStyle(
                                    color: colorProvider.colors.primaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Ahora es seguro hacer el cast
                        final userDataMap = userData as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                userDataMap['username'] ?? 'Usuario',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
                                ),
                              ),
                              Text(
                                // Reemplazar esto:
                                // 'Estado: ${participant.status.toString().split('.').last}',
                                // Por esto:
                                '${_getStatusText(participant.status)}',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
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

  Widget buildExpenseItem(BuildContext context, String name, double value,
      bool isIncome, NumberFormat currencyFormat) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
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

  Widget buildSubgroupSection(BuildContext context, List<Gasto> gastos,
      String subgroupName, NumberFormat currencyFormat) {
    final colorProvider = Provider.of<ColorProvider>(context);
    double subtotal =
        gastos.fold(0, (subtotalValue, gasto) => subtotalValue + gasto.valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subgroupName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.appBarColor,
                ),
              ),
              Text(
                'Subtotal: ${currencyFormat.format(subtotal)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.primaryTextColor,
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: colorProvider.colors.appBarColor,
          height: 0,
        ),
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

  // Añadir este método a la clase ExpenseDetailsWidget
  String _getStatusText(ParticipantStatus status) {
    switch (status) {
      case ParticipantStatus.accepted:
        return 'Invitación aceptada';
      case ParticipantStatus.pending:
        return 'Invitación pendiente';
      case ParticipantStatus.rejected:
        return 'Invitación rechazada';
      default:
        return 'Desconocido';
    }
  }
}
