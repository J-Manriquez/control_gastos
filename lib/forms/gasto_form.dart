import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:control_gastos/models/gastos_model.dart';

class GastoForm extends StatefulWidget {
  final Gasto? gasto;
  final VoidCallback? onCancel;
  final Function(Gasto) onGastoChanged;

  const GastoForm({
    super.key,
    this.gasto,
    this.onCancel,
    required this.onGastoChanged,
  });

  @override
  _GastoFormState createState() => _GastoFormState();
}

class _GastoFormState extends State<GastoForm> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  bool _esAFavor = true;
  DateTime? _fecha; // Almacenamos la fecha seleccionada aquí

  @override
  void initState() {
    super.initState();
    
    // Inicializar los controladores
    if (widget.gasto != null) {
      _nombreController.text = widget.gasto!.nombre;
      _valorController.text = widget.gasto!.valor.abs().toString();
      _fecha = widget.gasto!.fecha; // Establecer la fecha inicial
      _esAFavor = widget.gasto!.esAFavor;
    } else {
      _fecha = DateTime.now(); // Si no hay gasto, se establece la fecha actual
    }

    // Programar la notificación inicial para después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyGastoChanged();
      }
    });

    // Agregar listeners a los controladores para notificar cambios
    _nombreController.addListener(_notifyGastoChanged);
    _valorController.addListener(_notifyGastoChanged);
  }

  @override
  void dispose() {
    // Remover los listeners antes de disponer los controladores
    _nombreController.removeListener(_notifyGastoChanged);
    _valorController.removeListener(_notifyGastoChanged);
    
    _nombreController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  void _notifyGastoChanged() {
    if (mounted) {
      widget.onGastoChanged(getGasto());
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = _fecha ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) {
      setState(() {
        _fecha = picked; // Guardamos la nueva fecha seleccionada
        _notifyGastoChanged();
        // Muestra un mensaje con la fecha seleccionada
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fecha seleccionada: ${DateFormat('yyyy-MM-dd').format(_fecha!)}')),
        );
      });
    }
  }

  double getValorConSigno() {
    double valor = double.tryParse(_valorController.text) ?? 0;
    return _esAFavor ? valor.abs() : -valor.abs();
  }

  Gasto getGasto() {
    return Gasto(
      id: widget.gasto?.id,
      nombre: _nombreController.text,
      valor: getValorConSigno(),
      fecha: _fecha ?? DateTime.now(), // Usa la fecha almacenada o la actual
      esAFavor: _esAFavor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del gasto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context), // Abre el selector de fecha
                ),
                if (widget.onCancel != null)
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.delete),
                  // label: const Text('Eliminar gasto'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.red,
                    // backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: _esAFavor ? Colors.green : Colors.grey,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _esAFavor = true;
                      _notifyGastoChanged();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle,
                    color: !_esAFavor ? Colors.red : Colors.grey,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _esAFavor = false;
                      _notifyGastoChanged();
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _valorController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor del gasto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
