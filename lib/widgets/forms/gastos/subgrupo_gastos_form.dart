import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/widgets/forms/gastos/gasto_form.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

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
  late final TextEditingController _nombreSubgrupoController;
  // AÑADIDO: Mapa para mantener los gastos indexados por ID
  late Map<String, Gasto> _gastosMap;

  @override
  void initState() {
    super.initState();
    _nombreSubgrupoController = TextEditingController(text: widget.subgrupoNombre);
    _nombreSubgrupoController.addListener(_notifyNombreChanged);
    // AÑADIDO: Inicializar el mapa de gastos
    _initializeGastosMap();
  }

  // AÑADIDO: Método para inicializar el mapa de gastos
  void _initializeGastosMap() {
    _gastosMap = {
      for (var gasto in widget.gastos)
        gasto.id ?? DateTime.now().millisecondsSinceEpoch.toString(): gasto,
    };
  }

  @override
  void didUpdateWidget(SubgrupoGastoForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subgrupoNombre != oldWidget.subgrupoNombre) {
      _nombreSubgrupoController.text = widget.subgrupoNombre;
    }
    // AÑADIDO: Actualizar el mapa cuando cambien los gastos externos
    if (widget.gastos != oldWidget.gastos) {
      _initializeGastosMap();
    }
  }

  void _notifyNombreChanged() {
    widget.onNombreChanged(_nombreSubgrupoController.text);
  }

  void _agregarGasto() {
    // MODIFICADO: Crear nuevo gasto con ID único
    final newGasto = Gasto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: '',
      valor: 0,
      fecha: DateTime.now(),
      esAFavor: true,
    );

    setState(() {
      // MODIFICADO: Agregar al mapa y notificar
      _gastosMap[newGasto.id!] = newGasto;
      widget.onGastosChanged(_gastosMap.values.toList());
    });
  }

  // MODIFICADO: Método para manejar la eliminación de gastos
  void _handleDeleteGasto(String? gastoId) {
    if (gastoId == null) return;
    
    setState(() {
      _gastosMap.remove(gastoId);
      widget.onGastosChanged(_gastosMap.values.toList());
    });
  }

  // MODIFICADO: Método para actualizar un gasto
  void _handleGastoChanged(String? gastoId, Gasto updatedGasto) {
    if (gastoId == null) return;

    setState(() {
      _gastosMap[gastoId] = updatedGasto;
      widget.onGastosChanged(_gastosMap.values.toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

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
                      labelText: 'Nombre del subgrupo',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: colorProvider.colors.appBarColor),
                      ),
                    ),
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: _agregarGasto,
                ),
                if (widget.onEliminar != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: colorProvider.colors.negativeColor,
                    ),
                    onPressed: widget.onEliminar,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // MODIFICADO: Usar el mapa para renderizar los gastos
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreSubgrupoController.removeListener(_notifyNombreChanged);
    _nombreSubgrupoController.dispose();
    super.dispose();
  }
}