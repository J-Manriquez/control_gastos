import 'package:control_gastos/forms/subgrupo_gastos_form.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/forms/gasto_form.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/database/singleton_db.dart';

class InsertGroupScreen extends StatefulWidget {
  final String userUid;

  const InsertGroupScreen({super.key, required this.userUid});

  @override
  _InsertGroupScreenState createState() => _InsertGroupScreenState();
}

class _InsertGroupScreenState extends State<InsertGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<Gasto> _expenses = [];
  final List<List<Gasto>> _subgroupExpenses = []; // Lista para los gastos de cada subgrupo

  final List<String> _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  void _addExpenseForm() {
    setState(() {
      _expenses.add(Gasto(nombre: '', valor: 0, fecha: DateTime.now(), esAFavor: true));
    });
  }

  void _addSubgroup() {
    setState(() {
      _subgroupExpenses.add([]); // Agrega un nuevo subgrupo vacío
    });
  }

  void _updateExpense(int index, Gasto gasto) {
    if (mounted && !context.debugDoingBuild) {
      setState(() {
        _expenses[index] = gasto;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _expenses[index] = gasto;
          });
        }
      });
    }
  }

  void _updateSubgroupExpense(int subgroupIndex, int expenseIndex, Gasto gasto) {
    setState(() {
      _subgroupExpenses[subgroupIndex][expenseIndex] = gasto; // Actualiza el gasto del subgrupo
    });
  }

  double _calculateTotal() {
    // Calcula el total de gastos
    double total = _expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
    // Suma los totales de cada subgrupo
    for (var subgroup in _subgroupExpenses) {
      total += subgroup.fold(0.0, (sum, gasto) => sum + gasto.valor);
    }
    return total;
  }

  void _saveGroup() async {
  if (_groupNameController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debe ingresar un nombre para el grupo')),
    );
    return;
  }

  double total = _calculateTotal(); // Calcular el total antes de guardar

  // Guarda el grupo de gastos y los gastos en Firestore
  await FirestoreService().addExpenseGroup(
    widget.userUid,
    _groupNameController.text,
    _expenses,
    _subgroupExpenses, // Envía los subgrupos para guardar
    total: total, // Envía el total
  );

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grupo de gastos guardado con éxito')),
    );
    Navigator.of(context).pop();
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir gastos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
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
                          decoration: const InputDecoration(labelText: 'Nombre del grupo'),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (String value) {
                          setState(() {
                            _groupNameController.text = value;
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          return _months.map((String month) {
                            return PopupMenuItem<String>(
                              value: month,
                              child: Text(month),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                  // Espacio adicional para evitar que el contenido quede detrás del total
                  const SizedBox(height: 16),
                  // Lista de gastos
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
                  // Sección para subgrupos
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _subgroupExpenses.length,
                    itemBuilder: (context, subgroupIndex) {
                      return Column(
                        children: [
                          SubgrupoGastoForm(
                            subgrupoNombre: 'Subgrupo ${subgroupIndex + 1}',
                            gastos: _subgroupExpenses[subgroupIndex],
                            onGastosChanged: (gastos) {
                              setState(() {
                                _subgroupExpenses[subgroupIndex] = gastos; // Actualiza los gastos del subgrupo
                              });
                            },
                            onEliminar: () {
                              setState(() {
                                _subgroupExpenses.removeAt(subgroupIndex); // Elimina el subgrupo
                              });
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
          // Total fijo en la parte inferior
          Container(
            color: const Color.fromARGB(255, 245, 245, 245),
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${_calculateTotal().round()}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<int>(
                  icon: const Icon(
                    Icons.add,
                    color: Colors.red,
                    size: 20,
                  ),
                  onSelected: (int value) {
                    switch (value) {
                      case 1:
                        // Acción para agregar un gasto
                        _addExpenseForm();
                        break;
                      case 2:
                        // Acción para agregar un subgrupo de gastos
                        _addSubgroup();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<int>>[
                      const PopupMenuItem<int>(
                        value: 1,
                        child: Text(
                          'Agregar Gasto',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                      const PopupMenuItem<int>(
                        value: 2,
                        child: Text(
                          'Agregar Subgrupo de Gastos',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
