import 'package:control_gastos/models/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/services/friends_service.dart';
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
    // Obtener lista de participantes actuales
    final currentParticipantIds = _participants.map((p) => p.userId).toList();
    
    // Mostrar el diálogo de selección de amigos
    await showDialog(
      context: context,
      builder: (context) => AddParticipantDialog(
        sharedExpenseId: widget.group.id,
        currentParticipants: currentParticipantIds,
      ),
    );
  }



  Future<void> _removeParticipant(String userId) async {
    
    if (userId == widget.group.creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes eliminar al creador')),
      );
      return;
    }

    // Obtener el nombre del participante para el modal
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no encontrado')),
        );
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final username = userData['username'] ?? 'Usuario';

      // Mostrar modal de confirmación
      final bool? confirmed = await _showRemoveParticipantDialog(username);
      
      if (confirmed != true) {
        return;
      }

      setState(() => _isLoading = true);
      
      // Verificar si el participante está pendiente para eliminar notificaciones
      final participantToRemove = _participants.firstWhere(
        (p) => p.userId == userId,
        orElse: () => ExpenseParticipant(userId: userId, status: ParticipantStatus.pending),
      );
      
      setState(() {
        _participants.removeWhere((p) => p.userId == userId);
      });
      
      await _saveChanges();
      
      // Si el participante estaba pendiente, eliminar sus notificaciones de invitación
      if (participantToRemove.status == ParticipantStatus.pending) {
        try {
          await _removeParticipantNotifications(userId);
        } catch (e) {
          print('Error al eliminar notificaciones: $e');
          // No interrumpir el flujo principal por este error
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$username ha sido eliminado del gasto compartido')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges({bool showSuccessMessage = false}) async {
    
    try {
      setState(() => _isLoading = true);
      
      await FirestoreService().sharedExpenseService.updateSharedExpenseDirectly(
            widget.group.id,
            widget.group.copyWith(
              participants: _participants,
              permissionType: _permissionType,
            ),
            widget.userId, // Añadir el ID del usuario actual como modificador
          );

      if (mounted && showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
      }
    } catch (e) {
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final bool isCreator = widget.userId == widget.group.creatorId;

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
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

                  // Solo actualizar si no estamos en medio de una operación de guardado
                  if (!_isLoading) {
                    _participants = updatedGroup.participants;
                    _permissionType = updatedGroup.permissionType;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Solo mostrar la sección de permisos para el creador
                      if (isCreator) _buildPermissionsToggle(),
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

  Widget _buildPermissionsToggle() {
  final colorProvider = Provider.of<ColorProvider>(context);
  final List<bool> isSelected = [
    _permissionType == SharingPermissionType.creatorOnly,
    _permissionType == SharingPermissionType.allParticipants,
  ];

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      // 1. Alinear todos los hijos del Column a la izquierda (inicio).
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          'Permisos del gasto compartido:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: colorProvider.colors.primaryTextColor,
          ),
        ),
        const SizedBox(height: 16),
        // 2. Centrar específicamente el widget de los ToggleButtons.
        Center(
          child: Container(
            child: ToggleButtons(
              direction: Axis.horizontal,
              onPressed: (int index) async {
                final newPermissionType = index == 0
                    ? SharingPermissionType.creatorOnly
                    : SharingPermissionType.allParticipants;
                
                if (newPermissionType != _permissionType) {
                  setState(() {
                    _permissionType = newPermissionType;
                  });
                  
                  try {
                    await _saveChanges();
                  } catch (e) {
                    // Revertir el cambio si hay error
                    setState(() {
                      _permissionType = index == 0
                          ? SharingPermissionType.allParticipants
                          : SharingPermissionType.creatorOnly;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al cambiar permisos: $e')),
                      );
                    }
                  }
                }
              },
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              constraints: const BoxConstraints(
                minHeight: 40.0,
                minWidth: 120.0,
              ),
              isSelected: isSelected,
              selectedColor: colorProvider.colors.appBarColor,
              fillColor: colorProvider.colors.appBarColor,
              splashColor: colorProvider.colors.appBarColor.withOpacity(0.12),
              hoverColor: colorProvider.colors.appBarColor.withOpacity(0.04),
              borderColor: colorProvider.colors.appBarColor,
              selectedBorderColor: colorProvider.colors.appBarColor,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person,
                          color: isSelected[0]
                              ? colorProvider.colors.secondaryTextColor
                              : colorProvider.colors.primaryTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Solo creador',
                        style: TextStyle(
                            color: isSelected[0]
                                ? colorProvider.colors.secondaryTextColor
                                : colorProvider.colors.primaryTextColor),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group,
                          color: isSelected[1]
                              ? colorProvider.colors.secondaryTextColor
                              : colorProvider.colors.primaryTextColor),
                      const SizedBox(width: 8),
                      Text(
                        'Todos los Participantes',
                        style: TextStyle(
                            color: isSelected[1]
                                ? colorProvider.colors.secondaryTextColor
                                : colorProvider.colors.primaryTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildParticipantsList() {
    final colorProvider = Provider.of<ColorProvider>(context);
    
    // Separar participantes por estado
    final acceptedParticipants = _participants.where((p) => 
        p.status == ParticipantStatus.accepted || p.userId == widget.group.creatorId).toList();
    final pendingParticipants = _participants.where((p) => 
        p.status == ParticipantStatus.pending).toList();
    
    // Ordenar participantes aceptados: creador primero
    acceptedParticipants.sort((a, b) {
      if (a.userId == widget.group.creatorId) return -1;
      if (b.userId == widget.group.creatorId) return 1;
      return 0;
    });
    
    return ListView(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 48),
      children: [
        // Sección de participantes aceptados
        if (acceptedParticipants.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Participantes Activos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
          ),
          ...acceptedParticipants.map((participant) => _buildParticipantCard(participant, colorProvider)),
        ],
        
        // Sección de participantes pendientes
        if (pendingParticipants.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Invitaciones Pendientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
          ),
          ...pendingParticipants.map((participant) => _buildPendingParticipantCard(participant, colorProvider)),
        ],
      ],
    );
  }
  
  Widget _buildParticipantCard(ExpenseParticipant participant, ColorProvider colorProvider) {
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
        final userShortId = userData['userShortId'] ?? 'N/A';

        String statusText;
        Color statusColor;
        if (isCreator) {
          statusText = 'Creador';
          statusColor = colorProvider.colors.appBarColor;
        } else {
          statusText = 'Aceptado';
          statusColor = colorProvider.colors.positiveColor;
        }
        
        final shouldShowRemove = _shouldShowRemoveButton(participant.userId);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
          color: colorProvider.colors.backgroundColor,
          elevation: 4,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorProvider.colors.appBarColor,
              radius: 25,
              child: Text(
                username[0].toUpperCase(),
                style: TextStyle(
                  color: colorProvider.colors.secondaryTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              username,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'ID: $userShortId',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: shouldShowRemove
                ? IconButton(
                    icon: Icon(
                      Icons.person_remove,
                      color: colorProvider.colors.negativeColor,
                      size: 24,
                    ),
                    onPressed: () {
                      _removeParticipant(participant.userId);
                    },
                  )
                : (isCreator 
                    ? Icon(
                        Icons.star,
                        color: colorProvider.colors.appBarColor,
                        size: 24,
                      )
                    : null),
          ),
        );
      },
    );
  }
  
  Widget _buildPendingParticipantCard(ExpenseParticipant participant, ColorProvider colorProvider) {
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
        final userShortId = userData['userShortId'] ?? 'N/A';
        
        final shouldShowRemove = _shouldShowRemoveButton(participant.userId);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
          color: colorProvider.colors.backgroundColor,
          elevation: 4,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.2),
              radius: 25,
              child: Text(
                username[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              username,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'ID: $userShortId',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: colorProvider.colors.appBarColor,
                    size: 24,
                  ),
                  onPressed: () {
                    _resendInvitation(participant.userId);
                  },
                  tooltip: 'Reenviar invitación',
                ),
                if (shouldShowRemove)
                  IconButton(
                    icon: Icon(
                      Icons.person_remove,
                      color: colorProvider.colors.negativeColor,
                      size: 24,
                    ),
                    onPressed: () {
                      _removeParticipant(participant.userId);
                    },
                    tooltip: 'Eliminar participante',
                  ),
              ],
            ),
          ),
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
  
  // Método para reenviar invitación
  Future<void> _resendInvitation(String userId) async {
    try {
      setState(() => _isLoading = true);
      
      await FirestoreService()
          .sharedExpenseService
          .sendParticipationRequest(widget.group.id, userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invitación reenviada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reenviar invitación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeParticipantNotifications(String userId) async {
    try {
      // Buscar y eliminar todas las notificaciones relacionadas con este gasto compartido
      final notificationsRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('notifications')
          .where('sourceId', isEqualTo: widget.group.id)
          .where('type', isEqualTo: NotificationType.sharedExpense.toString());

      final notifications = await notificationsRef.get();

      // Eliminar todas las notificaciones encontradas
      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      print('Eliminadas ${notifications.docs.length} notificaciones para el usuario $userId');
    } catch (e) {
      print('Error al eliminar notificaciones del participante: $e');
      rethrow;
    }
  }

  // Modal de confirmación para eliminar participante
  Future<bool?> _showRemoveParticipantDialog(String username) async {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorProvider.colors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colorProvider.colors.negativeColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Eliminar Participante',
                  style: TextStyle(
                    color: colorProvider.colors.primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que quieres eliminar a',
                style: TextStyle(
                  color: colorProvider.colors.primaryTextColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorProvider.colors.appBarColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorProvider.colors.appBarColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: colorProvider.colors.appBarColor,
                      radius: 16,
                      child: Text(
                        username[0].toUpperCase(),
                        style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      username,
                      style: TextStyle(
                        color: colorProvider.colors.primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'del gasto compartido?',
                style: TextStyle(
                  color: colorProvider.colors.primaryTextColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                  color: colorProvider.colors.negativeColor,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: colorProvider.colors.primaryTextColor,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorProvider.colors.negativeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Eliminar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Diálogo para añadir participantes
class AddParticipantDialog extends StatefulWidget {
  final String sharedExpenseId;
  final List<String> currentParticipants;

  const AddParticipantDialog({
    super.key,
    required this.sharedExpenseId,
    required this.currentParticipants,
  });

  @override
  State<AddParticipantDialog> createState() => _AddParticipantDialogState();
}

class _AddParticipantDialogState extends State<AddParticipantDialog> {
  bool _isLoading = false;
  final Set<String> _selectedFriends = {};
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    
    return AlertDialog(
      backgroundColor: colorProvider.colors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.person_add,
            color: colorProvider.colors.appBarColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Añadir Participantes',
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona amigos para invitar:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<DocumentSnapshot>>(
                stream: FriendsService().getFriendsList(_currentUserId),
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
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(
                          color: colorProvider.colors.negativeColor,
                        ),
                      ),
                    );
                  }

                  final friends = snapshot.data ?? [];
                  
                  // Filtrar amigos que ya son participantes
                  final availableFriends = friends.where((friend) {
                    return !widget.currentParticipants.contains(friend.id);
                  }).toList();

                  if (availableFriends.isEmpty) {
                    return Center(
                      child: Text(
                        'No hay amigos disponibles para invitar',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: availableFriends.length,
                    itemBuilder: (context, index) {
                      final friend = availableFriends[index];
                      final friendData = friend.data() as Map<String, dynamic>;
                      final friendId = friend.id;
                      final isSelected = _selectedFriends.contains(friendId);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: colorProvider.colors.backgroundColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: isSelected 
                              ? BorderSide(
                                  color: colorProvider.colors.appBarColor,
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorProvider.colors.appBarColor,
                            child: Text(
                              (friendData['username'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: colorProvider.colors.secondaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            friendData['username'] ?? 'Usuario',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                          subtitle: Text(
                            friendData['email'] ?? '',
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                            ),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            activeColor: colorProvider.colors.appBarColor,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedFriends.add(friendId);
                                } else {
                                  _selectedFriends.remove(friendId);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedFriends.remove(friendId);
                              } else {
                                _selectedFriends.add(friendId);
                              }
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: CircularProgressIndicator(
                    color: colorProvider.colors.appBarColor,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Cancelar',
            style: TextStyle(
              color: colorProvider.colors.primaryTextColor,
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedFriends.isEmpty ? null : _addSelectedParticipants,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorProvider.colors.appBarColor,
            foregroundColor: colorProvider.colors.secondaryTextColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _selectedFriends.isEmpty 
                ? 'Seleccionar amigos'
                : 'Invitar (${_selectedFriends.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addSelectedParticipants() async {
    if (_selectedFriends.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Enviar solicitudes a todos los amigos seleccionados
      for (String friendId in _selectedFriends) {
        await FirestoreService()
            .sharedExpenseService
            .sendParticipationRequest(widget.sharedExpenseId, friendId);
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solicitudes enviadas a ${_selectedFriends.length} amigo${_selectedFriends.length > 1 ? 's' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
