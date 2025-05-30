import 'dart:async';

import 'dart:async';

import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/screens/cuenta/user_profile_screen.dart';
import 'package:control_gastos/screens/friends/friends_list_screen.dart';
import 'package:control_gastos/screens/gastos/edicion_gastos.dart';
import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/gastos/insercion_gastos_sc.dart';
import 'package:control_gastos/screens/shared_expenses/distribution_summary_screen.dart';
import 'package:control_gastos/screens/shared_expenses/participants_management_screen.dart';
import 'package:control_gastos/screens/shared_expenses/share_expense_options_screen.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:control_gastos/screens/notifications/notifications_screen.dart';
import 'package:control_gastos/screens/shared_expenses/shared_edicion_gastos.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:control_gastos/widgets/expense_details_widget.dart';
import 'package:control_gastos/widgets/expense_drawer.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:async/async.dart';
import 'package:rxdart/rxdart.dart' show Rx, SwitchMapExtension;

class ArchiveExpenseGroupsScreen extends StatefulWidget {
  final String userUid;

  const ArchiveExpenseGroupsScreen({super.key, required this.userUid});

  @override
  _ArchiveExpenseGroupsScreenState createState() =>
      _ArchiveExpenseGroupsScreenState();
}

class _ArchiveExpenseGroupsScreenState
    extends State<ArchiveExpenseGroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late List<bool> _isOpen;
  bool _showSharedExpenses = false;
  List<bool> _isSelectedToggle = [true, false];

  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  List<String> _groupOrder = [];
  static const String _orderPrefsKey = 'archive_expense_groups_order';

  @override
  void initState() {
    super.initState();
    _isOpen = [];
    _loadSavedOrder();

    // Añadir debug de gastos compartidos
    FirestoreService().debugSharedExpenses(widget.userUid).then((_) {
      CustomLogger().logInfo('Debug de gastos compartidos completado');
    }).catchError((error) {
      CustomLogger().logError('Error en debug de gastos compartidos: $error');
    });
  }

  Future<void> _loadSavedOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_orderPrefsKey);

      if (savedOrder != null && savedOrder.isNotEmpty) {
        setState(() {
          _groupOrder = savedOrder;
        });
      } else {
        // Si no hay orden guardado, inicializar con IDs actuales de los grupos.
        final groupsSnapshot = await _firestore
            .collection('usuarios')
            .doc(widget.userUid)
            .collection('expenseGroups')
            .where('archivado', isEqualTo: false)
            .get();

        final groupIds = groupsSnapshot.docs.map((doc) => doc.id).toList();

        setState(() {
          _groupOrder = groupIds;
        });

        await _saveOrder(_groupOrder); // Guardar el orden inicial.
      }

      CustomLogger().logInfo('Orden cargado exitosamente: $_groupOrder');
    } catch (e) {
      CustomLogger().logError('Error al cargar el orden guardado: $e');
    }
  }

  Future<void> _saveOrder(List<String> newOrder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_orderPrefsKey, newOrder);
    } catch (e) {
      CustomLogger().logError('Error al guardar el orden: $e');
    }
  }

  Stream<List<GroupModel>> _getPersonalExpenses() {
    final CustomLogger logger = CustomLogger();

    return _firestore
        .collection('usuarios')
        .doc(widget.userUid)
        .collection('expenseGroups')
        .where('archivado', isEqualTo: true) // Filtrar solo los no archivados
        .snapshots()
        .map((snapshot) {
      logger.logInfo(
          'Cargando gastos personales no archivados:: ${snapshot.docs.length} encontrados');
      return snapshot.docs
          .map((doc) {
            try {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id;
              return GroupModel.fromFirestore(doc);
            } catch (e, stackTrace) {
              logger.logError(
                  'Error al convertir gasto personal: $e\n$stackTrace');
              return null;
            }
          })
          .where((group) => group != null)
          .cast<GroupModel>()
          .toList();
    }).handleError((error) {
      logger.logError('Error en stream de gastos personales: $error');
      return <GroupModel>[];
    });
  }

  Stream<List<GroupModel>> _getSharedExpenses() {
    final CustomLogger logger = CustomLogger();

    return _firestore
        .collection('usuarios')
        .doc(widget.userUid)
        .snapshots()
        .switchMap((userDoc) {
      if (!userDoc.exists) {
        logger.logError('Usuario no encontrado');
        return Stream.value(<GroupModel>[]);
      }

      // Obtener mapa de gastos compartidos
      final Map<String, dynamic> sharedExpensesMap =
          Map<String, dynamic>.from(userDoc.data()?['sharedExpensesMap'] ?? {});

      // Filtrar los IDs de gastos archivados
      final List<String> archivedIds = sharedExpensesMap.entries
          .where((entry) => entry.value['archivado'] == true)
          .map((entry) => entry.key)
          .toList();

      if (archivedIds.isEmpty) {
        logger
            .logInfo('No hay gastos compartidos archivados para este usuario');
        return Stream.value(<GroupModel>[]);
      }

      return _firestore
          .collection('sharedExpenses')
          .where(FieldPath.documentId,
              whereIn: archivedIds) // Filtrar por IDs específicos
          .snapshots()
          .map((snapshot) {
        logger.logInfo(
            'Cargando gastos compartidos archivados: ${snapshot.docs.length} encontrados');
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                final group = SharedExpenseGroup.fromMap(data);

                // Filtrar participantes por el usuario actual y estado 'accepted'
                final participant = group.participants.firstWhere(
                  (p) => p.userId == widget.userUid,
                  orElse: () => ExpenseParticipant(
                      userId: widget.userUid,
                      status: ParticipantStatus.pending),
                );

                // Retornar el grupo solo si el estado del participante es 'accepted'
                return participant.status == ParticipantStatus.accepted
                    ? group
                    : null;
              } catch (e, stackTrace) {
                logger.logError(
                    'Error al convertir gasto compartido: $e\n$stackTrace');
                return null;
              }
            })
            .where((group) => group != null)
            .cast<GroupModel>()
            .toList();
      });
    }).handleError((error) {
      logger.logError('Error en stream de gastos compartidos: $error');
      return <GroupModel>[];
    });
  }

  Widget _buildToggleButtons() {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ToggleButtons(
        direction: Axis.horizontal,
        onPressed: (int index) {
          setState(() {
            for (int i = 0; i < _isSelectedToggle.length; i++) {
              _isSelectedToggle[i] = i == index;
            }
            _showSharedExpenses = index == 1;
          });
        },
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        constraints: const BoxConstraints(
          minHeight: 40.0,
          minWidth: 180.0,
        ),
        isSelected: _isSelectedToggle,
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
                    color: _isSelectedToggle[0]
                        ? colorProvider.colors.secondaryTextColor
                        : colorProvider.colors.primaryTextColor),
                const SizedBox(width: 8),
                Text(
                  'Personales',
                  style: TextStyle(
                      color: _isSelectedToggle[0]
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
                    color: _isSelectedToggle[1]
                        ? colorProvider.colors.secondaryTextColor
                        : colorProvider.colors.primaryTextColor),
                const SizedBox(width: 8),
                Text(
                  'Compartidos',
                  style: TextStyle(
                      color: _isSelectedToggle[1]
                          ? colorProvider.colors.secondaryTextColor
                          : colorProvider.colors.primaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 
  Future<void> _updateGroupsOrder(int oldIndex, int newIndex) async {
    // Obtener la lista actual de grupos mostrados
    final groups = await (_showSharedExpenses
        ? _getSharedExpenses().first
        : _getPersonalExpenses().first);

    if (groups.isEmpty) {
      CustomLogger().logError('No hay grupos para reordenar');
      return;
    }

    // Actualizar _groupOrder para asegurarse de que contiene todos los IDs actuales
    final currentIds = groups.map((group) => group.id!).toList();

    // Eliminar IDs que ya no existen
    _groupOrder.removeWhere((id) => !currentIds.contains(id));

    // Añadir nuevos IDs al final
    for (final id in currentIds) {
      if (!_groupOrder.contains(id)) {
        _groupOrder.add(id);
      }
    }

    // Ahora realizar la reordenación
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _groupOrder.removeAt(oldIndex);
      _groupOrder.insert(newIndex, movedId);
    });

    await _saveOrder(_groupOrder);
    CustomLogger().logInfo(
        'Orden actualizado exitosamente: oldIndex=$oldIndex, newIndex=$newIndex, _groupOrder=$_groupOrder');
  }

  void _navigateToInsertGroupScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InsertGroupScreen(
          userUid: widget.userUid,
          onNombreChanged: (int groupId, String groupName) {
            print('Group ID: $groupId, Group Name: $groupName');
          },
        ),
      ),
    );
  }

  Future<void> _deleteExpenseGroup(String groupId) async {
    await FirestoreService().deleteExpenseGroup(widget.userUid, groupId);
  }

 

  Widget _buildExpenseGroupCard(GroupModel group, int index) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final bool isShared = group is SharedExpenseGroup;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                if (isShared)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.group,
                      size: 20,
                      color: colorProvider.colors.appBarColor,
                    ),
                  ),
                Expanded(
                  child: Text(
                    group.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Total: \$${currencyFormat.format(group.calculateTotal())}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(group.creationDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                if (isShared)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc((group as SharedExpenseGroup).creatorId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      return Text(
                        'Creador: ${userData['username'] ?? 'Usuario'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorProvider.colors.primaryTextColor,
                        ),
                      );
                    },
                  ),
              ],
            ),
            trailing: SizedBox(
              width: 100, // Ancho fijo para asegurar espacio suficiente
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    MainAxisAlignment.end, // Alinear a la derecha
                children: [
                  IconButton(
                    icon: Icon(
                      _isOpen[index] ? Icons.visibility : Icons.visibility_off,
                      color: _isOpen[index]
                          ? colorProvider.colors.appBarColor
                          : colorProvider.colors.appBarColor.withOpacity(0.7),
                    ),
                    constraints: BoxConstraints(
                        maxWidth: 40), // Reducir el ancho del botón
                    padding: EdgeInsets.zero, // Eliminar padding interno
                    onPressed: () {
                      setState(() {
                        _isOpen[index] = !_isOpen[index];
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: colorProvider.colors.appBarColor,
                    ),
                    constraints: BoxConstraints(
                        maxWidth: 40), // Reducir el ancho del botón
                    padding: EdgeInsets.zero, // Eliminar padding interno
                    onPressed: () => _showGroupOptions(context, group),
                  ),
                  const SizedBox(width: 6),
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_handle,
                      color: colorProvider.colors.appBarColor.withOpacity(0.7),
                      size:
                          30, // Tamaño más pequeño para que no ocupe tanto espacio
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isOpen[index]) ExpenseDetailsWidget(group: group),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context).colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showSharedExpenses ? 'Gastos Archivados' : 'Gastos Archivados',
          style:
              TextStyle(color: colorProvider.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.secondaryTextColor),
      ),
      drawer: ExpenseDrawer(userUid: widget.userUid),
      body: Column(
        children: [
          _buildToggleButtons(),
          Expanded(
            child: StreamBuilder<List<GroupModel>>(
              stream: _showSharedExpenses
                  ? _getSharedExpenses()
                  : _getPersonalExpenses(),
              builder: (context, snapshot) {
                if (_showSharedExpenses) {
                  CustomLogger().logInfo(
                      'Estado del StreamBuilder de gastos compartidos: ${snapshot.connectionState}');
                  if (snapshot.hasError) {
                    CustomLogger().logError(
                        'Error en StreamBuilder de gastos compartidos: ${snapshot.error}');
                  }
                  if (snapshot.hasData) {
                    CustomLogger().logInfo(
                        'Datos recibidos en StreamBuilder: ${snapshot.data?.length} gastos');
                  }
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar grupos de gastos: ${snapshot.error}',
                      style: TextStyle(color: colorProvider.negativeColor),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: colorProvider.appBarColor,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showSharedExpenses
                              ? Icons.group_off
                              : Icons.money_off,
                          size: 64,
                          color:
                              colorProvider.primaryTextColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showSharedExpenses
                              ? 'No hay gastos compartidos'
                              : 'No hay grupos de gastos registrados',
                          style:
                              TextStyle(color: colorProvider.primaryTextColor),
                        ),
                      ],
                    ),
                  );
                }

                final groups = snapshot.data!;

                if (_isOpen.length != groups.length) {
                  _isOpen = List.generate(groups.length, (_) => false);
                }

                // Ordenar los grupos según _groupOrder
                groups.sort((a, b) {
                  final indexA = _groupOrder.indexOf(a.id!);
                  final indexB = _groupOrder.indexOf(b.id!);

                  // Si un ID no está en _groupOrder, ponerlo al final
                  if (indexA == -1 && indexB == -1) {
                    return 0; // Ambos ausentes, mantener orden original
                  } else if (indexA == -1) {
                    return 1; // a ausente, mover al final
                  } else if (indexB == -1) {
                    return -1; // b ausente, mover al final
                  }

                  return indexA.compareTo(indexB);
                });

                return ReorderableListView.builder(
                  buildDefaultDragHandles: false, // Añadir esta línea
                  shrinkWrap: true,
                  onReorder: (oldIndex, newIndex) =>
                      _updateGroupsOrder(oldIndex, newIndex),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      key: ValueKey(groups[index].id),
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: _buildExpenseGroupCard(groups[index], index),
                    );
                  },
                  proxyDecorator:
                      (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: child,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// Nuevo método para mostrar opciones según el tipo de gasto
  void _showGroupOptions(BuildContext context, GroupModel group) {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    final bool isShared = group is SharedExpenseGroup;

    // Determinar si el usuario puede editar el gasto compartido
    bool canEdit = !isShared ||
        (isShared &&
            ((group as SharedExpenseGroup).creatorId == widget.userUid ||
                ((group as SharedExpenseGroup).permissionType ==
                        SharingPermissionType.allParticipants &&
                    (group as SharedExpenseGroup).participants.any((p) =>
                        p.userId == widget.userUid &&
                        p.status == ParticipantStatus.accepted))));

    showModalBottomSheet(
      context: context,
      backgroundColor: colorProvider.colors.backgroundColor,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opción de Editar (disponible según permisos)
              if (canEdit)
                ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: colorProvider.colors.appBarColor,
                  ),
                  title: Text(
                    'Editar',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isShared) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SharedEditGroupScreen(
                            userUid: widget.userUid,
                            groupId: group.id,
                            participantIds: (group)
                                .participants
                                .map((p) => p.userId)
                                .toList(),
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditGroupScreen(
                            userUid: widget.userUid,
                            groupId: group.id,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.archive,
                  color: colorProvider.colors.appBarColor,
                ),
                title: Text(
                  'Desarchivar',
                  style: TextStyle(
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    if (isShared) {
                      await FirestoreService()
                          .sharedExpenseService
                          .toggleArchiveSharedExpense(
                            group.id,
                            widget.userUid,
                          );
                      // Mostrar un mensaje de confirmación
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(group.archivado
                              ? 'Gasto compartido desarchivado exitosamente'
                              : 'Gasto compartido archivado exitosamente'),
                          backgroundColor: colorProvider.colors.appBarColor,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      await FirestoreService().toggleGroupArchivado(
                        widget.userUid,
                        group.id,
                      );
                      // Mostrar un mensaje de confirmación
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(group.archivado
                              ? 'Grupo desarchivado exitosamente'
                              : 'Grupo archivado exitosamente'),
                          backgroundColor: colorProvider.colors.appBarColor,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    // Manejar el error
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Error: No se pudo ${group.archivado ? 'desarchivar' : 'archivar'} el grupo'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),

              // Opción de Compartir/Ver Participantes
              ListTile(
                leading: Icon(
                  Icons.share,
                  color: colorProvider.colors.appBarColor,
                ),
                title: Text(
                  isShared ? 'Gestionar Participantes' : 'Compartir',
                  style: TextStyle(
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  if (!isShared) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShareExpenseScreen(
                          existingGroup: group,
                          userUid: widget.userUid,
                        ),
                      ),
                    );
                    if (result != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Gasto compartido exitosamente'),
                          backgroundColor: colorProvider.colors.positiveColor,
                        ),
                      );
                    }
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParticipantsManagementScreen(
                          group: group as SharedExpenseGroup,
                          userId: widget.userUid,
                        ),
                      ),
                    );
                  }
                },
              ),

              // Ver Distribución (solo para gastos compartidos)
              if (isShared)
                ListTile(
                  leading: Icon(
                    Icons.assessment,
                    color: colorProvider.colors.appBarColor,
                  ),
                  title: Text(
                    'Ver Distribución',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DistributionSummaryScreen(
                          group: group as SharedExpenseGroup,
                          userId: widget.userUid,
                        ),
                      ),
                    );
                  },
                ),

              // Opción de Eliminar (solo para creador o gasto personal)
              if (!isShared ||
                  (isShared &&
                      (group as SharedExpenseGroup).creatorId ==
                          widget.userUid))
                ListTile(
                  leading: Icon(
                    Icons.delete,
                    color: colorProvider.colors.negativeColor,
                  ),
                  title: Text(
                    'Eliminar',
                    style: TextStyle(
                      color: colorProvider.colors.negativeColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmationDialog(group.id);
                  },
                ),

              // Salir del gasto compartido (solo para participantes que no son creadores)
              if (isShared &&
                  (group as SharedExpenseGroup).creatorId != widget.userUid)
                ListTile(
                  leading: Icon(
                    Icons.exit_to_app,
                    color: colorProvider.colors.negativeColor,
                  ),
                  title: Text(
                    'Salir del gasto',
                    style: TextStyle(
                      color: colorProvider.colors.negativeColor,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    // Mostrar diálogo de confirmación
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Salir del gasto'),
                        content: Text(
                            '¿Estás seguro de que quieres salir de este gasto compartido?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Salir'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        await FirestoreService()
                            .sharedExpenseService
                            .removeParticipant(group.id, widget.userUid);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Has salido del gasto compartido'),
                              backgroundColor:
                                  colorProvider.colors.positiveColor,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al salir del gasto: $e'),
                              backgroundColor:
                                  colorProvider.colors.negativeColor,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(String groupId) async {
    CustomLogger().logInfo('Iniciando diálogo de confirmación');
    // Obtenemos el provider con listen: false
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    try {
      CustomLogger().logInfo('ColorProvider obtenido');

      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          // Usamos un Builder para obtener el contexto correcto para los colores
          return AlertDialog(
            backgroundColor: colorProvider.colors.backgroundColor,
            title: Text(
              'Eliminar grupo',
              style: TextStyle(color: colorProvider.colors.primaryTextColor),
            ),
            content: Text(
              '¿Estás seguro de que deseas eliminar este grupo?',
              style: TextStyle(color: colorProvider.colors.primaryTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  CustomLogger().logInfo('Cancelar presionado');
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: colorProvider.colors.appBarColor),
                ),
              ),
              TextButton(
                onPressed: () {
                  CustomLogger().logInfo('Eliminar presionado');
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(
                  'Eliminar',
                  style: TextStyle(color: colorProvider.colors.negativeColor),
                ),
              ),
            ],
          );
        },
      );

      CustomLogger().logInfo('Diálogo cerrado con resultado: $confirm');

      if (confirm == true) {
        await _deleteExpenseGroup(groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Grupo eliminado con éxito'),
              backgroundColor: colorProvider.colors.positiveColor,
            ),
          );
        }
      }
    } catch (e) {
      CustomLogger().logError('Error en el diálogo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: colorProvider.colors.negativeColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
