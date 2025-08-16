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
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Variables para orden de elementos
  List<String> _expenseOrder = [];
  List<String> _subgroupOrder = [];
  List<String> _imageOrder = [];
   
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

  Future<void> _loadElementOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenseOrder = prefs.getStringList('expense_order_${widget.groupId}');
      final subgroupOrder = prefs.getStringList('subgroup_order_${widget.groupId}');
      final imageOrder = prefs.getStringList('image_order_${widget.groupId}');
      
      setState(() {
        _expenseOrder = expenseOrder ?? [];
        _subgroupOrder = subgroupOrder ?? [];
        _imageOrder = imageOrder ?? [];
      });
    } catch (e) {
      CustomLogger().logError('Error al cargar orden de elementos: $e');
    }
  }

  Future<void> _saveElementOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('expense_order_${widget.groupId}', _expenseOrder);
      await prefs.setStringList('subgroup_order_${widget.groupId}', _subgroupOrder);
      await prefs.setStringList('image_order_${widget.groupId}', _imageOrder);
    } catch (e) {
      CustomLogger().logError('Error al guardar orden de elementos: $e');
    }
  }

  void _initializeElementOrder() {
    // Inicializar orden de gastos
    final currentExpenseIds = _expenses.map((e) => e.id ?? 'expense_${_expenses.indexOf(e)}').toList();
    _expenseOrder.removeWhere((id) => !currentExpenseIds.contains(id));
    for (final id in currentExpenseIds) {
      if (!_expenseOrder.contains(id)) {
        _expenseOrder.add(id);
      }
    }
    
    // Inicializar orden de subgrupos
    final currentSubgroupIds = _subgroups.map((s) => s.subgroupName).toList();
    _subgroupOrder.removeWhere((id) => !currentSubgroupIds.contains(id));
    for (final id in currentSubgroupIds) {
      if (!_subgroupOrder.contains(id)) {
        _subgroupOrder.add(id);
      }
    }
    
    // Inicializar orden de imágenes
    final currentImageIds = _imagenes.keys.toList();
    _imageOrder.removeWhere((id) => !currentImageIds.contains(id));
    for (final id in currentImageIds) {
      if (!_imageOrder.contains(id)) {
        _imageOrder.add(id);
      }
    }
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
      
      // Cargar orden de elementos después de cargar los datos
      await _loadElementOrder();
      _initializeElementOrder();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar el grupo de gastos')),
      );
      Navigator.of(context).pop();
    }
  }

  void _addExpenseForm() {
    setState(() {
      final newExpense = Gasto(nombre: '', valor: 0, fecha: DateTime.now(), esAFavor: true);
      _expenses.add(newExpense);
      final expenseId = newExpense.id ?? 'expense_${_expenses.length - 1}';
      _expenseOrder.add(expenseId);
    });
    _saveElementOrder();
  }

  void _addSubgroup() {
    setState(() {
      final newSubgroup = SubgroupModel(
        subgroupName: '',
        expenses: [],
        subtotal: 0,
      );
      _subgroups.add(newSubgroup);
      _subgroupKeys.add(GlobalKey());
      _subgroupOrder.add(newSubgroup.subgroupName);
    });
    _saveElementOrder();
  }



  Future<void> _updateExpenseOrder(int oldIndex, int newIndex) async {
    print('DEBUG: _updateExpenseOrder called - oldIndex: $oldIndex, newIndex: $newIndex');
    
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _expenseOrder.removeAt(oldIndex);
      _expenseOrder.insert(newIndex, movedId);
    });
    await _saveElementOrder();
  }

  Future<void> _updateSubgroupOrder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _subgroupOrder.removeAt(oldIndex);
      _subgroupOrder.insert(newIndex, movedId);
    });
    await _saveElementOrder();
  }

  // Método para mover un gasto individual a un subgrupo
  Future<void> _moveExpenseToSubgroup(int expenseIndex, int subgroupIndex) async {
    print('DEBUG: _moveExpenseToSubgroup called - expenseIndex: $expenseIndex, subgroupIndex: $subgroupIndex');
    print('DEBUG: _expenseOrder.length: ${_expenseOrder.length}, _subgroups.length: ${_subgroups.length}');
    
    if (expenseIndex >= _expenseOrder.length || subgroupIndex >= _subgroups.length) {
      print('DEBUG: Invalid indices, returning early');
      return;
    }
    
    final expenseId = _expenseOrder[expenseIndex];
    print('DEBUG: expenseId: $expenseId');
    
    final gastoIndex = _expenses.indexWhere((e) => 
        (e.id ?? 'expense_${_expenses.indexOf(e)}') == expenseId);
    print('DEBUG: gastoIndex: $gastoIndex');
    
    if (gastoIndex == -1) {
      print('DEBUG: Gasto not found, returning');
      return;
    }
    
    final gasto = _expenses[gastoIndex];
    print('DEBUG: Moving gasto: ${gasto.nombre} to subgroup: ${_subgroups[subgroupIndex].subgroupName}');
    
    setState(() {
      // Remover el gasto de la lista principal (primero de _expenseOrder, luego de _expenses)
      _expenseOrder.removeAt(expenseIndex);
      _expenses.removeAt(gastoIndex);
      
      // Agregar el gasto al subgrupo
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: [..._subgroups[subgroupIndex].expenses, gasto],
      );
      
      // Recalcular subtotal del subgrupo
      final newSubtotal = _subgroups[subgroupIndex].expenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(subtotal: newSubtotal);
    });
    
    print('DEBUG: Expense moved successfully');
    _calculateTotal();
    await _saveElementOrder();
  }

  // Método para mover un gasto de un subgrupo a la lista principal
  Future<void> _moveExpenseFromSubgroup(int subgroupIndex, int gastoIndex) async {
    print('DEBUG: _moveExpenseFromSubgroup called - subgroupIndex: $subgroupIndex, gastoIndex: $gastoIndex');
    print('DEBUG: _subgroups.length: ${_subgroups.length}');
    
    if (subgroupIndex >= _subgroups.length || 
        gastoIndex >= _subgroups[subgroupIndex].expenses.length) {
      print('DEBUG: Invalid indices in _moveExpenseFromSubgroup, returning early');
      return;
    }
    
    final gasto = _subgroups[subgroupIndex].expenses[gastoIndex];
    print('DEBUG: Moving gasto: ${gasto.nombre} from subgroup: ${_subgroups[subgroupIndex].subgroupName} to main list');
    
    setState(() {
      // Remover el gasto del subgrupo
      final updatedExpenses = List<Gasto>.from(_subgroups[subgroupIndex].expenses);
      updatedExpenses.removeAt(gastoIndex);
      
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(
        expenses: updatedExpenses,
      );
      
      // Recalcular subtotal del subgrupo
      final newSubtotal = updatedExpenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[subgroupIndex] = _subgroups[subgroupIndex].copyWith(subtotal: newSubtotal);
      
      // Agregar el gasto a la lista principal
      _expenses.add(gasto);
      final newExpenseId = gasto.id ?? 'expense_${_expenses.length - 1}';
      _expenseOrder.add(newExpenseId);
    });
    
    print('DEBUG: Expense moved from subgroup to main list successfully');
    _calculateTotal();
    await _saveElementOrder();
  }

  // Método para mover un gasto entre subgrupos
  Future<void> _moveExpenseBetweenSubgroups(int sourceSubgroupIndex, int sourceExpenseIndex, int targetSubgroupIndex) async {
    print('DEBUG: _moveExpenseBetweenSubgroups called - sourceSubgroupIndex: $sourceSubgroupIndex, sourceExpenseIndex: $sourceExpenseIndex, targetSubgroupIndex: $targetSubgroupIndex');
    
    if (sourceSubgroupIndex >= _subgroups.length || 
        targetSubgroupIndex >= _subgroups.length ||
        sourceExpenseIndex >= _subgroups[sourceSubgroupIndex].expenses.length) {
      print('DEBUG: Invalid indices in _moveExpenseBetweenSubgroups, returning early');
      return;
    }
    
    final gasto = _subgroups[sourceSubgroupIndex].expenses[sourceExpenseIndex];
    print('DEBUG: Moving gasto: ${gasto.nombre} from subgroup: ${_subgroups[sourceSubgroupIndex].subgroupName} to subgroup: ${_subgroups[targetSubgroupIndex].subgroupName}');
    
    setState(() {
      // Remover el gasto del subgrupo origen
      final sourceUpdatedExpenses = List<Gasto>.from(_subgroups[sourceSubgroupIndex].expenses);
      sourceUpdatedExpenses.removeAt(sourceExpenseIndex);
      
      _subgroups[sourceSubgroupIndex] = _subgroups[sourceSubgroupIndex].copyWith(
        expenses: sourceUpdatedExpenses,
      );
      
      // Recalcular subtotal del subgrupo origen
      final sourceNewSubtotal = sourceUpdatedExpenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[sourceSubgroupIndex] = _subgroups[sourceSubgroupIndex].copyWith(subtotal: sourceNewSubtotal);
      
      // Agregar el gasto al subgrupo destino
      final targetUpdatedExpenses = List<Gasto>.from(_subgroups[targetSubgroupIndex].expenses);
      targetUpdatedExpenses.add(gasto);
      
      _subgroups[targetSubgroupIndex] = _subgroups[targetSubgroupIndex].copyWith(
        expenses: targetUpdatedExpenses,
      );
      
      // Recalcular subtotal del subgrupo destino
      final targetNewSubtotal = targetUpdatedExpenses.fold(0.0, (sum, g) => sum + g.valor);
      _subgroups[targetSubgroupIndex] = _subgroups[targetSubgroupIndex].copyWith(subtotal: targetNewSubtotal);
    });
    
    print('DEBUG: Expense moved between subgroups successfully');
    _calculateTotal();
    await _saveElementOrder();
  }

  Future<void> _updateImageOrder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String movedId = _imageOrder.removeAt(oldIndex);
      _imageOrder.insert(newIndex, movedId);
    });
    await _saveElementOrder();
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
          // Generar ID único para la imagen
          final String imageId = DateTime.now().millisecondsSinceEpoch.toString();
          
          // Procesar imagen fragmentada para evitar límite de Firestore
          final Map<String, dynamic> fragmentedImage = await _storageService.procesarImagenFragmentada(
            imageFile: image,
            descripcion: '', // Descripción vacía por defecto
            onProgress: (progress) {
              // Opcional: mostrar progreso adicional
            },
          );
          
          setState(() {
            _imagenes[imageId] = fragmentedImage;
            _imageOrder.add(imageId);
          });
          
          _saveElementOrder();

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
  void _updateImageDescription(String imageId, String newDescription) {
    setState(() {
      if (_imagenes.containsKey(imageId)) {
        _imagenes[imageId]!['descripcion'] = newDescription;
      }
    });
  }

  void _removeImage(String imageId) {
    print('=== ELIMINANDO IMAGEN EN GASTO NORMAL ===');
    print('Estado antes de eliminación:');
    print('  - Total de imágenes: ${_imagenes.length}');
    print('  - IDs disponibles: ${_imagenes.keys.toList()}');
    print('  - Imagen existe: ${_imagenes.containsKey(imageId)}');
    
    if (_imagenes.containsKey(imageId)) {
      // Obtener información de la imagen antes de eliminarla
      final imageData = _imagenes[imageId];
      print('Datos de la imagen a eliminar:');
      print('  - Descripción: ${imageData?['descripcion']}');
      print('  - Fecha: ${imageData?['fecha']}');
      print('  - Tamaño de data URL: ${imageData?['imagen']?.length ?? 0} caracteres');
      
      setState(() {
        _imagenes.remove(imageId);
      });
      
      print('Estado después de eliminación:');
      print('  - Imagen eliminada correctamente');
      print('  - Total de imágenes restantes: ${_imagenes.length}');
      print('  - IDs restantes: ${_imagenes.keys.toList()}');
    } else {
      print('ERROR: La imagen con ID $imageId no existe en el mapa');
    }
    print('=== FIN ELIMINACIÓN IMAGEN GASTO NORMAL ===');
    
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
      
      // Log del estado de las imágenes antes de guardar
      print('=== ESTADO DE IMÁGENES ANTES DE GUARDAR (GASTO NORMAL) ===');
      print('Total de imágenes: ${_imagenes.length}');
      print('Mapa de imágenes está vacío: ${_imagenes.isEmpty}');
      print('IDs de imágenes: ${_imagenes.keys.toList()}');
      if (_imagenes.isNotEmpty) {
        _imagenes.forEach((id, data) {
          print('Imagen $id: descripción="${data['descripcion']}", fecha=${data['fecha']}');
          print('Imagen $id: data URL válido=${StorageService.isValidDataUrl(data['imagen'] ?? '')}');
        });
      }
      print('=== FIN ESTADO IMÁGENES GASTO NORMAL ===');

      await FirestoreService().updateExpenseGroup(
        widget.userUid,
        widget.groupId,
        _groupNameController.text,
        _expenses,
        _subgroups,
        imagenes: _imagenes,
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
                        // Lista de gastos individuales con DragTarget
                        DragTarget<Map<String, dynamic>>(
                          onWillAccept: (data) {
                            print('DEBUG Main: DragTarget onWillAccept - data: $data');
                            return data != null && data.containsKey('gasto') && data.containsKey('sourceType') && data['sourceType'] == 'subgroup';
                          },
                          onAccept: (data) {
                            print('DEBUG Main: DragTarget onAccept - data: $data');
                            final sourceSubgroupIndex = data['sourceSubgroupIndex'];
                            final sourceIndex = data['sourceIndex'];
                            
                            if (sourceSubgroupIndex != null && sourceIndex != null) {
                              _moveExpenseFromSubgroup(sourceSubgroupIndex, sourceIndex);
                            }
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Container(
                              decoration: candidateData.isNotEmpty
                                  ? BoxDecoration(
                                      border: Border.all(color: Colors.green, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                itemCount: _expenseOrder.length,
                                onReorder: _updateExpenseOrder,
                                proxyDecorator: (Widget child, int index,
                                    Animation<double> animation) {
                                  return Material(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    child: child,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final expenseId = _expenseOrder[index];
                                  final expenseIndex = _expenses.indexWhere((e) => 
                                      (e.id ?? 'expense_${_expenses.indexOf(e)}') == expenseId);
                                  
                                  if (expenseIndex == -1) return const SizedBox.shrink();
                                  
                                  return LongPressDraggable<Map<String, dynamic>>(
                                    key: ValueKey('expense_$expenseId'),
                                    data: {
                                      'gasto': _expenses[expenseIndex],
                                      'sourceType': 'main',
                                      'sourceIndex': index,
                                    },
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        width: 300,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: GastoForm(
                                          gasto: _expenses[expenseIndex],
                                          index: index,
                                          onCancel: () {},
                                          onGastoChanged: (gasto) {},
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Container(
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: GastoForm(
                                      key: ValueKey('expense_$expenseId'),
                                      gasto: _expenses[expenseIndex],
                                      index: index,
                                      onCancel: () {
                                        setState(() {
                                          _expenses.removeAt(expenseIndex);
                                          _expenseOrder.remove(expenseId);
                                        });
                                        _saveElementOrder();
                                      },
                                      onGastoChanged: (gasto) =>
                                          _updateExpense(expenseIndex, gasto),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        
                        // Lista separada de subgrupos con reordenamiento independiente
                        if (_subgroups.isNotEmpty)
                          DragTarget<Map<String, dynamic>>(
                            onWillAccept: (data) {
                              return data != null && 
                                     data['sourceType'] == 'main' && 
                                     data['gasto'] != null;
                            },
                            onAccept: (data) {
                              final sourceIndex = data['sourceIndex'] as int;
                              // Mover al primer subgrupo por defecto
                              if (_subgroups.isNotEmpty) {
                                _moveExpenseToSubgroup(sourceIndex, 0);
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                decoration: candidateData.isNotEmpty
                                    ? BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                      )
                                    : null,
                                child: ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  itemCount: _subgroupOrder.length,
                                  onReorder: _updateSubgroupOrder,
                                  proxyDecorator: (Widget child, int index,
                                      Animation<double> animation) {
                                    return Material(
                                      color: Colors.transparent,
                                      elevation: 0,
                                      child: child,
                                    );
                                  },
                                  itemBuilder: (context, index) {
                                    final subgroupId = _subgroupOrder[index];
                                    final actualSubgroupIndex = _subgroups.indexWhere((s) => s.subgroupName == subgroupId);
                                    
                                    if (actualSubgroupIndex == -1) return const SizedBox.shrink();
                                    
                                    return ReorderableDragStartListener(
                                      key: ValueKey('subgroup_$subgroupId'),
                                      index: index,
                                      child: Column(
                                        children: [
                                          SubgrupoGastoForm(
                                            key: _subgroupKeys[actualSubgroupIndex],
                                            subgrupoNombre:
                                                _subgroups[actualSubgroupIndex].subgroupName,
                                            index: actualSubgroupIndex,
                                            onNombreChanged: (nombre) =>
                                                _updateSubgroup(actualSubgroupIndex, nombre),
                                            gastos: _subgroups[actualSubgroupIndex].expenses,
                                            onGastosChanged: (gastos) =>
                                                _updateSubgroupExpense(
                                                    actualSubgroupIndex, gastos),
                                            onMoveExpenseOut: (subgroupIdx, expenseIdx) =>
                                                _moveExpenseFromSubgroup(actualSubgroupIndex, expenseIdx),
                                            onMoveExpenseIn: (sourceIndex, targetSubgroupIndex) =>
                                                _moveExpenseToSubgroup(sourceIndex, actualSubgroupIndex),
                                            onMoveExpenseBetweenSubgroups: (sourceSubgroupIndex, sourceExpenseIndex, targetSubgroupIndex) =>
                                                _moveExpenseBetweenSubgroups(sourceSubgroupIndex, sourceExpenseIndex, actualSubgroupIndex),
                                            onEliminar: () {
                                              setState(() {
                                                _subgroups.removeAt(actualSubgroupIndex);
                                                _subgroupKeys.removeAt(actualSubgroupIndex);
                                                _subgroupOrder.remove(subgroupId);
                                              });
                                              _saveElementOrder();
                                              _calculateTotal();
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    );
                                  },
                                ),
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
                                  ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    itemCount: _imageOrder.length,
                                    onReorder: _updateImageOrder,
                                    proxyDecorator: (Widget child, int index,
                                        Animation<double> animation) {
                                      return Material(
                                        color: Colors.transparent,
                                        elevation: 0,
                                        child: child,
                                      );
                                    },
                                    itemBuilder: (context, index) {
                                      final imageId = _imageOrder[index];
                                      final imageData = _imagenes[imageId];
                                      
                                      if (imageData == null) return const SizedBox.shrink();
                                      
                                      return ExpenseImageWidget(
                                        key: ValueKey(imageId),
                                        imageData: imageData,
                                        index: index,
                                        onDelete: () {
                                          _removeImage(imageId);
                                          setState(() {
                                            _imageOrder.remove(imageId);
                                          });
                                          _saveElementOrder();
                                        },
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
