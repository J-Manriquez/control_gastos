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
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPermissionsSection(colorProvider),
                    const SizedBox(height: 24),
                    _buildFriendsSection(colorProvider),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomBar(colorProvider),
    );
  }

  Widget _buildPermissionsSection(ColorProvider colorProvider) {
    final List<bool> isSelected = [
      _permissionType == SharingPermissionType.creatorOnly,
      _permissionType == SharingPermissionType.allParticipants,
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 16, right: 16, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'Permisos de edición',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: colorProvider.colors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              child: ToggleButtons(
                direction: Axis.horizontal,
                onPressed: (int index) {
                  setState(() {
                    _permissionType = index == 0
                        ? SharingPermissionType.creatorOnly
                        : SharingPermissionType.allParticipants;
                  });
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
           const SizedBox(height: 16),
           Text(
             _getPermissionDescription(),
             style: TextStyle(
               fontSize: 14,
               color: colorProvider.colors.primaryTextColor.withOpacity(0.8),
               fontStyle: FontStyle.italic,
             ),
             textAlign: TextAlign.center,
           ),
         ],
       ),
     );
  }

  String _getPermissionDescription() {
    switch (_permissionType) {
      case SharingPermissionType.creatorOnly:
        return 'Deberás aprobar los cambios propuestos por los participantes y solo tú podrás gestionar participantes en este gasto compartido.';
      case SharingPermissionType.allParticipants:
        return 'Los cambios propuestos deben ser aprobados por todos los participantes y todos podrán gestionar participantes en este gasto compartido.';
    }
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
                    color:
                        colorProvider.colors.primaryTextColor.withOpacity(0.5),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 0, right: 16, bottom: 16),
              child: Text(
                'Selecciona amigos para compartir',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
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

                final isSelected = _selectedFriends.contains(friendId);
                final username = friend['username'] ?? '';
                final userShortId = friend['userShortId'] ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
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
                          username[0].toUpperCase(),
                          style: TextStyle(
                            color: colorProvider.colors.secondaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: colorProvider.colors.primaryTextColor,
                        ),
                      ),
                      subtitle: Text(
                        'ID: $userShortId',
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
                  ),
                );
              },
            ),
          ],
        );
      },
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
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colorProvider.colors.negativeColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _selectedFriends.isEmpty ? null : _shareExpense,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorProvider.colors.appBarColor,
              disabledBackgroundColor:
                  colorProvider.colors.appBarColor.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Compartir',
              style: TextStyle(
                color: colorProvider.colors.secondaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareExpense() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    final colorProvider = Provider.of<ColorProvider>(context, listen: false);

    try {
      if (widget.existingGroup != null) {
        // Asegurar que el creador esté incluido en la lista de participantes
        List<String> allParticipants = [widget.userUid];
        allParticipants.addAll(_selectedFriends);
        final expenseId = await FirestoreService().createSharedExpenseGroup(
          widget.userUid,
          widget.existingGroup!.nombre,
          widget.existingGroup!.expenses,
          widget.existingGroup!.subgroups,
          allParticipants, // Usar la lista que incluye al creador
          _permissionType,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gasto compartido exitosamente',
                style:
                    TextStyle(color: colorProvider.colors.secondaryTextColor),
              ),
              backgroundColor: colorProvider.colors.positiveColor,
            ),
          );
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
