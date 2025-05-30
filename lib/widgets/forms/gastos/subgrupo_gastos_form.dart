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

  const SubgrupoGastoForm({
    super.key,
    required this.subgrupoNombre,
    required this.onNombreChanged,
    required this.gastos,
    required this.onGastosChanged,
    this.onEliminar,
  });

  @override
  _SubgrupoGastoFormState createState() => _SubgrupoGastoFormState();
}

class _SubgrupoGastoFormState extends State<SubgrupoGastoForm> {
  late TextEditingController _nombreSubgrupoController;
  late Map<String, Gasto> _gastosMap;
  bool _nombreModificado = false;
  bool _isExpanded =
      true; // Nuevo estado para controlar si el contenido está expandido

  @override
  void initState() {
    super.initState();
    _nombreSubgrupoController =
        TextEditingController(text: widget.subgrupoNombre);
    _nombreSubgrupoController.addListener(_onTextChanged);
    _initializeGastosMap();
    CustomLogger().logInfo(
        'SubgrupoGastoForm inicializado con nombre: ${widget.subgrupoNombre}');
  }

  void _onTextChanged() {
    // Marcamos que el nombre ha sido modificado manualmente
    _nombreModificado = true;

    // Notificar el cambio al componente padre
    final nombre = _nombreSubgrupoController.text.trim();
    CustomLogger()
        .logInfo('Notificando cambio de nombre en tiempo real: $nombre');
    widget.onNombreChanged(nombre);
  }

  void _initializeGastosMap() {
    _gastosMap = {
      for (var gasto in widget.gastos)
        gasto.id ?? DateTime.now().millisecondsSinceEpoch.toString(): gasto,
    };
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

    // Actualizar el mapa cuando cambien los gastos externos
    if (widget.gastos != oldWidget.gastos) {
      _initializeGastosMap();
    }
  }

  void _notifyNombreChanged() {
    final nombre = _nombreSubgrupoController.text.trim();
    CustomLogger().logInfo('Notificando cambio de nombre: $nombre');
    widget.onNombreChanged(nombre);
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
      widget.onGastosChanged(_gastosMap.values.toList());
    });
  }

  void _handleDeleteGasto(String? gastoId) {
    if (gastoId == null) return;

    setState(() {
      _gastosMap.remove(gastoId);
      widget.onGastosChanged(_gastosMap.values.toList());
    });
  }

  void _handleGastoChanged(String? gastoId, Gasto updatedGasto) {
    if (gastoId == null) return;

    setState(() {
      _gastosMap[gastoId] = updatedGasto;
      widget.onGastosChanged(_gastosMap.values.toList());
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
    final double subtotal =
        _gastosMap.values.fold(0.0, (sum, gasto) => sum + gasto.valor);

    return Container(
      decoration: BoxDecoration(
        color: colorProvider.colors.backgroundColor,
        borderRadius: BorderRadius.circular(10.0),
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
                          'Nombre del subgrupo', // Usar hintText en lugar de labelText
                      hintStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor
                              .withOpacity(0.6)),
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
                    onSubmitted: (_) {
                      _notifyNombreChanged();
                      _nombreModificado = false;
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
                  tooltip:
                      _isExpanded ? 'Ocultar contenido' : 'Mostrar contenido',
                ),
              ],
            ),
            // Mostrar subtotal cuando el contenido está contraído
            if (!_isExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
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
            // Mostrar los gastos solo si el contenido está expandido
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              ..._gastosMap.entries.map((entry) {
                return GastoForm(
                  key: ValueKey(entry.key),
                  gasto: entry.value,
                  onCancel: () => _handleDeleteGasto(entry.key),
                  onGastoChanged: (updatedGasto) =>
                      _handleGastoChanged(entry.key, updatedGasto),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreSubgrupoController.removeListener(_onTextChanged);
    _nombreSubgrupoController.dispose();
    super.dispose();
  }
}
