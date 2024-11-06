import 'package:flutter/material.dart';
import 'package:control_gastos/forms/subgrupo_gastos_form.dart';
import 'package:control_gastos/forms/gasto_form.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class EditGroupScreen extends StatefulWidget {
  final String userUid;
  final String groupId;

  const EditGroupScreen(
      {super.key, required this.userUid, required this.groupId});

  @override
  _EditGroupScreenState createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<Gasto> _expenses = [];
  final List<SubgroupModel> _subgroups = [];
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

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    try {
      GroupModel group = await FirestoreService()
          .getExpenseGroup(widget.userUid, widget.groupId);

      setState(() {
        _groupNameController.text = group.nombre;
        _expenses.addAll(group.expenses);
        _subgroups.addAll(group.subgroups);
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar el grupo de gastos')),
      );
      Navigator.of(context).pop();
    }
  }

  void _addExpenseForm() {
    setState(() {
      _expenses.add(
          Gasto(nombre: '', valor: 0, fecha: DateTime.now(), esAFavor: true));
    });
  }

  void _addSubgroup() {
    setState(() {
      _subgroups.add(SubgroupModel(
        nombre: 'Subgrupo ${_subgroups.length + 1}',
        expenses: [],
        subtotal: 0,
      ));
    });
  }

  void _updateExpense(int index, Gasto gasto) {
    setState(() {
      _expenses[index] = gasto;
    });
  }

  void _updateSubgroup(int index, String nombre) {
    setState(() {
      _subgroups[index] = SubgroupModel(
        nombre: nombre,
        expenses: _subgroups[index].expenses,
        subtotal: _subgroups[index].subtotal,
      );
      _calculateTotal();
    });
  }

  void _updateSubgroupExpense(int subgroupIndex, List<Gasto> gastos) {
    setState(() {
      _subgroups[subgroupIndex] = SubgroupModel(
        nombre: _subgroups[subgroupIndex].nombre,
        expenses: gastos,
        subtotal: gastos.fold(0, (sum, gasto) => sum + gasto.valor),
      );
      _calculateTotal();
    });
  }

  double _calculateTotal() {
    double total = _expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
    for (var subgroup in _subgroups) {
      total += subgroup.subtotal;
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

    try {
      await FirestoreService().updateExpenseGroup(
        widget.userUid,
        widget.groupId,
        _groupNameController.text,
        _expenses,
        _subgroups,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Grupo de gastos actualizado con éxito')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el grupo de gastos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    double total = _calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar Grupo',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
        actions: [
          IconButton(
            icon: Icon(Icons.save,
                color: colorProvider.colors.secondaryTextColor),
            onPressed: _saveGroup,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            )
          : Column(
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
                                      color: colorProvider
                                          .colors.primaryTextColor),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color:
                                            colorProvider.colors.appBarColor),
                                  ),
                                ),
                                style: TextStyle(
                                    color:
                                        colorProvider.colors.primaryTextColor),
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
                              onGastoChanged: (gasto) =>
                                  _updateExpense(index, gasto),
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
                                  subgrupoNombre:
                                      _subgroups[subgroupIndex].nombre,
                                  onNombreChanged: (nombre) =>
                                      _updateSubgroup(subgroupIndex, nombre),
                                  gastos: _subgroups[subgroupIndex].expenses,
                                  onGastosChanged: (gastos) =>
                                      _updateSubgroupExpense(
                                          subgroupIndex, gastos),
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
                      : colorProvider.colors.negativeColor,
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
                          color: colorProvider.colors.secondaryTextColor,
                        ),
                      ),
                      PopupMenuButton<int>(
                        icon: Icon(
                          Icons.add,
                          color: colorProvider.colors.secondaryTextColor,
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
                                    color: colorProvider
                                        .colors.secondaryTextColor),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 2,
                              child: Text(
                                '• Agregar Subgrupo de Montos',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: colorProvider
                                        .colors.secondaryTextColor),
                              ),
                            ),
                          ];
                        },
                        offset: const Offset(0, 40),
                        color: colorProvider.colors.appBarColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
