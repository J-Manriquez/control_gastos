import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/utils/formato_monto_funcion.dart';
import 'package:control_gastos/forms/subgrupo_gastos_form.dart';
import 'package:control_gastos/forms/gasto_form.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/provider_colors.dart';

class EditGroupScreen extends StatefulWidget {
  final String userUid;
  final String groupId;

  const EditGroupScreen({
    super.key, 
    required this.userUid, 
    required this.groupId
  });

  @override
  _EditGroupScreenState createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<Gasto> _expenses = [];
  final List<SubgroupModel> _subgroups = [];
  final List<String> _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    try {
      GroupModel group = await FirestoreService()
          .getExpenseGroup(widget.userUid, widget.groupId);

      setState(() {
        _groupNameController.text = group.nombre;
        _expenses.clear(); // Limpiamos antes de agregar
        _expenses.addAll(group.expenses);
        _subgroups.clear(); // Limpiamos antes de agregar
        _subgroups.addAll(group.subgroups);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar el grupo de gastos')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _addExpenseForm() {
    setState(() {
      _expenses.add(
        Gasto(nombre: '', valor: 0, fecha: DateTime.now(), esAFavor: true)
      );
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
    if (index >= 0 && index < _expenses.length) {
      setState(() {
        _expenses[index] = gasto;
      });
    }
  }

  void _removeExpense(int index) {
    if (index >= 0 && index < _expenses.length) {
      setState(() {
        _expenses.removeAt(index);
      });
    }
  }

  double _calculateTotal() {
    double total = _expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
    
    for (var subgroup in _subgroups) {
      total += subgroup.expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
    }
    
    return total;
  }

  void _updateSubgroupExpense(int subgroupIndex, List<Gasto> gastos) {
    if (subgroupIndex >= 0 && subgroupIndex < _subgroups.length) {
      setState(() {
        double subtotal = gastos.fold(0.0, (sum, gasto) => sum + gasto.valor);
        _subgroups[subgroupIndex] = SubgroupModel(
          nombre: _subgroups[subgroupIndex].nombre,
          expenses: gastos,
          subtotal: subtotal,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final double total = _calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar Grupo',
          style: TextStyle(
            color: colorProvider.colors.secondaryTextColor, 
            fontSize: 20
          ),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(
          color: colorProvider.colors.secondaryTextColor
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color: colorProvider.colors.secondaryTextColor
            ),
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
                      // Nombre del grupo y selector de mes
                      _buildGroupNameField(colorProvider),
                      const SizedBox(height: 16),
                      
                      // Lista de gastos individuales
                      ..._expenses.asMap().entries.map((entry) {
                        return GastoForm(
                          key: ValueKey('gasto_${entry.key}'),
                          gasto: entry.value,
                          onCancel: () => _removeExpense(entry.key),
                          onGastoChanged: (gasto) => _updateExpense(entry.key, gasto),
                        );
                      }).toList(),
                      
                      const SizedBox(height: 16),
                      
                      // Lista de subgrupos
                      ..._subgroups.asMap().entries.map((entry) {
                        return Padding(
                          key: ValueKey('subgroup_${entry.key}'),
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SubgrupoGastoForm(
                            subgrupoNombre: entry.value.nombre,
                            onNombreChanged: (nombre) => _updateSubgroup(entry.key, nombre),
                            gastos: entry.value.expenses,
                            onGastosChanged: (gastos) => 
                                _updateSubgroupExpense(entry.key, gastos),
                            onEliminar: () {
                              setState(() {
                                _subgroups.removeAt(entry.key);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              // Barra inferior con total y botones de agregar
              _buildBottomBar(colorProvider, total),
            ],
          ),
    );
  }

  Widget _buildGroupNameField(ColorProvider colorProvider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: 'Descripción',
              labelStyle: TextStyle(
                color: colorProvider.colors.primaryTextColor
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: colorProvider.colors.appBarColor
                ),
              ),
            ),
            style: TextStyle(
              color: colorProvider.colors.primaryTextColor
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.arrow_drop_down,
            color: colorProvider.colors.primaryTextColor
          ),
          onSelected: (String value) {
            setState(() {
              _groupNameController.text = value;
            });
          },
          itemBuilder: (BuildContext context) {
            return _months.map((String month) {
              return PopupMenuItem<String>(
                value: month,
                child: Text(
                  month,
                  style: TextStyle(
                    color: colorProvider.colors.secondaryTextColor
                  ),
                ),
              );
            }).toList();
          },
          color: colorProvider.colors.appBarColor,
        ),
      ],
    );
  }

  Widget _buildBottomBar(ColorProvider colorProvider, double total) {
    return Container(
      color: total >= 0
          ? colorProvider.colors.positiveColor
          : colorProvider.colors.negativeColor,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: \$${FormatNumberFrench(total)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorProvider.colors.secondaryTextColor,
            ),
          ),
          _buildAddButton(colorProvider),
        ],
      ),
    );
  }

  Widget _buildAddButton(ColorProvider colorProvider) {
    return PopupMenuButton<int>(
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
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<int>(
          value: 1,
          child: Text(
            '• Agregar Monto',
            style: TextStyle(
              fontSize: 16,
              color: colorProvider.colors.secondaryTextColor
            ),
          ),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: Text(
            '• Agregar Subgrupo de Montos',
            style: TextStyle(
              fontSize: 16,
              color: colorProvider.colors.secondaryTextColor
            ),
          ),
        ),
      ],
      color: colorProvider.colors.appBarColor,
    );
  }

  void _updateSubgroup(int index, String nombre) {
    if (index >= 0 && index < _subgroups.length) {
      setState(() {
        _subgroups[index] = SubgroupModel(
          nombre: nombre,
          expenses: _subgroups[index].expenses,
          subtotal: _subgroups[index].subtotal,
        );
      });
    }
  }

  Future<void> _saveGroup() async {
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
          const SnackBar(content: Text('Grupo de gastos actualizado con éxito')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el grupo de gastos: $e')),
        );
      }
    }
  }
}