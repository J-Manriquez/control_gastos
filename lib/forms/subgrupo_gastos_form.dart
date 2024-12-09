import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/forms/gasto_form.dart';
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
  List<Gasto> _gastos = [];
  // Variable para mantener el subtotal local
  double _subtotal = 0.0;

  @override
  void initState() {
    super.initState();

    _nombreSubgrupoController =
        TextEditingController(text: widget.subgrupoNombre);
    _nombreSubgrupoController.addListener(_notifyNombreChanged);

    _gastos = List.from(widget.gastos);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyGastosChanged();
      }
    });

    _calculateSubtotal();
  }

  @override
  void didUpdateWidget(covariant SubgrupoGastoForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subgrupoNombre != widget.subgrupoNombre) {
      _nombreSubgrupoController.text = widget.subgrupoNombre;
    }
    if (oldWidget.gastos != widget.gastos) {
      _calculateSubtotal();
    }
  }

  @override
  void dispose() {
    _nombreSubgrupoController.removeListener(_notifyNombreChanged);
    _nombreSubgrupoController.dispose();
    super.dispose();
  }

  void _agregarGasto() {
    setState(() {
      _gastos.add(Gasto(
        nombre: '',
        valor: 0,
        fecha: DateTime.now(),
        esAFavor: true,
      ));
      _notifyGastosChanged();
    });
  }

  // Método para manejar la eliminación de gastos
  void _handleDeleteGasto(int index) {
    setState(() {
      // Crear una nueva lista con los gastos actuales
      List<Gasto> updatedGastos = List<Gasto>.from(widget.gastos);
      // Eliminar el gasto específico
      updatedGastos.removeAt(index);
      // Notificar el cambio al padre
      widget.onGastosChanged(updatedGastos);
      // Recalcular el subtotal
      _calculateSubtotal();
    });
  }

  // Método para manejar cambios en los gastos
  void _handleGastoChanged(int index, Gasto updatedGasto) {
    setState(() {
      // Crear una nueva lista con los gastos actuales
      List<Gasto> updatedGastos = List<Gasto>.from(widget.gastos);
      // Actualizar el gasto específico
      updatedGastos[index] = updatedGasto;
      // Notificar el cambio al padre
      widget.onGastosChanged(updatedGastos);
      // Recalcular el subtotal
      _calculateSubtotal();
    });
  }

  void _notifyGastosChanged() {
    if (mounted) {
      widget.onGastosChanged(_gastos);
    }
  }

  void _notifyNombreChanged() {
    if (mounted) {
      widget.onNombreChanged(_nombreSubgrupoController.text);
    }
  }

  double _calcularTotalGastos() {
    return _gastos.fold(0.0, (total, gasto) => total + gasto.valor);
  }

  void _calculateSubtotal() {
    setState(() {
      _subtotal = widget.gastos.fold(0.0, (sum, gasto) => sum + gasto.valor);
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
            ...widget.gastos.asMap().entries.map((entry) {
              int index = entry.key;
              Gasto gasto = entry.value;
              return GastoForm(
                key: ValueKey('${widget.subgrupoNombre}_gasto_$index'),
                gasto: gasto,
                onCancel: () => _handleDeleteGasto(index),
                onGastoChanged: (updatedGasto) =>
                    _handleGastoChanged(index, updatedGasto),
              );
            }).toList(),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Subgrupo:',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                  Text(
                    '\$${_subtotal.round()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _calcularTotalGastos() >= 0
                          ? colorProvider.colors.positiveColor
                          : colorProvider.colors.negativeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
