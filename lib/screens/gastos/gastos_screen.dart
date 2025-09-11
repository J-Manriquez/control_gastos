import 'dart:async';

import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/screens/cuenta/user_profile_screen.dart';
import 'package:control_gastos/screens/friends/friends_list_screen.dart';
import 'package:control_gastos/screens/gastos/edicion_gastos.dart';
import 'package:control_gastos/screens/gastos/gastos_archivados_sc.dart';
import 'package:control_gastos/screens/gastos/insercion_gastos_sc.dart';
import 'package:control_gastos/screens/shared_expenses/distribution_summary_screen.dart';
import 'package:control_gastos/screens/shared_expenses/participants_management_screen.dart';
import 'package:control_gastos/screens/shared_expenses/share_expense_options_screen.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:control_gastos/screens/notifications/notifications_screen.dart';
import 'package:control_gastos/screens/shared_expenses/shared_edicion_gastos.dart';
import 'package:control_gastos/screens/shared_expenses/expense_versions_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:control_gastos/widgets/loading_screen.dart';
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

class ExpenseGroupsScreen extends StatefulWidget {
  final String userUid;

  const ExpenseGroupsScreen({super.key, required this.userUid});

  @override
  _ExpenseGroupsScreenState createState() => _ExpenseGroupsScreenState();
}

class _ExpenseGroupsScreenState extends State<ExpenseGroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Map<String, bool> _isOpen; // Cambiar a Map para evitar recargas completas
  bool _showSharedExpenses = false;
  List<bool> _isSelectedToggle = [true, false];
  Map<String, bool> _trackingModeByGroup =
      {}; // Seguimiento específico por grupo
  
  // StreamController para manejar actualizaciones específicas
  late Stream<List<GroupModel>> _currentStream;
  List<GroupModel>? _cachedGroups; // Cache para evitar recargas innecesarias

  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  List<String> _groupOrder = [];
  static const String _orderPrefsKey = 'expense_groups_order';

  @override
  void initState() {
    super.initState();
    _isOpen = {}; // Inicializar como Map vacío
    _loadSavedOrder();
    _initializeStream();

    // Añadir debug de gastos compartidos
    FirestoreService().debugSharedExpenses(widget.userUid).then((_) {
      CustomLogger().logInfo('Debug de gastos compartidos completado');
    }).catchError((error) {
      CustomLogger().logError('Error en debug de gastos compartidos: $error');
    });
  }
  
  void _initializeStream() {
    _currentStream = _showSharedExpenses
        ? _getSharedExpenses()
        : _getPersonalExpenses();
  }
  
  // Método para refrescar el contenido de un grupo específico
  void _refreshGroupContent(String groupId) {
    setState(() {
      // Forzar actualización del stream manteniendo el estado de visibilidad
      _initializeStream();
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
        .where('archivado', isEqualTo: false) // Filtrar solo los no archivados
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

      // Filtrar los IDs de gastos no archivados
      final List<String> nonArchivedIds = sharedExpensesMap.entries
          .where((entry) => !(entry.value['archivado'] ?? false))
          .map((entry) => entry.key)
          .toList();

      if (nonArchivedIds.isEmpty) {
        print('No hay gastos compartidos no archivados para este usuario');
        return Stream.value(<GroupModel>[]);
      }

      return _firestore
          .collection('sharedExpenses')
          .where(FieldPath.documentId,
              whereIn: nonArchivedIds) // Filtrar por IDs específicos
          .snapshots()
          .map((snapshot) {
        print(
            'Cargando gastos compartidos no archivados: ${snapshot.docs.length} encontrados');
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
      padding: const EdgeInsets.only(bottom: 8.0, top: 16),
      child: ToggleButtons(
        direction: Axis.horizontal,
        onPressed: (int index) {
          setState(() {
            for (int i = 0; i < _isSelectedToggle.length; i++) {
              _isSelectedToggle[i] = i == index;
            }
            _showSharedExpenses = index == 1;
            _isOpen.clear(); // Limpiar estado de visibilidad al cambiar tipo
            _cachedGroups = null; // Limpiar cache
            _initializeStream(); // Reinicializar stream
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
        borderWidth: 1.5,
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

  void _toggleTrackingMode(String groupId) {
    setState(() {
      _trackingModeByGroup[groupId] = !(_trackingModeByGroup[groupId] ?? false);
    });
  }

  // Agregar nueva función para actualizar seguimiento de gastos en subgrupos
  Future<void> _updateSubgroupExpenseTracking(GroupModel group,
      String subgroupId, String expenseId, bool isTracked) async {
    try {
      CustomLogger().logInfo(
          'Actualizando seguimiento: Grupo=${group.id}, Subgrupo=$subgroupId, Gasto=$expenseId, Tracked=$isTracked');

      await FirestoreService().updateSubgroupExpenseTracking(
          widget.userUid, group.id!, subgroupId, expenseId, isTracked);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isTracked ? 'Gasto marcado como completado' : 'Gasto desmarcado'),
          backgroundColor: Provider.of<ColorProvider>(context, listen: false)
              .colors
              .positiveColor,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      CustomLogger().logError('Error en _updateSubgroupExpenseTracking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar seguimiento: $e'),
          backgroundColor: Provider.of<ColorProvider>(context, listen: false)
              .colors
              .negativeColor,
        ),
      );
    }
  }

  Future<void> _updateExpenseTracking(
      GroupModel group, String expenseId, bool isTracked) async {
    try {
      await FirestoreService().updateExpenseTracking(
          widget.userUid, group.id!, expenseId, isTracked);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isTracked ? 'Gasto marcado como completado' : 'Gasto desmarcado'),
          backgroundColor: Provider.of<ColorProvider>(context, listen: false)
              .colors
              .positiveColor,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar seguimiento: $e'),
          backgroundColor: Provider.of<ColorProvider>(context, listen: false)
              .colors
              .negativeColor,
        ),
      );
    }
  }

  Widget _buildExpenseGroupCard(GroupModel group, int index) {
    final colorProvider = Provider.of<ColorProvider>(context);
    final bool isShared = group is SharedExpenseGroup;

    return Card(
      margin: const EdgeInsets.only(top: 2.0, left: 16.0, right: 16.0, bottom: 0),
      color: colorProvider.colors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorProvider.colors.appBarColor,
          width: 1.5,
        ),
      ),
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
              width: isShared
                  ? 180
                  : 140, // Aumentar ancho para incluir botón de eliminar
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      (_isOpen[group.id] ?? false) ? Icons.visibility : Icons.visibility_off,
                      size: 30,
                      color: colorProvider.colors.appBarColor
                          
                    ),
                    constraints: BoxConstraints(maxWidth: 40),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        final groupId = group.id!;
                        _isOpen[groupId] = !(_isOpen[groupId] ?? false);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  // Agregar icono de versiones solo para gastos compartidos
                  if (isShared) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.history,
                        size: 30,
                        color: colorProvider.colors.appBarColor,
                      ),
                      constraints: BoxConstraints(maxWidth: 40),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExpenseVersionsScreen(
                              expenseId: group.id!,
                              currentUserId: widget.userUid,
                              expenseName: group.nombre,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 3),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: colorProvider.colors.appBarColor,
                      size: 30,
                    ),
                    constraints: BoxConstraints(maxWidth: 40),
                    padding: EdgeInsets.zero,
                    onPressed: () => _showGroupOptions(context, group),
                  ),
                  const SizedBox(width: 2),
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_handle,
                      color: colorProvider.colors.appBarColor.withOpacity(0.7),
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isOpen[group.id] ?? false)
            ExpenseDetailsWidget(
              group: group,
              isTrackingEnabled: _trackingModeByGroup[group.id] ?? false,
              onExpenseTrackingChanged: (expenseId, isTracked) =>
                  _updateExpenseTracking(group, expenseId, isTracked),
              onSubgroupExpenseTrackingChanged:
                  (subgroupId, expenseId, isTracked) =>
                      _updateSubgroupExpenseTracking(
                          group, subgroupId, expenseId, isTracked),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context).colors;

    return Scaffold(
      backgroundColor: colorProvider.backgroundColor,
      appBar: AppBar(
        title: Text(
          _showSharedExpenses ? 'Gastos Compartidos' : 'Gastos Personales',
          style:
              TextStyle(color: colorProvider.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.appBarColor,
        iconTheme: IconThemeData(
          size: 30,
          color: colorProvider
              .secondaryTextColor, // Cambia aquí el color de la flecha
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications,
                  size: 25,
                ),
                // padding: EdgeInsets.only(top: 15), // Ajusta según necesidad
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(
                        userId: widget.userUid,
                      ),
                    ),
                  );
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('usuarios')
                    .doc(widget.userUid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        margin: const EdgeInsets.all(0),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorProvider.negativeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          snapshot.data!.docs.length.toString(),
                          style: TextStyle(
                            color: colorProvider.secondaryTextColor,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return Container();
                },
              ),
            ],
          ),
        ],
      ),
      drawer: ExpenseDrawer(userUid: widget.userUid),
      body: Column(
        children: [
          _buildToggleButtons(),
          Expanded(
            child: StreamBuilder<List<GroupModel>>(
              stream: _currentStream,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _showSharedExpenses
                              ? Icons.group_off
                              : Icons.money_off,
                          size: 64,
                          color: colorProvider.primaryTextColor
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showSharedExpenses
                              ? 'No hay gastos compartidos'
                              : 'No hay grupos de gastos registrados',
                          style: TextStyle(
                              color: colorProvider.primaryTextColor),
                        ),
                      ],
                    ),
                  );
                }

                final groups = snapshot.data!;
                
                // Actualizar cache de grupos
                _cachedGroups = groups;

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

                return SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
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
                      proxyDecorator: (Widget child, int index,
                          Animation<double> animation) {
                        return Material(
                          color: Colors.transparent,
                          elevation: 0,
                          child: child,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !_showSharedExpenses
          ? FloatingActionButton(
              onPressed: () => _navigateToInsertGroupScreen(context),
              backgroundColor: colorProvider.appBarColor,
              child: Icon(
                Icons.add,
                color: colorProvider.secondaryTextColor,
              ),
            )
          : null,
    );
  }

// Nuevo método para mostrar opciones según el tipo de gasto
  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, GroupModel group) async {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    final bool isShared = group is SharedExpenseGroup;

    String title = '';
    String message = '';
    String buttonText = '';

    if (isShared) {
      final sharedGroup = group as SharedExpenseGroup;
      final isCreator = sharedGroup.creatorId == widget.userUid;

      if (isCreator) {
        final otherParticipants = sharedGroup.participants
            .where((p) => p.userId != widget.userUid)
            .toList();

        if (otherParticipants.isNotEmpty) {
          title = 'Transferir propiedad';
          message =
              'Al eliminar este gasto compartido, la propiedad se transferirá a otro participante y se eliminarán todas las distribuciones. ¿Deseas continuar?';
          buttonText = 'Eliminar';
        } else {
          title = 'Eliminar gasto';
          message =
              'Este gasto compartido se eliminará completamente ya que eres el único participante. ¿Deseas continuar?';
          buttonText = 'Eliminar';
        }
      } else {
        title = 'Salir del gasto';
        message =
            'Serás removido de este gasto compartido y se eliminarán las distribuciones relacionadas. ¿Deseas continuar?';
        buttonText = 'Salir';
      }
    } else {
      title = 'Eliminar gasto';
      message =
          '¿Estás seguro de que deseas eliminar este gasto? Esta acción no se puede deshacer.';
      buttonText = 'Eliminar';
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorProvider.colors.backgroundColor,
          title: Text(
            title,
            style: TextStyle(color: colorProvider.colors.primaryTextColor),
          ),
          content: Text(
            message,
            style: TextStyle(color: colorProvider.colors.primaryTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: colorProvider.colors.appBarColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                buttonText,
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _executeDeleteAction(group);
    }
  }

// Función para ejecutar la acción de eliminación con progreso
  Future<void> _executeDeleteAction(GroupModel group) async {
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);
    final bool isShared = group is SharedExpenseGroup;

    // Mostrar overlay de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LoadingScreen(
          message: isShared
              ? 'Eliminando gasto compartido...'
              : 'Eliminando gasto...',
          subtitle: 'Por favor espera mientras se completa la operación',
        );
      },
    );

    try {
      if (isShared) {
        final sharedGroup = group as SharedExpenseGroup;
        final isCreator = sharedGroup.creatorId == widget.userUid;

        if (isCreator) {
          final otherParticipants = sharedGroup.participants
              .where((p) => p.userId != widget.userUid)
              .toList();

          if (otherParticipants.isNotEmpty) {
            // Transferir propiedad
            await FirestoreService()
                .sharedExpenseService
                .transferOwnershipAndLeave(group.id, widget.userUid);

            Navigator.of(context).pop(); // Cerrar loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Propiedad transferida exitosamente'),
                backgroundColor: colorProvider.colors.positiveColor,
              ),
            );
          } else {
            // Eliminar completamente
            await FirestoreService()
                .sharedExpenseService
                .deleteSharedExpense(group.id, widget.userUid);

            Navigator.of(context).pop(); // Cerrar loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Gasto compartido eliminado exitosamente'),
                backgroundColor: colorProvider.colors.positiveColor,
              ),
            );
          }
        } else {
          // Salir del gasto
          await FirestoreService()
              .sharedExpenseService
              .leaveSharedExpense(group.id, widget.userUid);

          Navigator.of(context).pop(); // Cerrar loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Has salido del gasto compartido'),
              backgroundColor: colorProvider.colors.positiveColor,
            ),
          );
        }
      } else {
        // Eliminar gasto normal
        await FirestoreService().deleteNormalExpense(widget.userUid, group.id);

        Navigator.of(context).pop(); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gasto eliminado exitosamente'),
            backgroundColor: colorProvider.colors.positiveColor,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar loading en caso de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: colorProvider.colors.negativeColor,
        ),
      );
    }
  }

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

    // Determinar el texto del botón de eliminación
    String deleteButtonText = 'Eliminar';
    if (isShared) {
      final sharedGroup = group as SharedExpenseGroup;
      final isCreator = sharedGroup.creatorId == widget.userUid;
      if (!isCreator) {
        deleteButtonText = 'Salir del gasto';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colorProvider.colors.backgroundColor,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opción de Editar (disponible según permisos)
              // if (canEdit)
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
                onTap: () async {
                  Navigator.pop(context);
                  final result = await (isShared
                      ? Navigator.push(
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
                        )
                      : Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditGroupScreen(
                              userUid: widget.userUid,
                              groupId: group.id,
                            ),
                          ),
                        ));
                  
                  // Refrescar contenido si se realizaron cambios
                  if (result != null || mounted) {
                    _refreshGroupContent(group.id!);
                  }
                },
              ),

              // Opción de Seguimiento (solo para gastos personales)
              if (!isShared)
                ListTile(
                  leading: Icon(
                    (_trackingModeByGroup[group.id] ?? false)
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: (_trackingModeByGroup[group.id] ?? false)
                        ? colorProvider.colors.positiveColor
                        : colorProvider.colors.appBarColor,
                  ),
                  title: Text(
                    (_trackingModeByGroup[group.id] ?? false)
                        ? 'Desactivar Seguimiento'
                        : 'Activar Seguimiento',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleTrackingMode(group.id);
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.archive,
                  color: colorProvider.colors.appBarColor,
                ),
                title: Text(
                  group.archivado ? 'Desarchivar' : 'Archivar',
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
                  Icons.people,
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
              // if (!isShared ||
              //     (isShared &&
              //         (group as SharedExpenseGroup).creatorId ==
              //             widget.userUid))
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
                  _showDeleteConfirmationDialog(context, group);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
