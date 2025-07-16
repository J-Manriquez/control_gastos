import 'package:control_gastos/screens/cuenta/user_profile_screen.dart';
import 'package:control_gastos/screens/friends/friends_list_screen.dart';
import 'package:control_gastos/screens/gastos/gastos_archivados_sc.dart';
import 'package:control_gastos/screens/gastos/gastos_screen.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class ExpenseDrawer extends StatefulWidget {
  final String userUid;
  const ExpenseDrawer({Key? key, required this.userUid}) : super(key: key);

  @override
  _ExpenseDrawerState createState() => _ExpenseDrawerState();
}

class _ExpenseDrawerState extends State<ExpenseDrawer> {
  String? userShortId;
  String? username;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userUid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          userShortId = data['userShortId'];
          username = data['username'];
        });
      }
    } catch (e) {
      print('Error al cargar datos del usuario: $e');
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID copiado al portapapeles')),
    );
  }

  Future<void> _shareUserId(String userId, String username) async {
    try {
      await Share.share(
        'Mi ID de usuario en Control de Gastos es: $userId\n\n¡Agrégame como amigo usando este ID!',
        subject: 'Mi ID de Control de Gastos - $username',
      );
    } catch (e) {
      // Si falla el compartir, mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }

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
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                  ElevatedButton.icon(
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
                      Icons.account_circle,
                      color: colorProvider.colors.secondaryTextColor,
                      size: 30,
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
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Contenedor con altura fija para evitar descuadre
                  SizedBox(
                    height: 50,
                    child: userShortId != null
                        ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Mi ID:',
                                      style: TextStyle(
                                        color: colorProvider.colors.secondaryTextColor.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      userShortId!,
                                      style: TextStyle(
                                        color: colorProvider.colors.secondaryTextColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  color: colorProvider.colors.secondaryTextColor,
                                  size: 20,
                                ),
                                onPressed: () => _copyToClipboard(context, userShortId!),
                                tooltip: 'Copiar ID',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.share,
                                  color: colorProvider.colors.secondaryTextColor,
                                  size: 20,
                                ),
                                onPressed: () => _shareUserId(userShortId!, username ?? 'Usuario'),
                                tooltip: 'Compartir ID',
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Cargando ID...',
                                      style: TextStyle(
                                        color: colorProvider.colors.secondaryTextColor.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          colorProvider.colors.secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
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
}