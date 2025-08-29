import 'dart:async';
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
  final Function(int, int)? onMoveExpenseOut;
  final Function(int, int)? onMoveExpenseIn;
  final Function(int, int, int)? onMoveExpenseBetweenSubgroups;
  final Function(String, int, int)? onReorderSubgroupExpenses;

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
    this.onMoveExpenseOut,
    this.onMoveExpenseIn,
    this.onMoveExpenseBetweenSubgroups,
    this.onReorderSubgroupExpenses,
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
  Timer? _nombreDebounceTimer; // Timer para debounce del nombre
  Timer? _gastosDebounceTimer; // Timer para debounce de cambios en gastos


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
    });
    _onGastosChanged(); // Usar debounce
    
    // Notificar al padre sobre el nuevo gasto para actualizar el orden
    if (widget.onReorderSubgroupExpenses != null) {
      // Agregar el nuevo gasto al final del orden del subgrupo
      final currentOrder = _gastosMap.keys.toList();
      final newIndex = currentOrder.indexOf(newGasto.id!);
      if (newIndex != -1) {
        widget.onReorderSubgroupExpenses!(widget.subgrupoNombre, newIndex, newIndex);
      }
    }
  }

  void _handleDeleteGasto(String? gastoId) {
    if (gastoId == null) return;

    setState(() {
      _gastosMap.remove(gastoId);
    });
    _onGastosChanged(); // Usar debounce
  }

  void _handleGastoChanged(String? gastoId, Gasto updatedGasto) {
    if (gastoId == null) return;

    // Verificar si realmente hay cambios antes de llamar setState
    final currentGasto = _gastosMap[gastoId];
    if (currentGasto != null && 
        currentGasto.nombre == updatedGasto.nombre &&
        currentGasto.valor == updatedGasto.valor &&
        currentGasto.esAFavor == updatedGasto.esAFavor &&
        currentGasto.fecha == updatedGasto.fecha) {
      return; // No hay cambios, evitar setState
    }

    _gastosMap[gastoId] = updatedGasto;
    _calculateSubtotal();
    
    // Usar debounce para evitar reconstrucciones inmediatas
    _onGastosChanged();
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

  void _onGastosChanged() {
    _gastosDebounceTimer?.cancel();
    _gastosDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _notifyGastosChanged();
      }
    });
  }

  @override
  void dispose() {
    _nombreDebounceTimer?.cancel();
    _gastosDebounceTimer?.cancel();
    _nombreSubgrupoController.dispose();
    super.dispose();
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
          color: colorProvider.colors.appBarColor, // Mantiene tu borde original
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
                    onChanged: (value) {
                      _nombreModificado = true;
                      _nombreDebounceTimer?.cancel();
                      _nombreDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          widget.onNombreChanged(value);
                        }
                      });
                    },
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                ),
                if (widget.onEliminar != null && !_isExpanded)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: colorProvider.colors.negativeColor,
                    ),
                    onPressed: widget.onEliminar,
                  ),
                if (!_isExpanded)
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
                ),
                ReorderableDragStartListener(
                  index: widget.index ?? 0,
                  child: Icon(
                    Icons.drag_handle,
                    color: colorProvider.colors.appBarColor,
                  ),
                ),
              ],
            ),
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
            DragTarget<Map<String, dynamic>>(
              onWillAccept: (data) {
                return data != null &&
                    data.containsKey('gasto') &&
                    data.containsKey('sourceType') &&
                    (data['sourceType'] == 'main' ||
                        (data['sourceType'] == 'subgroup' &&
                            data['sourceSubgroupIndex'] != widget.index));
              },
              onAccept: (data) {
                if (data['sourceType'] == 'main') {
                  final sourceIndex = data['sourceIndex'];
                  if (sourceIndex != null && widget.onMoveExpenseIn != null) {
                    widget.onMoveExpenseIn!(sourceIndex, widget.index ?? 0);
                  }
                } else if (data['sourceType'] == 'subgroup') {
                  final sourceSubgroupIndex = data['sourceSubgroupIndex'];
                  final sourceExpenseIndex = data['sourceIndex'];
                  if (sourceSubgroupIndex != null &&
                      sourceExpenseIndex != null &&
                      widget.onMoveExpenseBetweenSubgroups != null) {
                    widget.onMoveExpenseBetweenSubgroups!(
                        sourceSubgroupIndex, sourceExpenseIndex, widget.index ?? 0);
                  }
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: candidateData.isNotEmpty
                      ? BoxDecoration(
                          border: Border.all(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Column(
                    children: [
                      if (!_isExpanded && _gastosMap.isNotEmpty)
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
                            });
                            _onGastosChanged(); // Usar debounce
                            
                            // Llamar al método de reorden en el padre
                            if (widget.onReorderSubgroupExpenses != null) {
                              widget.onReorderSubgroupExpenses!(widget.subgrupoNombre, oldIndex, newIndex);
                            }
                          },
                          proxyDecorator: (Widget child, int index, Animation<double> animation) {
                            return Material(
                              color: Colors.transparent,
                              elevation: 0,
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final entry = _gastosMap.entries.elementAt(index);
                            return LongPressDraggable<Map<String, dynamic>>(
                              key: ValueKey('subgroup_expense_${entry.key}_${index}'),
                              data: {
                                'gasto': entry.value,
                                'sourceType': 'subgroup',
                                'sourceSubgroupIndex': widget.index ?? 0,
                                'sourceIndex': index,
                                'gastoId': entry.key,
                              },
                              feedback: Material(
                                color: Colors.transparent,
                                elevation: 0,
                                child: Container(
                                  width: 300,
                                  child: SharedGastoForm(
                                    gasto: entry.value,
                                    participantIds: widget.group.participants.map((p) => p.userId).toList(),
                                    onCancel: () {},
                                    onGastoChanged: (updatedGasto, _) {},
                                    group: widget.group,
                                    isDistributionVisible: false,
                                    onVisibilityChanged: (_) {},
                                    showDistributionOption: false,
                                    index: index,
                                  ),
                                ),
                              ),
                              childWhenDragging: Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onDragEnd: (details) {
                                if (!details.wasAccepted) {
                                  if (widget.onMoveExpenseOut != null) {
                                    widget.onMoveExpenseOut!(widget.index ?? 0, index);
                                  }
                                }
                              },
                              child: SharedGastoForm(
                                key: ValueKey('subgroup_gastoform_${entry.key}_${index}'),
                                gasto: entry.value,
                                participantIds: widget.group.participants.map((p) => p.userId).toList(),
                                onCancel: () => _handleDeleteGasto(entry.key),
                                onGastoChanged: (updatedGasto, _) =>
                                    _handleGastoChanged(entry.key, updatedGasto),
                                group: widget.group,
                                isDistributionVisible: false,
                                onVisibilityChanged: (_) {},
                                showDistributionOption: false,
                                index: index,
                              ),
                            );
                          },
                        ),
                      if (candidateData.isNotEmpty || (_gastosMap.isEmpty && !_isExpanded))
                        Container(
                          height: 60,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: candidateData.isNotEmpty
                                  ? Colors.transparent
                                  : Colors.grey.withOpacity(0.3),
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              candidateData.isNotEmpty
                                  ? 'Suelta aquí para agregar al grupo'
                                  : 'Arrastrar aquí',
                              style: TextStyle(
                                color: candidateData.isNotEmpty
                                    ? Colors.green
                                    : Colors.grey[600],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

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
                          });
                          _onGastosChanged(); // Usar debounce
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
                    });
                    _onGastosChanged(); // Usar debounce
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
                    });
                    _onGastosChanged(); // Usar debounce
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

 
}
