import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_gasto_form.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/widgets/distribution/distribution_type_selector.dart';
import 'package:control_gastos/widgets/distribution/participant_distribution_list.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class SharedSubgrupoGastoForm extends StatefulWidget {
  final String subgrupoNombre;
  final Function(String) onNombreChanged;
  final List<Gasto> gastos;
  final List<String> participantIds;
  final Function(List<Gasto>, DistributionModule?) onGastosChanged;
  final VoidCallback? onEliminar;
  final DistributionModule? initialDistribution;
  final SharedExpenseGroup group;
  final bool isDistributionVisible;
  final Function(bool) onVisibilityChanged;
  final int? index;

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
    required this.isDistributionVisible,
    required this.onVisibilityChanged,
    this.index,
  });

  @override
  _SharedSubgrupoGastoFormState createState() =>
      _SharedSubgrupoGastoFormState();
}

class _SharedSubgrupoGastoFormState extends State<SharedSubgrupoGastoForm> {
  late final TextEditingController _nombreSubgrupoController;
  late Map<String, Gasto> _gastosMap;
  bool _showDistribution = false;
  DistributionType _distributionType = DistributionType.equalParts;
  List<ParticipantShare> _shares = [];
  double _subtotal = 0.0;
  bool _showDistributionOption =
      false; // Nueva propiedad para ocultar completamente la opción
  bool _isExpanded =
      false; // Nuevo estado para controlar si el contenido está expandido
  bool _nombreModificado = false; // Para controlar si el nombre ha sido modificado


  @override
  void initState() {
    super.initState();
    _nombreSubgrupoController =
        TextEditingController(text: widget.subgrupoNombre);
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
    final nombre = _nombreSubgrupoController.text.trim();
    CustomLogger().logInfo('=== NOTIFICANDO CAMBIO DE NOMBRE (COMPARTIDO) ===');
    CustomLogger().logInfo('Nombre anterior: ${widget.subgrupoNombre}');
    CustomLogger().logInfo('Nombre nuevo: $nombre');
    CustomLogger().logInfo('Callback existe: ${widget.onNombreChanged != null}');
    widget.onNombreChanged(nombre);
    CustomLogger().logInfo('Callback ejecutado exitosamente (compartido)');
  }

  // Método público para obtener el nombre actual del TextField
  String getCurrentName() {
    return _nombreSubgrupoController.text.trim();
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

// Método para alternar la visibilidad del contenido
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
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

    return Card(
      margin: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 4, top: 4),
      color: colorProvider.colors.backgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(8.0), // Mantiene tus bordes redondeados
        side: BorderSide(
          color: colorProvider.colors.appBarColor
              .withOpacity(0.25), // Mantiene tu borde original
          width: 2.0, // Ancho del borde
        ),
      ),
      // decoration: BoxDecoration(
      //   color: colorProvider.colors.backgroundColor,
      //   border: Border.all(
      //     color: colorProvider.colors.appBarColor,
      //   ),
      //   borderRadius: BorderRadius.circular(8.0),
      // ),
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
                      hintText: 'Nombre del subgrupo',
                      hintStyle: TextStyle(
                        color: colorProvider.colors.primaryTextColor.withOpacity(0.6),
                      ),
                      labelStyle: TextStyle(
                        color: colorProvider.colors.primaryTextColor,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorProvider.colors.appBarColor,
                        ),
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: colorProvider.colors.appBarColor,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      _nombreModificado = true;
                    },
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                ),
                if (widget.onEliminar != null)
                  if (!_isExpanded) // Botón para alternar la visibilidad
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: colorProvider.colors.negativeColor,
                      ),
                      onPressed: widget.onEliminar,
                    ),
                if (!_isExpanded) // Botón para alternar la visibilidad
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: colorProvider.colors.appBarColor,
                    ),
                    onPressed: _agregarGasto,
                  ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showDistributionOption = !_showDistributionOption;
                    });
                    //color segun valor de widget.isDistributionVisible
                  },
                  icon: Icon(Icons.pie_chart),
                  color: _showDistribution
                      ? colorProvider.colors.positiveColor
                      : colorProvider.colors.appBarColor,
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.visibility_off : Icons.visibility,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: _toggleExpanded,
                  // tooltip:
                  //     _isExpanded ? 'Ocultar contenido' : 'Mostrar contenido',
                ),
                // Icono de arrastre para reordenar
                ReorderableDragStartListener(
                  index: widget.index ?? 0,
                  child: Icon(
                    Icons.drag_handle,
                    color: colorProvider.colors.appBarColor,
                  ),
                ),
              ],
            ),
            // Mostrar subtotal cuando el contenido está contraído
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(children: [
                      Text(
                        'Total Subgrupo:',
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${_subtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _subtotal >= 0
                              ? colorProvider.colors.positiveColor
                              : colorProvider.colors.negativeColor,
                        ),
                      ),
                    ])
                  ],
                ),
              ),
            // Mostrar gastos cuando el contenido está expandido
            if (!_isExpanded) ...{
              const SizedBox(height: 16),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _gastosMap.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final entries = _gastosMap.entries.toList();
                    final item = entries.removeAt(oldIndex);
                    entries.insert(newIndex, item);
                    _gastosMap = Map.fromEntries(entries);
                    _notifyGastosChanged();
                  });
                },
                proxyDecorator: (Widget child, int index,
                          Animation<double> animation) {
                        return Material(
                          color: Colors.transparent,
                          elevation: 0,
                          child: child,
                        );
                      },
                itemBuilder: (context, index) {
                  final entry = _gastosMap.entries.elementAt(index);
                  return SharedGastoForm(
                    key: ValueKey(entry.key),
                    gasto: entry.value,
                    participantIds:
                        widget.group.participants.map((p) => p.userId).toList(),
                    onCancel: () => _handleDeleteGasto(entry.key),
                    onGastoChanged: (updatedGasto, _) =>
                        _handleGastoChanged(entry.key, updatedGasto),
                    group: widget.group,
                    isDistributionVisible: false,
                    onVisibilityChanged:
                        (_) {}, // No permitir cambios de visibilidad
                    showDistributionOption:
                        false, // Nueva propiedad para ocultar completamente la opción
                    index: index,
                  );
                },
              ),
            },
            if (_showDistributionOption) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Distribuir este subgrupo',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ToggleButtons(
                        isSelected: [
                          _showDistribution,
                          !_showDistribution
                        ], // Debe tener la misma cantidad de elementos que children
                        onPressed: (index) {
                          setState(() {
                            _showDistribution =
                                index == 0; // Activo en el primer botón
                            if (_showDistribution && _shares.isEmpty) {
                              _initializeEqualDistribution();
                            }
                            _notifyGastosChanged();
                          });
                        },
                        borderColor: _showDistribution
                            ? colorProvider.colors.positiveColor
                            : colorProvider.colors.appBarColor,
                        selectedBorderColor: _showDistribution
                            ? colorProvider.colors.positiveColor
                            : colorProvider.colors.appBarColor,
                        color: const Color.fromARGB(255, 0, 0, 0),
                        constraints: const BoxConstraints(
                          minHeight: 25.0,
                          minWidth: 140.0,
                        ),
                        selectedColor: colorProvider.colors.secondaryTextColor,
                        borderRadius: BorderRadius.circular(10),
                        fillColor: _showDistribution
                            ? colorProvider.colors.positiveColor
                            : colorProvider.colors.appBarColor,
                        children: [
                          SizedBox(
                              child: Center(
                                  child: Text('ACTIVO',
                                      style:
                                          TextStyle(fontSize: 14, height: 0)))),
                          SizedBox(
                              child: Center(
                                  child: Text('INACTIVO',
                                      style:
                                          TextStyle(fontSize: 14, height: 0)))),
                        ],
                      )
                    ],
                  ),
                ],
              ),
              if (_showDistribution) ...[
                const SizedBox(height: 16),
                // if (widget.isDistributionVisible) ...[
                // Añade esta condición
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
                // const SizedBox(height: 16),
                ParticipantDistributionList(
                  participantIds:
                      widget.group.participants.map((p) => p.userId).toList(),
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
                // ],
              ],
            ]
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreSubgrupoController.dispose();
    super.dispose();
  }
}
