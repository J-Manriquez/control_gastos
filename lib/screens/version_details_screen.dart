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
                mainAxisSize: MainAxisSize.min,
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
      color: Colors.white,
      elevation: 6,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
      elevation: 6,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
          nameChange['old'] ?? 'No definido',
          nameChange['new'] ?? 'No definido',
        ),
      ],
    );
  }

  Widget _buildAmountChangeWidget(Map<String, dynamic> amountChange) {
    return _buildChangeCard(
      'Monto Total',
      [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.0),
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.5),
                    width: 1.0,
                  ),
                ),
             
              child:
                  Text('\$${currencyFormat.format(amountChange['old'] ?? 0)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                      ))),
          SizedBox(width: 8.0),
          Text(
            '→',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25.0),
          ),
          SizedBox(width: 8.0),
          Container(
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.0),
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.5),
                    width: 1.0,
                  ),
                ),
              width: 175,
              child:
                  Text('\$${currencyFormat.format(amountChange['new'] ?? 0)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                      )))
        ])
        // _buildChangeItem(
        //   'Monto',
        //   '\$${currencyFormat.format(amountChange['old'] ?? 0)}',
        //   '\$${currencyFormat.format(amountChange['new'] ?? 0)}',
        // ),
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

  Widget _buildExpenseItem(Map<String, dynamic> expense, Color backgroundColor,
      BoxBorder border, IconData icon, Color iconColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.0, left: 0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6.0),
        border: border,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16.0),
          SizedBox(width: 8.0),
          Expanded(
            child: Text(
              '${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
              style: TextStyle(fontSize: 13.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifiedExpenseItem(Map<String, dynamic> expense) {
    Map<String, dynamic> mods = expense['modifications'] ?? {};

    return Container(
      margin: EdgeInsets.only(bottom: 8, left: 0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.edit, color: Colors.orange, size: 16.0),
              SizedBox(width: 8.0),
              Text(
                '${expense['nombre']}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
              ),
            ],
          ),
          Divider(height: 12.0, thickness: 0.5),
          ...mods.entries.map((entry) {
            String field = entry.key;
            Map<String, dynamic> change = entry.value;
            String fieldName = _getFieldDisplayName(field);
            String oldValue = _formatFieldValue(field, change['old']);
            String newValue = _formatFieldValue(field, change['new']);

            return Padding(
              padding: EdgeInsets.only(left: 0, top: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• $fieldName: ',
                    style:
                        TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
                  ),
                  Text(
                      '$oldValue → $newValue',
                      style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.black,
                          fontWeight: FontWeight.w500),
                  
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAddedExpensesWidget(List<dynamic> addedExpenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Gastos añadidos:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...addedExpenses.map((expense) => _buildExpenseItem(
              expense,
              Colors.green.withOpacity(0.1),
              Border.all(color: Colors.green.withOpacity(0.3)),
              Icons.add_circle_outline,
              Colors.green,
            )),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildRemovedExpensesWidget(List<dynamic> removedExpenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Gastos eliminados:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...removedExpenses.map((expense) => _buildExpenseItem(
              expense,
              Colors.red.withOpacity(0.1),
              Border.all(color: Colors.red.withOpacity(0.3)),
              Icons.remove_circle_outline,
              Colors.red,
            )),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildModifiedExpensesWidget(List<dynamic> modifiedExpenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Gastos modificados:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...modifiedExpenses
            .map((expense) => _buildModifiedExpenseItem(expense)),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Subgrupos Añadidos:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...addedSubgroups
            .map((subgroup) => Container(
                  margin: EdgeInsets.only(bottom: 8.0, left: 0),
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: Colors.green, size: 16.0),
                          SizedBox(width: 8.0),
                          Text(
                              '${subgroup['nombre']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.0),
                            
                          ),
                        ],
                      ),
                      if ((subgroup['gastos'] as List?)?.isNotEmpty ?? false)
                        Divider(height: 12.0, thickness: 0.5),
                      ...((subgroup['gastos'] as List?) ?? [])
                          .map((gasto) => Padding(
                                padding: EdgeInsets.only(left: 0, top: 2.0),
                                child: Text(
                                  '• ${gasto['nombre']}: \$${currencyFormat.format(gasto['valor'])}',
                                  style: TextStyle(fontSize: 12.0),
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
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Subgrupos Eliminados:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...removedSubgroups
            .map((subgroup) => Container(
                  margin: EdgeInsets.only(bottom: 8.0, left: 0),
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 16.0),
                          SizedBox(width: 8.0),
                          Text(
                              '${subgroup['nombre']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.0),
                            
                          ),
                        ],
                      ),
                      if ((subgroup['gastos'] as List?)?.isNotEmpty ?? false)
                        Divider(height: 12.0, thickness: 0.5),
                      ...((subgroup['gastos'] as List?) ?? [])
                          .map((gasto) => Padding(
                                padding: EdgeInsets.only(left: 0, top: 2.0),
                                child: Text(
                                  '• ${gasto['nombre']}: \$${currencyFormat.format(gasto['valor'])}',
                                  style: TextStyle(fontSize: 12.0),
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
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Subgrupos Modificados:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...modifiedSubgroups.map((subgroup) {
          Map<String, dynamic> mods = subgroup['modifications'] ?? {};

          return Container(
            margin: EdgeInsets.only(bottom: 8, left: 0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange, size: 16.0),
                    SizedBox(width: 8.0),
                    Text(
                        '${subgroup['nombre']}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.0),
                      
                    ),
                  ],
                ),
                Divider(height: 12.0, thickness: 0.5),
                // Cambios en el nombre del subgrupo
                if (mods.containsKey('nombre'))
                  Padding(
                    padding: EdgeInsets.only(left: 0, top: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre: ',
                          style: TextStyle(
                              fontSize: 12.0, fontWeight: FontWeight.w500),
                        ),
                        Text(
                            '${mods['nombre']['old']} → ${mods['nombre']['new']}',
                            style: TextStyle(
                                fontSize: 12.0,
                                color: Colors.black,
                                fontWeight: FontWeight.w500),
                          
                        )
                      ],
                    ),
                  ),
                // Cambios en gastos del subgrupo
                if (mods.containsKey('gastos'))
                  _buildSubgroupExpenseChangesImproved(mods['gastos']),
              ],
            ),
          );
        }).toList(),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildSubgroupExpenseChangesImproved(
      Map<String, dynamic> expenseChanges) {
    List<Widget> widgets = [];

    if (expenseChanges['added'] != null &&
        (expenseChanges['added'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Gastos añadidos:',
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (var expense in expenseChanges['added']) {
        widgets.add(
          Container(
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.green, size: 12.0),
                SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    '${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
                    style: TextStyle(fontSize: 11.0),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (expenseChanges['removed'] != null &&
        (expenseChanges['removed'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Gastos removidos:',
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (var expense in expenseChanges['removed']) {
        widgets.add(
          Container(
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 12.0),
                SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    '${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
                    style: TextStyle(fontSize: 11.0),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (expenseChanges['modified'] != null &&
        (expenseChanges['modified'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Gastos modificados:',
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (var expense in expenseChanges['modified']) {
        Map<String, dynamic> mods = expense['modifications'] ?? {};
        widgets.add(
          Container(
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange, size: 12.0),
                    SizedBox(width: 8.0),
                    Text(
                        '${expense['nombre']}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11.0),
                      
                    ),
                  ],
                ),
                ...mods.entries.map((entry) {
                  String field = entry.key;
                  Map<String, dynamic> change = entry.value;
                  String fieldName = _getFieldDisplayName(field);
                  String oldValue = _formatFieldValue(field, change['old']);
                  String newValue = _formatFieldValue(field, change['new']);

                  return Padding(
                    padding: EdgeInsets.only(left: 0, top: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• $fieldName: ',
                          style: TextStyle(
                              fontSize: 10.0, fontWeight: FontWeight.w500),
                        ),
                        Text(
                            '$oldValue → $newValue',
                            style: TextStyle(
                                fontSize: 10.0,
                                color: Colors.black,
                                fontWeight: FontWeight.w500),
                          
                        )
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widgets);
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Participantes Añadidos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...((participantChanges['added'] as List)
                .map((participant) => Container(
                      margin: EdgeInsets.only(bottom: 8.0, left: 0),
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.0),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add,
                              color: Colors.green, size: 16.0),
                          SizedBox(width: 8.0),
                          Text(
                              '${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                              style: TextStyle(fontSize: 13.0),
                            
                          ),
                        ],
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Participantes Removidos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...((participantChanges['removed'] as List)
                .map((participant) => Container(
                      margin: EdgeInsets.only(bottom: 8.0, left: 0),
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_remove,
                              color: Colors.red, size: 16.0),
                          SizedBox(width: 8.0),
                          Text(
                              '${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                              style: TextStyle(fontSize: 13.0),
                            
                          ),
                        ],
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
            Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Participantes Modificados:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...((participantChanges['modified'] as List).map((participant) {
              Map<String, dynamic> mods = participant['modifications'] ?? {};

              return Container(
                margin: EdgeInsets.only(bottom: 8.0, left: 0),
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit, color: Colors.orange, size: 16.0),
                        SizedBox(width: 8.0),
                        Text(
                            '${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13.0),
                          
                        ),
                      ],
                    ),
                    Divider(height: 12.0, thickness: 0.5),
                    ...mods.entries.map((entry) {
                      String field = entry.key;
                      Map<String, dynamic> change = entry.value;
                      String fieldName = _getFieldDisplayName(field);
                      String oldValue = _formatFieldValue(field, change['old']);
                      String newValue = _formatFieldValue(field, change['new']);

                      return Padding(
                        padding: EdgeInsets.only(left: 0, top: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• $fieldName: ',
                              style: TextStyle(
                                  fontSize: 12.0, fontWeight: FontWeight.w500),
                            ),
                            Text(
                                '$oldValue → $newValue',
                                style: TextStyle(
                                    fontSize: 12.0, fontWeight: FontWeight.w500),
                              
                            )
                            // Expanded(
                            //   child: RichText(
                            //     text: TextSpan(
                            //       style: TextStyle(
                            //           fontSize: 12.0, color: Colors.black),
                            //       children: [
                            //         TextSpan(text: oldValue),
                            //         TextSpan(
                            //             text: ' → ',
                            //             style: TextStyle(
                            //                 fontWeight: FontWeight.bold)),
                            //         TextSpan(text: newValue),
                            //       ],
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      );
                    }).toList(),
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
      // Obtener los nombres de los gastos si están disponibles
      for (var dist in distributionChanges['expense_distributions']) {
        // Buscar el nombre del gasto en los datos de cambios de gastos
        if (_changeDetails != null &&
            _changeDetails!['expense_changes'] != null) {
          // Buscar en gastos añadidos
          if (_changeDetails!['expense_changes']['added'] != null) {
            for (var expense in _changeDetails!['expense_changes']['added']) {
              if (expense['id'] == dist['targetId']) {
                dist['targetName'] = expense['nombre'] ?? 'Gasto';
                break;
              }
            }
          }

          // Buscar en gastos modificados
          if (dist['targetName'] == null &&
              _changeDetails!['expense_changes']['modified'] != null) {
            for (var expense in _changeDetails!['expense_changes']
                ['modified']) {
              if (expense['id'] == dist['targetId']) {
                dist['targetName'] = expense['nombre'] ?? 'Gasto';
                break;
              }
            }
          }

          // Buscar en gastos eliminados
          if (dist['targetName'] == null &&
              _changeDetails!['expense_changes']['removed'] != null) {
            for (var expense in _changeDetails!['expense_changes']['removed']) {
              if (expense['id'] == dist['targetId']) {
                dist['targetName'] = expense['nombre'] ?? 'Gasto';
                break;
              }
            }
          }
        }

        // Si no se encontró un nombre, usar un valor predeterminado
        if (dist['targetName'] == null) {
          dist['targetName'] = 'Gasto: ' + dist['targetId'];
        }
      }

      widgets.add(_buildDistributionSection(
        'Distribuciones de Gastos',
        distributionChanges['expense_distributions'],
      ));
    }

    // Distribuciones de subgrupos
    if (distributionChanges['subgroup_distributions'] != null && distributionChanges['subgroup_distributions'].isNotEmpty) {
      // Obtener los nombres de los subgrupos si están disponibles
      for (var dist in distributionChanges['subgroup_distributions']) {
        // Buscar el nombre del subgrupo en los datos de cambios de subgrupos
        if (_changeDetails != null &&
            _changeDetails!['subgroup_changes'] != null) {
          // Buscar en subgrupos añadidos
          if (_changeDetails!['subgroup_changes']['added'] != null) {
            for (var subgroup in _changeDetails!['subgroup_changes']['added']) {
              if (subgroup['id'] == dist['targetId']) {
                dist['targetName'] = subgroup['nombre'] ?? 'Subgrupo';
                break;
              }
            }
          }

          // Buscar en subgrupos modificados
          if (dist['targetName'] == null &&
              _changeDetails!['subgroup_changes']['modified'] != null) {
            for (var subgroup in _changeDetails!['subgroup_changes']
                ['modified']) {
              if (subgroup['id'] == dist['targetId']) {
                dist['targetName'] = subgroup['nombre'] ?? 'Subgrupo';
                break;
              }
            }
          }

          // Buscar en subgrupos eliminados
          if (dist['targetName'] == null &&
              _changeDetails!['subgroup_changes']['removed'] != null) {
            for (var subgroup in _changeDetails!['subgroup_changes']
                ['removed']) {
              if (subgroup['id'] == dist['targetId']) {
                dist['targetName'] = subgroup['nombre'] ?? 'Subgrupo';
                break;
              }
            }
          }
        }

        // Si no se encontró un nombre, usar un valor predeterminado
        if (dist['targetName'] == null) {
          dist['targetName'] = 'Subgrupo: ' + dist['targetId'];
        }
      }

      if (distributionChanges['subgroup_distributions'].isNotEmpty) {
        widgets.add(_buildDistributionSection(
          'Distribuciones de Subgrupos',
          distributionChanges['subgroup_distributions'],
        ));
      }
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
    String targetName = distribution['targetName'] ?? targetId;
    Color typeColor;
    IconData typeIcon;
    String typeText;

    switch (type) {
      case 'added':
        typeColor = Colors.green;
        typeIcon = Icons.add_circle_outline;
        typeText = 'AÑADIDO';
        break;
      case 'removed':
        typeColor = Colors.red;
        typeIcon = Icons.remove_circle_outline;
        typeText = 'ELIMINADO';
        break;
      case 'modified':
        typeColor = Colors.orange;
        typeIcon = Icons.edit;
        typeText = 'MODIFICADO';
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.info_outline;
        typeText = type.toUpperCase();
    }

    List<Widget> content = [];

    if (type == 'modified' && distribution['modifications'] != null) {
      content.add(_buildDistributionModificationsImproved(
          distribution['modifications']));
    } else if (distribution['distribution'] != null) {
      content.add(_buildDistributionDetailsImproved(
          distribution['distribution'],
          operationType: type));
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.0, left: 0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(typeIcon, color: typeColor, size: 16.0),
                SizedBox(width: 8.0),
                Text(
                    '$typeText: $targetName',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                        color: typeColor),
                  
                ),
              ],
            ),
          ),
          if (content.isNotEmpty) Divider(height: 12.0, thickness: 0.5),
          ...content,
        ],
      ),
    );
  }

  Widget _buildDistributionModificationsImproved(
      Map<String, dynamic> modifications) {
    List<Widget> widgets = [];

    if (modifications['totalAmount'] != null) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Monto total: ',
                style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
              ),
              Text(
                  '\$${currencyFormat.format(modifications['totalAmount']['old'])} → \$${currencyFormat.format(modifications['totalAmount']['new'])}',
                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
                
              )
              // Expanded(
              //   child: RichText(
              //     text: TextSpan(
              //       style: TextStyle(fontSize: 12.0, color: Colors.black),
              //       children: [
              //         TextSpan(
              //             text:
              //                 '\$${currencyFormat.format(modifications['totalAmount']['old'])}'),
              //         TextSpan(
              //             text: ' → ',
              //             style: TextStyle(fontWeight: FontWeight.bold)),
              //         TextSpan(
              //             text:
              //                 '\$${currencyFormat.format(modifications['totalAmount']['new'])}'),
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      );
    }

    if (modifications['shares'] != null) {
      widgets.add(_buildShareModificationsImproved(modifications['shares']));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widgets);
  }

  Widget _buildShareModificationsImproved(Map<String, dynamic> shareChanges) {
    List<Widget> widgets = [];

    if (shareChanges['added'] != null &&
        (shareChanges['added'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Distribución entre participantes:',
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w900),
          ),
        ),
      );

      for (var share in shareChanges['added']) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.green, size: 12.0),
                SizedBox(width: 4.0),
                Flexible(
                  child: Text(
                    '${_userNames[share['userId']] ?? 'Usuario'}: \$${currencyFormat.format(share['amount'])} (${share['percentage']?.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11.0),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (shareChanges['removed'] != null &&
        (shareChanges['removed'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Distribución entre participantes:',
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w900),
          ),
        ),
      );

      for (var share in shareChanges['removed']) {
        widgets.add(
          Container(
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 12.0),
                SizedBox(width: 4.0),
                Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_userNames[share['userId']] ?? 'Usuario'}',
                            style: TextStyle(
                                fontSize: 11.0, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Monto: \$${currencyFormat.format(share['amount'])} \nporcentaje: ${share['percentage']?.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 11.0, fontWeight: FontWeight.bold),
                          )
                    ])

                // Icon(Icons.person, color: iconColor, size: 12.0),
                //           SizedBox(width: 4.0),
                //           Column(
                //               mainAxisAlignment: MainAxisAlignment.start,
                //               crossAxisAlignment: CrossAxisAlignment.start,
                //               children: [
                //                 Text(
                //                   '${_userNames[share['userId']] ?? 'Usuario'}',
                //                   style: TextStyle(
                //                       fontSize: 11.0,
                //                       fontWeight: FontWeight.bold),
                //                 ),
                //                 Text(
                //                   'Monto: ${currencyFormat.format(share['amount'])} \nporcentraje: ${share['percentage']?.toStringAsFixed(1)}%',
                //                   style: TextStyle(fontSize: 11.0),
                //                 ),
                //               ]),
                // Flexible(
                //   child: Text(
                //     '${_userNames[share['userId']] ?? 'Usuario'}: \$${currencyFormat.format(share['amount'])} (${share['percentage']?.toStringAsFixed(1)}%)',
                //     style: TextStyle(fontSize: 11.0),
                //   ),
                // ),
              ],
            ),
          ),
        );
      }
    }

    if (shareChanges['modified'] != null &&
        (shareChanges['modified'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Distribución entre participantes:',
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w900),
          ),
        ),
      );

      for (var share in shareChanges['modified']) {
        Map<String, dynamic> mods = share['modifications'] ?? {};
        widgets.add(
          Container(
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange, size: 12.0),
                    SizedBox(width: 4.0),
                    Text(
                      '${_userNames[share['userId']] ?? 'Usuario'}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11.0),
                    ),
                  ],
                ),
                ...mods.entries.map((entry) {
                  String field = entry.key;
                  Map<String, dynamic> change = entry.value;
                  String oldValue = field == 'amount'
                      ? '\$${currencyFormat.format(change['old'])}'
                      : '${change['old']?.toStringAsFixed(1)}%';
                  String newValue = field == 'amount'
                      ? '\$${currencyFormat.format(change['new'])}'
                      : '${change['new']?.toStringAsFixed(1)}%';

                  return Padding(
                    padding: EdgeInsets.only(left: 0, top: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${field == 'amount' ? 'Monto' : 'Porcentaje'}: ',
                          style: TextStyle(
                              fontSize: 12.0, fontWeight: FontWeight.w500),
                        ),
                        Text(
                            '$oldValue → $newValue',
                            style: TextStyle(
                                fontSize: 12.0, fontWeight: FontWeight.w500),
                          
                        )
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widgets);
  }

  Widget _buildDistributionDetailsImproved(Map<String, dynamic> distribution,
      {String operationType = 'info'}) {
    // Convertir el tipo a un formato más amigable
    String distributionType = distribution['type'] ?? '';
    String formattedType;

    // Extraer el tipo real si viene con el prefijo DistributionType.
    if (distributionType.startsWith('DistributionType.')) {
      distributionType = distributionType.substring('DistributionType.'.length);
    }

    switch (distributionType) {
      case 'equalParts':
      case 'equal':
        formattedType = 'Partes iguales';
        break;
      case 'percentage':
        formattedType = 'Porcentajes';
        break;
      case 'amount':
        formattedType = 'Montos específicos';
        break;
      case 'custom':
        formattedType = 'Personalizada';
        break;
      default:
        formattedType = distributionType;
    }

    // Determinar colores según el tipo de operación
    Color containerColor;
    Color iconColor;

    switch (operationType) {
      case 'added':
        containerColor = Colors.green;
        iconColor = Colors.green;
        break;
      case 'removed':
        containerColor = Colors.red;
        iconColor = Colors.red;
        break;
      case 'modified':
        containerColor = Colors.orange;
        iconColor = Colors.orange;
        break;
      default:
        containerColor = Colors.blue;
        iconColor = Colors.blue;
    }

    return Padding(
      padding: EdgeInsets.only(left: 0, top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo: $formattedType',
            style: TextStyle(fontSize: 12.0),
          ),
          Text(
            'Monto total: \$${currencyFormat.format(distribution['totalAmount'])}',
            style: TextStyle(fontSize: 12.0),
          ),
          if (distribution['shares'] != null) ...[
            Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text(
                'Distribución entre participantes:',
                style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w900),
              ),
            ),
            ...((distribution['shares'] as List)
                .map((share) => Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
                      padding:
                          EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: containerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.0),
                        border:
                            Border.all(color: containerColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        // mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(width: 4.0),
                          Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person,
                                          color: iconColor, size: 12.0),
                                      SizedBox(width: 4.0),
                                      Text(
                                        '${_userNames[share['userId']] ?? 'Usuario'}',
                                        style: TextStyle(
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Monto: ${currencyFormat.format(share['amount'])} \nporcentraje: ${share['percentage']?.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 11.0),
                                  ),
                                ]),
                          
                        ],
                      ),
                    ))
                .toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildChangeCard(String title, List<Widget> children) {
    if (children.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 0),
      // elevation: 2.0,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Divider(thickness: 0.5, height: 0),
            SizedBox(height: 8.0),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildChangeItem(String field, String oldValue, String newValue) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$field:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.0),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    oldValue,
                    style: TextStyle(fontSize: 13.0),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 0),
                child: Icon(Icons.arrow_forward, size: 16.0),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    newValue,
                    style: TextStyle(fontSize: 13.0),
                  ),
                ),
              ),
            ],
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
      color: Colors.white,
      elevation: 6.0,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Votos',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            _votes.isEmpty
                ? Text('No hay votos registrados')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _votes.map((vote) => _buildVoteItem(vote)).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteItem(VersionVoteModel vote) {
    final colorProvider = Provider.of<ColorProvider>(context);

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
            backgroundColor: colorProvider.colors.appBarColor.withOpacity(0.5),
            child: Icon(
              Icons.person,
              color: colorProvider.colors.appBarColor,
            ),
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
        SizedBox(
          width: 220,
          child: ElevatedButton.icon(
            icon: Icon(Icons.check, color: Colors.white),
            label: Text(
              'Aceptar Cambios'.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              iconSize: 25,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 22.0),
            ),
            onPressed: () => _submitVote(VoteStatus.accepted),
          ),
        ),
        SizedBox(
          width: 220,
          child: ElevatedButton.icon(
            icon: Icon(Icons.close, color: Colors.white),
            label: Text(
              'Rechazar Cambios'.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              iconSize: 25,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 22.0),
            ),
            onPressed: () => _submitVote(VoteStatus.rejected),
          ),
        )
      ],
    );
  }
}
