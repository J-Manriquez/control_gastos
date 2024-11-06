import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

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
  DateTime? _fecha;
  final NumberFormat _numberFormat = NumberFormat('#,###', 'fr_FR');

  @override
  void initState() {
    super.initState();

    if (widget.gasto != null) {
      _nombreController.text = widget.gasto!.nombre;
      // Formatear el valor inicial con el formato francés
      _valorController.text =
          _numberFormat.format(widget.gasto!.valor.abs().round());
      _fecha = widget.gasto!.fecha;
      _esAFavor = widget.gasto!.esAFavor;
    } else {
      _fecha = DateTime.now();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyGastoChanged();
      }
    });

    _nombreController.addListener(_notifyGastoChanged);
    _valorController.addListener(_notifyGastoChanged);
  }

  @override
  void dispose() {
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    DateTime initialDate = _fecha ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorProvider.colors.appBarColor,
              onPrimary: colorProvider.colors.secondaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _fecha = picked;
        _notifyGastoChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fecha seleccionada: ${DateFormat('yyyy-MM-dd').format(_fecha!)}',
              style: TextStyle(color: colorProvider.colors.secondaryTextColor),
            ),
            backgroundColor: colorProvider.colors.appBarColor,
          ),
        );
      });
    }
  }

  double getValorConSigno() {
    // Remover los espacios del formato francés y cualquier otro caracter no numérico
    String valorLimpio =
        _valorController.text.replaceAll(RegExp(r'[^0-9]'), '');
    // Convertir a double después de limpiar el string
    double valor = double.tryParse(valorLimpio) ?? 0.0;
    return _esAFavor ? valor : -valor;
  }

  Gasto getGasto() {
    return Gasto(
      id: widget.gasto?.id,
      nombre: _nombreController.text,
      valor: getValorConSigno(),
      fecha: _fecha ?? DateTime.now(),
      esAFavor: _esAFavor,
    );
  }

  void _onValorChanged(String value) {
  // Remover cualquier caracter no numérico
  String numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');
  
  if (numericValue.isNotEmpty) {
    // Convertir a entero
    int valorEntero = int.tryParse(numericValue) ?? 0;
    // Formatear con el formato francés
    String formattedValue = _numberFormat.format(valorEntero);
    
    // Actualizar el controlador solo si el valor es diferente
    if (_valorController.text != formattedValue) {
      _valorController.value = TextEditingValue(
        text: formattedValue,
        selection: TextSelection.collapsed(offset: formattedValue.length),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Container(
      decoration: BoxDecoration(
        color: colorProvider.colors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
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
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Descripcion del Monto',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: colorProvider.colors.appBarColor),
                      ),
                      focusedBorder: OutlineInputBorder(
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
                    Icons.calendar_today,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: () => _selectDate(context),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(
                      Icons.delete,
                      color: colorProvider.colors.negativeColor,
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
                    color: _esAFavor
                        ? colorProvider.colors.positiveColor
                        : colorProvider.colors.primaryTextColor
                            .withOpacity(0.3),
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
                    color: !_esAFavor
                        ? colorProvider.colors.negativeColor
                        : colorProvider.colors.primaryTextColor
                            .withOpacity(0.3),
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
                    onChanged: _onValorChanged,
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: colorProvider.colors.appBarColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: colorProvider.colors.appBarColor),
                      ),
                    ),
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
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
