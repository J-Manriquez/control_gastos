import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/version_vote_model.dart';
import 'package:control_gastos/services/shared_expense_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';

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
  
  bool _isLoading = true;
  Map<String, dynamic>? _versionData;
  SharedExpenseGroup? _originalGroup;
  SharedExpenseGroup? _updatedGroup;
  List<VersionVoteModel> _votes = [];
  String _versionStatus = 'pending';
  bool _userHasVoted = false;
  VoteStatus? _userVoteStatus;
  SharingPermissionType _permissionType = SharingPermissionType.allParticipants;
  String _modifierName = '';

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
      
      // Obtener datos del grupo original
      _originalGroup = await _sharedExpenseService.getSharedExpense(widget.expenseId);
      
      // Obtener datos del grupo actualizado
      _updatedGroup = SharedExpenseGroup.fromMap(_versionData?['data'] ?? {});
      
      // Obtener votos
      List<dynamic> votesData = _versionData?['votes'] ?? [];
      _votes = votesData.map((vote) => VersionVoteModel.fromMap(vote)).toList();
      
      // Verificar si el usuario actual ya votó
      var userVote = _votes.where((vote) => vote.userId == widget.currentUserId).toList();
      _userHasVoted = userVote.isNotEmpty;
      if (_userHasVoted) {
        _userVoteStatus = userVote.first.status;
      }
      
      // Obtener tipo de permiso
      _permissionType = _originalGroup?.permissionType ?? SharingPermissionType.allParticipants;
      
      // Obtener nombre del modificador
      String modifierId = _versionData?['modifierId'] ?? '';
      if (modifierId.isNotEmpty) {
        final modifierDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(modifierId)
            .get();
        _modifierName = modifierDoc.data()?['username'] ?? 'Usuario desconocido';
      }

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de Cambios'),
      ),
      body: _isLoading
          ? const CircularProgressIndicator()
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVersionInfo(),
                  SizedBox(height: 16.0),
                  _buildChangesSection(),
                  SizedBox(height: 16.0),
                  _buildVotesSection(),
                  SizedBox(height: 24.0),
                  if (_versionStatus == 'pending' && !_userHasVoted)
                    _buildVotingButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildVersionInfo() {
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
              'Fecha: ${_versionData?['timestamp']?.toDate().toString() ?? 'No disponible'}',
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

  Widget _buildChangesSection() {
    if (_originalGroup == null || _updatedGroup == null) {
      return Text('No se pueden mostrar los cambios');
    }

    List<Widget> changes = [];

    // Comparar nombre del grupo
    if (_originalGroup!.nombre != _updatedGroup!.nombre) {
      changes.add(_buildChangeItem(
        'Nombre del grupo',
        _originalGroup!.nombre,
        _updatedGroup!.nombre,
      ));
    }

    // Comparar total
    if (_originalGroup!.total != _updatedGroup!.total) {
      changes.add(_buildChangeItem(
        'Total',
        _originalGroup!.total.toString(),
        _updatedGroup!.total.toString(),
      ));
    }

    // Comparar gastos
    if (_originalGroup!.expenses.length != _updatedGroup!.expenses.length) {
      changes.add(_buildChangeItem(
        'Número de gastos',
        _originalGroup!.expenses.length.toString(),
        _updatedGroup!.expenses.length.toString(),
      ));
    }

    // Comparar subgrupos
    if (_originalGroup!.subgroups.length != _updatedGroup!.subgroups.length) {
      changes.add(_buildChangeItem(
        'Número de subgrupos',
        _originalGroup!.subgroups.length.toString(),
        _updatedGroup!.subgroups.length.toString(),
      ));
    }

    // Comparar participantes
    if (_originalGroup!.participants.length != _updatedGroup!.participants.length) {
      changes.add(_buildChangeItem(
        'Número de participantes',
        _originalGroup!.participants.length.toString(),
        _updatedGroup!.participants.length.toString(),
      ));
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cambios Realizados',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            changes.isEmpty
                ? Text('No se detectaron cambios en los datos principales')
                : Column(children: changes),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeItem(String field, String oldValue, String newValue) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Anterior: $oldValue',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              Icon(Icons.arrow_forward, size: 16.0),
              Expanded(
                child: Text(
                  'Nuevo: $newValue',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                    children: _votes.map((vote) => _buildVoteItem(vote)).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteItem(VersionVoteModel vote) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(vote.userId).get(),
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