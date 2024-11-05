import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/grupo_gastos_model.dart';
import 'package:control_gastos/screens/gastos/edicion_gastos.dart';
import 'package:control_gastos/screens/gastos/insercion_gastos_sc.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:intl/intl.dart';

class ExpenseGroupsScreen extends StatefulWidget {
  final String userUid;

  const ExpenseGroupsScreen({super.key, required this.userUid});

  @override
  _ExpenseGroupsScreenState createState() => _ExpenseGroupsScreenState();
}

class _ExpenseGroupsScreenState extends State<ExpenseGroupsScreen> {
  late List<bool> _isOpen;
  final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _isOpen = [];
  }

  void _navigateToInsertGroupScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InsertGroupScreen(userUid: widget.userUid),
      ),
    );
  }

  Future<void> _deleteExpenseGroup(String groupId) async {
    await FirestoreService().deleteExpenseGroup(widget.userUid, groupId);
  }

  Widget _buildExpenseItem(String name, double value, bool isIncome) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 16,
              color: isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubgroupSection(List<Gasto> gastos, String subgroupName) {
    double subtotal = gastos.fold(0, (sum, gasto) => sum + gasto.valor);

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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              Text(
                'Subtotal: ${currencyFormat.format(subtotal)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Text(
              group.nombre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Total: ${currencyFormat.format(group.total)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Fecha: ${DateFormat('dd/MM/yyyy').format(group.creationDate)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isOpen[index] ? Icons.visibility : Icons.visibility_off,
                    color: _isOpen[index] ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isOpen[index] = !_isOpen[index];
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () async {
                    try {
                      // Obtener los detalles completos del grupo
                      final groupDetails = await FirestoreService()
                          .getExpenseGroup(widget.userUid, group.id);
                      
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditGroupScreen(
                              userUid: widget.userUid,
                              groupId: group.id,
                              initialGroupName: groupDetails.nombre,
                              initialExpenses: groupDetails.expenses,
                              initialSubgroupExpenses: groupDetails.subgroups
                                  .map((subgroup) => subgroup.expenses)
                                  .toList(),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al cargar el grupo: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmationDialog(group.id),
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
                  // Gastos principales
                  const Text(
                    'Gastos Principales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Divider(),
                  ...group.expenses.map((expense) => _buildExpenseItem(
                        expense.nombre,
                        expense.valor,
                        expense.esAFavor,
                      )),
                  const SizedBox(height: 16),

                  // Subgrupos
                  if (group.subgroups.isNotEmpty) ...[
                    const Text(
                      'Subgrupos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: const Text('¿Estás seguro de que deseas eliminar este grupo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deleteExpenseGroup(groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grupo eliminado con éxito')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar el grupo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos de Gastos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToInsertGroupScreen(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getExpenseGroups(widget.userUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No tienes grupos de gastos aún',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _navigateToInsertGroupScreen(context),
                    child: const Text('Crear nuevo grupo'),
                  ),
                ],
              ),
            );
          }

          final groups = snapshot.data!.docs.map((doc) {
            return GroupModel.fromDocument(doc);
          }).toList();

          if (_isOpen.length != groups.length) {
            _isOpen = List.generate(groups.length, (index) => false);
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              return _buildExpenseGroupCard(groups[index], index);
            },
          );
        },
      ),
    );
  }
}