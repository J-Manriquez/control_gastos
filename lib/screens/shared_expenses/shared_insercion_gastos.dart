import 'package:control_gastos/widgets/distribution/distribution_type_selector.dart';
import 'package:control_gastos/widgets/distribution/participant_distribution_list.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_gasto_form.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_subgrupo_gasto_form.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/distribution_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class SharedInsertGroupScreen extends StatefulWidget {
  final String userUid;
  final List<String> participantIds;
  final Function(int, String) onNombreChanged;

  const SharedInsertGroupScreen({
    super.key,
    required this.userUid,
    required this.participantIds,
    required this.onNombreChanged,
  });

  @override
  _SharedInsertGroupScreenState createState() =>
      _SharedInsertGroupScreenState();
}

class _SharedInsertGroupScreenState extends State<SharedInsertGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final DistributionService _distributionService = DistributionService();
  final List<Gasto> _expenses = [];
  final List<SubgroupModel> _subgroups = [];
  final List<GlobalKey> _subgroupKeys = [];
  // ignore: unused_field
  bool _isDistributionVisible = false;

  Map<String, DistributionModule> _expenseDistributions = {};
  Map<String, DistributionModule> _subgroupDistributions = {};
  DistributionModule? _totalDistribution;
  bool _showTotalDistribution = false;
  DistributionType _totalDistributionType = DistributionType.equalParts;
  Map<String, bool> _distributionVisibility = {};

  double _total = 0.0;
  bool _isLoading = false;

  Map<String, List<String>> _subgroupExpenseOrder = {};

  // Método para reordenar gastos dentro de un subgrupo
  Future<void> _reorderSubgroupExpenses(String subgroupName, int oldIndex, int newIndex) async {
    // Para inserción, solo manejamos el reordenamiento local
    // El orden se guardará cuando se guarde todo el grupo
    if (!_subgroupExpenseOrder.containsKey(subgroupName)) {
      _subgroupExpenseOrder[subgroupName] = [];
    }
    
    // Si es el mismo índice, es una adición de nuevo gasto
    if (oldIndex == newIndex) {
      // Sincronizar el orden con los gastos actuales del subgrupo
      final subgroupIndex = _subgroups.indexWhere((s) => s.subgroupName == subgroupName);
      if (subgroupIndex != -1) {
        final currentExpenseIds = _subgroups[subgroupIndex].expenses.map((e) => e.id!).toList();
        // Agregar nuevos gastos que no estén en el orden
        for (final expenseId in currentExpenseIds) {
          if (!_subgroupExpenseOrder[subgroupName]!.contains(expenseId)) {
            _subgroupExpenseOrder[subgroupName]!.add(expenseId);
          }
        }
        // Remover gastos que ya no existen
        _subgroupExpenseOrder[subgroupName]!.removeWhere((id) => !currentExpenseIds.contains(id));
      }
      return;
    }
    
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _subgroupExpenseOrder[subgroupName]!.removeAt(oldIndex);
      _subgroupExpenseOrder[subgroupName]!.insert(newIndex, movedId);
    });
  }

  SharedExpenseGroup? _originalGroup;

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

  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _isDistributionVisible = false;
    _calculateTotal();
    _initializeElementOrder();
    // Inicializar visibilidad para todos los gastos y subgrupos
    for (var expense in _expenses) {
      _distributionVisibility[expense.id!] = false;
    }
    for (var subgroup in _subgroups) {
      _distributionVisibility[subgroup.subgroupName] = false;
    }
    _distributionVisibility['total'] = false;
  }

  void _initializeElementOrder() {
    // Inicializar orden de gastos dentro de subgrupos
    for (final subgroup in _subgroups) {
      final subgroupName = subgroup.subgroupName;
      final currentSubgroupExpenseIds = subgroup.expenses.map((e) => e.id!).toList();
      
      if (!_subgroupExpenseOrder.containsKey(subgroupName)) {
        _subgroupExpenseOrder[subgroupName] = [];
      }
      
      _subgroupExpenseOrder[subgroupName]!.removeWhere((id) => !currentSubgroupExpenseIds.contains(id));
      for (final id in currentSubgroupExpenseIds) {
        if (!_subgroupExpenseOrder[subgroupName]!.contains(id)) {
          _subgroupExpenseOrder[subgroupName]!.add(id);
        }
      }
    }
  }

  void _updateDistributionVisibility(bool isVisible) {
    setState(() {
      _isDistributionVisible = isVisible;
    });
  }

  void _calculateTotal() {
    setState(() {
      _total = _expenses.fold(0.0, (sum, expense) => sum + (expense.esAFavor ? expense.valor : -expense.valor)) +
          _subgroups.fold(
              0.0,
              (sum, subgroup) =>
                  sum +
                  subgroup.expenses
                      .fold(0.0, (subSum, exp) => subSum + (exp.esAFavor ? exp.valor : -exp.valor)));
    });
  }

  void _addExpenseForm() {
    setState(() {
      _expenses.add(Gasto(
        nombre: '',
        valor: 0,
        fecha: DateTime.now(),
        esAFavor: true,
      ));
    });
  }

  void _addSubgroup() {
    setState(() {
      _subgroups.add(SubgroupModel(
        subgroupName: '',
        expenses: [],
        subtotal: 0,
      ));
      _subgroupKeys.add(GlobalKey());
    });
  }

  void _handleExpenseChanged(
      int index, Gasto gasto, DistributionModule? distribution) {
    setState(() {
      _expenses[index] = gasto;
      if (distribution != null) {
        _expenseDistributions[gasto.id!] = distribution;
      } else {
        _expenseDistributions.remove(gasto.id);
      }
      _calculateTotal();
    });
  }

  void _handleSubgroupChanged(int index, String nombre, List<Gasto> gastos,
      DistributionModule? distribution) {
    setState(() {
      // Obtener el nombre anterior del subgrupo
      String nombreAnterior = _subgroups[index].subgroupName;
      
      // Actualizar el subgrupo
      _subgroups[index] = SubgroupModel(
        subgroupName: nombre,
        expenses: gastos,
        subtotal: gastos.fold(0.0, (sum, gasto) => sum + (gasto.esAFavor ? gasto.valor : -gasto.valor)),
      );
      
      // Manejar las distribuciones
      if (distribution != null) {
        // Si hay una nueva distribución, usarla
        _subgroupDistributions[nombre] = distribution;
      } else {
        // Si no hay nueva distribución pero el nombre cambió, mover la distribución existente
        if (nombreAnterior != nombre && _subgroupDistributions.containsKey(nombreAnterior)) {
          DistributionModule? existingDistribution = _subgroupDistributions.remove(nombreAnterior);
          if (existingDistribution != null) {
            _subgroupDistributions[nombre] = existingDistribution;
          }
        }
      }
      
      // Limpiar distribuciones huérfanas si el nombre cambió
      if (nombreAnterior != nombre) {
        _subgroupDistributions.remove(nombreAnterior);
        _distributionVisibility.remove(nombreAnterior);
        if (_distributionVisibility.containsKey(nombreAnterior)) {
          _distributionVisibility[nombre] = _distributionVisibility.remove(nombreAnterior) ?? true;
        }
      }
      
      _calculateTotal();
    });
  }

  Future<void> _saveGroup() async {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe ingresar un nombre para el grupo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Obtener nombres actuales de los formularios de subgrupos y actualizar
      for (int i = 0; i < _subgroups.length; i++) {
        final formKey = _subgroupKeys[i];
        final state = formKey.currentState;
         if (state != null) {
           // Usar dynamic para acceder al método público getCurrentName
           final dynamic dynamicState = state;
           try {
             final currentName = dynamicState.getCurrentName() as String;
             if (currentName != _subgroups[i].subgroupName) {
               String nombreAnterior = _subgroups[i].subgroupName;
               setState(() {
                 _subgroups[i] = _subgroups[i].copyWith(
                   subgroupName: currentName,
                   subtotal: _subgroups[i].calculateSubtotal(),
                 );
               });
               
               // Migrar distribuciones si el nombre cambió
               if (_subgroupDistributions.containsKey(nombreAnterior)) {
                 DistributionModule? existingDistribution = _subgroupDistributions.remove(nombreAnterior);
                 if (existingDistribution != null) {
                   _subgroupDistributions[currentName] = existingDistribution;
                 }
               }
             }
           } catch (e) {
             // Log del error si es necesario
           }
         }
      }

      final expenseId = await FirestoreService().createSharedExpenseGroup(
        widget.userUid,
        _groupNameController.text,
        _expenses,
        _subgroups,
        widget.participantIds,
        SharingPermissionType.creatorOnly,
        subgroupExpenseOrder: _subgroupExpenseOrder,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo guardado con éxito')),
        );
        Navigator.of(context).pop(expenseId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el grupo: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Nuevo Gasto Compartido',
          style: TextStyle(
            color: colorProvider.colors.secondaryTextColor,
            fontSize: 20,
          ),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                Icons.save,
                color: colorProvider.colors.secondaryTextColor,
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
                        _buildGroupNameField(),
                        const SizedBox(height: 16),
                        _buildExpensesList(),
                        const SizedBox(height: 16),
                        _buildSubgroupsList(),
                        const SizedBox(height: 16),
                        _buildTotalDistributionSection(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildGroupNameField() {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: 'Nombre del grupo',
              labelStyle: TextStyle(
                color: colorProvider.colors.primaryTextColor,
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: colorProvider.colors.appBarColor,
                ),
              ),
            ),
            style: TextStyle(
              color: colorProvider.colors.primaryTextColor,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.arrow_drop_down,
            color: colorProvider.colors.primaryTextColor,
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
                    color: colorProvider.colors.secondaryTextColor,
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

  Widget _buildExpensesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return SharedGastoForm(
          key: ValueKey(expense.id),
          gasto: expense,
          participantIds: widget.participantIds,
          initialDistribution: _expenseDistributions[expense.id],
          isDistributionVisible: _distributionVisibility[expense.id] ?? false,
          onVisibilityChanged: (value) {
            setState(() {
              _distributionVisibility[expense.id!] = value;
              _updateDistributionVisibility(value);
            });
          },
          onCancel: () {
            setState(() {
              _expenses.removeAt(index);
              if (expense.id != null) {
                _expenseDistributions.remove(expense.id);
              }
              _calculateTotal();
            });
          },
          onGastoChanged: (gasto, distribution) =>
              _handleExpenseChanged(index, gasto, distribution),
          group: _originalGroup!,
        );
      },
    );
  }

  Widget _buildSubgroupsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _subgroups.length,
      itemBuilder: (context, index) {
        final subgroup = _subgroups[index];
        return SharedSubgrupoGastoForm(
          key: _subgroupKeys[index],
          subgrupoNombre: subgroup.subgroupName,
          gastos: subgroup.expenses,
          participantIds: widget.participantIds,
          initialDistribution: _subgroupDistributions[subgroup.subgroupName],
          isDistributionVisible:
              _distributionVisibility[subgroup.subgroupName] ?? false,
          onVisibilityChanged: (value) {
            setState(() {
              _distributionVisibility[subgroup.subgroupName] = value;
              _updateDistributionVisibility(value);
            });
          },
          onNombreChanged: (nombre) =>
              _handleSubgroupChanged(index, nombre, subgroup.expenses, null),
          onGastosChanged: (gastos, distribution) => _handleSubgroupChanged(
              index, subgroup.subgroupName, gastos, distribution),
          onReorderSubgroupExpenses: (subgroupName, oldIndex, newIndex) =>
              _reorderSubgroupExpenses(subgroupName, oldIndex, newIndex),
          onEliminar: () {
            setState(() {
              _subgroupDistributions.remove(subgroup.subgroupName);
              _subgroups.removeAt(index);
              _subgroupKeys.removeAt(index);
              _calculateTotal();
            });
          },
          group: _originalGroup!,
        );
      },
    );
  }

  Widget _buildTotalDistributionSection() {
    final colorProvider = Provider.of<ColorProvider>(context);

    if (_total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Distribuir total del grupo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            Row(
              children: [
                if (_showTotalDistribution)
                  IconButton(
                    icon: Icon(
                      _distributionVisibility['total'] ?? false
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: colorProvider.colors.primaryTextColor,
                    ),
                    onPressed: () {
                      setState(() {
                        bool newValue =
                            !(_distributionVisibility['total'] ?? false);
                        _distributionVisibility['total'] = newValue;
                        _updateDistributionVisibility(newValue);
                      });
                    },
                  ),
                Switch(
                  value: _showTotalDistribution,
                  onChanged: (value) {
                    setState(() {
                      _showTotalDistribution = value;
                      if (value && _totalDistribution == null) {
                        _totalDistribution = DistributionModule(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          targetId: 'total',
                          targetType: DistributionTarget.total,
                          type: _totalDistributionType,
                          shares: _distributionService.calculateEqualShares(
                            widget.participantIds,
                            _total,
                          ),
                          totalAmount: _total,
                          lastModified: DateTime.now(),
                        );
                      }
                    });
                  },
                  activeColor: colorProvider.colors.appBarColor,
                ),
              ],
            ),
          ],
        ),
        if (_showTotalDistribution && _totalDistribution != null) ...[
          const SizedBox(height: 16),
          DistributionTypeSelector(
            selectedType: _totalDistributionType,
            onTypeChanged: (type) {
              setState(() {
                _totalDistributionType = type;
                if (_totalDistribution != null) {
                  if (type == DistributionType.equalParts) {
                    _totalDistribution =
                        _distributionService.recalculateDistribution(
                      _totalDistribution!,
                      _total,
                    );
                  }
                }
              });
            },
          ),
          const SizedBox(height: 16),
          if (_totalDistribution != null)
            ParticipantDistributionList(
              participantIds: widget.participantIds,
              totalAmount: _total,
              distributionType: _totalDistributionType,
              shares: _totalDistribution!.shares,
              onSharesChanged: (shares) {
                setState(() {
                  _totalDistribution = DistributionModule(
                    id: _totalDistribution!.id,
                    targetId: _totalDistribution!.targetId,
                    targetType: DistributionTarget.total,
                    type: _totalDistributionType,
                    shares: shares,
                    totalAmount: _total,
                    lastModified: DateTime.now(),
                  );
                });
              },
            ),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Container(
      color: _total >= 0
          ? colorProvider.colors.positiveColor
          : colorProvider.colors.negativeColor,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: \$${_currencyFormat.format(_total)}',
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
              return [
                PopupMenuItem<int>(
                  value: 1,
                  child: Text(
                    '• Agregar Monto',
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                  ),
                ),
                PopupMenuItem<int>(
                  value: 2,
                  child: Text(
                    '• Agregar Grupo',
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                  ),
                ),
              ];
            },
            color: colorProvider.colors.appBarColor,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}
