import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ExpenseDetailsWidget extends StatefulWidget {
  final GroupModel group;
  final bool isTrackingEnabled;
  final Function(String expenseId, bool isTracked)? onExpenseTrackingChanged;
  final Function(String subgroupId, String expenseId, bool isTracked)? onSubgroupExpenseTrackingChanged; // Nueva función para gastos en subgrupos

  const ExpenseDetailsWidget({
    Key? key,
    required this.group,
    this.isTrackingEnabled = false,
    this.onExpenseTrackingChanged,
    this.onSubgroupExpenseTrackingChanged,
    SharedExpenseGroup? expense,
  }) : super(key: key);

  @override
  _ExpenseDetailsWidgetState createState() => _ExpenseDetailsWidgetState();
}

class _ExpenseDetailsWidgetState extends State<ExpenseDetailsWidget> {
  @override
  Widget build(BuildContext context) {
    return buildGroupDetails(context, widget.group);
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
                expenseId: expense.id,
                isTracked: expense.isTracked,
              )),
          const SizedBox(height: 5),
          if (group.subgroups.isNotEmpty) ...[
            ...group.subgroups.map((subgroup) => buildSubgroupSection(
                  context,
                  subgroup.expenses,
                  subgroup.subgroupName,
                  currencyFormat,
                  subgroupId: subgroup.id,
                  isTracked: subgroup.isTracked,
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
      bool isIncome, NumberFormat currencyFormat, {String? expenseId, bool? isTracked, String? subgroupId}) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Checkbox para seguimiento
          if (widget.isTrackingEnabled && expenseId != null)
            Checkbox(
              value: isTracked ?? false,
              onChanged: (bool? value) {
                if (subgroupId != null && widget.onSubgroupExpenseTrackingChanged != null) {
                  // Es un gasto dentro de un subgrupo
                  widget.onSubgroupExpenseTrackingChanged!(subgroupId, expenseId, value ?? false);
                } else if (widget.onExpenseTrackingChanged != null) {
                  // Es un gasto principal
                  widget.onExpenseTrackingChanged!(expenseId, value ?? false);
                }
              },
              activeColor: Colors.white,
              checkColor: colorProvider.colors.positiveColor,
            ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor,
                decoration: (widget.isTrackingEnabled && (isTracked ?? false)) 
                    ? TextDecoration.lineThrough 
                    : null,
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
              decoration: (widget.isTrackingEnabled && (isTracked ?? false)) 
                  ? TextDecoration.lineThrough 
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSubgroupSection(BuildContext context, List<Gasto> gastos,
      String subgroupName, NumberFormat currencyFormat, {String? subgroupId, bool? isTracked}) {
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
              Expanded(
                child: Text(
                  subgroupName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.appBarColor,
                  ),
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
        // Mostrar cada gasto del subgrupo con su propio checkbox
        ...gastos.map((gasto) => buildExpenseItem(
              context,
              gasto.nombre,
              gasto.valor,
              gasto.esAFavor,
              currencyFormat,
              expenseId: gasto.id,
              isTracked: gasto.isTracked,
              subgroupId: subgroupId, // Pasar el ID del subgrupo
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
