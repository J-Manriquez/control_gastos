import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/version_vote_model.dart';
import 'package:control_gastos/services/shared_expense_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class VersionDetailsScreen extends StatefulWidget {
  final String expenseId;
  final String version;
  final String currentUserId;

  const VersionDetailsScreen({
    Key? key,
    required this.expenseId,
    required this.version,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _VersionDetailsScreenState createState() => _VersionDetailsScreenState();
}

class _VersionDetailsScreenState extends State<VersionDetailsScreen> {
  final CustomLogger _logger = CustomLogger();
  final SharedExpenseService _sharedExpenseService = SharedExpenseService();
  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  Map<String, dynamic>? _versionData;
  Map<String, dynamic>? _changeDetails;
  SharedExpenseGroup? _originalGroup;
  SharedExpenseGroup? _updatedGroup;
  List<VersionVoteModel> _votes = [];
  String _versionStatus = 'pending';
  bool _userHasVoted = false;
  VoteStatus? _userVoteStatus;
  SharingPermissionType _permissionType = SharingPermissionType.allParticipants;
  String _modifierName = '';
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener datos de la versión
      final versionDoc = await FirebaseFirestore.instance
          .collection('sharedExpenses')
          .doc(widget.expenseId)
          .collection('versions')
          .doc(widget.version)
          .get();

      if (!versionDoc.exists) {
        throw Exception('Versión no encontrada');
      }

      _versionData = versionDoc.data();
      _versionStatus = _versionData?['status'] ?? 'pending';
      _changeDetails = _versionData?['changeDetails'] ?? {};

      // Obtener datos del grupo original
      _originalGroup =
          await _sharedExpenseService.getSharedExpense(widget.expenseId);

      // Obtener datos del grupo actualizado
      _updatedGroup = SharedExpenseGroup.fromMap(_versionData?['data'] ?? {});

      // Obtener votos
      List<dynamic> votesData = _versionData?['votes'] ?? [];
      _votes = votesData.map((vote) => VersionVoteModel.fromMap(vote)).toList();

      // Verificar si el usuario actual ya votó
      var userVote =
          _votes.where((vote) => vote.userId == widget.currentUserId).toList();
      _userHasVoted = userVote.isNotEmpty;
      if (_userHasVoted) {
        _userVoteStatus = userVote.first.status;
      }

      // Obtener tipo de permiso
      _permissionType = _originalGroup?.permissionType ??
          SharingPermissionType.allParticipants;

      // Obtener nombre del modificador
      String modifierId = _versionData?['modifierId'] ?? '';
      if (modifierId.isNotEmpty) {
        final modifierDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(modifierId)
            .get();
        _modifierName =
            modifierDoc.data()?['username'] ?? 'Usuario desconocido';
      }

      // Cargar nombres de usuarios para participantes
      await _loadUserNames();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.logError('Error al cargar datos de versión: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _loadUserNames() async {
    Set<String> userIds = {};

    // Recopilar todos los IDs de usuarios
    if (_originalGroup != null) {
      for (var participant in _originalGroup!.participants) {
        userIds.add(participant.userId);
      }
    }
    if (_updatedGroup != null) {
      for (var participant in _updatedGroup!.participants) {
        userIds.add(participant.userId);
      }
    }

    // Obtener nombres de usuarios
    for (String userId in userIds) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          _userNames[userId] =
              userDoc.data()?['username'] ?? 'Usuario desconocido';
        }
      } catch (e) {
        _userNames[userId] = 'Usuario desconocido';
      }
    }
  }

  Future<void> _submitVote(VoteStatus status) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _sharedExpenseService.respondToVersionVote(
        widget.expenseId,
        widget.version,
        widget.currentUserId,
        status,
      );

      // Recargar datos después de votar
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tu voto ha sido registrado')),
      );
    } catch (e) {
      _logger.logError('Error al enviar voto: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar voto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context).colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalles de Cambios',
          style:
              TextStyle(color: colorProvider.secondaryTextColor, fontSize: 20),
        ),
        iconTheme: IconThemeData(color: colorProvider.secondaryTextColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVersionInfo(),
                  SizedBox(height: 16.0),
                  if (_versionStatus == 'pending' && !_userHasVoted)
                    _buildVotingButtons(),
                  SizedBox(height: 24.0),
                  _buildVotesSection(),
                  SizedBox(height: 16.0),
                  _buildDetailedChangesSection(),
                ],
              ),
            ),
    );
  }

  String formatTimestamp(dynamic timestampInput) {
    if (timestampInput == null) {
      return 'No disponible';
    }

    DateTime dateTime;

    if (timestampInput is Timestamp) {
      dateTime = timestampInput.toDate();
    } else if (timestampInput is Map &&
        timestampInput.containsKey('seconds') &&
        timestampInput.containsKey('nanoseconds')) {
      final int seconds = timestampInput['seconds'] ?? 0;
      final int nanoseconds = timestampInput['nanoseconds'] ?? 0;
      final int milliseconds = seconds * 1000;
      final int totalMilliseconds = milliseconds + (nanoseconds ~/ 1000000);
      dateTime = DateTime.fromMillisecondsSinceEpoch(totalMilliseconds);
    } else {
      // Fallback or error handling if the input is neither Timestamp nor the expected Map
      return 'Formato de fecha inválido';
    }

    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  Widget _buildVersionInfo() {
    final String fechaFormateada = formatTimestamp(_versionData?['timestamp']);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cambios propuestos por $_modifierName',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.0),
            Text(
              'Versión: ${widget.version}',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 8.0),
            Text(
              'Fecha: $fechaFormateada',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 8.0),
            Row(
              children: [
                Text(
                  'Estado: ',
                  style: TextStyle(fontSize: 16.0),
                ),
                _buildStatusChip(_versionStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Pendiente';
        break;
      case 'accepted':
        chipColor = Colors.green;
        statusText = 'Aceptado';
        break;
      case 'rejected':
        chipColor = Colors.red;
        statusText = 'Rechazado';
        break;
      default:
        chipColor = Colors.grey;
        statusText = 'Desconocido';
    }

    return Chip(
      label: Text(
        statusText,
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: chipColor,
    );
  }

  Widget _buildDetailedChangesSection() {
    if (_changeDetails == null || _changeDetails!.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No se encontraron detalles de cambios'),
        ),
      );
    }

    List<Widget> changeWidgets = [];

    // Cambios en el nombre
    if (_changeDetails!.containsKey('name_change')) {
      changeWidgets.add(_buildNameChangeWidget(_changeDetails!['name_change']));
    }

    // Cambios en el monto total
    if (_changeDetails!.containsKey('amount_change')) {
      changeWidgets
          .add(_buildAmountChangeWidget(_changeDetails!['amount_change']));
    }

    // Cambios en gastos
    if (_changeDetails!.containsKey('expense_changes')) {
      changeWidgets
          .add(_buildExpenseChangesWidget(_changeDetails!['expense_changes']));
    }

    // Cambios en subgrupos
    if (_changeDetails!.containsKey('subgroup_changes')) {
      changeWidgets.add(
          _buildSubgroupChangesWidget(_changeDetails!['subgroup_changes']));
    }

    // Cambios en participantes
    if (_changeDetails!.containsKey('participant_changes')) {
      changeWidgets.add(_buildParticipantChangesWidget(
          _changeDetails!['participant_changes']));
    }

    // Cambios en distribuciones
    if (_changeDetails!.containsKey('distribution_changes')) {
      changeWidgets.add(_buildDistributionChangesWidget(
          _changeDetails!['distribution_changes']));
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cambios Detallados',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            ...changeWidgets,
          ],
        ),
      ),
    );
  }

  Widget _buildNameChangeWidget(Map<String, dynamic> nameChange) {
    return _buildChangeCard(
      'Nombre del Gasto',
      [
        _buildChangeItem(
          'Nombre',
          nameChange['old']?.toString() ?? '',
          nameChange['new']?.toString() ?? '',
        ),
      ],
    );
  }

  Widget _buildAmountChangeWidget(Map<String, dynamic> amountChange) {
    return _buildChangeCard(
      'Monto Total',
      [
        _buildChangeItem(
          'Total',
          '\$${currencyFormat.format(amountChange['old'] ?? 0)}',
          '\$${currencyFormat.format(amountChange['new'] ?? 0)}',
        ),
      ],
    );
  }

  Widget _buildExpenseChangesWidget(Map<String, dynamic> expenseChanges) {
    List<Widget> widgets = [];

    // Gastos añadidos
    if (expenseChanges['added'] != null &&
        (expenseChanges['added'] as List).isNotEmpty) {
      widgets.add(_buildAddedExpensesWidget(expenseChanges['added']));
    }

    // Gastos removidos
    if (expenseChanges['removed'] != null &&
        (expenseChanges['removed'] as List).isNotEmpty) {
      widgets.add(_buildRemovedExpensesWidget(expenseChanges['removed']));
    }

    // Gastos modificados
    if (expenseChanges['modified'] != null &&
        (expenseChanges['modified'] as List).isNotEmpty) {
      widgets.add(_buildModifiedExpensesWidget(expenseChanges['modified']));
    }

    return _buildChangeCard('Cambios en Gastos', widgets);
  }

  Widget _buildAddedExpensesWidget(List<dynamic> addedExpenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastos Añadidos:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        ...addedExpenses
            .map((expense) => Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 4.0),
                  child: Text(
                    '+ ${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
                    style: TextStyle(color: Colors.green),
                  ),
                ))
            .toList(),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildRemovedExpensesWidget(List<dynamic> removedExpenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastos Removidos:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        ...removedExpenses
            .map((expense) => Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 4.0),
                  child: Text(
                    '- ${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
                    style: TextStyle(color: Colors.red),
                  ),
                ))
            .toList(),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildModifiedExpensesWidget(List<dynamic> modifiedExpenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastos Modificados:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        ...modifiedExpenses.map((expense) {
          List<Widget> modifications = [];
          Map<String, dynamic> mods = expense['modifications'] ?? {};

          mods.forEach((field, change) {
            String fieldName = _getFieldDisplayName(field);
            String oldValue = _formatFieldValue(field, change['old']);
            String newValue = _formatFieldValue(field, change['new']);

            modifications.add(
              Padding(
                padding: EdgeInsets.only(left: 32.0, top: 2.0),
                child: Text(
                  '$fieldName: $oldValue → $newValue',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            );
          });

          return Padding(
            padding: EdgeInsets.only(left: 16.0, top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '~ ${expense['nombre']}',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                ...modifications,
              ],
            ),
          );
        }).toList(),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildSubgroupChangesWidget(Map<String, dynamic> subgroupChanges) {
    List<Widget> widgets = [];

    // Subgrupos añadidos
    if (subgroupChanges['added'] != null &&
        (subgroupChanges['added'] as List).isNotEmpty) {
      widgets.add(_buildAddedSubgroupsWidget(subgroupChanges['added']));
    }

    // Subgrupos removidos
    if (subgroupChanges['removed'] != null &&
        (subgroupChanges['removed'] as List).isNotEmpty) {
      widgets.add(_buildRemovedSubgroupsWidget(subgroupChanges['removed']));
    }

    // Subgrupos modificados
    if (subgroupChanges['modified'] != null &&
        (subgroupChanges['modified'] as List).isNotEmpty) {
      widgets.add(_buildModifiedSubgroupsWidget(subgroupChanges['modified']));
    }

    return _buildChangeCard('Cambios en Subgrupos', widgets);
  }

  Widget _buildAddedSubgroupsWidget(List<dynamic> addedSubgroups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subgrupos Añadidos:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        ...addedSubgroups
            .map((subgroup) => Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+ ${subgroup['nombre']}',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      ...((subgroup['gastos'] as List?) ?? [])
                          .map((gasto) => Padding(
                                padding: EdgeInsets.only(left: 16.0, top: 2.0),
                                child: Text(
                                  '  • ${gasto['nombre']}: \$${currencyFormat.format(gasto['valor'])}',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 12),
                                ),
                              ))
                          .toList(),
                    ],
                  ),
                ))
            .toList(),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildRemovedSubgroupsWidget(List<dynamic> removedSubgroups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subgrupos Removidos:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        ...removedSubgroups
            .map((subgroup) => Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '- ${subgroup['nombre']}',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      ...((subgroup['gastos'] as List?) ?? [])
                          .map((gasto) => Padding(
                                padding: EdgeInsets.only(left: 16.0, top: 2.0),
                                child: Text(
                                  '  • ${gasto['nombre']}: \$${currencyFormat.format(gasto['valor'])}',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ))
                          .toList(),
                    ],
                  ),
                ))
            .toList(),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildModifiedSubgroupsWidget(List<dynamic> modifiedSubgroups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subgrupos Modificados:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        ...modifiedSubgroups.map((subgroup) {
          List<Widget> modifications = [];
          Map<String, dynamic> mods = subgroup['modifications'] ?? {};

          // Cambios en el nombre del subgrupo
          if (mods.containsKey('nombre')) {
            modifications.add(
              Padding(
                padding: EdgeInsets.only(left: 32.0, top: 2.0),
                child: Text(
                  'Nombre: ${mods['nombre']['old']} → ${mods['nombre']['new']}',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            );
          }

          // Cambios en gastos del subgrupo
          if (mods.containsKey('gastos')) {
            modifications.add(_buildSubgroupExpenseChanges(mods['gastos']));
          }

          return Padding(
            padding: EdgeInsets.only(left: 16.0, top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '~ ${subgroup['nombre']}',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                ...modifications,
              ],
            ),
          );
        }).toList(),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildSubgroupExpenseChanges(Map<String, dynamic> expenseChanges) {
    List<Widget> widgets = [];

    if (expenseChanges['added'] != null) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            'Gastos añadidos:',
            style: TextStyle(
                color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var expense in expenseChanges['added']) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 32.0, top: 2.0),
            child: Text(
              '+ ${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
              style: TextStyle(color: Colors.green, fontSize: 11),
            ),
          ),
        );
      }
    }

    if (expenseChanges['removed'] != null) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            'Gastos removidos:',
            style: TextStyle(
                color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var expense in expenseChanges['removed']) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 32.0, top: 2.0),
            child: Text(
              '- ${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
              style: TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
        );
      }
    }

    if (expenseChanges['modified'] != null) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            'Gastos modificados:',
            style: TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var expense in expenseChanges['modified']) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 32.0, top: 2.0),
            child: Text(
              '~ ${expense['nombre']}',
              style: TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );

        Map<String, dynamic> mods = expense['modifications'] ?? {};
        mods.forEach((field, change) {
          String fieldName = _getFieldDisplayName(field);
          String oldValue = _formatFieldValue(field, change['old']);
          String newValue = _formatFieldValue(field, change['new']);

          widgets.add(
            Padding(
              padding: EdgeInsets.only(left: 48.0, top: 1.0),
              child: Text(
                '$fieldName: $oldValue → $newValue',
                style: TextStyle(color: Colors.orange, fontSize: 10),
              ),
            ),
          );
        });
      }
    }

    return Column(children: widgets);
  }

  Widget _buildParticipantChangesWidget(
      Map<String, dynamic> participantChanges) {
    List<Widget> widgets = [];

    // Participantes añadidos
    if (participantChanges['added'] != null &&
        (participantChanges['added'] as List).isNotEmpty) {
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participantes Añadidos:',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            ...((participantChanges['added'] as List)
                .map((participant) => Padding(
                      padding: EdgeInsets.only(left: 16.0, top: 4.0),
                      child: Text(
                        '+ ${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                        style: TextStyle(color: Colors.green),
                      ),
                    ))
                .toList()),
            SizedBox(height: 8.0),
          ],
        ),
      );
    }

    // Participantes removidos
    if (participantChanges['removed'] != null &&
        (participantChanges['removed'] as List).isNotEmpty) {
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participantes Removidos:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            ...((participantChanges['removed'] as List)
                .map((participant) => Padding(
                      padding: EdgeInsets.only(left: 16.0, top: 4.0),
                      child: Text(
                        '- ${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                        style: TextStyle(color: Colors.red),
                      ),
                    ))
                .toList()),
            SizedBox(height: 8.0),
          ],
        ),
      );
    }

    // Participantes modificados
    if (participantChanges['modified'] != null &&
        (participantChanges['modified'] as List).isNotEmpty) {
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participantes Modificados:',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            ...((participantChanges['modified'] as List).map((participant) {
              List<Widget> modifications = [];
              Map<String, dynamic> mods = participant['modifications'] ?? {};

              mods.forEach((field, change) {
                String fieldName = _getFieldDisplayName(field);
                String oldValue = _formatFieldValue(field, change['old']);
                String newValue = _formatFieldValue(field, change['new']);

                modifications.add(
                  Padding(
                    padding: EdgeInsets.only(left: 32.0, top: 2.0),
                    child: Text(
                      '$fieldName: $oldValue → $newValue',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                );
              });

              return Padding(
                padding: EdgeInsets.only(left: 16.0, top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '~ ${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    ...modifications,
                  ],
                ),
              );
            }).toList()),
            SizedBox(height: 8.0),
          ],
        ),
      );
    }

    return _buildChangeCard('Cambios en Participantes', widgets);
  }

  Widget _buildDistributionChangesWidget(
      Map<String, dynamic> distributionChanges) {
    List<Widget> widgets = [];

    // Distribuciones de gastos
    if (distributionChanges['expense_distributions'] != null) {
      widgets.add(_buildDistributionSection(
        'Distribuciones de Gastos',
        distributionChanges['expense_distributions'],
      ));
    }

    // Distribuciones de subgrupos
    if (distributionChanges['subgroup_distributions'] != null) {
      widgets.add(_buildDistributionSection(
        'Distribuciones de Subgrupos',
        distributionChanges['subgroup_distributions'],
      ));
    }

    return _buildChangeCard('Cambios en Distribuciones', widgets);
  }

  Widget _buildDistributionSection(String title, List<dynamic> distributions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        SizedBox(height: 8.0),
        ...distributions.map((dist) => _buildDistributionItem(dist)).toList(),
        SizedBox(height: 12.0),
      ],
    );
  }

  Widget _buildDistributionItem(Map<String, dynamic> distribution) {
    String type = distribution['type'] ?? '';
    String targetId = distribution['targetId'] ?? '';
    Color typeColor;

    switch (type) {
      case 'added':
        typeColor = Colors.green;
        break;
      case 'removed':
        typeColor = Colors.red;
        break;
      case 'modified':
        typeColor = Colors.orange;
        break;
      default:
        typeColor = Colors.grey;
    }

    List<Widget> content = [
      Text(
        '${type.toUpperCase()}: $targetId',
        style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
      ),
    ];

    if (type == 'modified' && distribution['modifications'] != null) {
      content
          .add(_buildDistributionModifications(distribution['modifications']));
    } else if (distribution['distribution'] != null) {
      content.add(_buildDistributionDetails(distribution['distribution']));
    }

    return Padding(
      padding: EdgeInsets.only(left: 16.0, top: 4.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }

  Widget _buildDistributionModifications(Map<String, dynamic> modifications) {
    List<Widget> widgets = [];

    if (modifications['totalAmount'] != null) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            'Monto total: \$${currencyFormat.format(modifications['totalAmount']['old'])} → \$${currencyFormat.format(modifications['totalAmount']['new'])}',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ),
      );
    }

    if (modifications['shares'] != null) {
      widgets.add(_buildShareModifications(modifications['shares']));
    }

    return Column(children: widgets);
  }

  Widget _buildShareModifications(Map<String, dynamic> shareChanges) {
    List<Widget> widgets = [];

    if (shareChanges['added'] != null &&
        (shareChanges['added'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            'Participaciones añadidas:',
            style: TextStyle(
                color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var share in shareChanges['added']) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 32.0, top: 2.0),
            child: Text(
              '+ ${_userNames[share['userId']] ?? 'Usuario'}: \$${currencyFormat.format(share['amount'])} (${share['percentage']?.toStringAsFixed(1)}%)',
              style: TextStyle(color: Colors.green, fontSize: 11),
            ),
          ),
        );
      }
    }

    if (shareChanges['removed'] != null &&
        (shareChanges['removed'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            'Participaciones removidas:',
            style: TextStyle(
                color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var share in shareChanges['removed']) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 32.0, top: 2.0),
            child: Text(
              '- ${_userNames[share['userId']] ?? 'Usuario'}: \$${currencyFormat.format(share['amount'])} (${share['percentage']?.toStringAsFixed(1)}%)',
              style: TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
        );
      }
    }

    if (shareChanges['modified'] != null &&
        (shareChanges['modified'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            'Participaciones modificadas:',
            style: TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var share in shareChanges['modified']) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 32.0, top: 2.0),
            child: Text(
              '~ ${_userNames[share['userId']] ?? 'Usuario'}:',
              style: TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );

        Map<String, dynamic> mods = share['modifications'] ?? {};
        mods.forEach((field, change) {
          String oldValue = field == 'amount'
              ? '\$${currencyFormat.format(change['old'])}'
              : '${change['old']?.toStringAsFixed(1)}%';
          String newValue = field == 'amount'
              ? '\$${currencyFormat.format(change['new'])}'
              : '${change['new']?.toStringAsFixed(1)}%';

          widgets.add(
            Padding(
              padding: EdgeInsets.only(left: 48.0, top: 1.0),
              child: Text(
                '${field == 'amount' ? 'Monto' : 'Porcentaje'}: $oldValue → $newValue',
                style: TextStyle(color: Colors.orange, fontSize: 10),
              ),
            ),
          );
        });
      }
    }

    return Column(children: widgets);
  }

  Widget _buildDistributionDetails(Map<String, dynamic> distribution) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0, top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo: ${distribution['type']}',
            style: TextStyle(fontSize: 12),
          ),
          Text(
            'Monto total: \$${currencyFormat.format(distribution['totalAmount'])}',
            style: TextStyle(fontSize: 12),
          ),
          if (distribution['shares'] != null)
            ...((distribution['shares'] as List)
                .map((share) => Text(
                      '  • ${_userNames[share['userId']] ?? 'Usuario'}: \$${currencyFormat.format(share['amount'])} (${share['percentage']?.toStringAsFixed(1)}%)',
                      style: TextStyle(fontSize: 11),
                    ))
                .toList()),
        ],
      ),
    );
  }

  Widget _buildChangeCard(String title, List<Widget> children) {
    if (children.isEmpty) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8.0),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildChangeItem(String field, String oldValue, String newValue) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$field:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    oldValue,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                Icon(Icons.arrow_forward, size: 16.0),
                Expanded(
                  child: Text(
                    newValue,
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'nombre':
        return 'Nombre';
      case 'valor':
        return 'Valor';
      case 'fecha':
        return 'Fecha';
      case 'esAFavor':
        return 'Tipo';
      case 'status':
        return 'Estado';
      case 'customPercentage':
        return 'Porcentaje personalizado';
      default:
        return field;
    }
  }

  String _formatFieldValue(String field, dynamic value) {
    switch (field) {
      case 'valor':
        return '\$${currencyFormat.format(value ?? 0)}';
      case 'fecha':
        if (value is String) {
          try {
            DateTime date = DateTime.parse(value);
            return DateFormat('dd/MM/yyyy').format(date);
          } catch (e) {
            return value;
          }
        }
        return value?.toString() ?? '';
      case 'esAFavor':
        return value == true ? 'Ingreso' : 'Gasto';
      case 'status':
        return _formatParticipantStatus(value?.toString() ?? '');
      case 'customPercentage':
        return value != null ? '${value}%' : 'No definido';
      default:
        return value?.toString() ?? '';
    }
  }

  String _formatParticipantStatus(String status) {
    switch (status) {
      case 'ParticipantStatus.accepted':
        return 'Aceptado';
      case 'ParticipantStatus.pending':
        return 'Pendiente';
      case 'ParticipantStatus.rejected':
        return 'Rechazado';
      default:
        return status;
    }
  }

  Widget _buildVotesSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votos',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            _votes.isEmpty
                ? Text('No hay votos registrados')
                : Column(
                    children:
                        _votes.map((vote) => _buildVoteItem(vote)).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteItem(VersionVoteModel vote) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(vote.userId)
          .get(),
      builder: (context, snapshot) {
        String username = 'Usuario desconocido';
        if (snapshot.hasData && snapshot.data!.exists) {
          username = snapshot.data!.get('username') ?? 'Usuario desconocido';
        }

        Color statusColor;
        IconData statusIcon;

        switch (vote.status) {
          case VoteStatus.accepted:
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
            break;
          case VoteStatus.rejected:
            statusColor = Colors.red;
            statusIcon = Icons.cancel;
            break;
          default:
            statusColor = Colors.orange;
            statusIcon = Icons.hourglass_empty;
        }

        return ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text(username),
          subtitle: Text(
            'Votó: ${vote.timestamp.toString()}',
            style: TextStyle(fontSize: 12.0),
          ),
          trailing: Icon(
            statusIcon,
            color: statusColor,
          ),
        );
      },
    );
  }

  Widget _buildVotingButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          icon: Icon(Icons.check, color: Colors.white),
          label: Text('Aceptar Cambios'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          ),
          onPressed: () => _submitVote(VoteStatus.accepted),
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.close, color: Colors.white),
          label: Text('Rechazar Cambios'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          ),
          onPressed: () => _submitVote(VoteStatus.rejected),
        ),
      ],
    );
  }
}
