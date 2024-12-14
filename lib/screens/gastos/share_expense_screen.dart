import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/services/friends_service.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class ShareExpenseScreen extends StatefulWidget {
  final GroupModel? existingGroup;
  final String userUid;

  const ShareExpenseScreen({
    super.key,
    this.existingGroup,
    required this.userUid,
  });

  @override
  _ShareExpenseScreenState createState() => _ShareExpenseScreenState();
}

class _ShareExpenseScreenState extends State<ShareExpenseScreen> {
  final FriendsService _friendsService = FriendsService();
  final List<String> _selectedFriends = [];
  SharingPermissionType _permissionType = SharingPermissionType.creatorOnly;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Compartir Gasto',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme: IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPermissionsSection(colorProvider),
                    const SizedBox(height: 24),
                    _buildFriendsSection(colorProvider),
                    const SizedBox(height: 24),
                    if (_selectedFriends.isNotEmpty)
                      _buildSelectedFriendsSection(colorProvider),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomBar(colorProvider),
    );
  }

  Widget _buildPermissionsSection(ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            RadioListTile<SharingPermissionType>(
              title: Text(
                'Solo creador',
                style: TextStyle(color: colorProvider.colors.primaryTextColor),
              ),
              subtitle: Text(
                'Solo tú podrás proponer cambios',
                style: TextStyle(
                  color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                ),
              ),
              value: SharingPermissionType.creatorOnly,
              groupValue: _permissionType,
              onChanged: (SharingPermissionType? value) {
                if (value != null) {
                  setState(() {
                    _permissionType = value;
                  });
                }
              },
              activeColor: colorProvider.colors.appBarColor,
            ),
            RadioListTile<SharingPermissionType>(
              title: Text(
                'Todos los participantes',
                style: TextStyle(color: colorProvider.colors.primaryTextColor),
              ),
              subtitle: Text(
                'Cualquier participante podrá proponer cambios',
                style: TextStyle(
                  color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                ),
              ),
              value: SharingPermissionType.allParticipants,
              groupValue: _permissionType,
              onChanged: (SharingPermissionType? value) {
                if (value != null) {
                  setState(() {
                    _permissionType = value;
                  });
                }
              },
              activeColor: colorProvider.colors.appBarColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsSection(ColorProvider colorProvider) {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _friendsService.getFriendsList(widget.userUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar amigos',
              style: TextStyle(color: colorProvider.colors.negativeColor),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: colorProvider.colors.appBarColor,
            ),
          );
        }

        final friends = snapshot.data!;

        if (friends.isEmpty) {
          return Card(
            color: colorProvider.colors.backgroundColor,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: colorProvider.colors.primaryTextColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes amigos agregados',
                    style: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Navegar a la pantalla de agregar amigos
                      Navigator.pushNamed(context, '/add_friends');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorProvider.colors.appBarColor,
                    ),
                    child: Text(
                      'Agregar Amigos',
                      style: TextStyle(
                        color: colorProvider.colors.secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          color: colorProvider.colors.backgroundColor,
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Selecciona amigos para compartir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index].data() as Map<String, dynamic>;
                  final friendId = friends[index].id;

                  return CheckboxListTile(
                    title: Text(
                      friend['username'] ?? '',
                      style: TextStyle(
                        color: colorProvider.colors.primaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${friend['userShortId'] ?? ''}',
                      style: TextStyle(
                        color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
                      ),
                    ),
                    value: _selectedFriends.contains(friendId),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedFriends.add(friendId);
                        } else {
                          _selectedFriends.remove(friendId);
                        }
                      });
                    },
                    activeColor: colorProvider.colors.appBarColor,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedFriendsSection(ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amigos seleccionados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorProvider.colors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedFriends.length} amigo${_selectedFriends.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: colorProvider.colors.primaryTextColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ColorProvider colorProvider) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorProvider.colors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colorProvider.colors.negativeColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _selectedFriends.isEmpty ? null : _shareExpense,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorProvider.colors.appBarColor,
              disabledBackgroundColor: colorProvider.colors.appBarColor.withOpacity(0.3),
            ),
            child: Text(
              'Compartir',
              style: TextStyle(
                color: colorProvider.colors.secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareExpense() async {
    setState(() => _isLoading = true);
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);


    try {
      if (widget.existingGroup != null) {
        final expenseId = await FirestoreService().createSharedExpenseGroup(
          widget.userUid,
          widget.existingGroup!.nombre,
          widget.existingGroup!.expenses,
          widget.existingGroup!.subgroups,
          _selectedFriends,
          _permissionType,
        );

        if (mounted) {
          Navigator.pop(context, expenseId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir gasto: $e'),
            backgroundColor: colorProvider.colors.negativeColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}