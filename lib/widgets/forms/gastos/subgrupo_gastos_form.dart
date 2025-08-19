import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/widgets/forms/gastos/gasto_form.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class SubgrupoGastoForm extends StatefulWidget {
  final String subgrupoNombre;
  final Function(String) onNombreChanged;
  final List<Gasto> gastos;
  final Function(List<Gasto>) onGastosChanged;
  final VoidCallback? onEliminar;
  final int? index;
  final int? subgroupReorderIndex; // Índice para reordenamiento de subgrupos
  final Function(int, int)? onMoveExpenseOut; // Callback para mover gasto fuera del subgrupo
  final Function(int, int)? onMoveExpenseIn; // Callback para recibir gasto de la lista principal
  final Function(int, int, int)? onMoveExpenseBetweenSubgroups; // Callback para mover gasto entre subgrupos

  const SubgrupoGastoForm({
    super.key,
    required this.subgrupoNombre,
    required this.onNombreChanged,
    required this.gastos,
    required this.onGastosChanged,
    this.onEliminar,
    this.index,
    this.subgroupReorderIndex,
    this.onMoveExpenseOut,
    this.onMoveExpenseIn,
    this.onMoveExpenseBetweenSubgroups,
  });

  @override
  _SubgrupoGastoFormState createState() => _SubgrupoGastoFormState();
}

class _SubgrupoGastoFormState extends State<SubgrupoGastoForm> {
  late TextEditingController _nombreSubgrupoController;
  late List<Gasto> _gastosList;
  bool _nombreModificado = false;
  bool _isExpanded = true;


  @override
  void initState() {
    super.initState();
    _nombreSubgrupoController =
        TextEditingController(text: widget.subgrupoNombre);
    _initializeGastosList();
    CustomLogger().logInfo(
        'SubgrupoGastoForm inicializado con nombre: ${widget.subgrupoNombre}');
  }

  void _initializeGastosList() {
    _gastosList = List<Gasto>.from(widget.gastos);
    // Asegurar que todos los gastos tengan un ID
    for (int i = 0; i < _gastosList.length; i++) {
      if (_gastosList[i].id == null) {
        _gastosList[i] = _gastosList[i].copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
        );
      }
    }
  }

  @override
  void didUpdateWidget(SubgrupoGastoForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Solo actualizamos el texto del controller si no ha sido modificado manualmente
    // y si el nombre del subgrupo ha cambiado desde el widget padre
    if (!_nombreModificado &&
        widget.subgrupoNombre != oldWidget.subgrupoNombre) {
      _nombreSubgrupoController.text = widget.subgrupoNombre;
      CustomLogger().logInfo(
          'Nombre de subgrupo actualizado desde widget padre: ${widget.subgrupoNombre}');
    }

    // Actualizar la lista cuando cambien los gastos externos
    if (widget.gastos != oldWidget.gastos) {
      _initializeGastosList();
    }
  }

  void _notifyNombreChanged() {
    final nombre = _nombreSubgrupoController.text.trim();
    CustomLogger().logInfo('=== NOTIFICANDO CAMBIO DE NOMBRE ===');
    CustomLogger().logInfo('Nombre anterior: ${widget.subgrupoNombre}');
    CustomLogger().logInfo('Nombre nuevo: $nombre');
    CustomLogger().logInfo('Callback existe: ${widget.onNombreChanged != null}');
    widget.onNombreChanged(nombre);
    CustomLogger().logInfo('Callback ejecutado exitosamente');
  }

  // Método público para obtener el nombre actual del TextField
  String getCurrentName() {
    return _nombreSubgrupoController.text.trim();
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
      _gastosList.add(newGasto);
      widget.onGastosChanged(_gastosList);
    });
  }

  void _handleDeleteGasto(String? gastoId) {
    if (gastoId == null) return;

    setState(() {
      _gastosList.removeWhere((gasto) => gasto.id == gastoId);
      widget.onGastosChanged(_gastosList);
    });
  }

  void _handleGastoChanged(String? gastoId, Gasto updatedGasto) {
    if (gastoId == null) return;

    setState(() {
      final index = _gastosList.indexWhere((gasto) => gasto.id == gastoId);
      if (index != -1) {
        _gastosList[index] = updatedGasto;
        widget.onGastosChanged(_gastosList);
      }
    });
  }



  // Método para alternar la visibilidad del contenido
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final double subtotal = _gastosList.fold(0.0, (sum, gasto) {
      return sum + (gasto.esAFavor ? gasto.valor : -gasto.valor);
    });

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
                      hintText:
                          'Nombre del Grupo', // Usar hintText en lugar de labelText
                      hintStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
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
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                ),
                if (widget.onEliminar != null)
                  if (_isExpanded) // Botón para alternar la visibilidad
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: colorProvider.colors.negativeColor,
                      ),
                      onPressed: widget.onEliminar,
                    ),
                // Solo mostrar el botón de añadir si el contenido está expandido
                if (_isExpanded)
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      color: colorProvider.colors.appBarColor,
                    ),
                    onPressed: _agregarGasto,
                  ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.visibility_off : Icons.visibility,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: _toggleExpanded,
                  // tooltip: _isExpanded == true 
                  //     ? 'Ocultar contenido' 
                  //     : 'Mostrar contenido',
                ),
                // Icono de arrastre para reordenar subgrupos
                if (widget.subgroupReorderIndex != null)
                  ReorderableDragStartListener(
                    index: widget.subgroupReorderIndex!,
                    child: Icon(
                      Icons.drag_handle,
                      color: colorProvider.colors.appBarColor,
                    ),
                  )
                else
                  Icon(
                    Icons.drag_handle,
                    color: colorProvider.colors.appBarColor,
                  ),
              ],
            ),
            // Mostrar subtotal cuando el contenido está contraído
            if (!_isExpanded)
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
                        '\$${subtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: subtotal >= 0
                              ? colorProvider.colors.positiveColor
                              : colorProvider.colors.negativeColor,
                        ),
                      ),
                    ])
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Área de drop para recibir gastos de otros subgrupos (siempre visible)
            DragTarget<Map<String, dynamic>>(
                onWillAccept: (data) {
                  print('DEBUG SubgrupoGastoForm: DragTarget onWillAccept - data: $data');
                  return data != null && data.containsKey('gasto') && data.containsKey('sourceType');
                },
                onAccept: (data) {
                  print('DEBUG SubgrupoGastoForm: DragTarget onAccept - data: $data');
                  final gasto = data['gasto'];
                  final sourceType = data['sourceType'];
                  final sourceIndex = data['sourceIndex'];
                  final sourceSubgroupIndex = data['sourceSubgroupIndex'];
                  
                  if (sourceType == 'main') {
                    // Gasto viene de la lista principal
                    if (widget.onMoveExpenseIn != null) {
                      widget.onMoveExpenseIn!(sourceIndex, widget.index ?? 0);
                    }
                  } else if (sourceType == 'subgroup' && sourceSubgroupIndex != widget.index) {
                    // Gasto viene de otro subgrupo
                    if (widget.onMoveExpenseBetweenSubgroups != null) {
                      widget.onMoveExpenseBetweenSubgroups!(sourceSubgroupIndex, sourceIndex, widget.index ?? 0);
                    }
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    decoration: candidateData.isNotEmpty
                        ? BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Column(
                      children: [
                        // Mostrar gastos solo si el subgrupo está expandido
                        if (_isExpanded && _gastosList.isNotEmpty)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _gastosList.length,
                            itemBuilder: (context, index) {
                              final gasto = _gastosList[index];
                              return Container(
                                key: ValueKey('subgroup_${widget.index}_gasto_${gasto.id}_${index}'),
                                child: LongPressDraggable<Map<String, dynamic>>(
                                  data: {
                                    'gasto': gasto,
                                    'sourceType': 'subgroup',
                                    'sourceIndex': index,
                                    'sourceSubgroupIndex': widget.index,
                                  },
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 300,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: GastoForm(
                                      key: ValueKey('gastoform_reorder_${widget.index}_${gasto.id}_${index}'),
                                      gasto: gasto,
                                      index: index,
                                      onCancel: () {},
                                      onGastoChanged: (updatedGasto) {},
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
                                    print('DEBUG SubgrupoGastoForm: onDragEnd called - wasAccepted: ${details.wasAccepted}');
                                  // Si el drag no fue aceptado por ningún DragTarget, significa que se soltó fuera
                                  if (!details.wasAccepted) {
                                    print('DEBUG SubgrupoGastoForm: Drag not accepted, moving expense out');
                                    if (widget.onMoveExpenseOut != null) {
                                      widget.onMoveExpenseOut!(widget.index ?? 0, index);
                                    }
                                  }
                                },
                                  child: GastoForm(
                                    key: ValueKey('gastoform_draggable_${widget.index}_${gasto.id}_${index}'),
                                    gasto: gasto,
                                    index: index,
                                    onCancel: () => _handleDeleteGasto(gasto.id),
                                    onGastoChanged: (updatedGasto) =>
                                        _handleGastoChanged(gasto.id, updatedGasto),
                                  ),
                                ),
                              );
                            },
                          ),
                        // Área de drop visual - visible cuando se arrastra un gasto o cuando el subgrupo está vacío
                        if (candidateData.isNotEmpty || (_gastosList.isEmpty && _isExpanded))
                          Container(
                            height: 60,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: candidateData.isNotEmpty ? Colors.blue : Colors.grey.withOpacity(0.3),
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                candidateData.isNotEmpty ? 'Soltar aquí' : 'Arrastrar aquí',
                                style: TextStyle(
                                  color: candidateData.isNotEmpty ? Colors.blue : Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
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
