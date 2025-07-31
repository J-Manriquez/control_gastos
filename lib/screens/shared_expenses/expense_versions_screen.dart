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
  Map<String, String> _userNames = {};
  Stream<QuerySnapshot>? _versionsStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
    _loadUserNames();
  }

  void _initializeStream() {
    _versionsStream = FirebaseFirestore.instance
        .collection('sharedExpenses')
        .doc(widget.expenseId)
        .collection('versions')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _loadVersions() async {
    // Este método se mantiene para compatibilidad pero ya no se usa
    // La carga ahora se hace a través del StreamBuilder
  }

  Future<void> _loadUserNames() async {
    // Cargar nombres de usuarios de forma dinámica cuando se necesiten
    // Este método ahora se llama desde _getUserName cuando es necesario
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _versionsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar versiones: ${snapshot.error}',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No hay versiones disponibles',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          List<Map<String, dynamic>> versions = snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['versionId'] = doc.id;
            return data;
          }).toList();

          return ListView.builder(
            padding: EdgeInsets.all(16.0),
            itemCount: versions.length,
            itemBuilder: (context, index) {
              return _buildVersionCard(versions[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildVersionCard(Map<String, dynamic> version) {
    final colorProvider = Provider.of<ColorProvider>(context).colors;
    String versionId = version['versionId'] ?? '';
    String modifierId = version['modifierId'] ?? '';
    String status = version['status'] ?? 'pending';
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
      color: colorProvider.backgroundColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorProvider.appBarColor,
          width: 1.5,
        ),
      ),
      margin: EdgeInsets.only(bottom: 12.0),
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
                  Expanded(
                    child: Text(
                      'Versión: ${versionId.length > 8 ? versionId.substring(0, 8) + '...' : versionId}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorProvider.primaryTextColor,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              SizedBox(height: 8.0),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: colorProvider.primaryTextColor),
                  SizedBox(width: 4.0),
                  FutureBuilder<String>(
                    future: _getUserName(modifierId),
                    builder: (context, snapshot) {
                      String modifierName = snapshot.data ?? 'Cargando...';
                      return Text(
                        'Modificado por: $modifierName',
                        style: TextStyle(fontSize: 14, color: colorProvider.primaryTextColor),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 4.0),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: colorProvider.primaryTextColor),
                  SizedBox(width: 4.0),
                  Text(
                    'Fecha: $formattedTimestamp',
                    style: TextStyle(fontSize: 14, color: colorProvider.primaryTextColor),
                  ),
                ],
              ),
              SizedBox(height: 8.0),
              if (changeTypes.isNotEmpty) ...[
                Text(
                  'Tipos de cambios:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: colorProvider.primaryTextColor,
                  ),
                ),
                SizedBox(height: 4.0),
                Wrap(
                  spacing: 4.0,
                  runSpacing: 4.0,
                  children: changeTypes
                      .map((type) => Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getChangeTypeColor(type),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getChangeTypeDisplayName(type),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorProvider.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
              SizedBox(height: 8.0),
              if (status == 'pending') ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sharedExpenses')
                      .doc(widget.expenseId)
                      .collection('versions')
                      .doc(versionId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      Map<String, dynamic> versionData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      List<dynamic> liveVotes = versionData['votes'] ?? [];
                      return Row(
                        children: [
                          Icon(Icons.how_to_vote, size: 16, color: colorProvider.primaryTextColor),
                          SizedBox(width: 4.0),
                          Text(
                            'Votos: ${liveVotes.length}',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.bold,
                              color: colorProvider.primaryTextColor,
                            ),
                          ),
                          Spacer(),
                          if (liveVotes.isNotEmpty) _buildVoteSummary(liveVotes),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Icon(Icons.how_to_vote, size: 16, color: colorProvider.primaryTextColor),
                          SizedBox(width: 4.0),
                          Text(
                            'Votos: ${votes.length}',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.bold,
                              color: colorProvider.primaryTextColor,
                            ),
                          ),
                          Spacer(),
                          if (votes.isNotEmpty) _buildVoteSummary(votes),
                        ],
                      );
                    }
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(Icons.how_to_vote, size: 16, color: colorProvider.primaryTextColor),
                    SizedBox(width: 4.0),
                    Text(
                      'Votos: ${votes.length}',
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                        color: colorProvider.primaryTextColor,
                      ),
                    ),
                    Spacer(),
                    if (votes.isNotEmpty) _buildVoteSummary(votes),
                  ],
                ),
              ],
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
        chipColor = const Color.fromARGB(255, 35, 32, 32);
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

  Widget _buildVoteSummaryStream(String versionId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sharedExpenses')
          .doc(widget.expenseId)
          .collection('versions')
          .doc(versionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text('Cargando votos...');
        }

        Map<String, dynamic> versionData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        List<dynamic> votes = versionData['votes'] ?? [];
        int accepted = votes.where((vote) => vote['status'] == 'VoteStatus.accepted').length;
        int rejected = votes.where((vote) => vote['status'] == 'VoteStatus.rejected').length;
        int pending = votes.where((vote) => vote['status'] == 'VoteStatus.pending').length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVoteChip('✓', accepted, Colors.green),
            SizedBox(width: 4),
            _buildVoteChip('✗', rejected, Colors.red),
            SizedBox(width: 4),
            _buildVoteChip('⏳', pending, Colors.orange),
          ],
        );
      },
    );
  }

  Widget _buildVoteChip(String icon, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(color: color, fontSize: 10)),
          SizedBox(width: 2),
          Text('$count', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVoteSummary(List<dynamic> votes) {
    int accepted = votes.where((vote) => vote['status'] == 'VoteStatus.accepted').length;
    int rejected = votes.where((vote) => vote['status'] == 'VoteStatus.rejected').length;
    int pending = votes.where((vote) => vote['status'] == 'VoteStatus.pending').length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVoteChip('✓', accepted, Colors.green),
        SizedBox(width: 4),
        _buildVoteChip('✗', rejected, Colors.red),
        SizedBox(width: 4),
        _buildVoteChip('⏳', pending, Colors.orange),
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
        return Colors.blue[700]!;
      case 'amount_change':
        return Colors.green[700]!;
      case 'expense_change':
        return Colors.orange[700]!;
      case 'subgroup_change':
        return Colors.purple[700]!;
      case 'participant_change':
        return Colors.teal[700]!;
      case 'distribution_change':
        return Colors.red[700]!;
      case 'image_change':
        return Colors.yellow[700]!;
      default:
        return const Color.fromARGB(255, 25, 26, 26);
    }
  }
}
