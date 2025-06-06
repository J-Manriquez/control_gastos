import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/version_vote_model.dart';
import 'package:control_gastos/screens/version_details_screen.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ExpenseVersionsScreen extends StatefulWidget {
  final String expenseId;
  final String currentUserId;
  final String expenseName;

  const ExpenseVersionsScreen({
    Key? key,
    required this.expenseId,
    required this.currentUserId,
    required this.expenseName,
  }) : super(key: key);

  @override
  _ExpenseVersionsScreenState createState() => _ExpenseVersionsScreenState();
}

class _ExpenseVersionsScreenState extends State<ExpenseVersionsScreen> {
  final CustomLogger _logger = CustomLogger();
  bool _isLoading = true;
  List<Map<String, dynamic>> _versions = [];
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Obtener todas las versiones
      final versionsSnapshot = await FirebaseFirestore.instance
          .collection('sharedExpenses')
          .doc(widget.expenseId)
          .collection('versions')
          .orderBy('timestamp', descending: true)
          .get();

      _versions = versionsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['versionId'] = doc.id;
        return data;
      }).toList();

      // Cargar nombres de usuarios
      await _loadUserNames();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.logError('Error al cargar versiones: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar versiones: $e')),
      );
    }
  }

  Future<void> _loadUserNames() async {
    Set<String> userIds = {};

    // Recopilar todos los IDs de usuarios de las versiones
    for (var version in _versions) {
      String modifierId = version['modifierId'] ?? '';
      if (modifierId.isNotEmpty) {
        userIds.add(modifierId);
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

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context).colors;

    return Scaffold(
      backgroundColor: colorProvider.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Versiones - ${widget.expenseName}',
          style:
              TextStyle(color: colorProvider.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.secondaryTextColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _versions.isEmpty
              ? Center(
                  child: Text(
                    'No hay versiones disponibles',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.0),
                  itemCount: _versions.length,
                  itemBuilder: (context, index) {
                    return _buildVersionCard(_versions[index]);
                  },
                ),
    );
  }

  Widget _buildVersionCard(Map<String, dynamic> version) {
    String versionId = version['versionId'] ?? '';
    String modifierId = version['modifierId'] ?? '';
    String modifierName = _userNames[modifierId] ?? 'Usuario desconocido';
    String status = version['status'] ?? 'pending';
    // String timestamp = version['timestamp'] ?? ''; // Old problematic line
    Timestamp? timestampData = version['timestamp'] as Timestamp?;
    String formattedTimestamp = '';
    if (timestampData != null) {
      DateTime dateTime = timestampData.toDate();
      formattedTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } else {
      formattedTimestamp = 'Fecha desconocida';
    }

    List<dynamic> votes = version['votes'] ?? [];
    List<String> changeTypes = List<String>.from(version['changeTypes'] ?? []);

    return Card(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 12.0),
      elevation: 6,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VersionDetailsScreen(
                expenseId: widget.expenseId,
                version: versionId,
                currentUserId: widget.currentUserId,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Versión $versionId',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              SizedBox(height: 8.0),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4.0),
                  Text(
                    'Modificado por: $modifierName',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4.0),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4.0),
                  Text(
                    'Fecha: $formattedTimestamp',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8.0),
              if (changeTypes.isNotEmpty) ...[
                Text(
                  'Tipos de cambios:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4.0),
                Wrap(
                  spacing: 4.0,
                  children: changeTypes
                      .map((type) => Chip(
                            label: Text(
                              _getChangeTypeDisplayName(type),
                              style: TextStyle(fontSize: 12),
                            ),
                            backgroundColor: _getChangeTypeColor(type),
                          ))
                      .toList(),
                ),
              ],
              SizedBox(height: 8.0),
              Row(
                children: [
                  Icon(Icons.how_to_vote, size: 16, color: const Color.fromARGB(255, 0, 0, 0)),
                  SizedBox(width: 4.0),
                  Text(
                    'Votos: ${votes.length}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  if (votes.isNotEmpty) _buildVoteSummary(votes),
                ],
              ),
            ],
          ),
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
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: chipColor,
    );
  }

  Widget _buildVoteSummary(List<dynamic> votes) {
    int accepted = 0;
    int rejected = 0;
    int pending = 0;

    for (var vote in votes) {
      String status = vote['status'] ?? '';
      switch (status) {
        case 'VoteStatus.accepted':
          accepted++;
          break;
        case 'VoteStatus.rejected':
          rejected++;
          break;
        default:
          pending++;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (accepted > 0) ...[
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          Text(' $accepted',
              style: TextStyle(color: Colors.green, fontSize: 12)),
          SizedBox(width: 8.0),
        ],
        if (rejected > 0) ...[
          Icon(Icons.cancel, color: Colors.red, size: 16),
          Text(' $rejected', style: TextStyle(color: Colors.red, fontSize: 12)),
          SizedBox(width: 8.0),
        ],
        if (pending > 0) ...[
          Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
          Text(' $pending',
              style: TextStyle(color: Colors.orange, fontSize: 12)),
        ],
      ],
    );
  }

  String _getChangeTypeDisplayName(String type) {
    switch (type) {
      case 'name_change':
        return 'Nombre';
      case 'amount_change':
        return 'Monto Total';
      case 'expense_change':
        return 'Gastos';
      case 'subgroup_change':
        return 'Subgrupos';
      case 'participant_change':
        return 'Participantes';
      case 'distribution_change':
        return 'Distribución';
      default:
        return type;
    }
  }

  Color _getChangeTypeColor(String type) {
    switch (type) {
      case 'name_change':
        return Colors.blue[100]!;
      case 'amount_change':
        return Colors.green[100]!;
      case 'expense_change':
        return Colors.orange[100]!;
      case 'subgroup_change':
        return Colors.purple[100]!;
      case 'participant_change':
        return Colors.teal[100]!;
      case 'distribution_change':
        return Colors.red[100]!;
      default:
        return Colors.grey[100]!;
    }
  }
}
