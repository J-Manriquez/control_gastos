import 'package:control_gastos/models/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/widgets/expense_drawer.dart';
import 'package:uuid/uuid.dart';

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
  late Stream<DocumentSnapshot> _sharedExpenseStream;
  List<ExpenseParticipant> _participants = [];
  SharingPermissionType _permissionType = SharingPermissionType.creatorOnly;

  @override
  void initState() {
    super.initState();
    _participants = List.from(widget.group.participants);
    _permissionType = widget.group.permissionType;

    // Configurar el stream para escuchar cambios en el documento del gasto compartido
    _sharedExpenseStream = FirebaseFirestore.instance
        .collection('sharedExpenses')
        .doc(widget.group.id)
        .snapshots();
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

        // Verificar si el usuario ya es participante
        if (_participants.any((p) => p.userId == result)) {
          throw Exception('El usuario ya es participante');
        }

        // Crear nuevo participante
        final newParticipant = ExpenseParticipant(
          userId: result,
          status: ParticipantStatus.pending,
        );

        setState(() {
          _participants.add(newParticipant);
        });

        // Guardar cambios en Firestore
        await _saveChanges();

        // Enviar notificación al nuevo participante
        await _notifyNewParticipant(result);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Método para enviar notificación al nuevo participante
  Future<void> _notifyNewParticipant(String userId) async {
    try {
      // Obtener datos del creador para la notificación
      final creatorDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .get();
      final creatorData = creatorDoc.data() as Map<String, dynamic>;
      final creatorName = creatorData['username'] ?? 'Usuario';

      // Crear notificación
      final notificationId = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .set({
        'id': notificationId,
        'title': 'Nuevo gasto compartido',
        'message': '$creatorName te ha invitado a un gasto compartido',
        'type': NotificationType.sharedExpense.toString(),
        'sourceId': widget.group.id,
        'senderId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'additionalData': {
          'status': 'pending',
          'expenseName': widget.group.nombre,
          'total': widget.group.total,
        }
      });
    } catch (e) {
      print('Error al enviar notificación: $e');
      // No lanzar excepción para no interrumpir el flujo principal
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
            widget.userId, // Añadir el ID del usuario actual como modificador
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
    final bool isCreator = widget.userId == widget.group.creatorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestionar Participantes',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      // drawer: ExpenseDrawer(userUid: widget.userId),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: _sharedExpenseStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: colorProvider.colors.appBarColor,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.hasData && snapshot.data!.exists) {
                  // Actualizar datos del gasto compartido
                  final sharedExpenseData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final updatedGroup =
                      SharedExpenseGroup.fromMap(sharedExpenseData);

                  // Actualizar participantes y permisos
                  _participants = updatedGroup.participants;
                  _permissionType = updatedGroup.permissionType;

                  return Column(
                    children: [
                      // Solo mostrar la sección de permisos para el creador
                      if (isCreator) _buildPermissionsSection(),
                      Expanded(
                        child: _buildParticipantsList(),
                      ),
                      Container(
                        height: 80,
                        color: Colors.transparent,
                      )
                    ],
                  );
                }

                return Center(
                  child: Text('No se encontró el gasto compartido'),
                );
              },
            ),
      floatingActionButton: _shouldShowAddButton()
          ? FloatingActionButton(
              onPressed: _addParticipant,
              backgroundColor: colorProvider.colors.appBarColor,
              child: Icon(
                Icons.person_add,
                color: colorProvider.colors.secondaryTextColor,
              ),
            )
          : null,
    );
  }

  // Método para determinar si se debe mostrar el botón de añadir participante
  bool _shouldShowAddButton() {
    // Siempre mostrar para el creador
    if (widget.userId == widget.group.creatorId) {
      return true;
    }

    // Para participantes, mostrar solo si los permisos son para todos
    return _permissionType == SharingPermissionType.allParticipants;
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
    // Ordenar participantes: creador primero, luego el resto
    final sortedParticipants = List<ExpenseParticipant>.from(_participants);

    // Mover el creador al principio de la lista
    sortedParticipants.sort((a, b) {
      if (a.userId == widget.group.creatorId) return -1;
      if (b.userId == widget.group.creatorId) return 1;
      return 0;
    });

    return ListView.builder(
      itemCount: sortedParticipants.length,
      itemBuilder: (context, index) {
        final participant = sortedParticipants[index];
        final bool isCreator = participant.userId == widget.group.creatorId;

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

            // Determinar el texto de estado según el estado del participante
            String statusText;
            if (isCreator) {
              statusText = 'Creador';
            } else {
              // Convertir el enum a texto más legible
              switch (participant.status) {
                case ParticipantStatus.pending:
                  statusText = 'Pendiente';
                  break;
                case ParticipantStatus.accepted:
                  statusText = 'Aceptado';
                  break;
                case ParticipantStatus.rejected:
                  statusText = 'Rechazado';
                  break;
                default:
                  statusText = participant.status.toString().split('.').last;
              }
            }

            return ListTile(
              leading: CircleAvatar(
                child: Text(username[0].toUpperCase()),
              ),
              title: Text(username),
              subtitle: Text(statusText),
              trailing: _shouldShowRemoveButton(participant.userId)
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

  // Método para determinar si se debe mostrar el botón de eliminar
  bool _shouldShowRemoveButton(String participantId) {
    // Nunca mostrar para el creador
    if (participantId == widget.group.creatorId) {
      return false;
    }

    // Si el usuario actual es el creador, siempre puede eliminar participantes
    if (widget.userId == widget.group.creatorId) {
      return true;
    }

    // Para participantes, solo mostrar si los permisos son para todos
    return _permissionType == SharingPermissionType.allParticipants;
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
