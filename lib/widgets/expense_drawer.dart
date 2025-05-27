import 'package:control_gastos/screens/cuenta/user_profile_screen.dart';
import 'package:control_gastos/screens/friends/friends_list_screen.dart';
import 'package:control_gastos/screens/gastos/gastos_archivados_sc.dart';
import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class ExpenseDrawer extends StatelessWidget {
  final String userUid;
  const ExpenseDrawer({Key? key, required this.userUid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                          userId: userUid,
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
                  leading: Icon(Icons.attach_money_rounded,
                      color: colorProvider.colors.appBarColor),
                  title: Text('Gastos',
                      style: TextStyle(
                          color: colorProvider.colors.primaryTextColor)),
                  onTap: () async {
                    final String? savedUID =
                        await AuthService().getSavedUserUID();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExpenseGroupsScreen(
                          userUid: savedUID!,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.archive,
                      color: colorProvider.colors.appBarColor),
                  title: Text('Archivados',
                      style: TextStyle(
                          color: colorProvider.colors.primaryTextColor)),
                  onTap: () async {
                    final String? savedUID =
                        await AuthService().getSavedUserUID();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArchiveExpenseGroupsScreen(
                          userUid: savedUID!,
                        ),
                      ),
                    );
                  },
                ),
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
                          userId: userUid,
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
}