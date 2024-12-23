import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/database/singleton_db.dart';

class ParticipantsManagementScreen extends StatefulWidget {
  final SharedExpenseGroup group;
  final String userId;

  const ParticipantsManagementScreen({
    Key? key,
    required this.group,
    required this.userId,
  }) : super(key: key);

  @override
  _ParticipantsManagementScreenState createState() =>
      _ParticipantsManagementScreenState();
}

class _ParticipantsManagementScreenState
    extends State<ParticipantsManagementScreen> {
  bool _isLoading = false;
  List<ExpenseParticipant> _participants = [];
  SharingPermissionType _permissionType = SharingPermissionType.creatorOnly;

  @override
  void initState() {
    super.initState();
    _participants = List.from(widget.group.participants);
    _permissionType = widget.group.permissionType;
  }

  Future<void> _addParticipant() async {
    // Implementar lógica para añadir participante
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AddParticipantDialog(),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(result)
            .get();

        if (!userDoc.exists) {
          throw Exception('Usuario no encontrado');
        }

        setState(() {
          _participants.add(ExpenseParticipant(
            userId: result,
            status: ParticipantStatus.pending,
          ));
        });

        await _saveChanges();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeParticipant(String userId) async {
    if (userId == widget.group.creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes eliminar al creador')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      setState(() {
        _participants.removeWhere((p) => p.userId == userId);
      });
      await _saveChanges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    try {
      await FirestoreService().sharedExpenseService.updateSharedExpense(
        widget.group.id,
        widget.group.copyWith(
          participants: _participants,
          permissionType: _permissionType,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestionar Participantes',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            )
          : Column(
              children: [
                _buildPermissionsSection(),
                Expanded(
                  child: _buildParticipantsList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addParticipant,
        backgroundColor: colorProvider.colors.appBarColor,
        child: Icon(
          Icons.person_add,
          color: colorProvider.colors.secondaryTextColor,
        ),
      ),
    );
  }

  Widget _buildPermissionsSection() {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permisos de edición',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<SharingPermissionType>(
              segments: [
                ButtonSegment<SharingPermissionType>(
                  value: SharingPermissionType.creatorOnly,
                  label: Text('Solo creador'),
                ),
                ButtonSegment<SharingPermissionType>(
                  value: SharingPermissionType.allParticipants,
                  label: Text('Todos'),
                ),
              ],
              selected: {_permissionType},
              onSelectionChanged: (Set<SharingPermissionType> newSelection) {
                setState(() {
                  _permissionType = newSelection.first;
                });
                _saveChanges();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsList() {
    return ListView.builder(
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(participant.userId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final username = userData['username'] ?? 'Usuario';

            return ListTile(
              leading: CircleAvatar(
                child: Text(username[0].toUpperCase()),
              ),
              title: Text(username),
              subtitle: Text(participant.status.toString().split('.').last),
              trailing: participant.userId != widget.group.creatorId
                  ? IconButton(
                      icon: const Icon(Icons.remove_circle),
                      onPressed: () => _removeParticipant(participant.userId),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

// Diálogo para añadir participantes
class AddParticipantDialog extends StatefulWidget {
  @override
  _AddParticipantDialogState createState() => _AddParticipantDialogState();
}

class _AddParticipantDialogState extends State<AddParticipantDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return AlertDialog(
      title: Text('Añadir Participante'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'ID de Usuario o Correo',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            final input = _controller.text.trim();
            if (input.isEmpty) return;

            try {
              QuerySnapshot result;
              if (input.contains('@')) {
                result = await FirebaseFirestore.instance
                    .collection('usuarios')
                    .where('email', isEqualTo: input)
                    .limit(1)
                    .get();
              } else {
                result = await FirebaseFirestore.instance
                    .collection('usuarios')
                    .where('userShortId', isEqualTo: input)
                    .limit(1)
                    .get();
              }

              if (result.docs.isEmpty) {
                throw Exception('Usuario no encontrado');
              }

              Navigator.pop(context, result.docs.first.id);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: Text('Añadir'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}