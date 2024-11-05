import 'package:flutter/material.dart';
import 'package:control_gastos/forms/gasto_form.dart';
import 'package:control_gastos/forms/subgrupo_gastos_form.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/database/singleton_db.dart';

class EditGroupScreen extends StatefulWidget {
  final String userUid;
  final String groupId;
  final String initialGroupName;
  final List<Gasto> initialExpenses;
  final List<List<Gasto>> initialSubgroupExpenses;

  const EditGroupScreen({
    super.key, 
    required this.userUid,
    required this.groupId,
    required this.initialGroupName,
    required this.initialExpenses,
    required this.initialSubgroupExpenses,
  });

  @override
  _EditGroupScreenState createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  late TextEditingController _groupNameController;
  late List<Gasto> _expenses;
  late List<List<Gasto>> _subgroupExpenses;
  bool _hasChanges = false;

  final List<String> _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController(text: widget.initialGroupName);
    _expenses = List.from(widget.initialExpenses);
    _subgroupExpenses = List.from(widget.initialSubgroupExpenses);

    // Agregar listener para detectar cambios
    _groupNameController.addListener(_onChangeMade);
  }

  void _onChangeMade() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _addExpenseForm() {
    setState(() {
      _expenses.add(Gasto(nombre: '', valor: 0, fecha: DateTime.now(), esAFavor: true));
      _onChangeMade();
    });
  }

  void _addSubgroup() {
    setState(() {
      _subgroupExpenses.add([]);
      _onChangeMade();
    });
  }

  void _updateExpense(int index, Gasto gasto) {
    if (mounted && !context.debugDoingBuild) {
      setState(() {
        _expenses[index] = gasto;
        _onChangeMade();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _expenses[index] = gasto;
            _onChangeMade();
          });
        }
      });
    }
  }

  void _removeExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
      _onChangeMade();
    });
  }

  void _updateSubgroupExpense(int subgroupIndex, List<Gasto> gastos) {
    setState(() {
      _subgroupExpenses[subgroupIndex] = gastos;
      _onChangeMade();
    });
  }

  void _removeSubgroup(int index) {
    setState(() {
      _subgroupExpenses.removeAt(index);
      _onChangeMade();
    });
  }

  double _calculateTotal() {
    double total = _expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
    for (var subgroup in _subgroupExpenses) {
      total += subgroup.fold(0.0, (sum, gasto) => sum + gasto.valor);
    }
    return total;
  }

  Future<void> _saveChanges() async {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe ingresar un nombre para el grupo')),
      );
      return;
    }

    try {
      await FirestoreService().updateExpenseGroup(
        widget.userUid,
        widget.groupId,
        _groupNameController.text,
        _expenses,
        _subgroupExpenses,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados con éxito')),
        );
        setState(() {
          _hasChanges = false;
        });
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar los cambios: $e')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Hay cambios sin guardar. ¿Desea descartarlos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar grupo de gastos'),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveChanges,
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
                            decoration: const InputDecoration(
                              labelText: 'Nombre del grupo',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (String value) {
                            setState(() {
                              _groupNameController.text = value;
                              _onChangeMade();
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
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: GastoForm(
                            key: ValueKey('expense_$index'),
                            gasto: _expenses[index],
                            onCancel: () => _removeExpense(index),
                            onGastoChanged: (gasto) => _updateExpense(index, gasto),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _subgroupExpenses.length,
                      itemBuilder: (context, subgroupIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: SubgrupoGastoForm(
                            key: ValueKey('subgroup_$subgroupIndex'),
                            subgrupoNombre: 'Subgrupo ${subgroupIndex + 1}',
                            gastos: _subgroupExpenses[subgroupIndex],
                            onGastosChanged: (gastos) => 
                                _updateSubgroupExpense(subgroupIndex, gastos),
                            onEliminar: () => _removeSubgroup(subgroupIndex),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: const Color.fromARGB(255, 245, 245, 245),
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: \$${_calculateTotal().round()}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold
                    ),
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
                          _addExpenseForm();
                          break;
                        case 2:
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
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}