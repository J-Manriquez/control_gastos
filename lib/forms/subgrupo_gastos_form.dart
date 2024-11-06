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
  }

  @override
  void didUpdateWidget(covariant SubgrupoGastoForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subgrupoNombre != widget.subgrupoNombre) {
      _nombreSubgrupoController.text = widget.subgrupoNombre;
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

  void _eliminarGasto(int index) {
    setState(() {
      _gastos.removeAt(index);
      _notifyGastosChanged();
    });
  }

  void _actualizarGasto(int index, Gasto gasto) {
    setState(() {
      _gastos[index] = gasto;
      _notifyGastosChanged();
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
            ..._gastos.map((gasto) {
              int index = _gastos.indexOf(gasto);
              return GastoForm(
                key: ValueKey(gasto.id), // Asumiendo que Gasto tiene un ID
                gasto: gasto,
                onCancel: () => _eliminarGasto(index),
                onGastoChanged: (updatedGasto) =>
                    _actualizarGasto(index, updatedGasto),
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
                    '\$${_calcularTotalGastos().round()}',
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
