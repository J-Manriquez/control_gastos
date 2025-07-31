import 'package:control_gastos/utils/custom_logger.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/widgets/forms/gastos/subgrupo_gastos_form.dart';
import 'package:control_gastos/widgets/forms/gastos/gasto_form.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/widgets/loading_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/services/storage_service.dart';
import 'package:control_gastos/widgets/profile_image.dart';
import 'package:image_picker/image_picker.dart';

// Importar para acceder a la clase de estado
import 'package:control_gastos/widgets/forms/gastos/subgrupo_gastos_form.dart' show SubgrupoGastoForm;

class EditGroupScreen extends StatefulWidget {
  final String userUid;
  final String groupId;

  const EditGroupScreen(
      {super.key, required this.userUid, required this.groupId});

  @override
  _EditGroupScreenState createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  List<Gasto> _expenses = [];
  List<SubgroupModel> _subgroups = [];
  List<GlobalKey> _subgroupKeys = [];
  bool _isLoading = true;
  
  // Variables para manejo de imágenes
  final StorageService _storageService = StorageService();
  Map<String, Map<String, dynamic>> _imagenes = {};
   
  final List<String> _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
  ];
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0, // Esto fuerza que no haya decimales
    // customPattern: '# ##0.00 ¤' // El patrón personalizado donde , es el separador de miles
  );

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    try {
      GroupModel group = await FirestoreService()
          .getExpenseGroup(widget.userUid, widget.groupId);

      setState(() {
        _groupNameController.text = group.nombre;
        _expenses.addAll(group.expenses);
        _subgroups.addAll(group.subgroups);
        // Inicializar claves para subgrupos existentes
        _subgroupKeys = List.generate(
          _subgroups.length,
          (index) => GlobalKey()
        );
        // Cargar imágenes existentes
        if (group.imagenes != null) {
          _imagenes = Map<String, Map<String, dynamic>>.from(group.imagenes!);
        }
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar el grupo de gastos')),
      );
      Navigator.of(context).pop();
    }
  }

  void _addExpenseForm() {
    setState(() {
      _expenses.add(
          Gasto(nombre: '', valor: 0, fecha: DateTime.now(), esAFavor: true));
    });
  }

  void _addSubgroup() {
    setState(() {
      _subgroups.add(SubgroupModel(
        subgroupName: '',
        expenses: [],
        subtotal: 0,
      ));
      _subgroupKeys.add(GlobalKey());
    });
  }

  void _updateExpense(int index, Gasto gasto) {
    setState(() {
      _expenses[index] = gasto;
    });
  }

  void _updateSubgroup(int index, String nombre) {
    CustomLogger().logInfo('=== ACTUALIZANDO SUBGRUPO ===');
    CustomLogger().logInfo('Índice: $index');
    CustomLogger().logInfo('Nombre anterior: ${_subgroups[index].subgroupName}');
    CustomLogger().logInfo('Nombre nuevo: $nombre');
    CustomLogger().logInfo('ID del subgrupo: ${_subgroups[index].id}');

    setState(() {
      final oldSubgroup = _subgroups[index];
      _subgroups[index] = _subgroups[index].copyWith(
        subgroupName: nombre,
        subtotal: _subgroups[index].calculateSubtotal(),
      );
      CustomLogger().logInfo('Subgrupo actualizado - Nombre: ${_subgroups[index].subgroupName}, ID: ${_subgroups[index].id}');
    });

    _calculateTotal();
  }

  void _updateSubgroupExpense(int subgroupIndex, List<Gasto> gastos) {
    setState(() {
      double subtotal = gastos.fold(0.0, (sum, gasto) {
        // Asegurarse de que el valor es un número válido
        return sum + gasto.valor;
      });

      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: gastos,
        subtotal: subtotal,
      );
    });
    _calculateTotal();
  }

  double _calculateTotal() {
    try {
      // Calcular total de gastos principales
      double total = _expenses.fold(0.0, (sum, gasto) {
        return sum + gasto.valor;
      });

      // Agregar totales de subgrupos
      for (var subgroup in _subgroups) {
        total += subgroup.expenses.fold(0.0, (sum, gasto) => sum + gasto.valor);
      }

      return total;
    } catch (e) {
      print('Error al calcular total: $e');
      return 0.0;
    }
  }

  // Métodos para manejo de imágenes
  Future<void> _addImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        // Mostrar pantalla de carga
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const LoadingScreen(
                message: 'Subiendo imagen...',
                subtitle: 'Por favor espera mientras procesamos tu imagen',
                type: LoadingType.general,
              ),
            ),
          );
        }

        try {
          final String base64Image = await _storageService.convertirImagenABase64(imageFile: image);
          
          // Generar ID único para la imagen
          final String imageId = DateTime.now().millisecondsSinceEpoch.toString();
          
          setState(() {
            _imagenes[imageId] = {
              'imagen': base64Image,
              'descripcion': '', // Descripción vacía por defecto
              'fecha': DateTime.now().toIso8601String(),
            };
          });

          // Cerrar pantalla de carga
          if (mounted) {
            Navigator.of(context).pop();
          }
        } catch (e) {
          // Cerrar pantalla de carga en caso de error
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al procesar la imagen: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  // Método para actualizar la descripción de una imagen
  void _updateImageDescription(String imageId, String description) {
    // Actualizar directamente sin setState para evitar re-renderizado innecesario
    if (_imagenes.containsKey(imageId)) {
      _imagenes[imageId]!['descripcion'] = description;
    }
  }

  void _removeImage(String imageId) {
    setState(() {
      _imagenes.remove(imageId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imagen eliminada')),
    );
  }

  void _saveGroup() async {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe ingresar un nombre para el grupo')),
      );
      return;
    }

    // Mostrar pantalla de carga
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoadingScreen(
            message: 'Actualizando Gastos...',
            subtitle: 'Por favor espera mientras actualizamos tu grupo de gastos',
            type: LoadingType.general,
          ),
        ),
      );
    }

    try {
      CustomLogger().logInfo('=== INICIANDO GUARDADO DE GRUPO ===');
      CustomLogger().logInfo('Número de subgrupos: ${_subgroups.length}');
      
      // Obtener nombres actuales de los formularios y actualizar subgrupos
      for (int i = 0; i < _subgroups.length; i++) {
        final formKey = _subgroupKeys[i];
        final state = formKey.currentState;
         if (state != null) {
           // Usar dynamic para acceder al método público getCurrentName
           final dynamic dynamicState = state;
           try {
             final currentName = dynamicState.getCurrentName() as String;
             CustomLogger().logInfo('Subgrupo $i - Nombre del formulario: "$currentName"');
             CustomLogger().logInfo('Subgrupo $i - Nombre anterior: "${_subgroups[i].subgroupName}"');
             
             if (currentName != _subgroups[i].subgroupName) {
               setState(() {
                 _subgroups[i] = _subgroups[i].copyWith(
                   subgroupName: currentName,
                   subtotal: _subgroups[i].calculateSubtotal(),
                 );
               });
               CustomLogger().logInfo('Subgrupo $i actualizado con nuevo nombre: "$currentName"');
             }
           } catch (e) {
             CustomLogger().logError('Error al acceder a getCurrentName: $e');
           }
         }
      }

      // Log final de todos los subgrupos antes de enviar a la base de datos
      CustomLogger().logInfo('=== SUBGRUPOS FINALES ANTES DE GUARDAR ===');
      for (int i = 0; i < _subgroups.length; i++) {
        CustomLogger().logInfo('Subgrupo $i: Nombre="${_subgroups[i].subgroupName}", ID="${_subgroups[i].id}", Gastos=${_subgroups[i].expenses.length}');
      }

      await FirestoreService().updateExpenseGroup(
        widget.userUid,
        widget.groupId,
        _groupNameController.text,
        _expenses,
        _subgroups,
        imagenes: _imagenes.isNotEmpty ? _imagenes : null,
      );

      if (mounted) {
        // Cerrar pantalla de carga
        Navigator.of(context).pop();
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Grupo de gastos actualizado con éxito')),
        );
        
        // Navegar de vuelta a la pantalla anterior
        try {
          Navigator.of(context).pop();
        } catch (navError) {
          CustomLogger().logError('Error en navegación: $navError');
        }
      }
    } catch (e) {
      if (mounted) {
        // Cerrar pantalla de carga
        Navigator.of(context).pop();
        
        CustomLogger().logError('Error al guardar grupo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el grupo de gastos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    double total = _calculateTotal();

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Editar Grupo',
          style: TextStyle(
              color: colorProvider.colors.secondaryTextColor, fontSize: 20),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
        actions: [
          IconButton(
            icon: Icon(Icons.save,
                color: colorProvider.colors.secondaryTextColor),
            onPressed: _saveGroup,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorProvider.colors.appBarColor,
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                            margin: const EdgeInsets.only(
                                left: 1.5, right: 1.5, bottom: 4, top: 4),
                            color: colorProvider.colors.backgroundColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  8.0), // Mantiene tus bordes redondeados
                              side: BorderSide(
                                color: colorProvider.colors.appBarColor
                                    .withOpacity(
                                        0.25), // Mantiene tu borde original
                                width: 2.0, // Ancho del borde
                              ),
                            ),
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _groupNameController,
                                          decoration: InputDecoration(
                                            labelText: 'Descripcion',
                                            labelStyle: TextStyle(
                                                color: colorProvider
                                                    .colors.primaryTextColor),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: colorProvider
                                                      .colors.appBarColor),
                                            ),
                                          ),
                                          style: TextStyle(
                                              color: colorProvider
                                                  .colors.primaryTextColor),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.arrow_drop_down,
                                            color: colorProvider
                                                .colors.primaryTextColor),
                                        onSelected: (String value) {
                                          setState(() {
                                            _groupNameController.text = value;
                                          });
                                        },
                                        itemBuilder: (BuildContext context) {
                                          return _months.map((String month) {
                                            return PopupMenuItem<String>(
                                              value: month,
                                              child: Text(month,
                                                  style: TextStyle(
                                                      color: colorProvider
                                                          .colors
                                                          .secondaryTextColor)),
                                            );
                                          }).toList();
                                        },
                                        color: colorProvider.colors.appBarColor,
                                        offset: const Offset(0, 40),
                                      ),
                                    ]),
                                  ],
                                ))), // const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            return GastoForm(
                              key: ValueKey(_expenses[index].id ?? 'expense_$index'),
                              gasto: _expenses[index],
                              onCancel: () {
                                setState(() {
                                  _expenses.removeAt(index);
                                });
                              },
                              onGastoChanged: (gasto) =>
                                  _updateExpense(index, gasto),
                            );
                          },
                        ),
                        // const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _subgroups.length,
                          itemBuilder: (context, subgroupIndex) {
                            return Column(
                              children: [
                                SubgrupoGastoForm(
                                  key: _subgroupKeys[subgroupIndex],
                                  subgrupoNombre:
                                      _subgroups[subgroupIndex].subgroupName,
                                  onNombreChanged: (nombre) =>
                                      _updateSubgroup(subgroupIndex, nombre),
                                  gastos: _subgroups[subgroupIndex].expenses,
                                  onGastosChanged: (gastos) =>
                                      _updateSubgroupExpense(
                                          subgroupIndex, gastos),
                                  onEliminar: () {
                                    setState(() {
                                      _subgroups.removeAt(subgroupIndex);
                                      _subgroupKeys.removeAt(subgroupIndex);
                                    });
                                    _calculateTotal();
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
                        // Sección de imágenes
                        if (_imagenes.isNotEmpty)
                          Card(
                            margin: const EdgeInsets.only(
                                left: 1.5, right: 1.5, bottom: 4, top: 4),
                            color: colorProvider.colors.backgroundColor,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              side: BorderSide(
                                color: colorProvider.colors.appBarColor
                                    .withOpacity(0.25),
                                width: 2.0,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Imágenes',
                                    style: TextStyle(
                                      color: colorProvider.colors.primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _imagenes.length,
                                    itemBuilder: (context, index) {
                                      String imageId = _imagenes.keys.elementAt(index);
                                      Map<String, dynamic> imageData = _imagenes[imageId]!;
                                      return ExpenseImageWidget(
                                        key: ValueKey(imageId), // Clave única para optimizar re-renderizado
                                        imageData: imageData,
                                        onDelete: () => _removeImage(imageId),
                                        onDescriptionChanged: (description) => _updateImageDescription(imageId, description),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  color: total >= 0
                      ? colorProvider.colors.positiveColor
                      : colorProvider.colors.negativeColor,
                  padding: const EdgeInsets.all(16.0),
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: \$${_currencyFormat.format(total)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorProvider.colors.secondaryTextColor,
                        ),
                      ),
                      PopupMenuButton<int>(
                        icon: Icon(
                          Icons.add,
                          color: colorProvider.colors.secondaryTextColor,
                          size: 20,
                        ),
                        onSelected: (int value) {
                          switch (value) {
                            case 1:
                              _addExpenseForm();
                              break;
                            case 2:
                              _addSubgroup();
                              break;
                            case 3:
                              _addImage();
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return <PopupMenuEntry<int>>[
                            PopupMenuItem<int>(
                              value: 1,
                              child: Text(
                                '• Agregar Monto',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: colorProvider
                                        .colors.secondaryTextColor),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 2,
                              child: Text(
                                '• Agregar Grupo',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: colorProvider
                                        .colors.secondaryTextColor),
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 3,
                              child: Text(
                                '• Agregar Imagen',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: colorProvider
                                        .colors.secondaryTextColor),
                              ),
                            ),
                          ];
                        },
                        offset: const Offset(0, 40),
                        color: colorProvider.colors.appBarColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
