import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:control_gastos/models/user_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/auth_service.dart';
import 'package:control_gastos/screens/inicio/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  bool _showUsernameEdit = false;
  bool _showEmailEdit = false;
  bool _showPasswordEdit = false;
  bool _showDeleteAccount = false;

  final TextEditingController _newUsernameController = TextEditingController();
  final TextEditingController _currentPasswordForEmailController =
      TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _deleteAccountPasswordController =
      TextEditingController();

  Future<UserModel?> _getUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
      return null;
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID copiado al portapapeles')),
    );
  }

  Widget _buildEditUsernameCard(
      BuildContext context, UserModel user, ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Cambiar Nombre de Usuario',
              style: TextStyle(color: colorProvider.colors.primaryTextColor),
            ),
            trailing: IconButton(
              icon: Icon(
                _showUsernameEdit ? Icons.visibility : Icons.visibility_off,
                color: colorProvider.colors.appBarColor,
              ),
              onPressed: () {
                setState(() {
                  _showUsernameEdit = !_showUsernameEdit;
                  if (!_showUsernameEdit) {
                    _newUsernameController.clear();
                  }
                });
              },
            ),
          ),
          if (_showUsernameEdit)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _newUsernameController,
                    decoration: InputDecoration(
                      labelText: 'Nuevo nombre de usuario',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_newUsernameController.text.isNotEmpty) {
                        bool success = await _authService.updateUsername(
                          widget.userId,
                          _newUsernameController.text,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Nombre de usuario actualizado')),
                          );
                          setState(() {
                            _showUsernameEdit = false;
                            _newUsernameController.clear();
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorProvider.colors.appBarColor,
                    ),
                    child: Text(
                      'Guardar',
                      style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditEmailCard(
      BuildContext context, UserModel user, ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Cambiar Email',
              style: TextStyle(color: colorProvider.colors.primaryTextColor),
            ),
            trailing: IconButton(
              icon: Icon(
                _showEmailEdit ? Icons.visibility : Icons.visibility_off,
                color: colorProvider.colors.appBarColor,
              ),
              onPressed: () {
                setState(() {
                  _showEmailEdit = !_showEmailEdit;
                  if (!_showEmailEdit) {
                    _newEmailController.clear();
                    _currentPasswordForEmailController.clear();
                  }
                });
              },
            ),
          ),
          if (_showEmailEdit)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _newEmailController,
                    decoration: InputDecoration(
                      labelText: 'Nuevo email',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _currentPasswordForEmailController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                    obscureText: true,
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_newEmailController.text.isNotEmpty &&
                          _currentPasswordForEmailController.text.isNotEmpty) {
                        try {
                          // Mostrar diálogo de carga
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

                          bool emailUpdateInitiated =
                              await _authService.updateEmail(
                            _currentPasswordForEmailController.text,
                            _newEmailController.text,
                          );

                          // Cerrar diálogo de carga
                          if (mounted) Navigator.of(context).pop();

                          if (emailUpdateInitiated && mounted) {
                            // Mostrar mensaje de éxito
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor:
                                      colorProvider.colors.backgroundColor,
                                  title: Text(
                                    'Verificación Requerida',
                                    style: TextStyle(
                                      color:
                                          colorProvider.colors.primaryTextColor,
                                    ),
                                  ),
                                  content: Text(
                                    'Se ha enviado un email de verificación a ${_newEmailController.text}. Por favor, verifica tu nuevo email para completar el cambio.',
                                    style: TextStyle(
                                      color:
                                          colorProvider.colors.primaryTextColor,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        'Entendido',
                                        style: TextStyle(
                                          color:
                                              colorProvider.colors.appBarColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            setState(() {
                              _showEmailEdit = false;
                              _newEmailController.clear();
                              _currentPasswordForEmailController.clear();
                            });
                          }
                        } catch (e) {
                          // Cerrar diálogo de carga si está visible
                          if (mounted) Navigator.of(context).pop();

                          // Mostrar error
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al actualizar email: ${e.toString()}',
                                ),
                                backgroundColor:
                                    colorProvider.colors.negativeColor,
                              ),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Por favor, completa todos los campos',
                              style: TextStyle(
                                color: colorProvider.colors.secondaryTextColor,
                              ),
                            ),
                            backgroundColor: colorProvider.colors.negativeColor,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorProvider.colors.appBarColor,
                    ),
                    child: Text(
                      'Guardar',
                      style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditPasswordCard(
      BuildContext context, ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Cambiar Contraseña',
              style: TextStyle(color: colorProvider.colors.primaryTextColor),
            ),
            trailing: IconButton(
              icon: Icon(
                _showPasswordEdit ? Icons.visibility : Icons.visibility_off,
                color: colorProvider.colors.appBarColor,
              ),
              onPressed: () {
                setState(() {
                  _showPasswordEdit = !_showPasswordEdit;
                  if (!_showPasswordEdit) {
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  }
                });
              },
            ),
          ),
          if (_showPasswordEdit)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _currentPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                    obscureText: true,
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                    obscureText: true,
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                    obscureText: true,
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_newPasswordController.text ==
                          _confirmPasswordController.text) {
                        bool success = await _authService.updatePassword(
                          _currentPasswordController.text,
                          _newPasswordController.text,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Contraseña actualizada')),
                          );
                          setState(() {
                            _showPasswordEdit = false;
                            _currentPasswordController.clear();
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                          });
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Las contraseñas no coinciden')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorProvider.colors.appBarColor,
                    ),
                    child: Text(
                      'Guardar',
                      style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountCard(
      BuildContext context, ColorProvider colorProvider) {
    return Card(
      color: colorProvider.colors.backgroundColor,
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Eliminar Cuenta',
              style: TextStyle(color: colorProvider.colors.negativeColor),
            ),
            trailing: IconButton(
              icon: Icon(
                _showDeleteAccount ? Icons.visibility : Icons.visibility_off,
                color: colorProvider.colors.negativeColor,
              ),
              onPressed: () {
                setState(() {
                  _showDeleteAccount = !_showDeleteAccount;
                  if (!_showDeleteAccount) {
                    _deleteAccountPasswordController.clear();
                  }
                });
              },
            ),
          ),
          if (_showDeleteAccount)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Esta acción es irreversible. Se eliminarán todos tus datos.',
                    style: TextStyle(color: colorProvider.colors.negativeColor),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _deleteAccountPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      labelStyle: TextStyle(
                          color: colorProvider.colors.primaryTextColor),
                    ),
                    obscureText: true,
                    style:
                        TextStyle(color: colorProvider.colors.primaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor:
                                colorProvider.colors.backgroundColor,
                            title: Text(
                              '¿Estás seguro?',
                              style: TextStyle(
                                  color: colorProvider.colors.negativeColor),
                            ),
                            content: Text(
                              'Esta acción no se puede deshacer',
                              style: TextStyle(
                                  color: colorProvider.colors.primaryTextColor),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                      color: colorProvider.colors.appBarColor),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(
                                      color:
                                          colorProvider.colors.negativeColor),
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirm == true) {
                        bool success = await _authService.deleteAccount(
                          _deleteAccountPasswordController.text,
                        );
                        if (success && mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => WelcomeScreen()),
                            (Route<dynamic> route) => false,
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorProvider.colors.negativeColor,
                    ),
                    child: Text(
                      'Eliminar Cuenta',
                      style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Perfil de Usuario',
          style: TextStyle(color: colorProvider.colors.secondaryTextColor),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
      ),
      body: FutureBuilder<UserModel?>(
        future: _getUserData(),
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
                'Error al cargar datos',
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Text(
                'Usuario no encontrado',
                style: TextStyle(color: colorProvider.colors.negativeColor),
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información básica del usuario
                  Card(
                    color: colorProvider.colors.backgroundColor,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nombre de usuario:',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                          Text(
                            user.username,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Email:',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorProvider.colors.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID de Usuario:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                          colorProvider.colors.primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    user.userShortId,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: colorProvider.colors.appBarColor,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  color: colorProvider.colors.appBarColor,
                                ),
                                onPressed: () =>
                                    _copyToClipboard(context, user.userShortId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tipo de cuenta
                  Card(
                    color: colorProvider.colors.backgroundColor,
                    elevation: 4,
                    child: ListTile(
                      title: Text(
                        'Tipo de cuenta:',
                        style: TextStyle(
                          color: colorProvider.colors.primaryTextColor,
                        ),
                      ),
                      subtitle: Text(
                        user.userType == 'free' ? 'Gratuita' : 'Premium',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: user.userType == 'free'
                              ? colorProvider.colors.primaryTextColor
                              : colorProvider.colors.positiveColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cards de edición
                  _buildEditUsernameCard(context, user, colorProvider),
                  const SizedBox(height: 16),
                  _buildEditEmailCard(context, user, colorProvider),
                  const SizedBox(height: 16),
                  _buildEditPasswordCard(context, colorProvider),
                  const SizedBox(height: 16),
                  _buildDeleteAccountCard(context, colorProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _newUsernameController.dispose();
    _newEmailController.dispose();
    _currentPasswordForEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deleteAccountPasswordController.dispose();
    super.dispose();
  }
}
