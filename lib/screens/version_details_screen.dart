import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/version_vote_model.dart';
import 'package:control_gastos/services/shared_expense_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:control_gastos/widgets/profile_image.dart';
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
  String _versionStatus = 'pending';
  bool _userHasVoted = false;
  VoteStatus? _userVoteStatus;
  SharingPermissionType _permissionType = SharingPermissionType.allParticipants;
  String _modifierName = '';
  Map<String, String> _userNames = {};
  Stream<DocumentSnapshot>? _versionStream;
  Stream<DocumentSnapshot>? _votesStream;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
    _loadStaticData();
  }

  void _initializeStreams() {
    _versionStream = FirebaseFirestore.instance
        .collection('sharedExpenses')
        .doc(widget.expenseId)
        .collection('versions')
        .doc(widget.version)
        .snapshots();

    // Los votos están en el campo 'votes' del documento de la versión
    _votesStream = FirebaseFirestore.instance
        .collection('sharedExpenses')
        .doc(widget.expenseId)
        .collection('versions')
        .doc(widget.version)
        .snapshots();
  }

  Future<void> _loadStaticData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener datos del grupo original
      _originalGroup =
          await _sharedExpenseService.getSharedExpense(widget.expenseId);

      // Obtener tipo de permiso
      _permissionType = _originalGroup?.permissionType ??
          SharingPermissionType.allParticipants;

      // Cargar nombres de usuarios para participantes
      await _loadUserNames();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.logError('Error al cargar datos estáticos: $e');
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
    if (_isVoting) return; // Prevenir múltiples clics

    setState(() {
      _isVoting = true;
    });
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    // Mostrar modal de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorProvider.colors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: colorProvider.colors.appBarColor,
              width: 3,
            ),
          ),
          content: Row(
            children: [
              CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
              SizedBox(width: 20),
              Text(
                'Enviando voto',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18.0,
                  color: colorProvider.colors.primaryTextColor,
                ),
              ),
              SizedBox(width: 20),
              Icon(
                //send
                Icons.send,
                color: colorProvider.colors.appBarColor,
                size: 30,
              )
            ],
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _isVoting = false;
      });
    }

    try {
      await _sharedExpenseService.respondToVersionVote(
        widget.expenseId,
        widget.version,
        widget.currentUserId,
        status,
      );

      // Cerrar modal de carga
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tu voto ha sido registrado')),
        );
      }
    } catch (e) {
      _logger.logError('Error al enviar voto: $e');

      // Cerrar modal de carga
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar voto: $e')),
        );
      }
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
          : StreamBuilder<DocumentSnapshot>(
              stream: _versionStream,
              builder: (context, versionSnapshot) {
                if (versionSnapshot.hasError) {
                  final colorProvider = Provider.of<ColorProvider>(context, listen: false);
                  return Center(
                    child: Text(
                      'Error al cargar datos: ${versionSnapshot.error}',
                      style: TextStyle(color: colorProvider.colors.negativeColor),
                    ),
                  );
                }

                if (!versionSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!versionSnapshot.data!.exists) {
                  return Center(
                    child: Text('Versión no encontrada'),
                  );
                }

                // Actualizar datos de la versión
                _versionData =
                    versionSnapshot.data!.data() as Map<String, dynamic>?;
                _versionStatus = _versionData?['status'] ?? 'pending';
                _changeDetails = _versionData?['changeDetails'] ?? {};
                _updatedGroup =
                    SharedExpenseGroup.fromMap(_versionData?['data'] ?? {});

                // Obtener nombre del modificador
                String modifierId = _versionData?['modifierId'] ?? '';

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildVersionInfoStream(modifierId),
                      SizedBox(height: 16.0),
                      _buildVotingButtonsStream(),
                      _buildVotesSectionStream(),
                      SizedBox(height: 16.0),
                      _buildDetailedChangesSection(),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String formatTimestamp(dynamic timestampInput) {
    if (timestampInput == null) {
      return 'No disponible';
    }

    DateTime dateTime;

    if (timestampInput is DateTime) {
      dateTime = timestampInput;
    } else if (timestampInput is Timestamp) {
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
      // Fallback or error handling if the input is neither DateTime, Timestamp nor the expected Map
      return 'Formato de fecha inválido';
    }

    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  Widget _buildVersionInfoStream(String modifierId) {
    final String fechaFormateada = formatTimestamp(_versionData?['timestamp']);
    final colorProvider = Provider.of<ColorProvider>(context);
    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorProvider.colors.appBarColor,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<String>(
              future: _getUserName(modifierId),
              builder: (context, snapshot) {
                String modifierName = snapshot.data ?? 'Cargando...';
                return Text(
                  'Cambios propuestos por $modifierName',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                );
              },
            ),
            SizedBox(height: 8.0),
            Text(
              'Versión: ${widget.version}',
              style: TextStyle(fontSize: 14.0),
            ),
            SizedBox(height: 8.0),
            Text(
              'Fecha: $fechaFormateada',
              style: TextStyle(fontSize: 14.0),
            ),
            SizedBox(height: 8.0),
            Row(
              children: [
                Text(
                  'Estado: ',
                  style: TextStyle(fontSize: 14.0),
                ),
                _buildStatusChip(_versionStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        String userName = userDoc.data()?['username'] ?? 'Usuario desconocido';
        _userNames[userId] = userName;
        return userName;
      }
    } catch (e) {
      _userNames[userId] = 'Usuario desconocido';
    }
    return 'Usuario desconocido';
  }

  Widget _buildStatusChip(String status) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    Color chipColor;
    String statusText;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Pendiente';
        break;
      case 'accepted':
        chipColor = colorProvider.colors.positiveColor;
        statusText = 'Aceptado';
        break;
      case 'rejected':
        chipColor = colorProvider.colors.negativeColor;
        statusText = 'Rechazado';
        break;
      default:
        chipColor = colorProvider.colors.appBarColor;
        statusText = 'Desconocido';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: colorProvider.colors.secondaryTextColor),
      ),
    );
  }

  Widget _buildDetailedChangesSection() {
    // Debug logs
    print('DEBUG _buildDetailedChangesSection:');
    print('  - _changeDetails: $_changeDetails');
    print('  - _changeDetails keys: ${_changeDetails?.keys.toList()}');
    print(
        '  - contains image_changes: ${_changeDetails?.containsKey('image_changes')}');
    if (_changeDetails?.containsKey('image_changes') == true) {
      print('  - image_changes content: ${_changeDetails!['image_changes']}');
    }
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    if (_changeDetails == null || _changeDetails!.isEmpty) {
      return Card(
        color: colorProvider.colors.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: colorProvider.colors.appBarColor,
            width: 1.5,
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No se encontraron detalles de cambios')),
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

    // Cambios en imágenes
    if (_changeDetails!.containsKey('image_changes')) {
      changeWidgets
          .add(_buildImageChangesWidget(_changeDetails!['image_changes']));
    }

    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorProvider.colors.appBarColor,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    return _buildChangeCard(
      'Monto Total',
      [
        Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Container(
                      padding: EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6.0),
                        color: colorProvider.colors.negativeColor.withOpacity(0.1),
                        border: Border.all(
                          color: colorProvider.colors.negativeColor.withOpacity(0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                          '\$${currencyFormat.format(amountChange['old'] ?? 0)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.0,
                          )))),
              SizedBox(width: 8.0),
              Text(
                '→',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25.0),
              ),
              SizedBox(width: 8.0),
              Expanded(
                  child: Container(
                      padding: EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6.0),
                        color: colorProvider.colors.positiveColor.withOpacity(0.1),
                        border: Border.all(
                          color: colorProvider.colors.positiveColor.withOpacity(0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                          '\$${currencyFormat.format(amountChange['new'] ?? 0)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.0,
                          ))))
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

    return _buildChangeCard('Montos', widgets);
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
          Icon(icon, color: iconColor, size: 20.0),
          SizedBox(width: 8.0),
          Expanded(
            child: Text(
              '${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
              style: TextStyle(fontSize: 14.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModifiedExpenseItem(Map<String, dynamic> expense) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
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
              Icon(Icons.edit, color: Colors.orange, size: 20.0),
              SizedBox(width: 8.0),
              Text(
                '${expense['nombre']}',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '• $fieldName: ',
                    style:
                        TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    oldValue,
                    style: TextStyle(
                        fontSize: 14.0,
                        color: colorProvider.colors.primaryTextColor,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '  →  ',
                    style: TextStyle(
                        fontSize: 14.0,
                        color: colorProvider.colors.primaryTextColor,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    newValue,
                    style: TextStyle(
                        fontSize: 14.0,
                        color: colorProvider.colors.primaryTextColor,
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Añadidos:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
        ...addedExpenses.map((expense) => _buildExpenseItem(
              expense,
              colorProvider.colors.positiveColor.withOpacity(0.1),
              Border.all(color: colorProvider.colors.positiveColor.withOpacity(0.3)),
              Icons.add_circle_outline,
              colorProvider.colors.positiveColor,
            )),
        SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildRemovedExpensesWidget(List<dynamic> removedExpenses) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Eliminados:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
        ...removedExpenses.map((expense) => _buildExpenseItem(
              expense,
              colorProvider.colors.negativeColor.withOpacity(0.1),
              Border.all(color: colorProvider.colors.negativeColor.withOpacity(0.3)),
              Icons.remove_circle_outline,
              colorProvider.colors.negativeColor,
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
            'Modificados:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
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

    return _buildChangeCard('Grupos', widgets);
  }

  Widget _buildAddedSubgroupsWidget(List<dynamic> addedSubgroups) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Añadidos:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
        ...addedSubgroups
            .map((subgroup) => Container(
                  margin: EdgeInsets.only(bottom: 8.0, left: 0),
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: colorProvider.colors.positiveColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: colorProvider.colors.positiveColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: colorProvider.colors.positiveColor, size: 20.0),
                          SizedBox(width: 8.0),
                          Text(
                            '${subgroup['nombre']}',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14.0),
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
                                  style: TextStyle(fontSize: 14.0),
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Eliminados:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...removedSubgroups
            .map((subgroup) => Container(
                  margin: EdgeInsets.only(bottom: 8.0, left: 0),
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: colorProvider.colors.negativeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: colorProvider.colors.negativeColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.remove_circle_outline,
                              color: colorProvider.colors.negativeColor, size: 20.0),
                          SizedBox(width: 8.0),
                          Text(
                            '${subgroup['nombre']}',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14.0),
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
                                  style: TextStyle(fontSize: 14.0),
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Modificados:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...modifiedSubgroups.map((subgroup) {
          Map<String, dynamic> mods = subgroup['modifications'] ?? {};

          return Container(
            margin: EdgeInsets.only(bottom: 8, left: 0),
            padding: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color.fromARGB(127, 255, 153, 0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange, size: 20.0),
                    SizedBox(width: 8.0),
                    Text(
                      '${subgroup['nombre']}',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14.0),
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
                          '• Nombre: ',
                          style: TextStyle(
                              fontSize: 14.0, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${mods['nombre']['old']}',
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '  →  ',
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${mods['nombre']['new']}',
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.w500),
                        ),
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    List<Widget> widgets = [];

    if (expenseChanges['added'] != null &&
        (expenseChanges['added'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Añadidos:',
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (var expense in expenseChanges['added']) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: colorProvider.colors.positiveColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: colorProvider.colors.positiveColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: colorProvider.colors.positiveColor, size: 20.0),
                SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    '${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
                    style: TextStyle(fontSize: 14.0),
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
            'Eliminados:',
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (var expense in expenseChanges['removed']) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: colorProvider.colors.negativeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: colorProvider.colors.negativeColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_circle_outline,
                    color: colorProvider.colors.negativeColor, size: 20.0),
                SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    '${expense['nombre']}: \$${currencyFormat.format(expense['valor'])}',
                    style: TextStyle(fontSize: 14.0),
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
            'Modificados:',
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
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
                    Icon(Icons.edit, color: Colors.orange, size: 20.0),
                    SizedBox(width: 8.0),
                    Text(
                      '${expense['nombre']}',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14.0),
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
                    padding: EdgeInsets.only(left: 0, top: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '• $fieldName: ',
                          style: TextStyle(
                              fontSize: 14.0, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          oldValue,
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '  →  ',
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          newValue,
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.w500),
                        ),
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
        final colorProvider = Provider.of<ColorProvider>(context, listen: false);
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
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
            ...((participantChanges['added'] as List)
                .map((participant) => Container(
                      margin: EdgeInsets.only(bottom: 8.0, left: 0),
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: colorProvider.colors.positiveColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.0),
                        border:
                            Border.all(color: colorProvider.colors.positiveColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add,
                              color: colorProvider.colors.positiveColor, size: 16.0),
                          SizedBox(width: 8.0),
                          Text(
                            '${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                            style: TextStyle(fontSize: 14.0),
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
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
            ...((participantChanges['removed'] as List)
                .map((participant) => Container(
                      margin: EdgeInsets.only(bottom: 8.0, left: 0),
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: colorProvider.colors.negativeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: colorProvider.colors.negativeColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_remove,
                              color: colorProvider.colors.negativeColor, size: 16.0),
                          SizedBox(width: 8.0),
                          Text(
                            '${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                            style: TextStyle(fontSize: 14.0),
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
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
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
                        Icon(Icons.edit, color: Colors.orange, size: 20.0),
                        SizedBox(width: 8.0),
                        Text(
                          '${_userNames[participant['userId']] ?? 'Usuario desconocido'}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14.0),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '• $fieldName: ',
                              style: TextStyle(
                                  fontSize: 14.0, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              oldValue,
                              style: TextStyle(
                                  fontSize: 14.0,
                                  color: colorProvider.colors.primaryTextColor,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '  →  ',
                              style: TextStyle(
                                  fontSize: 14.0,
                                  color: colorProvider.colors.primaryTextColor,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              newValue,
                              style: TextStyle(
                                  fontSize: 14.0,
                                  color: colorProvider.colors.primaryTextColor,
                                  fontWeight: FontWeight.w500),
                            ),
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
        'Distribuciones de Montos',
        distributionChanges['expense_distributions'],
      ));
    }

    // Distribuciones de subgrupos
    if (distributionChanges['subgroup_distributions'] != null &&
        distributionChanges['subgroup_distributions'].isNotEmpty) {
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
          'Distribuciones de Grupos',
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8.0),
        ...distributions.map((dist) => _buildDistributionItem(dist)).toList(),
        SizedBox(height: 12.0),
      ],
    );
  }

  Widget _buildDistributionItem(Map<String, dynamic> distribution) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    String type = distribution['type'] ?? '';
    String targetId = distribution['targetId'] ?? '';
    String targetName = distribution['targetName'] ?? targetId;
    Color typeColor;
    IconData typeIcon;
    String typeText;

    switch (type) {
      case 'added':
        typeColor = colorProvider.colors.positiveColor;
        typeIcon = Icons.add_circle_outline;
        typeText = 'AÑADIDO';
        break;
      case 'removed':
        typeColor = colorProvider.colors.negativeColor;
        typeIcon = Icons.remove_circle_outline;
        typeText = 'ELIMINADO';
        break;
      case 'modified':
        typeColor = Colors.orange;
        typeIcon = Icons.edit;
        typeText = 'MODIFICADO';
        break;
      default:
        typeColor = colorProvider.colors.appBarColor;
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
                      fontSize: 14.0,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Monto total: ',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
              ),
              Text(
                '\$${currencyFormat.format(modifications['totalAmount']['old'])}',
                style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
              ),
              Text(
                '  →  ',
                style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${currencyFormat.format(modifications['totalAmount']['new'])}',
                style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    List<Widget> widgets = [];

    if (shareChanges['added'] != null &&
        (shareChanges['added'] as List).isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: 0, top: 8.0, bottom: 4.0),
          child: Text(
            'Distribución entre participantes:',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w900),
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
              color: colorProvider.colors.positiveColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: colorProvider.colors.positiveColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: colorProvider.colors.positiveColor, size: 20.0),
                SizedBox(width: 4.0),
                Flexible(
                  child: Text(
                    '${_userNames[share['userId']] ?? 'Usuario'}: \$${currencyFormat.format(share['amount'])} (${share['percentage']?.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 14.0),
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
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w900),
          ),
        ),
      );

      for (var share in shareChanges['removed']) {
        widgets.add(
          Container(
            margin: EdgeInsets.only(left: 0, top: 4.0, bottom: 4.0),
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
            decoration: BoxDecoration(
              color: colorProvider.colors.negativeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: colorProvider.colors.negativeColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_circle_outline,
                    color: colorProvider.colors.negativeColor, size: 20.0),
                SizedBox(width: 4.0),
                Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_userNames[share['userId']] ?? 'Usuario'}',
                        style: TextStyle(
                            fontSize: 14.0, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Monto: \$${currencyFormat.format(share['amount'])} \nporcentaje: ${share['percentage']?.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 14.0, fontWeight: FontWeight.w500),
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
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w900),
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
                    Icon(Icons.edit, color: Colors.orange, size: 20.0),
                    SizedBox(width: 4.0),
                    Text(
                      '${_userNames[share['userId']] ?? 'Usuario'}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.0),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${field == 'amount' ? 'Monto' : 'Porcentaje'}: ',
                          style: TextStyle(
                              fontSize: 14.0, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          oldValue,
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '→',
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          newValue,
                          style: TextStyle(
                              fontSize: 14.0,
                              color: colorProvider.colors.primaryTextColor,
                              fontWeight: FontWeight.w500),
                        ),
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
        containerColor = Color.fromARGB(127, 255, 153, 0);
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
            style: TextStyle(fontSize: 14.0),
          ),
          Text(
            'Monto total: \$${currencyFormat.format(distribution['totalAmount'])}',
            style: TextStyle(fontSize: 14.0),
          ),
          if (distribution['shares'] != null) ...[
            Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text(
                'Distribución entre participantes:',
                style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w900),
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
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Monto: ${currencyFormat.format(share['amount'])} \nporcentraje: ${share['percentage']?.toStringAsFixed(1)}%',
                                  style: TextStyle(fontSize: 14.0),
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    return Container(
      margin: EdgeInsets.only(bottom: 0),
      // elevation: 2.0,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      decoration: BoxDecoration(
        color: colorProvider.colors.backgroundColor,
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
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    return Padding(
      padding: EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$field:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
          ),
          SizedBox(height: 4.0),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: colorProvider.colors.negativeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: colorProvider.colors.negativeColor.withOpacity(0.3)),
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
                    color: colorProvider.colors.positiveColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: colorProvider.colors.positiveColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    newValue,
                    style: TextStyle(fontSize: 14.0),
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

  Widget _buildVotesSectionStream() {
    final colorProvider = Provider.of<ColorProvider>(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: _votesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: colorProvider.colors.backgroundColor,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: colorProvider.colors.appBarColor,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Votos',
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.0),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: colorProvider.colors.backgroundColor,
            elevation: 6.0,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Votos',
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.0),
                  Text('Error al cargar votos: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        // Obtener votos del campo 'votes' del documento de la versión
        Map<String, dynamic> versionData =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        List<dynamic> votesData = versionData['votes'] ?? [];
        List<VersionVoteModel> votes = votesData
            .map((voteData) =>
                VersionVoteModel.fromMap(voteData as Map<String, dynamic>))
            .toList();

        return Card(
          color: colorProvider.colors.backgroundColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: colorProvider.colors.appBarColor,
              width: 1.5,
            ),
          ),
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
                votes.isEmpty
                    ? Text('No hay votos registrados', style: TextStyle(color: colorProvider.colors.secondaryTextColor),)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: votes
                            .map((vote) => _buildVoteItemStream(vote))
                            .toList(),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoteItemStream(VersionVoteModel vote) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return FutureBuilder<String>(
      future: _getUserName(vote.userId),
      builder: (context, snapshot) {
        String username = snapshot.data ?? 'Cargando...';

        Color statusColor;
        IconData statusIcon;

        switch (vote.status) {
          case VoteStatus.accepted:
            statusColor = colorProvider.colors.positiveColor;
            statusIcon = Icons.check_circle;
            break;
          case VoteStatus.rejected:
            statusColor = colorProvider.colors.negativeColor;
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
          title: Text(
            username,
            style: TextStyle(fontSize: 14.0, color: colorProvider.colors.secondaryTextColor),
          ),
          subtitle: Text(
            'Votó: ${formatTimestamp(vote.timestamp)}',
            style: TextStyle(fontSize: 13.0, color: colorProvider.colors.secondaryTextColor),
          ),
          trailing: Icon(
            statusIcon,
            color: statusColor,
            size: 30.0,
          ),
        );
      },
    );
  }

  Widget _buildVotingButtonsStream() {
    final colorProvider = Provider.of<ColorProvider>(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: _votesStream,
      builder: (context, votesSnapshot) {
        if (!votesSnapshot.hasData) {
          return SizedBox.shrink();
        }

        // Obtener votos del campo 'votes' del documento de la versión
        Map<String, dynamic> versionData =
            votesSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        List<dynamic> votes = versionData['votes'] ?? [];
        bool userHasVoted =
            votes.any((vote) => vote['userId'] == widget.currentUserId);

        if (_versionStatus == 'pending' && !userHasVoted) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.check, color: colorProvider.colors.secondaryTextColor),
                        label: Text(
                          'Aceptar Cambios'.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          iconSize: 25,
                          backgroundColor: colorProvider.colors.positiveColor,
                          foregroundColor: colorProvider.colors.secondaryTextColor,
                          padding: EdgeInsets.symmetric(vertical: 22.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                10.0), // Adjust the radius as needed
                          ),
                        ),
                        onPressed: _isVoting
                            ? null
                            : () => _submitVote(VoteStatus.accepted),
                      ),
                    ),
                    SizedBox(width: 16.0),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.close, color: colorProvider.colors.secondaryTextColor),
                        label: Text(
                          'Rechazar Cambios'.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          iconSize: 25,
                          backgroundColor: colorProvider.colors.negativeColor,
                          foregroundColor: colorProvider.colors.secondaryTextColor,
                          padding: EdgeInsets.symmetric(vertical: 22.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                10.0), // Adjust the radius as needed
                          ),
                        ),
                        onPressed: _isVoting
                            ? null
                            : () => _submitVote(VoteStatus.rejected),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 16.0),
            ],
          );
        }
        return SizedBox.shrink();
      },
    );
  }

  Widget _buildImageChangesWidget(Map<String, dynamic> imageChanges) {
    // Debug logs
    print('DEBUG _buildImageChangesWidget:');
    print('  - imageChanges: $imageChanges');
    print('  - imageChanges keys: ${imageChanges.keys.toList()}');
    print('  - added count: ${(imageChanges['added'] as List?)?.length ?? 0}');
    print(
        '  - removed count: ${(imageChanges['removed'] as List?)?.length ?? 0}');
    print(
        '  - modified count: ${(imageChanges['modified'] as List?)?.length ?? 0}');

    List<Widget> widgets = [];

    // Imágenes añadidas
    if (imageChanges['added'] != null &&
        (imageChanges['added'] as List).isNotEmpty) {
      widgets.add(_buildAddedImagesWidget(imageChanges['added']));
    }

    // Imágenes removidas
    if (imageChanges['removed'] != null &&
        (imageChanges['removed'] as List).isNotEmpty) {
      widgets.add(_buildRemovedImagesWidget(imageChanges['removed']));
    }

    // Imágenes modificadas
    if (imageChanges['modified'] != null &&
        (imageChanges['modified'] as List).isNotEmpty) {
      widgets.add(_buildModifiedImagesWidget(imageChanges['modified']));
    }

    return _buildChangeCard('Imágenes', widgets);
  }

  Widget _buildAddedImagesWidget(List<dynamic> addedImages) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    // Debug logs
    print('DEBUG _buildAddedImagesWidget:');
    print('  - addedImages count: ${addedImages.length}');
    for (int i = 0; i < addedImages.length; i++) {
      print('  - addedImage[$i]: ${addedImages[i]}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Añadidas:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        SizedBox(height: 8.0),
        ...addedImages.map((image) => _buildImageItem(
            image,
            colorProvider.colors.positiveColor.withOpacity(0.1),
            Border.all(color: colorProvider.colors.positiveColor.withOpacity(0.3)),
            Icons.add_photo_alternate,
            colorProvider.colors.positiveColor)),
      ],
    );
  }

  Widget _buildRemovedImagesWidget(List<dynamic> removedImages) {
    // Debug logs
    print('DEBUG _buildRemovedImagesWidget:');
    print('  - removedImages count: ${removedImages.length}');
    for (int i = 0; i < removedImages.length; i++) {
      print('  - removedImage[$i]: ${removedImages[i]}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Eliminadas:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        SizedBox(height: 8.0),
        ...removedImages.map((image) => _buildImageItem(
            image,
            Colors.red.withOpacity(0.1),
            Border.all(color: Colors.red.withOpacity(0.3)),
            Icons.delete,
            Colors.red)),
      ],
    );
  }

  Widget _buildModifiedImagesWidget(List<dynamic> modifiedImages) {
    // Debug logs
    print('DEBUG _buildModifiedImagesWidget:');
    print('  - modifiedImages count: ${modifiedImages.length}');
    for (int i = 0; i < modifiedImages.length; i++) {
      print('  - modifiedImage[$i]: ${modifiedImages[i]}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Modificadas:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        SizedBox(height: 8.0),
        ...modifiedImages.map((image) => _buildModifiedImageItem(image)),
      ],
    );
  }

  Widget _buildImageItem(Map<String, dynamic> image, Color backgroundColor,
      BoxBorder border, IconData icon, Color iconColor) {
    Map<String, dynamic> imageData = image['imageData'] ?? {};
    String imageName = imageData['descripcion'] ?? 'Imagen sin nombre';
    int imageSize = imageData['size'] ?? 0;
    String sizeText =
        imageSize > 0 ? ' (${(imageSize / 1024).toStringAsFixed(1)} KB)' : '';
    String? imageBase64 = imageData['data'] ?? imageData['imagen'];

    // Debug logs
    print('DEBUG _buildImageItem:');
    print('  - imageName: $imageName');
    print('  - imageSize: $imageSize');
    print('  - imageData keys: ${imageData.keys.toList()}');
    print('  - imageBase64 length: ${imageBase64?.length ?? 0}');
    print('  - imageBase64 is null: ${imageBase64 == null}');
    print('  - imageBase64 is empty: ${imageBase64?.isEmpty ?? true}');
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      print(
          '  - imageBase64 preview: ${imageBase64.substring(0, imageBase64.length > 50 ? 50 : imageBase64.length)}...');
    }

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
          // Miniatura de la imagen usando ProfileImage
          if (imageBase64 != null && imageBase64.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(imageBase64, imageName),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: ProfileImage(
                    base64Image: imageBase64,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.image, color: Colors.grey, size: 24),
                    ),
                    errorWidget: Container(
                      color: Colors.grey[200],
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  imageName,
                  style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.0),
                if (sizeText.isNotEmpty)
                  Text(
                    sizeText,
                    style: TextStyle(fontSize: 14.0, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (imageBase64 != null && imageBase64.isNotEmpty)
            Icon(icon, color: iconColor, size: 30.0),
        ],
      ),
    );
  }

  Widget _buildModifiedImageItem(Map<String, dynamic> image) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    Map<String, dynamic> mods = image['modifications'] ?? {};
    Map<String, dynamic> imageData = image['imageData'] ?? {};
    String imageName = imageData['descripcion'] ?? 'Imagen sin nombre';
    int imageSize = imageData['size'] ?? 0;
    String sizeText =
        imageSize > 0 ? ' (${(imageSize / 1024).toStringAsFixed(1)} KB)' : '';
    String? imageBase64 = imageData['data'] ?? imageData['imagen'];

    // Debug logs
    print('DEBUG _buildModifiedImageItem:');
    print('  - imageName: $imageName');
    print('  - imageSize: $imageSize');
    print('  - imageData keys: ${imageData.keys.toList()}');
    print('  - modifications keys: ${mods.keys.toList()}');
    print('  - imageBase64 length: ${imageBase64?.length ?? 0}');
    print('  - imageBase64 is null: ${imageBase64 == null}');
    print('  - imageBase64 is empty: ${imageBase64?.isEmpty ?? true}');
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      print(
          '  - imageBase64 preview: ${imageBase64.substring(0, imageBase64.length > 50 ? 50 : imageBase64.length)}...');
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8, left: 0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Color.fromARGB(127, 255, 153, 0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Miniatura de la imagen usando ProfileImage
              if (imageBase64 != null && imageBase64.isNotEmpty)
                GestureDetector(
                  onTap: () => _showFullScreenImage(imageBase64, imageName),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: colorProvider.colors.appBarColor.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: ProfileImage(
                        base64Image: imageBase64,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: colorProvider.colors.backgroundColor,
                          child:
                              Icon(Icons.image, color: colorProvider.colors.appBarColor, size: 24),
                        ),
                        errorWidget: Container(
                          color: colorProvider.colors.backgroundColor,
                          child:
                              Icon(Icons.edit, color: Colors.orange, size: 24),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorProvider.colors.backgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: colorProvider.colors.appBarColor.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.edit, color: Colors.orange, size: 24),
                ),
              SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            imageName,
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14.0),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Icon(Icons.edit, color: Colors.orange, size: 30),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mods.isNotEmpty) ...[
            Divider(height: 12.0, thickness: 0.5),
            ...mods.entries.map((entry) {
              String field = entry.key;
              Map<String, dynamic> change = entry.value;
              String fieldName = _getImageFieldDisplayName(field);
              String oldValue = _formatImageFieldValue(field, change['old']);
              String newValue = _formatImageFieldValue(field, change['new']);

              return Padding(
                padding: EdgeInsets.only(left: 0, top: 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Texto Original: $oldValue',
                    style: TextStyle(
                        fontSize: 14.0,
                        color: colorProvider.colors.primaryTextColor,
                        fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  String _getImageFieldDisplayName(String field) {
    switch (field) {
      case 'name':
        return 'Nombre';
      case 'size':
        return 'Tamaño';
      case 'descripcion':
        return 'Descripción';
      default:
        return field;
    }
  }

  String _formatImageFieldValue(String field, dynamic value) {
    switch (field) {
      case 'size':
        return value != null
            ? '${(value / 1024).toStringAsFixed(1)} KB'
            : '0 KB';
      case 'descripcion':
        return value?.toString() ?? 'Sin descripción';
      default:
        return value?.toString() ?? '';
    }
  }

  void _showFullScreenImage(String imageBase64, String imageName) {
    if (imageBase64.isEmpty) return;
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: colorProvider.colors.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: colorProvider.colors.secondaryTextColor),
            title: Text(
              imageName,
              style: TextStyle(color: colorProvider.colors.secondaryTextColor),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: ProfileImage(
                base64Image: imageBase64,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                fit: BoxFit.contain,
                errorWidget: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: colorProvider.colors.secondaryTextColor, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Error al cargar la imagen',
                        style: TextStyle(color: colorProvider.colors.secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
