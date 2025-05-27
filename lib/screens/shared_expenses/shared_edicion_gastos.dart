import 'package:control_gastos/widgets/distribution/distribution_type_selector.dart';
import 'package:control_gastos/widgets/distribution/participant_distribution_list.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_gasto_form.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_subgrupo_gasto_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/distribution_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class SharedEditGroupScreen extends StatefulWidget {
  final String userUid;
  final String groupId;
  final List<String> participantIds;

  const SharedEditGroupScreen({
    super.key,
    required this.userUid,
    required this.groupId,
    required this.participantIds,
  });

  @override
  _SharedEditGroupScreenState createState() => _SharedEditGroupScreenState();
}

class _SharedEditGroupScreenState extends State<SharedEditGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final DistributionService _distributionService = DistributionService();
  final CustomLogger _logger = CustomLogger();

  List<String> _participantIds = [];
  List<Gasto> _expenses = [];
  List<SubgroupModel> _subgroups = [];
  Map<String, DistributionModule> _expenseDistributions = {};
  Map<String, DistributionModule> _subgroupDistributions = {};
  DistributionModule? _totalDistribution;
  bool _showTotalDistribution = false;
  DistributionType _totalDistributionType = DistributionType.equalParts;
  Map<String, bool> _distributionVisibility = {};
  bool _isDistributionVisible = false;

  double _total = 0.0;
  bool _isLoading = true;
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
    _loadSharedGroupData();
    for (var expense in _expenses) {
      _distributionVisibility[expense.id!] = true;
    }
    for (var subgroup in _subgroups) {
      _distributionVisibility[subgroup.subgroupName] = true;
    }
    _distributionVisibility['total'] = true;
  }

  void _updateDistributionVisibility(bool isVisible) {
    setState(() {
      _isDistributionVisible = isVisible;
    });
  }

  Future<void> _loadSharedGroupData() async {
    try {
      _logger.logInfo('Cargando datos del grupo compartido...');

      final group =
          await FirestoreService().getSharedExpenseGroup(widget.groupId);

      setState(() {
        _originalGroup = group;
        _participantIds = group.participants
            .map((p) => p.userId)
            .toList(); // Actualizar la lista de participantes
        _groupNameController.text = group.nombre;
        _expenses = List.from(group.expenses);
        _subgroups = List.from(group.subgroups);
        _expenseDistributions = Map.from(group.expenseDistributions);
        _subgroupDistributions = Map.from(group.subgroupDistributions);
        _totalDistribution = group.totalDistribution;
        _showTotalDistribution = group.totalDistribution != null;
        if (_totalDistribution != null) {
          _totalDistributionType = _totalDistribution!.type;
        }
        _calculateTotal();
        _isLoading = false;
      });

      _logger.logInfo('Datos del grupo cargados exitosamente');
    } catch (e) {
      _logger.logError('Error al cargar datos del grupo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el grupo: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _calculateTotal() {
    setState(() {
      _total = _expenses.fold(0.0, (sum, expense) => sum + expense.valor) +
          _subgroups.fold(
              0.0,
              (sum, subgroup) =>
                  sum +
                  subgroup.expenses
                      .fold(0.0, (subSum, exp) => subSum + exp.valor));
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
        subgroupName: 'Subgrupo ${_subgroups.length + 1}',
        expenses: [],
        subtotal: 0,
      ));
    });
  }

  void _handleExpenseChanged(
      int index, Gasto gasto, DistributionModule? distribution) {
    setState(() {
      // Asegúrate de que el gasto tenga un ID válido
      if (gasto.id == null) {
        gasto = gasto.copyWith(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_$index');
      }

      _expenses[index] = gasto;
      if (distribution != null && gasto.id != null) {
        _expenseDistributions[gasto.id!] = distribution;
      } else if (gasto.id != null) {
        _expenseDistributions.remove(gasto.id);
      }
      _calculateTotal();
    });
  }

  void _handleSubgroupChanged(int index, String nombre, List<Gasto> gastos,
      DistributionModule? distribution) {
    setState(() {
      _subgroups[index] = SubgroupModel(
        subgroupName: nombre,
        expenses: gastos,
        subtotal: gastos.fold(0.0, (sum, gasto) => sum + gasto.valor),
      );
      if (distribution != null) {
        _subgroupDistributions[nombre] = distribution;
      } else {
        _subgroupDistributions.remove(nombre);
      }
      _calculateTotal();
    });
  }

  Future<void> _saveGroup() async {
    // En tu widget o bloque donde se llama a _saveGroup
    print('Usuario autenticado ID: ${FirebaseAuth.instance.currentUser?.uid}');
    print('Creator ID del grupo: ${_originalGroup?.creatorId}');
    print('Permission Type del grupo: ${_originalGroup?.permissionType.toString()}');
    print('Participantes del grupo: ${_originalGroup?.participants.map((p) => {'userId': p.userId, 'status': p.status.toString()}).toList()}');
    
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe ingresar un nombre para el grupo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      _logger.logInfo('Iniciando proceso de guardado del grupo');

      // Verificar IDs de gastos
      for (int i = 0; i < _expenses.length; i++) {
        _logger.logInfo(
            'Gasto $i: ID = ${_expenses[i].id}, Nombre = ${_expenses[i].nombre}');
        if (_expenses[i].id == null) {
          String newId = 'expense_${DateTime.now().millisecondsSinceEpoch}_$i';
          _logger.logInfo('Generando nuevo ID para gasto $i: $newId');
          _expenses[i] = _expenses[i].copyWith(id: newId);
        }
      }

      // Verificar IDs en las distribuciones
      _logger.logInfo(
          'Verificando distribuciones de gastos: ${_expenseDistributions.length} encontradas');
      Map<String, DistributionModule> validatedExpenseDistributions = {};
      _expenseDistributions.forEach((key, value) {
        _logger.logInfo(
            'Verificando distribución con clave: $key, objetivo: ${value.targetId}');
        if (key != null && key.isNotEmpty) {
          validatedExpenseDistributions[key] = value;
        } else {
          _logger.logError(
              'Encontrada clave nula o vacía en _expenseDistributions');
        }
      });

      // Verificar IDs de subgrupos
      _logger
          .logInfo('Verificando subgrupos: ${_subgroups.length} encontrados');
      for (int i = 0; i < _subgroups.length; i++) {
        _logger.logInfo(
            'Subgrupo $i: Nombre = ${_subgroups[i].subgroupName}, ${_subgroups[i].expenses.length} gastos');
        // Verificar cada gasto dentro del subgrupo
        for (int j = 0; j < _subgroups[i].expenses.length; j++) {
          Gasto gasto = _subgroups[i].expenses[j];
          _logger.logInfo(
              '  Gasto $j del subgrupo $i: ID = ${gasto.id}, Nombre = ${gasto.nombre}');
          if (gasto.id == null) {
            String newId =
                'subgroup_${i}_expense_${DateTime.now().millisecondsSinceEpoch}_$j';
            _logger.logInfo(
                '  Generando nuevo ID para gasto $j del subgrupo $i: $newId');
            _subgroups[i].expenses[j] = gasto.copyWith(id: newId);
          }
        }
      }

      // Verificar distribuciones de subgrupos
      _logger.logInfo(
          'Verificando distribuciones de subgrupos: ${_subgroupDistributions.length} encontradas');
      Map<String, DistributionModule> validatedSubgroupDistributions = {};
      _subgroupDistributions.forEach((key, value) {
        _logger.logInfo(
            'Verificando distribución de subgrupo con clave: $key, objetivo: ${value.targetId}');
        if (key != null && key.isNotEmpty) {
          validatedSubgroupDistributions[key] = value;
        } else {
          _logger.logError(
              'Encontrada clave nula o vacía en _subgroupDistributions');
        }
      });

      // Verificar distribución total
      if (_showTotalDistribution && _totalDistribution != null) {
        _logger.logInfo(
            'Distribución total activa: ID = ${_totalDistribution!.id}, Objetivo = ${_totalDistribution!.targetId}');
      } else {
        _logger.logInfo('Sin distribución total activa');
      }

      _logger.logInfo('Creando objeto SharedExpenseGroup actualizado');
      final updatedGroup = SharedExpenseGroup(
        id: widget.groupId,
        nombre: _groupNameController.text,
        total: _total,
        expenses: _expenses,
        subgroups: _subgroups,
        creationDate: _originalGroup!.creationDate,
        creatorId: _originalGroup!.creatorId,
        participants: _originalGroup!.participants,
        permissionType: _originalGroup!.permissionType,
        version: _originalGroup!.version,
        lastModified: DateTime.now(),
        expenseDistributions: validatedExpenseDistributions,
        subgroupDistributions: validatedSubgroupDistributions,
        totalDistribution: _showTotalDistribution ? _totalDistribution : null,
      );

      _logger
          .logInfo('Objeto SharedExpenseGroup creado, procediendo a guardarlo');

      // Crear un mapa para inspección antes de guardar
      Map<String, dynamic> groupMap = updatedGroup.toMap();
      _logger
          .logInfo('Mapa generado para Firebase: ${groupMap.keys.join(', ')}');

      // Guardando en Firebase
      _logger
          .logInfo('Llamando a updateSharedExpense con ID: ${widget.groupId}');
      await FirestoreService()
          .sharedExpenseService
          .updateSharedExpense(widget.groupId, updatedGroup);

      _logger.logInfo('Grupo actualizado con éxito');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo actualizado con éxito')),
        );
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      _logger.logError('Error al actualizar grupo: $e');
      _logger.logError('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el grupo: $e')),
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
      appBar: AppBar(
        title: Text(
          'Editar Gasto Compartido',
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
          participantIds: _participantIds,
          initialDistribution: _expenseDistributions[expense.id],
          isDistributionVisible: _distributionVisibility[expense.id] ?? true,
          onVisibilityChanged: (value) {
            setState(() {
              _distributionVisibility[expense.id!] = value;
              _updateDistributionVisibility(value); // Llamar aquí
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
          subgrupoNombre: subgroup.subgroupName,
          gastos: subgroup.expenses,
          participantIds: _participantIds,
          initialDistribution: _subgroupDistributions[subgroup.subgroupName],
          onVisibilityChanged: (value) {
            setState(() {
              _distributionVisibility[subgroup.subgroupName] = value;
              _updateDistributionVisibility(
                  value); // Llamar aquí si es necesario actualizar algo en el padre
            });
          },
          isDistributionVisible:
              _distributionVisibility[subgroup.subgroupName] ?? true,
          onNombreChanged: (nombre) =>
              _handleSubgroupChanged(index, nombre, subgroup.expenses, null),
          onGastosChanged: (gastos, distribution) => _handleSubgroupChanged(
              index, subgroup.subgroupName, gastos, distribution),
          onEliminar: () {
            setState(() {
              _subgroupDistributions.remove(subgroup.subgroupName);
              _subgroups.removeAt(index);
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
                      _distributionVisibility['total'] ?? true
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: colorProvider.colors.primaryTextColor,
                    ),
                    onPressed: () {
                      setState(() {
                        bool newValue =
                            !(_distributionVisibility['total'] ?? true);
                        _distributionVisibility['total'] = newValue;
                        _updateDistributionVisibility(newValue); // Llamar aquí
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
                            _participantIds,
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
          if (_distributionVisibility['total'] ?? true) ...[
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
                    '• Agregar Gasto',
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                  ),
                ),
                PopupMenuItem<int>(
                  value: 2,
                  child: Text(
                    '• Agregar Subgrupo',
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
