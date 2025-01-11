import 'dart:async';

import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/screens/cuenta/user_profile_screen.dart';
import 'package:control_gastos/screens/friends/friends_list_screen.dart';
import 'package:control_gastos/screens/gastos/edicion_gastos.dart';
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
  late List<bool> _isOpen;
  bool _showSharedExpenses = false;
  List<bool> _isSelectedToggle = [true, false];

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
      if (savedOrder != null) {
        setState(() {
          _groupOrder = savedOrder;
        });
      }
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
        .snapshots()
        .map((snapshot) {
      logger.logInfo(
          'Cargando gastos personales: ${snapshot.docs.length} encontrados');
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

      // Obtener IDs de gastos compartidos y filtrar por estado 'accepted'
      final sharedExpenseIds =
          List<String>.from(userDoc.get('sharedExpensesList') ?? []);

      if (sharedExpenseIds.isEmpty) {
        logger.logInfo('No hay gastos compartidos para este usuario');
        return Stream.value(<GroupModel>[]);
      }

      logger
          .logInfo('Obteniendo ${sharedExpenseIds.length} gastos compartidos');

      return _firestore
          .collection('sharedExpenses')
          .where(FieldPath.documentId, whereIn: sharedExpenseIds)
          .snapshots()
          .map((snapshot) {
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
                      status: ParticipantStatus
                          .pending), // Valor por defecto si no se encuentra
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
            .where((group) => group != null) // Filtrar los nulos
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

  Widget _buildGroupDetails(GroupModel group) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastos Principales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorProvider.colors.appBarColor,
            ),
          ),
          Divider(color: colorProvider.colors.appBarColor),
          ...group.expenses.map((expense) => _buildExpenseItem(
                expense.nombre,
                expense.valor,
                expense.esAFavor,
              )),
          const SizedBox(height: 16),
          if (group.subgroups.isNotEmpty) ...[
            Text(
              'Subgrupos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            ...group.subgroups.map((subgroup) => _buildSubgroupSection(
                  subgroup.expenses,
                  subgroup.nombre,
                )),
          ],
          if (group is SharedExpenseGroup) ...[
            const SizedBox(height: 16),
            Text(
              'Participantes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.appBarColor,
              ),
            ),
            Divider(color: colorProvider.colors.appBarColor),
            ...group.participants
                .map((participant) => FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(participant.userId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(
                            userData['username'] ?? 'Usuario',
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                          subtitle: Text(
                            'Estado: ${participant.status.toString().split('.').last}',
                            style: TextStyle(
                              color: colorProvider.colors.primaryTextColor
                                  .withOpacity(0.7),
                            ),
                          ),
                        );
                      },
                    )),
          ],
        ],
      ),
    );
  }

  Future<void> _updateGroupsOrder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _groupOrder.removeAt(oldIndex);
      _groupOrder.insert(newIndex, movedId);
    });
    await _saveOrder(_groupOrder);
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

  Widget _buildExpenseItem(String name, double value, bool isIncome) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 16,
              color: isIncome
                  ? colorProvider.colors.positiveColor
                  : colorProvider.colors.negativeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubgroupSection(List<Gasto> gastos, String subgroupName) {
    final colorProvider = Provider.of<ColorProvider>(context);
    double subtotal =
        gastos.fold(0, (subtotalValue, gasto) => subtotalValue + gasto.valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subgroupName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.appBarColor,
                ),
              ),
              Text(
                'Subtotal: ${currencyFormat.format(subtotal)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorProvider.colors.primaryTextColor,
                ),
              ),
            ],
          ),
        ),
        Divider(color: colorProvider.colors.appBarColor),
        ...gastos.map((gasto) => _buildExpenseItem(
              gasto.nombre,
              gasto.valor,
              gasto.esAFavor,
            )),
        const SizedBox(height: 8),
      ],
    );
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
                if (isShared)
                  Tooltip(
                    message: 'Gasto compartido',
                    child: Icon(
                      Icons.group,
                      size: 20,
                      color: colorProvider.colors.appBarColor,
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isOpen[index] ? Icons.visibility : Icons.visibility_off,
                    color: _isOpen[index]
                        ? colorProvider.colors.appBarColor
                        : colorProvider.colors.appBarColor.withOpacity(0.7),
                  ),
                  onPressed: () {
                    setState(() {
                      _isOpen[index] = !_isOpen[index];
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorProvider.colors.appBarColor,
                  ),
                  onPressed: () => _showGroupOptions(context, group),
                ),
              ],
            ),
          ),
          if (_isOpen[index]) _buildGroupDetails(group),
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
          _showSharedExpenses ? 'Gastos Compartidos' : 'Gastos Personales',
          style:
              TextStyle(color: colorProvider.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.secondaryTextColor),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
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
      drawer: _buildDrawer(),
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

                return ReorderableListView.builder(
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

  Widget _buildDrawer() {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorProvider.colors.appBarColor,
            ),
            child: Container(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navegar al perfil de usuario
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          userId: widget.userUid,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons
                        .account_circle, // Cambia el icono según tus necesidades
                    color: colorProvider.colors.secondaryTextColor,
                  ),
                  label: Text(
                    'Gestionar Cuenta',
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors
                        .transparent, // Cambia el color de fondo si es necesario
                    shadowColor:
                        Colors.transparent, // Elimina la sombra si es necesario
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: Icon(Icons.people,
                      color: colorProvider.colors.appBarColor),
                  title: Text('Amigos',
                      style: TextStyle(
                          color: colorProvider.colors.primaryTextColor)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FriendsListScreen(
                          userId: widget.userUid,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.diamond,
                      color: colorProvider.colors.appBarColor),
                  title: Text('Hazte Premium',
                      style: TextStyle(
                          color: colorProvider.colors.primaryTextColor)),
                  onTap: () {},
                ),
                ListTile(
                  leading:
                      Icon(Icons.code, color: colorProvider.colors.appBarColor),
                  title: Text('Ando Devs',
                      style: TextStyle(
                          color: colorProvider.colors.primaryTextColor)),
                  onTap: () {},
                ),
              ],
            ),
          ),
          ListTile(
            leading:
                Icon(Icons.logout, color: colorProvider.colors.negativeColor),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: colorProvider.colors.negativeColor),
            ),
            onTap: () async {
              try {
                // Mostrar diálogo de confirmación
                final bool? confirmar = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: colorProvider.colors.backgroundColor,
                      title: Text(
                        '¿Cerrar sesión?',
                        style: TextStyle(
                            color: colorProvider.colors.primaryTextColor),
                      ),
                      content: Text(
                        '¿Estás seguro que deseas cerrar sesión?',
                        style: TextStyle(
                            color: colorProvider.colors.primaryTextColor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                                color: colorProvider.colors.appBarColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Cerrar sesión',
                            style: TextStyle(
                                color: colorProvider.colors.negativeColor),
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (confirmar == true) {
                  // Mostrar indicador de carga
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: colorProvider.colors.appBarColor,
                        ),
                      );
                    },
                  );

                  // Cerrar sesión
                  await AuthService().signOut();

                  // Cerrar el indicador de carga
                  Navigator.of(context).pop();

                  // Navegar a la pantalla de bienvenida y limpiar el stack de navegación
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => WelcomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              } catch (e) {
                // Manejar errores
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al cerrar sesión: $e'),
                    backgroundColor: colorProvider.colors.negativeColor,
                  ),
                );
              }
            },
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
                            participantIds: (group as SharedExpenseGroup)
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
