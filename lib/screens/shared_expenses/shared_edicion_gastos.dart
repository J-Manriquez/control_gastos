import 'package:control_gastos/widgets/distribution/distribution_type_selector.dart';
import 'package:control_gastos/widgets/distribution/participant_distribution_list.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_gasto_form.dart';
import 'package:control_gastos/widgets/forms/compartidos/shared_subgrupo_gasto_form.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:control_gastos/models/gastos_model.dart';
import 'package:control_gastos/models/shared_expense_models.dart';
import 'package:control_gastos/models/distribution_module_model.dart';
import 'package:control_gastos/database/singleton_db.dart';
import 'package:control_gastos/services/distribution_service.dart';
import 'package:control_gastos/utils/custom_logger.dart';
import 'package:control_gastos/widgets/loading_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/services/storage_service.dart';
import 'package:control_gastos/widgets/profile_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedEditGroupScreen extends StatefulWidget {
  final String userUid;
  final String groupId;
  final List<String> participantIds;

  const SharedEditGroupScreen({
    super.key,
    required this.userUid,
    required this.groupId,
    required this.participantIds,
  });

  @override
  _SharedEditGroupScreenState createState() => _SharedEditGroupScreenState();
}

class _SharedEditGroupScreenState extends State<SharedEditGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final DistributionService _distributionService = DistributionService();
  final CustomLogger _logger = CustomLogger();


  List<String> _participantIds = [];
  List<Gasto> _expenses = [];
  List<SubgroupModel> _subgroups = [];
  List<GlobalKey> _subgroupKeys = [];
  Map<String, DistributionModule> _expenseDistributions = {};
  Map<String, DistributionModule> _subgroupDistributions = {};
  DistributionModule? _totalDistribution;
  bool _showTotalDistribution = false;
  DistributionType _totalDistributionType = DistributionType.equalParts;
  Map<String, bool> _distributionVisibility = {};
  bool _isDistributionVisible = false;

  double _total = 0.0;
  bool _isLoading = true;
  SharedExpenseGroup? _originalGroup;
  
  // Variables para manejo de imágenes
  final StorageService _storageService = StorageService();
  Map<String, Map<String, dynamic>> _imagenes = {};
  
  // Variables para el orden de elementos
  final List<String> _expenseOrder = [];
  final List<String> _subgroupOrder = [];
  final List<String> _imageOrder = [];

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
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _isDistributionVisible = false;
    _loadSharedGroupData().then((_) {
      _initializeElementOrder();
    });
    for (var expense in _expenses) {
      _distributionVisibility[expense.id!] = true;
    }
    for (var subgroup in _subgroups) {
      _distributionVisibility[subgroup.subgroupName] = true;
    }
    _distributionVisibility['total'] = true;
  }

  Future<void> _loadElementOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expenseOrder = prefs.getStringList('shared_expense_order_${widget.groupId}') ?? [];
      final subgroupOrder = prefs.getStringList('shared_subgroup_order_${widget.groupId}') ?? [];
      final imageOrder = prefs.getStringList('shared_image_order_${widget.groupId}') ?? [];
      
      setState(() {
        _expenseOrder.clear();
        _expenseOrder.addAll(expenseOrder);
        _subgroupOrder.clear();
        _subgroupOrder.addAll(subgroupOrder);
        _imageOrder.clear();
        _imageOrder.addAll(imageOrder);
      });
    } catch (e) {
      _logger.logError('Error al cargar orden de elementos: $e');
    }
  }

  Future<void> _saveElementOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('shared_expense_order_${widget.groupId}', _expenseOrder);
      await prefs.setStringList('shared_subgroup_order_${widget.groupId}', _subgroupOrder);
      await prefs.setStringList('shared_image_order_${widget.groupId}', _imageOrder);
    } catch (e) {
      _logger.logError('Error al guardar orden de elementos: $e');
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

  Future<void> _updateExpenseOrder(int oldIndex, int newIndex) async {
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

  void _updateDistributionVisibility(bool isVisible) {
    setState(() {
      _isDistributionVisible = isVisible;
    });
  }

  Future<void> _loadSharedGroupData() async {
    try {
      _logger.logInfo('Cargando datos del grupo compartido...');

      final group =
          await FirestoreService().getSharedExpenseGroup(widget.groupId);

      setState(() {
        _originalGroup = group;
        _participantIds = group.participants
            .map((p) => p.userId)
            .toList(); // Actualizar la lista de participantes
        _groupNameController.text = group.nombre;
        _expenses = List.from(group.expenses);
        _subgroups = List.from(group.subgroups);
        // Inicializar claves para subgrupos existentes
        _subgroupKeys = List.generate(
          _subgroups.length,
          (index) => GlobalKey()
        );
        _expenseDistributions = Map.from(group.expenseDistributions);
        _subgroupDistributions = Map.from(group.subgroupDistributions);
        _totalDistribution = group.totalDistribution;
        _showTotalDistribution = group.totalDistribution != null;
        if (_totalDistribution != null) {
          _totalDistributionType = _totalDistribution!.type;
        }
        // Cargar imágenes existentes
        if (group.imagenes != null) {
          _imagenes = Map<String, Map<String, dynamic>>.from(group.imagenes!);
        }
        _calculateTotal();
        _isLoading = false;
      });

      _logger.logInfo('Datos del grupo cargados exitosamente');
      
      // Cargar el orden de los elementos
      await _loadElementOrder();
    } catch (e) {
      _logger.logError('Error al cargar datos del grupo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el grupo: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _calculateTotal() {
    double newTotal =
        _expenses.fold(0.0, (sum, expense) => sum + expense.valor) +
            _subgroups.fold(
                0.0,
                (sum, subgroup) =>
                    sum +
                    subgroup.expenses
                        .fold(0.0, (subSum, exp) => subSum + exp.valor));

    setState(() {
      _total = newTotal;

      // Si hay una distribución total activa, actualizar su monto total
      if (_totalDistribution != null) {
        _totalDistribution = _totalDistribution!.copyWith(totalAmount: _total);

        // Si no hay distribuciones activas y es una distribución normal, recalcular shares
        if (_expenseDistributions.isEmpty && _subgroupDistributions.isEmpty) {
          if (_totalDistributionType == DistributionType.equalParts) {
            _totalDistribution = _distributionService.recalculateDistribution(
              _totalDistribution!,
              _total,
            );
          }
        } else {
          // Si hay distribuciones activas, actualizar el resumen
          _updateTotalDistributionSummary();
        }
      }
    });
  }

  void _addExpenseForm() {
    final newExpense = Gasto(
      nombre: '',
      valor: 0,
      fecha: DateTime.now(),
      esAFavor: true,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    setState(() {
      _expenses.add(newExpense);
      _expenseOrder.add(newExpense.id!);
    });
    _saveElementOrder();
  }

  void _addSubgroup() {
    final subgroupName = 'Subgrupo ${_subgroups.length + 1}';
    setState(() {
      _subgroups.add(SubgroupModel(
        subgroupName: subgroupName,
        expenses: [],
        subtotal: 0,
      ));
      _subgroupKeys.add(GlobalKey());
      _subgroupOrder.add(subgroupName);
    });
    _saveElementOrder();
  }

  void _handleExpenseChanged(
      int index, Gasto gasto, DistributionModule? distribution) {
    setState(() {
      // Asegúrate de que el gasto tenga un ID válido
      if (gasto.id == null) {
        gasto = gasto.copyWith(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_$index');
      }

      _expenses[index] = gasto;
      if (distribution != null && gasto.id != null) {
        _expenseDistributions[gasto.id!] = distribution;
      } else if (gasto.id != null) {
        _expenseDistributions.remove(gasto.id);
      }
      _calculateTotal();
      _updateTotalDistributionSummary(); // Actualizar el resumen de distribución
    });
  }

  void _handleSubgroupChanged(int index, String nombre, List<Gasto> gastos,
      DistributionModule? distribution) {
    setState(() {
      // Obtener el nombre anterior del subgrupo
      String nombreAnterior = _subgroups[index].subgroupName;
      
      // Actualizar el subgrupo preservando el ID original
      _subgroups[index] = _subgroups[index].copyWith(
        subgroupName: nombre,
        expenses: gastos,
        subtotal: gastos.fold(0.0, (sum, gasto) => sum! + gasto.valor),
      );
      
      // Manejar las distribuciones
      if (distribution != null) {
        // Si hay una nueva distribución, usarla
        _subgroupDistributions[nombre] = distribution;
      } else {
        // Si no hay nueva distribución pero el nombre cambió, mover la distribución existente
        if (nombreAnterior != nombre && _subgroupDistributions.containsKey(nombreAnterior)) {
          DistributionModule? existingDistribution = _subgroupDistributions.remove(nombreAnterior);
          if (existingDistribution != null) {
            _subgroupDistributions[nombre] = existingDistribution;
          }
        }
      }
      
      // Limpiar distribuciones huérfanas si el nombre cambió
      if (nombreAnterior != nombre) {
        _subgroupDistributions.remove(nombreAnterior);
        _distributionVisibility.remove(nombreAnterior);
        if (_distributionVisibility.containsKey(nombreAnterior)) {
          _distributionVisibility[nombre] = _distributionVisibility.remove(nombreAnterior) ?? true;
        }
      }
      
      _calculateTotal();
      _updateTotalDistributionSummary(); // Actualizar el resumen de distribución
    });
  }

  Future<void> _addImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        // Mostrar pantalla de carga solo después de seleccionar la imagen
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
          final Map<String, dynamic> imagenFragmentada = await _storageService.procesarImagenFragmentada(imageFile: image);
          
          setState(() {
            _imagenes[imageId] = imagenFragmentada;
            _imageOrder.add(imageId);
          });
          _saveElementOrder();
          
          print('Imagen agregada correctamente. Total de imágenes: ${_imagenes.length}');
          print('IDs de imágenes: ${_imagenes.keys.toList()}');
          // print('Data URL válido: ${StorageService.isValidDataUrl(data['imagen'] ?? '')}');
          
          // Cerrar pantalla de carga
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        } catch (e) {
          // Cerrar pantalla de carga en caso de error
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al procesar la imagen: $e')),
            );
          }
        }
      }
    } catch (e) {
      // Cerrar pantalla de carga en caso de error
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar imagen: $e')),
        );
      }
    }
  }

  void _deleteImage(String imageId) {
    print('=== INICIO ELIMINACIÓN DE IMAGEN ===');
    print('ID de imagen a eliminar: $imageId');
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
        _imageOrder.remove(imageId);
      });
      _saveElementOrder();
      
      print('Estado después de eliminación:');
      print('  - Imagen eliminada correctamente');
      print('  - Total de imágenes restantes: ${_imagenes.length}');
      print('  - IDs restantes: ${_imagenes.keys.toList()}');
      print('  - Mapa de imágenes vacío: ${_imagenes.isEmpty}');
    } else {
      print('ERROR: Intento de eliminar imagen inexistente');
      print('  - ID solicitado: $imageId');
      print('  - IDs disponibles: ${_imagenes.keys.toList()}');
    }
    print('=== FIN ELIMINACIÓN DE IMAGEN ===');
  }

  void _updateImageDescription(String imageId, String description) {
    if (_imagenes.containsKey(imageId)) {
      setState(() {
        _imagenes[imageId]!['descripcion'] = description;
      });
      print('Descripción de imagen actualizada. ID: $imageId, Descripción: "$description"');
    } else {
      print('Error: Intento de actualizar descripción de imagen inexistente. ID: $imageId');
      print('IDs disponibles: ${_imagenes.keys.toList()}');
    }
  }

  Future<void> _saveGroup() async {
    // En tu widget o bloque donde se llama a _saveGroup
    print('Usuario autenticado ID: ${FirebaseAuth.instance.currentUser?.uid}');
    print('Creator ID del grupo: ${_originalGroup?.creatorId}');
    print(
        'Permission Type del grupo: ${_originalGroup?.permissionType.toString()}');
    print('Participantes del grupo: ${_originalGroup?.participants.map((p) => {
          'userId': p.userId,
          'status': p.status.toString()
        }).toList()}');

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
            message: 'Actualizando Gastos Compartidos...',
            subtitle: 'Por favor espera mientras actualizamos tu grupo de gastos compartidos',
            type: LoadingType.general,
          ),
        ),
      );
    }

    try {
      _logger.logInfo('Iniciando proceso de guardado del grupo');

      // Obtener nombres actuales de los formularios de subgrupos y actualizar
      for (int i = 0; i < _subgroups.length; i++) {
        final formKey = _subgroupKeys[i];
        final state = formKey.currentState;
         if (state != null) {
           // Usar dynamic para acceder al método público getCurrentName
           final dynamic dynamicState = state;
           try {
             final currentName = dynamicState.getCurrentName() as String;
             _logger.logInfo('Subgrupo $i - Nombre del formulario: "$currentName"');
             _logger.logInfo('Subgrupo $i - Nombre anterior: "${_subgroups[i].subgroupName}"');
             
             if (currentName != _subgroups[i].subgroupName) {
               String nombreAnterior = _subgroups[i].subgroupName;
               setState(() {
                 _subgroups[i] = _subgroups[i].copyWith(
                   subgroupName: currentName,
                   subtotal: _subgroups[i].calculateSubtotal(),
                 );
               });
               
               // Migrar distribuciones si el nombre cambió
               if (_subgroupDistributions.containsKey(nombreAnterior)) {
                 DistributionModule? existingDistribution = _subgroupDistributions.remove(nombreAnterior);
                 if (existingDistribution != null) {
                   _subgroupDistributions[currentName] = existingDistribution;
                 }
               }
               
               _logger.logInfo('Subgrupo $i actualizado con nuevo nombre: "$currentName"');
             }
           } catch (e) {
             _logger.logError('Error al acceder a getCurrentName: $e');
           }
         }
      }

      // Verificar IDs de gastos
      for (int i = 0; i < _expenses.length; i++) {
        _logger.logInfo(
            'Gasto $i: ID = ${_expenses[i].id}, Nombre = ${_expenses[i].nombre}');
        if (_expenses[i].id == null) {
          String newId = 'expense_${DateTime.now().millisecondsSinceEpoch}_$i';
          _logger.logInfo('Generando nuevo ID para gasto $i: $newId');
          _expenses[i] = _expenses[i].copyWith(id: newId);
        }
      }

      // Verificar IDs en las distribuciones
      _logger.logInfo(
          'Verificando distribuciones de gastos: ${_expenseDistributions.length} encontradas');
      Map<String, DistributionModule> validatedExpenseDistributions = {};
      _expenseDistributions.forEach((key, value) {
        _logger.logInfo(
            'Verificando distribución con clave: $key, objetivo: ${value.targetId}');
        if (key != null && key.isNotEmpty) {
          validatedExpenseDistributions[key] = value;
        } else {
          _logger.logError(
              'Encontrada clave nula o vacía en _expenseDistributions');
        }
      });

      // Verificar IDs de subgrupos
      _logger
          .logInfo('Verificando subgrupos: ${_subgroups.length} encontrados');
      for (int i = 0; i < _subgroups.length; i++) {
        _logger.logInfo(
            'Subgrupo $i: Nombre = ${_subgroups[i].subgroupName}, ${_subgroups[i].expenses.length} gastos');
        // Verificar cada gasto dentro del subgrupo
        for (int j = 0; j < _subgroups[i].expenses.length; j++) {
          Gasto gasto = _subgroups[i].expenses[j];
          _logger.logInfo(
              '  Gasto $j del subgrupo $i: ID = ${gasto.id}, Nombre = ${gasto.nombre}');
          if (gasto.id == null) {
            String newId =
                'subgroup_${i}_expense_${DateTime.now().millisecondsSinceEpoch}_$j';
            _logger.logInfo(
                '  Generando nuevo ID para gasto $j del subgrupo $i: $newId');
            _subgroups[i].expenses[j] = gasto.copyWith(id: newId);
          }
        }
      }

      // Verificar distribuciones de subgrupos
      _logger.logInfo(
          'Verificando distribuciones de subgrupos: ${_subgroupDistributions.length} encontradas');
      Map<String, DistributionModule> validatedSubgroupDistributions = {};
      _subgroupDistributions.forEach((key, value) {
        _logger.logInfo(
            'Verificando distribución de subgrupo con clave: $key, objetivo: ${value.targetId}');
        if (key != null && key.isNotEmpty) {
          validatedSubgroupDistributions[key] = value;
        } else {
          _logger.logError(
              'Encontrada clave nula o vacía en _subgroupDistributions');
        }
      });

      // Verificar distribución total
      if (_showTotalDistribution && _totalDistribution != null) {
        _logger.logInfo(
            'Distribución total activa: ID = ${_totalDistribution!.id}, Objetivo = ${_totalDistribution!.targetId}');
      } else {
        _logger.logInfo('Sin distribución total activa');
      }

      // Logging específico para imágenes
      print('=== ESTADO DE IMÁGENES ANTES DE GUARDAR ===');
      print('Total de imágenes en _imagenes: ${_imagenes.length}');
      print('IDs de imágenes: ${_imagenes.keys.toList()}');
      print('Mapa de imágenes vacío: ${_imagenes.isEmpty}');
      if (_imagenes.isNotEmpty) {
        _imagenes.forEach((id, data) {
          print('Imagen $id:');
          print('  - Descripción: "${data['descripcion']}"');
          print('  - Fecha: ${data['fecha']}');
          print('  - Data URL válido: ${StorageService.isValidDataUrl(data['imagen'] ?? '')}');
          print('  - Tamaño data URL: ${data['imagen']?.length ?? 0} caracteres');
        });
      } else {
        print('No hay imágenes en el mapa _imagenes');
      }
      print('=== FIN ESTADO IMÁGENES ===');
      
      _logger.logInfo('Estado de imágenes antes de guardar:');
      _logger.logInfo('Total de imágenes: ${_imagenes.length}');
      _logger.logInfo('IDs de imágenes: ${_imagenes.keys.toList()}');
      if (_imagenes.isNotEmpty) {
        _imagenes.forEach((id, data) {
          _logger.logInfo('Imagen $id: descripción="${data['descripcion']}", fecha=${data['fecha']}');
          _logger.logInfo('Imagen $id: data URL válido=${StorageService.isValidDataUrl(data['imagen'] ?? '')}');
        });
      }

      _logger.logInfo('Creando objeto SharedExpenseGroup actualizado');
      final updatedGroup = SharedExpenseGroup(
        id: widget.groupId,
        nombre: _groupNameController.text,
        total: _total,
        expenses: _expenses,
        subgroups: _subgroups,
        creationDate: _originalGroup!.creationDate,
        creatorId: _originalGroup!.creatorId,
        participants: _originalGroup!.participants,
        permissionType: _originalGroup!.permissionType,
        version: _originalGroup!.version,
        lastModified: DateTime.now(),
        expenseDistributions: validatedExpenseDistributions,
        subgroupDistributions: validatedSubgroupDistributions,
        totalDistribution: _showTotalDistribution ? _totalDistribution : null,
        imagenes: _imagenes, // Siempre pasar el mapa, aunque esté vacío
      );

      print('=== UPDATEDGROUP CREADO ===');
      print('Imágenes en updatedGroup: ${updatedGroup.imagenes?.length ?? 0}');
      print('IDs en updatedGroup: ${updatedGroup.imagenes?.keys.toList() ?? []}');
      print('updatedGroup.imagenes es null: ${updatedGroup.imagenes == null}');
      print('updatedGroup.imagenes está vacío: ${updatedGroup.imagenes?.isEmpty ?? true}');
      print('=== FIN UPDATEDGROUP ===');
      
      _logger
          .logInfo('Objeto SharedExpenseGroup creado, procediendo a guardarlo');

      // Crear un mapa para inspección antes de guardar
      Map<String, dynamic> groupMap = updatedGroup.toMap();
      print('=== MAPA PARA FIRESTORE ===');
      print('Campo imagenes en mapa: ${groupMap.containsKey('imagenes')}');
      if (groupMap.containsKey('imagenes')) {
        final imagenesEnMapa = groupMap['imagenes'] as Map<String, dynamic>?;
        print('Imágenes en mapa: ${imagenesEnMapa?.length ?? 0}');
        print('IDs en mapa: ${imagenesEnMapa?.keys.toList() ?? []}');
      }
      print('=== FIN MAPA FIRESTORE ===');
      
      _logger
          .logInfo('Mapa generado para Firebase: ${groupMap.keys.join(', ')}');

      // Guardando en Firebase
      _logger
          .logInfo('Llamando a updateSharedExpense con ID: ${widget.groupId}');
      await FirestoreService()
          .sharedExpenseService
          .updateSharedExpense(widget.groupId, updatedGroup, widget.userUid);

      _logger.logInfo('Grupo actualizado con éxito');

      if (mounted) {
        // Cerrar pantalla de carga
        Navigator.of(context).pop();
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo actualizado con éxito')),
        );
        
        // Navegar de vuelta a la pantalla anterior
        try {
          Navigator.of(context).pop();
        } catch (navError) {
          _logger.logError('Error en navegación: $navError');
        }
      }
    } catch (e, stackTrace) {
      _logger.logError('Error al actualizar grupo: $e');
      _logger.logError('Stack trace: $stackTrace');

      if (mounted) {
        // Cerrar pantalla de carga
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el grupo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Scaffold(
      backgroundColor: colorProvider.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Editar Gasto Compartido',
          style: TextStyle(
            color: colorProvider.colors.secondaryTextColor,
            fontSize: 20,
          ),
        ),
        backgroundColor: colorProvider.colors.appBarColor,
        iconTheme:
            IconThemeData(color: colorProvider.colors.secondaryTextColor),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                Icons.save,
                color: colorProvider.colors.secondaryTextColor,
              ),
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
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGroupNameField(),
                        // const SizedBox(height: 3),
                        _buildTotalDistributionSection(),
                        // const SizedBox(height: 3),
                        _buildExpensesList(),
                        _buildSubgroupsList(),
                        if (_imagenes.isNotEmpty) _buildImagesSection(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildGroupNameField() {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Card(
      margin: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 4, top: 4),
      color: colorProvider.colors.backgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(8.0), // Mantiene tus bordes redondeados
        side: BorderSide(
          color: colorProvider.colors.appBarColor, // Mantiene tu borde original
          width: 2.0, // Ancho del borde
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del grupo',
                    labelStyle: TextStyle(
                      color: colorProvider.colors.primaryTextColor,
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: colorProvider.colors.appBarColor,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: colorProvider.colors.primaryTextColor,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: colorProvider.colors.primaryTextColor,
                ),
                onSelected: (String value) {
                  setState(() {
                    _groupNameController.text = value;
                  });
                },
                itemBuilder: (BuildContext context) {
                  return _months.map((String month) {
                    return PopupMenuItem<String>(
                      value: month,
                      child: Text(
                        month,
                        style: TextStyle(
                          color: colorProvider.colors.secondaryTextColor,
                        ),
                      ),
                    );
                  }).toList();
                },
                color: colorProvider.colors.appBarColor,
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildExpensesList() {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
        final expenseIndex = _expenses.indexWhere((e) => (e.id ?? 'expense_${_expenses.indexOf(e)}') == expenseId);
        if (expenseIndex == -1) return Container(key: ValueKey(expenseId));
        
        final expense = _expenses[expenseIndex];
        return SharedGastoForm(
          key: ValueKey(expense.id),
          gasto: expense,
          participantIds: _participantIds,
          initialDistribution: _expenseDistributions[expense.id],
          isDistributionVisible: _distributionVisibility[expense.id] ?? true,
          index: index,
          onVisibilityChanged: (value) {
            setState(() {
              _distributionVisibility[expense.id!] = value;
              _updateDistributionVisibility(value); // Llamar aquí
            });
          },
          onCancel: () {
            setState(() {
              _expenses.removeAt(expenseIndex);
              _expenseOrder.remove(expenseId);
              if (expense.id != null) {
                _expenseDistributions.remove(expense.id);
              }
              _calculateTotal();
            });
            _saveElementOrder();
          },
          onGastoChanged: (gasto, distribution) =>
              _handleExpenseChanged(expenseIndex, gasto, distribution),
          group: _originalGroup!,
        );
      },
    );
  }

  Widget _buildSubgroupsList() {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
        final subgroupName = _subgroupOrder[index];
        final subgroupIndex = _subgroups.indexWhere((s) => s.subgroupName == subgroupName);
        if (subgroupIndex == -1) return Container(key: ValueKey(subgroupName));
        
        final subgroup = _subgroups[subgroupIndex];
        return SharedSubgrupoGastoForm(
          key: _subgroupKeys[subgroupIndex],
          subgrupoNombre: subgroup.subgroupName,
          gastos: subgroup.expenses,
          participantIds: _participantIds,
          initialDistribution: _subgroupDistributions[subgroup.subgroupName],
          index: index,
          onVisibilityChanged: (value) {
            setState(() {
              _distributionVisibility[subgroup.subgroupName] = value;
              _updateDistributionVisibility(
                  value); // Llamar aquí si es necesario actualizar algo en el padre
            });
          },
          isDistributionVisible:
              _distributionVisibility[subgroup.subgroupName] ?? true,
          onNombreChanged: (nombre) => _handleSubgroupChanged(subgroupIndex, nombre, subgroup.expenses, null),
          onGastosChanged: (gastos, distribution) => _handleSubgroupChanged(
              subgroupIndex, subgroup.subgroupName, gastos, distribution),
          onEliminar: () {
            setState(() {
              _subgroupDistributions.remove(subgroup.subgroupName);
              _subgroups.removeAt(subgroupIndex);
              _subgroupKeys.removeAt(subgroupIndex);
              _subgroupOrder.remove(subgroupName);
              _calculateTotal();
            });
            _saveElementOrder();
          },
          group: _originalGroup!,
        );
      },
    );
  }

  Widget _buildImagesSection() {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Card(
      margin: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 4, top: 4),
      color: colorProvider.colors.backgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: colorProvider.colors.appBarColor,
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
            _imagenes.isEmpty
                ? const Text('No hay imágenes agregadas')
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                      if (!_imagenes.containsKey(imageId)) {
                        return Container(key: ValueKey(imageId));
                      }
                      final imageData = _imagenes[imageId]!;
                      return ExpenseImageWidget(
                        key: ValueKey(imageId),
                        imageData: imageData,
                        index: index,
                        onDelete: () {
                          _deleteImage(imageId);
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
    );
  }

  // Añadir este nuevo método para actualizar el resumen de distribución
  void _updateTotalDistributionSummary() {
    if (!_showTotalDistribution) return;

    // Verificar si hay distribuciones activas
    bool hasActiveDistributions =
        _expenseDistributions.isNotEmpty || _subgroupDistributions.isNotEmpty;

    if (hasActiveDistributions) {
      // Calcular la suma de todas las distribuciones activas por participante
      Map<String, double> participantTotals = {};
      double totalDistributed = 0.0;

      // Inicializar totales para todos los participantes
      for (var participantId in _participantIds) {
        participantTotals[participantId] = 0.0;
      }

      // Sumar distribuciones de gastos individuales
      _expenseDistributions.forEach((_, distribution) {
        for (var share in distribution.shares) {
          participantTotals[share.userId] =
              (participantTotals[share.userId] ?? 0) + share.amount;
          totalDistributed += share.amount;
        }
      });

      // Sumar distribuciones de subgrupos
      _subgroupDistributions.forEach((_, distribution) {
        for (var share in distribution.shares) {
          participantTotals[share.userId] =
              (participantTotals[share.userId] ?? 0) + share.amount;
          totalDistributed += share.amount;
        }
      });

      // Calcular monto no distribuido
      double undistributedAmount = _total - totalDistributed;
      if (undistributedAmount < 0.01)
        undistributedAmount =
            0.0; // Evitar valores negativos muy pequeños por errores de redondeo

      // Crear distribución basada en la suma de distribuciones existentes
      List<ParticipantShare> summaryShares = [];

      // Agregar participantes con sus montos sumados
      participantTotals.forEach((userId, amount) {
        if (amount > 0) {
          summaryShares.add(ParticipantShare(
            userId: userId,
            amount: amount,
            percentage: (_total > 0) ? (amount / _total) * 100 : 0.0,
          ));
        }
      });

      // Agregar monto no distribuido como un participante especial
      if (undistributedAmount > 0) {
        summaryShares.add(ParticipantShare(
          userId: 'undistributed',
          amount: undistributedAmount,
          percentage: (_total > 0) ? (undistributedAmount / _total) * 100 : 0.0,
        ));
      }

      _totalDistribution = DistributionModule(
        id: _totalDistribution?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        targetId: 'total',
        targetType: DistributionTarget.total,
        type: DistributionType.percentage, // Usar porcentaje para el resumen
        shares: summaryShares,
        totalAmount: _total,
        lastModified: DateTime.now(),
      );
    }
  }

  Widget _buildTotalDistributionSection() {
    final colorProvider = Provider.of<ColorProvider>(context);

    // Verificar si hay distribuciones activas
    bool hasActiveDistributions =
        _expenseDistributions.isNotEmpty || _subgroupDistributions.isNotEmpty;

    // Calcular la suma de todas las distribuciones activas por participante
    Map<String, double> participantTotals = {};
    double totalDistributed = 0.0;

    if (hasActiveDistributions) {
      // Inicializar totales para todos los participantes
      for (var participantId in _participantIds) {
        participantTotals[participantId] = 0.0;
      }

      // Sumar distribuciones de gastos individuales
      _expenseDistributions.forEach((_, distribution) {
        for (var share in distribution.shares) {
          participantTotals[share.userId] =
              (participantTotals[share.userId] ?? 0) + share.amount;
          totalDistributed += share.amount;
        }
      });

      // Sumar distribuciones de subgrupos
      _subgroupDistributions.forEach((_, distribution) {
        for (var share in distribution.shares) {
          participantTotals[share.userId] =
              (participantTotals[share.userId] ?? 0) + share.amount;
          totalDistributed += share.amount;
        }
      });
    }

    // Calcular monto no distribuido
    double undistributedAmount = _total - totalDistributed;
    if (undistributedAmount < 0.01) {
      undistributedAmount =
          0.0; // Evitar valores negativos muy pequeños por errores de redondeo
    }

    return Card(
        margin: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 4, top: 4),
        color: colorProvider.colors.backgroundColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(8.0), // Mantiene tus bordes redondeados
          side: BorderSide(
          color: colorProvider.colors.appBarColor, // Mantiene tu borde original
            width: 2.0, // Ancho del borde
          ),
        ),
        child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasActiveDistributions
                          ? 'Resumen de Distribución'
                          : 'Distribuir Total',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorProvider.colors.primaryTextColor,
                      ),
                    ),
                    if (_showTotalDistribution)
                      IconButton(
                        icon: Icon(
                          _distributionVisibility['total'] ?? false
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: colorProvider.colors.primaryTextColor,
                        ),
                        onPressed: () {
                          setState(() {
                            bool newValue =
                                !(_distributionVisibility['total'] ?? true);
                            _distributionVisibility['total'] = newValue;
                            _updateDistributionVisibility(newValue);
                          });
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ToggleButtons(
                      isSelected: [
                        _showTotalDistribution,
                        !_showTotalDistribution,
                      ],
                      // En el método _buildTotalDistributionSection, reemplazar el bloque donde se crea la distribución
                      // cuando _showTotalDistribution es true con esto:

                      onPressed: (index) {
                        setState(() {
                          _showTotalDistribution = index == 0;

                          if (_showTotalDistribution) {
                            bool hasActiveDistributions =
                                _expenseDistributions.isNotEmpty ||
                                    _subgroupDistributions.isNotEmpty;

                            if (hasActiveDistributions) {
                              _updateTotalDistributionSummary();
                            } else if (_totalDistribution == null) {
                              // Si no hay distribuciones activas, crear una distribución normal
                              List<ParticipantShare> shares =
                                  _distributionService.calculateEqualShares(
                                _participantIds,
                                _total,
                              );

                              _totalDistribution = DistributionModule(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                targetId: 'total',
                                targetType: DistributionTarget.total,
                                type: _totalDistributionType,
                                shares: shares,
                                totalAmount: _total,
                                lastModified: DateTime.now(),
                              );
                            }
                          }
                        });
                      },
                      borderColor: _showTotalDistribution
                          ? colorProvider.colors.positiveColor
                          : colorProvider.colors.appBarColor,
                      selectedBorderColor: _showTotalDistribution
                          ? colorProvider.colors.positiveColor
                          : colorProvider.colors.appBarColor,
                      color: colorProvider.colors.primaryTextColor,
                      constraints: const BoxConstraints(
                        minHeight: 25.0,
                        minWidth: 120.0,
                      ),
                      selectedColor: colorProvider.colors.secondaryTextColor,
                      borderRadius: BorderRadius.circular(10),
                      fillColor: _showTotalDistribution
                          ? colorProvider.colors.positiveColor
                          : colorProvider.colors.appBarColor,
                      children: const [
                        SizedBox(
                          child: Center(
                            child: Text(
                              'ACTIVO',
                              style: TextStyle(fontSize: 14, height: 0),
                            ),
                          ),
                        ),
                        SizedBox(
                          child: Center(
                            child: Text(
                              'INACTIVO',
                              style: TextStyle(fontSize: 14, height: 0),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                if (_showTotalDistribution && _totalDistribution != null) ...[
                  // const SizedBox(height: 16),
                  if (_distributionVisibility['total'] ?? true) ...[
                    if (!hasActiveDistributions) ...[
                      // Solo mostrar selector de tipo si no hay distribuciones activas
                      DistributionTypeSelector(
                        selectedType: _totalDistributionType,
                        onTypeChanged: (type) {
                          setState(() {
                            _totalDistributionType = type;
                            if (_totalDistribution != null) {
                              if (type == DistributionType.equalParts) {
                                _totalDistribution = _distributionService
                                    .recalculateDistribution(
                                  _totalDistribution!,
                                  _total,
                                );
                              }
                            }
                          });
                        },
                      ),
                    ],
                    // const SizedBox(height: 16),
                    if (_totalDistribution != null)
                      ParticipantDistributionList(
                        participantIds: hasActiveDistributions
                            ? [
                                ..._participantIds,
                                'undistributed'
                              ] // Incluir 'undistributed' en modo resumen
                            : _participantIds,
                        totalAmount: _total,
                        distributionType: hasActiveDistributions
                            ? DistributionType
                                .percentage // Forzar porcentaje en modo resumen
                            : _totalDistributionType,
                        shares: _totalDistribution!.shares,
                        onSharesChanged: (shares) {
                          setState(() {
                            _totalDistribution = DistributionModule(
                              id: _totalDistribution!.id,
                              targetId: _totalDistribution!.targetId,
                              targetType: DistributionTarget.total,
                              type: hasActiveDistributions
                                  ? DistributionType
                                      .percentage // Forzar porcentaje en modo resumen
                                  : _totalDistributionType,
                              shares: shares,
                              totalAmount: _total,
                              lastModified: DateTime.now(),
                            );
                          });
                        },
                        isReadOnly:
                            hasActiveDistributions, // Hacer la lista de solo lectura en modo resumen
                      ),
                  ],
                ],
              ],
            )));
  }

  Widget _buildBottomBar() {
    final colorProvider = Provider.of<ColorProvider>(context);

    return Container(
      color: _total >= 0
          ? colorProvider.colors.positiveColor
          : colorProvider.colors.negativeColor,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: \$${_currencyFormat.format(_total)}',
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
              return [
                PopupMenuItem<int>(
                  value: 1,
                  child: Text(
                    '• Agregar Monto',
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                  ),
                ),
                PopupMenuItem<int>(
                  value: 2,
                  child: Text(
                    '• Agregar Grupo',
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                  ),
                ),
                PopupMenuItem<int>(
                  value: 3,
                  child: Text(
                    '• Agregar Imagen',
                    style: TextStyle(
                      color: colorProvider.colors.secondaryTextColor,
                    ),
                  ),
                ),
              ];
            },
            color: colorProvider.colors.appBarColor,
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}
