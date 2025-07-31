import 'dart:convert';
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
  final Function(String subgroupId, String expenseId, bool isTracked)?
      onSubgroupExpenseTrackingChanged; // Nueva función para gastos en subgrupos

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
                              color: colorProvider.colors.appBarColor,
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
          // Solo mostrar la sección de Gastos Principales si hay gastos
          if (group.expenses.isNotEmpty) ...[
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
          ],
          const SizedBox(height: 0),
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
          // Mostrar miniaturas de imágenes del grupo
          if (group.imagenes != null && group.imagenes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Imágenes del grupo',
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.imagenes!.entries.map((entry) {
                final imageData = entry.value;
                final imageUrl = imageData['imagen'] as String?;
                final description = imageData['descripcion'] as String? ?? '';
                return GestureDetector(
                  onTap: () => _showFullScreenImage(context, imageUrl, description, colorProvider),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: colorProvider.colors.appBarColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: imageUrl != null
                          ? Image.memory(
                              Uri.parse(imageUrl).data!.contentAsBytes(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: colorProvider.colors.appBarColor
                                      .withOpacity(0.1),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 16,
                                    color: colorProvider.colors.appBarColor
                                        .withOpacity(0.5),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: colorProvider.colors.appBarColor
                                  .withOpacity(0.1),
                              child: Icon(
                                Icons.image,
                                size: 16,
                                color: colorProvider.colors.appBarColor
                                    .withOpacity(0.5),
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
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
            ...group.participants.map((participant) =>
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(participant.userId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    // Verificar si los datos existen y no son nulos
                    final userData = snapshot.data!.data();
                    if (userData == null) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorProvider.colors.appBarColor
                              .withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorProvider.colors.appBarColor
                                .withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colorProvider.colors.appBarColor
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: colorProvider.colors.appBarColor
                                    .withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Usuario no encontrado',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_getStatusText(participant.status)}',
                                style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Ahora es seguro hacer el cast
                    final userDataMap = userData as Map<String, dynamic>;
                    final username = userDataMap['username'] ?? 'Usuario';

                    // Determinar color del estado
                    Color statusColor;
                    switch (participant.status) {
                      case ParticipantStatus.accepted:
                        statusColor = Colors.green;
                        break;
                      case ParticipantStatus.pending:
                        statusColor = Colors.orange;
                        break;
                      case ParticipantStatus.rejected:
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            colorProvider.colors.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              colorProvider.colors.appBarColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colorProvider.colors.appBarColor
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 18,
                              color: colorProvider.colors.appBarColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              username,
                              style: TextStyle(
                                color: colorProvider.colors.primaryTextColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_getStatusText(participant.status)}',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
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
      bool isIncome, NumberFormat currencyFormat,
      {String? expenseId, bool? isTracked, String? subgroupId}) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Padding(
      padding: widget.isTrackingEnabled
          ? const EdgeInsets.symmetric(vertical: 0)
          : const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Checkbox para seguimiento
          if (widget.isTrackingEnabled && expenseId != null)
            Checkbox(
              value: isTracked ?? false,
              onChanged: (bool? value) {
                if (subgroupId != null &&
                    widget.onSubgroupExpenseTrackingChanged != null) {
                  // Es un gasto dentro de un subgrupo
                  widget.onSubgroupExpenseTrackingChanged!(
                      subgroupId, expenseId, value ?? false);
                } else if (widget.onExpenseTrackingChanged != null) {
                  // Es un gasto principal
                  widget.onExpenseTrackingChanged!(expenseId, value ?? false);
                }
              },
              activeColor: Colors.white,
              checkColor: colorProvider.colors.positiveColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
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
      String subgroupName, NumberFormat currencyFormat,
      {String? subgroupId, bool? isTracked}) {
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
        const SizedBox(height: 0),
        Container(
            alignment: Alignment.centerRight,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: colorProvider.colors.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorProvider.colors.appBarColor.withOpacity(1),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Total Grupo: ${currencyFormat.format(subtotal)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.appBarColor,
                  ),
                ))),
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

  void _showFullScreenImage(BuildContext context, String? imageUrl, String description, ColorProvider colorProvider) {
     if (imageUrl == null) return;
     
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (BuildContext context) {
         bool showDescription = false;
         
         return StatefulBuilder(
           builder: (context, setState) {
             return Dialog(
               backgroundColor: Colors.transparent,
               child: GestureDetector(
                 onTap: () {
                   if (description.isNotEmpty) {
                     setState(() {
                       showDescription = !showDescription;
                     });
                   }
                 },
                 child: Stack(
                   children: [
                     // Imagen en pantalla completa
                     Center(
                       child: Container(
                         constraints: BoxConstraints(
                           maxHeight: MediaQuery.of(context).size.height * 0.8,
                           maxWidth: MediaQuery.of(context).size.width * 0.9,
                         ),
                         child: ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.memory(
                             Uri.parse(imageUrl).data!.contentAsBytes(),
                             fit: BoxFit.contain,
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                                 color: colorProvider.colors.backgroundColor,
                                 child: Icon(
                                   Icons.image_not_supported,
                                   size: 64,
                                   color: colorProvider.colors.appBarColor.withOpacity(0.5),
                                 ),
                               );
                             },
                           ),
                         ),
                       ),
                     ),
                     // Botón de cerrar
                     Positioned(
                       top: 40,
                       right: 20,
                       child: Container(
                         decoration: BoxDecoration(
                           color: Colors.black.withOpacity(0.5),
                           shape: BoxShape.circle,
                         ),
                         child: IconButton(
                           icon: const Icon(Icons.close, color: Colors.white),
                           onPressed: () => Navigator.of(context).pop(),
                         ),
                       ),
                     ),
                     // Indicador de descripción disponible
                     if (description.isNotEmpty && !showDescription)
                       Positioned(
                         bottom: 40,
                         left: 0,
                         right: 0,
                         child: Center(
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             decoration: BoxDecoration(
                               color: Colors.black.withOpacity(0.75),
                               borderRadius: BorderRadius.circular(20),
                             ),
                             child: const Text(
                               'Toca aquí para ver descripción',
                               style: TextStyle(
                                 color: Colors.white,
                                 fontSize: 14,
                               ),
                             ),
                           ),
                         ),
                       ),
                     // Descripción en la parte inferior
                     if (description.isNotEmpty && showDescription)
                       Positioned(
                         bottom: 40,
                         left: 20,
                         right: 20,
                         child: Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.black.withOpacity(0.8),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Text(
                                 description,
                                 style: const TextStyle(
                                   color: Colors.white,
                                   fontSize: 16,
                                 ),
                                 textAlign: TextAlign.center,
                               ),
                               const SizedBox(height: 8),
                               Text(
                                 'Toca para ocultar',
                                 style: TextStyle(
                                   color: Colors.white.withOpacity(0.7),
                                   fontSize: 12,
                                 ),
                                 textAlign: TextAlign.center,
                               ),
                             ],
                           ),
                         ),
                       ),
                   ],
                 ),
               ),
             );
           },
         );
       },
     );
   }
}
