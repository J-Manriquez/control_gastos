import 'package:flutter/material.dart';
import 'package:control_gastos/forms/subgrupo_gastos_form.dart';
import 'package:control_gastos/forms/gasto_form.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:provider/provider.dart'; // Importa Provider
import 'package:control_gastos/services/provider_colors.dart'; // Importa el proveedor de colores

class InsertGroupScreen extends StatefulWidget {
  final String userUid;
  final Function(int, String)
      onNombreChanged; // Callback para el cambio de nombre del grupo

  const InsertGroupScreen({
    super.key,
    required this.userUid,
    required this.onNombreChanged,
  });

  @override
  _InsertGroupScreenState createState() => _InsertGroupScreenState();
}

class _InsertGroupScreenState extends State<InsertGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<Gasto> _expenses = []; // Lista de gastos individuales
  final List<SubgroupModel> _subgroups = []; // Lista de subgrupos de gastos

  final List<String> _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
  ];

  // Agrega un formulario para un gasto individual
  void _addExpenseForm() {
    setState(() {
      _expenses.add(
          Gasto(nombre: '', valor: 0, fecha: DateTime.now(), esAFavor: true));
    });
  }

  // Agrega un nuevo subgrupo a la lista
  void _addSubgroup() {
    setState(() {
      _subgroups.add(SubgroupModel(
        nombre: 'Subgrupo ${_subgroups.length + 1}',
        expenses: [],
        subtotal: 0,
      ));
    });
  }

  // Actualiza un gasto individual
  void _updateExpense(int index, Gasto gasto) {
    setState(() {
      _expenses[index] = gasto;
    });
  }

  // Actualiza el nombre y subtotal de un subgrupo específico
  void _updateSubgroup(int index, String nombre) {
    setState(() {
      _subgroups[index] = SubgroupModel(
        nombre: nombre,
        expenses: _subgroups[index].expenses,
        subtotal: _subgroups[index].subtotal,
      );
    });
    _calculateTotal(); // Actualiza el total general
    _notifyNombreChanged(index); // Notifica el cambio de nombre del subgrupo
  }

  // Notifica el cambio de nombre del subgrupo a través del callback
  void _notifyNombreChanged(int index) {
    widget.onNombreChanged(index, _subgroups[index].nombre);
  }

  // Actualiza la lista de gastos en un subgrupo específico y recalcula el subtotal
  void _updateSubgroupExpense(int subgroupIndex, List<Gasto> gastos) {
    setState(() {
      _subgroups[subgroupIndex] = SubgroupModel(
        nombre: _subgroups[subgroupIndex].nombre,
        expenses: gastos,
        subtotal: gastos.fold(0, (sum, gasto) => sum + gasto.valor),
      );
    });
    _calculateTotal(); // Actualiza el total general
  }

  // Calcula el total general de todos los gastos y subtotales de subgrupos
  double _calculateTotal() {
    double total = _expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
    for (var subgroup in _subgroups) {
      total += subgroup.subtotal;
    }
    return total;
  }

  // Guarda el grupo de gastos en la base de datos
  void _saveGroup() async {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Debe ingresar un nombre o descropcion para el grupo')),
      );
      return;
    }

    double total = _calculateTotal();

    await FirestoreService().addExpenseGroup(
      widget.userUid,
      _groupNameController.text,
      _expenses,
      _subgroups,
      total: total,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo guardado con éxito')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider =
        Provider.of<ColorProvider>(context); // Accede al proveedor de colores
    double total = _calculateTotal();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Añadir Grupo',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(
            color: colorProvider.colors
                .secondaryTextColor), // Añadir esta línea // Color del AppBar
        actions: [
          IconButton(
            icon: Icon(Icons.save,
                color: colorProvider
                    .colors.secondaryTextColor), // Color icono del appbar
            onPressed: _saveGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _groupNameController,
                          decoration: InputDecoration(
                            labelText: 'Descripcion',
                            labelStyle: TextStyle(
                                color: colorProvider.colors.primaryTextColor),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: colorProvider.colors.appBarColor),
                            ),
                          ),
                          style: TextStyle(
                              color: colorProvider.colors.primaryTextColor),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.arrow_drop_down,
                            color: colorProvider.colors.primaryTextColor),
                        onSelected: (String value) {
                          setState(() {
                            _groupNameController.text = value;
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          return _months.map((String month) {
                            return PopupMenuItem<String>(
                              value: month,
                              child: Text(month,
                                  style: TextStyle(
                                      color: colorProvider
                                          .colors.secondaryTextColor)),
                            );
                          }).toList();
                        },
                        color: colorProvider.colors.appBarColor,
                        offset: const Offset(0, 40),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      return GastoForm(
                        key: ValueKey(index),
                        gasto: _expenses[index],
                        onCancel: () {
                          setState(() {
                            _expenses.removeAt(index);
                          });
                        },
                        onGastoChanged: (gasto) => _updateExpense(index, gasto),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _subgroups.length,
                    itemBuilder: (context, subgroupIndex) {
                      return Column(
                        children: [
                          SubgrupoGastoForm(
                            subgrupoNombre: _subgroups[subgroupIndex].nombre,
                            onNombreChanged: (nombre) =>
                                _updateSubgroup(subgroupIndex, nombre),
                            gastos: _subgroups[subgroupIndex].expenses,
                            onGastosChanged: (gastos) =>
                                _updateSubgroupExpense(subgroupIndex, gastos),
                            onEliminar: () {
                              setState(() {
                                _subgroups.removeAt(subgroupIndex);
                              });
                              _calculateTotal();
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: total >= 0
                ? colorProvider.colors.positiveColor
                : colorProvider
                    .colors.negativeColor, // Color de fondo según el total
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${total.round()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorProvider
                        .colors.secondaryTextColor, // Color del texto del total
                  ),
                ),
                PopupMenuButton<int>(
                  icon: Icon(
                    Icons.add,
                    color: colorProvider
                        .colors.secondaryTextColor, // Color del icono de añadir
                    size: 20,
                  ),
                  onSelected: (int value) {
                    switch (value) {
                      case 1:
                        _addExpenseForm();
                        break;
                      case 2:
                        _addSubgroup();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<int>>[
                      PopupMenuItem<int>(
                        value: 1,
                        child: Text(
                          '• Agregar Monto',
                          style: TextStyle(
                              fontSize: 16,
                              color: colorProvider.colors
                                  .secondaryTextColor), // Color del texto de los elementos
                        ),
                      ),
                      PopupMenuItem<int>(
                        value: 2,
                        child: Text(
                          '• Agregar Subgrupo de Montos',
                          style: TextStyle(
                              fontSize: 16,
                              color: colorProvider.colors
                                  .secondaryTextColor), // Color del texto de los elementos
                        ),
                      ),
                    ];
                  },
                  // Establecer el fondo del PopupMenu igual al color del AppBar
                  offset: const Offset(0, 40),
                  color: colorProvider
                      .colors.appBarColor, // Color de fondo del PopupMenu
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
