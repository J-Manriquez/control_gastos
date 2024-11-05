import 'package:control_gastos/forms/gasto_form.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';

class SubgrupoGastoForm extends StatefulWidget {
  final String subgrupoNombre;
  final List<Gasto> gastos;
  final Function(List<Gasto>) onGastosChanged;
  final VoidCallback? onEliminar;

  const SubgrupoGastoForm({
    super.key,
    required this.subgrupoNombre,
    required this.gastos,
    required this.onGastosChanged,
    this.onEliminar,
  });

  @override
  _SubgrupoGastoFormState createState() => _SubgrupoGastoFormState();
}

class _SubgrupoGastoFormState extends State<SubgrupoGastoForm> {
  final TextEditingController _nombreSubgrupoController =
      TextEditingController();
  List<Gasto> _gastos = [];

  @override
  void initState() {
    super.initState();
    _nombreSubgrupoController.text = widget.subgrupoNombre;
    _gastos = List.from(widget.gastos);

    // Programar la notificación inicial para después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyGastosChanged();
      }
    });

    // Agregar listener al controlador para notificar cambios
    _nombreSubgrupoController.addListener(_notifyGastosChanged);
  }

  @override
  void dispose() {
    _nombreSubgrupoController.removeListener(_notifyGastosChanged);
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

  double _calcularTotalGastos() {
    return _gastos.fold(0.0, (total, gasto) => total + gasto.valor);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 245, 245, 245),
        borderRadius: BorderRadius.circular(10.0),
      ),
      // margin: const EdgeInsets.symmetric(vertical: 8.0),
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
                    decoration: const InputDecoration(
                      labelText: 'Nombre del subgrupo',
                      // border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _agregarGasto,
                ),
                if (widget.onEliminar != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: widget.onEliminar,
                    color: Colors.red,
                  ),
              ],
            ),
            // const SizedBox(height: 2),
            // Lista de gastos
            ..._gastos.map((gasto) {
              int index = _gastos.indexOf(gasto);
              return GastoForm(
                key: ValueKey(index),
                gasto: gasto,
                onCancel: () => _eliminarGasto(index),
                onGastoChanged: (updatedGasto) =>
                    _actualizarGasto(index, updatedGasto),
              );
            }).toList(),
            // const SizedBox(height: 16),
            Container(
              // padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                // color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Subgrupo:',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '\$${_calcularTotalGastos().round()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _calcularTotalGastos() >= 0
                          ? Colors.green
                          : Colors.red,
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
