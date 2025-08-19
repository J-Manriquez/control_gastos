import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class GastoForm extends StatefulWidget {
  final Gasto? gasto;
  final VoidCallback? onCancel;
  final Function(Gasto) onGastoChanged;
  final int? index;

  const GastoForm({
    super.key,
    this.gasto,
    this.onCancel,
    required this.onGastoChanged,
    this.index,
  });

  @override
  _GastoFormState createState() => _GastoFormState();
}

class _GastoFormState extends State<GastoForm> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  bool _esAFavor = true;
  DateTime? _fecha;
  double _valorNumerico = 0.0;
  final NumberFormat _numberFormat = NumberFormat('#,###', 'fr_FR');
  // AÑADIDO: Variable para mantener el ID del gasto
  String? _gastoId;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();

    if (widget.gasto != null) {
      // MODIFICADO: Guardar el ID del gasto
      _gastoId = widget.gasto!.id;
      _nombreController.text = widget.gasto!.nombre;
      _valorNumerico = widget.gasto!.valor.abs();
      _valorController.text = _numberFormat.format(_valorNumerico);
      _fecha = widget.gasto!.fecha;
      _esAFavor = widget.gasto!.esAFavor;
    } else {
      // AÑADIDO: Generar nuevo ID si es un gasto nuevo
      _gastoId = DateTime.now().millisecondsSinceEpoch.toString();
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

  // MODIFICADO: Método para crear objeto Gasto actualizado
  Gasto getGasto() {
    return Gasto(
      id: _gastoId, // Usar el ID almacenado
      nombre: _nombreController.text,
      valor: getValorConSigno(),
      fecha: _fecha ?? DateTime.now(),
      esAFavor: _esAFavor,
    );
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
    return _esAFavor ? _valorNumerico : -_valorNumerico;
  }

  void _onValorChanged(String value) {
    try {
      String numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');

      if (numericValue.isNotEmpty) {
        _valorNumerico = double.parse(numericValue);
        String formattedValue = _numberFormat.format(_valorNumerico);

        if (_valorController.text != formattedValue) {
          _valorController.value = TextEditingValue(
            text: formattedValue,
            selection: TextSelection.collapsed(offset: formattedValue.length),
          );
        }
      } else {
        _valorNumerico = 0.0;
      }

      _notifyGastoChanged();
    } catch (e) {
      print('Error en _onValorChanged: $e');
    }
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

    return Card(
      color: colorProvider.colors.backgroundColor,
      margin: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 4, top: 4),
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
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Descripción del Monto',
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
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                ),
                if (widget.onCancel != null)
                  if (_isExpanded)
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: Icon(
                        Icons.delete,
                        color: colorProvider.colors.negativeColor,
                      ),
                    ),
                if (_isExpanded)
                  IconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      color: colorProvider.colors.appBarColor,
                    ),
                    onPressed: () => _selectDate(context),
                  ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.visibility_off : Icons.visibility,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: _toggleExpanded,
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
            if (!_isExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(children: [
                      Text(
                        'Monto:',
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${_valorController.value.text}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _valorNumerico >= 0
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
                          borderSide: BorderSide(
                              color: colorProvider.colors.appBarColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: colorProvider.colors.appBarColor),
                        ),
                      ),
                      style: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
