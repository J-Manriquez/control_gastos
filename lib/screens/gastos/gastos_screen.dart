import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/screens/gastos/edicion_gastos.dart';
import 'package:control_gastos/screens/gastos/insercion_gastos_sc.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/services/provider_colors.dart'; // Importa el proveedor de colores
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ExpenseGroupsScreen extends StatefulWidget {
  final String userUid;

  const ExpenseGroupsScreen({super.key, required this.userUid});

  @override
  _ExpenseGroupsScreenState createState() => _ExpenseGroupsScreenState();
}

class _ExpenseGroupsScreenState extends State<ExpenseGroupsScreen> {
  late List<bool> _isOpen;
  final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '',
      decimalDigits: 0, // Esto fuerza que no haya decimales
      // customPattern: '# ##0.00 ¤' // El patrón personalizado donde , es el separador de miles
      );

  @override
  void initState() {
    super.initState();
    _isOpen = [];
  }

  Stream<QuerySnapshot> _getExpenseGroupsStream() {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.userUid)
        .collection('expenseGroups')
        .snapshots();
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
            '\$${currencyFormat.format(value)}',
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
                '\$${currencyFormat.format(subtotal)}',
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Text(
              group.nombre,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Total: \$${currencyFormat.format(group.total)}',
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
                      color: colorProvider.colors.primaryTextColor),
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
                  icon:
                      Icon(Icons.edit, color: colorProvider.colors.appBarColor),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditGroupScreen(
                          userUid: widget.userUid,
                          groupId: group.id,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete,
                      color: colorProvider.colors.negativeColor),
                  onPressed: () {
                    CustomLogger().logInfo('Botón de eliminar presionado');
                    try {
                      _showDeleteConfirmationDialog(group.id);
                    } catch (e) {
                      CustomLogger().logError('Error al mostrar diálogo: $e');
                    }
                  },
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _isOpen[index] = !_isOpen[index];
              });
            },
          ),
          if (_isOpen[index])
            Padding(
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
                  // const SizedBox(height: 16),
                  if (group.subgroups.isNotEmpty) ...[
                    // Text(
                    //   'Subgrupos',
                    //   style: TextStyle(
                    //     fontSize: 20,
                    //     fontWeight: FontWeight.bold,
                    //     color: colorProvider.colors.primaryTextColor,
                    //   ),
                    // ),
                    const SizedBox(height: 8),
                    ...group.subgroups.map((subgroup) => _buildSubgroupSection(
                          subgroup.expenses,
                          subgroup.nombre,
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
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
                    // Aquí puedes añadir la funcionalidad que desees
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
            title: Text('Cerrar sesión',
                style: TextStyle(color: colorProvider.colors.negativeColor)),
            onTap: () {
              AuthService().signOut();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
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
          'Grupos de Gastos',
          style:
              TextStyle(color: colorProvider.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.appBarColor,
        iconTheme: IconThemeData(
            color: colorProvider.secondaryTextColor), // Añadir esta línea
      ),
      drawer: _buildDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getExpenseGroupsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorProvider
                    .appBarColor), // Cambia Colors.blue por el color que desees
              ),
            );
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Error al cargar grupos de gastos'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No hay grupos de gastos registrados.'));
          }
          final expenseGroups = snapshot.data!.docs.map((doc) {
            return GroupModel.fromFirestore(doc);
          }).toList();
          if (_isOpen.length != expenseGroups.length) {
            _isOpen = List.generate(expenseGroups.length, (index) => false);
          }
          return ListView.builder(
            itemCount: expenseGroups.length,
            itemBuilder: (context, index) {
              return _buildExpenseGroupCard(expenseGroups[index], index);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToInsertGroupScreen(context),
        backgroundColor: colorProvider.appBarColor,
        child: Icon(
          Icons.add,
          color: colorProvider.secondaryTextColor,
        ), // Aplicar opacidad al botón flotante
      ),
    );
  }
}
