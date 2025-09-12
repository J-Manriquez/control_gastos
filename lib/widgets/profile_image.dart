import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:control_gastos/services/storage_service.dart';
import 'package:control_gastos/database/singleton_db.dart';

class ProfileImage extends StatelessWidget {
  final dynamic imageData; // Puede ser String (base64) o Map (fragmentada)
  final double width;
  final double height;
  final BoxFit fit;
  final double? radius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  // Cache estático para imágenes decodificadas
  static final Map<String, Uint8List> _imageCache = {};
  static const int _maxCacheSize = 50; // Límite de cache

  const ProfileImage({
    Key? key,
    required this.imageData,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholder,
    this.errorWidget,
    this.errorBuilder,
  }) : super(key: key);

  // Constructor para retrocompatibilidad
  const ProfileImage.fromBase64({
    Key? key,
    required String base64Image,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    double? radius,
    Widget? placeholder,
    Widget? errorWidget,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) : this(
          key: key,
          imageData: base64Image,
          width: width,
          height: height,
          fit: fit,
          radius: radius,
          placeholder: placeholder,
          errorWidget: errorWidget,
          errorBuilder: errorBuilder,
        );

  @override
  Widget build(BuildContext context) {
    try {
      String base64Image = '';

      // Determinar el tipo de imagen y obtener el base64 completo
      if (imageData is String) {
        // Imagen normal (retrocompatibilidad)
        base64Image = imageData as String;
      } else if (imageData is Map<String, dynamic>) {
        // Imagen fragmentada
        base64Image = StorageService.obtenerImagenCompleta(
            imageData as Map<String, dynamic>);
      }

      // Si no hay imagen válida, mostrar placeholder
      if (base64Image.isEmpty || !StorageService.isValidDataUrl(base64Image)) {
        return _buildPlaceholder();
      }

      // Usar cache para evitar decodificar repetidamente
      final String cacheKey = base64Image.hashCode.toString();
      Uint8List? imageBytes = _imageCache[cacheKey];
      
      if (imageBytes == null) {
        // Extraer la parte Base64 del data URL y decodificar
        final String base64String =
            StorageService.extractBase64FromDataUrl(base64Image);
        imageBytes = base64Decode(base64String);
        
        // Agregar al cache con límite de tamaño
        if (_imageCache.length >= _maxCacheSize) {
          // Remover la entrada más antigua
          final firstKey = _imageCache.keys.first;
          _imageCache.remove(firstKey);
        }
        _imageCache[cacheKey] = imageBytes;
      }

      Widget imageWidget = Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true, // Evita parpadeo durante reconstrucciones
        errorBuilder: errorBuilder ??
            (context, error, stackTrace) {
              return errorWidget ?? _buildErrorWidget();
            },
      );

      // Aplicar border radius si se especifica
      if (radius != null) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(radius!),
          child: imageWidget,
        );
      }

      return SizedBox(
        width: width,
        height: height,
        child: imageWidget,
      );
    } catch (e) {
      if (errorBuilder != null) {
        return errorBuilder!(context, e, null);
      }
      return errorWidget ?? _buildErrorWidget();
    }
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) {
      return SizedBox(
        width: width,
        height: height,
        child: placeholder,
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: radius != null ? BorderRadius.circular(radius!) : null,
      ),
      child: const Icon(
        Icons.image,
        color: Colors.grey,
        size: 40,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: radius != null ? BorderRadius.circular(radius!) : null,
      ),
      child: const Icon(
        Icons.error,
        color: Colors.red,
        size: 40,
      ),
    );
  }
}

/// Widget para mostrar imágenes de gastos con información adicional
class ExpenseImageWidget extends StatefulWidget {
  final Map<String, dynamic> imageData;
  final VoidCallback? onDelete;
  final Function(String)? onDescriptionChanged;
  final Function(double?, bool?)? onValueChanged;
  final int? index;
  final String? groupId;
  final String? imageId;

  const ExpenseImageWidget({
    Key? key,
    required this.imageData,
    this.onDelete,
    this.onDescriptionChanged,
    this.onValueChanged,
    this.index,
    this.groupId,
    this.imageId,
  }) : super(key: key);

  @override
  State<ExpenseImageWidget> createState() => _ExpenseImageWidgetState();
}

class _ExpenseImageWidgetState extends State<ExpenseImageWidget> {
  late TextEditingController _descriptionController;
  late TextEditingController _valorController;
  bool _isEditing = false;
  bool _showValueMode = false;
  bool _esAFavor = true;
  double _valorNumerico = 0.0;
  final NumberFormat _numberFormat = NumberFormat('#,###', 'fr_FR');
  Timer? _debounceTimer; // Timer para debounce de cambios de valor
  Timer? _descriptionDebounceTimer; // Timer para debounce de cambios de descripción
  
  // Variables para carga asíncrona de imágenes fragmentadas externas
  String? _loadedExternalImage;
  bool _isLoadingExternalImage = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.imageData['descripcion'] ?? '',
    );

    // Inicializar valores del modo valor
    _valorNumerico = widget.imageData['valor'] != null 
        ? (widget.imageData['valor'] is int 
            ? (widget.imageData['valor'] as int).toDouble() 
            : widget.imageData['valor'] as double?) ?? 0.0
        : 0.0;
    _esAFavor = widget.imageData['esAFavor'] ?? true;
    // Mostrar el modo de valor por defecto cuando se añade una imagen
    _showValueMode = true;
    _valorController = TextEditingController(
      text: _valorNumerico > 0 ? _numberFormat.format(_valorNumerico) : '',
    );
    
    // Iniciar carga asíncrona de imágenes fragmentadas externas
    _loadExternalFragmentedImageIfNeeded();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _valorController.dispose();
    _debounceTimer?.cancel();
    _descriptionDebounceTimer?.cancel();
    super.dispose();
  }

  void _onValorChanged(String value) {
    try {
      String numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');

      if (numericValue.isNotEmpty) {
        _valorNumerico = double.parse(numericValue);
        String formattedValue = _numberFormat.format(_valorNumerico);

        if (_valorController.text != formattedValue) {
          _valorController.value = TextEditingValue(
            text: formattedValue,
            selection: TextSelection.collapsed(offset: formattedValue.length),
          );
        }
      } else {
        _valorNumerico = 0.0;
      }

      _notifyValueChanged();
    } catch (e) {
      print('Error en _onValorChanged: $e');
    }
  }

  void _notifyValueChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (widget.onValueChanged != null) {
        // Enviar el valor sin signo y dejar que el receptor maneje el signo basado en esAFavor
        widget.onValueChanged!(_valorNumerico, _esAFavor);
      }
    });
  }

  void _notifyDescriptionChanged(String value) {
    _descriptionDebounceTimer?.cancel();
    _descriptionDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (widget.onDescriptionChanged != null) {
        widget.onDescriptionChanged!(value);
      }
    });
  }
  
  Future<void> _loadExternalFragmentedImageIfNeeded() async {
    // Solo cargar si es una imagen fragmentada externa
    if (widget.imageData['tipo'] != 'fragmentada_externa') {
      return;
    }
    
    setState(() {
      _isLoadingExternalImage = true;
    });
    
    try {
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid == null) {
        print('Usuario no autenticado');
        return;
      }
      
      // Usar los parámetros proporcionados o buscar en imageData
       String? imageId = widget.imageId ?? widget.imageData['imageId'] as String?;
       String? groupId = widget.groupId;
       
       // Si no hay imageId o groupId, no se puede cargar
       if (imageId == null || groupId == null) {
         print('No se pudo determinar imageId ($imageId) o groupId ($groupId) para imagen fragmentada externa');
         return;
       }
       
       print('Cargando imagen fragmentada externa: $imageId en grupo: $groupId');
       
       // Recuperar fragmentos desde Firestore
       Map<String, dynamic> reconstructedImage;
       
       // Verificar si es un gasto compartido
       bool isSharedExpense = widget.imageData['isSharedExpense'] == true;
       
       if (isSharedExpense) {
         // Para gastos compartidos, usar el método específico
         reconstructedImage = await FirestoreService().recuperarFragmentosDesdeSharedExpenses(
           groupId: groupId,
           imageId: imageId,
           header: widget.imageData['header'] as String? ?? '',
           totalFragments: widget.imageData['totalFragments'] as int? ?? 0,
         );
       } else {
         // Para gastos normales, usar el método original
         reconstructedImage = await FirestoreService().recuperarFragmentosDesdeDocumentosSeparados(
           userUid: userUid,
           groupId: groupId,
           imageId: imageId,
           header: widget.imageData['header'] as String? ?? '',
           totalFragments: widget.imageData['totalFragments'] as int? ?? 0,
         );
       }
      
      // Convertir List<String> a Map<String, dynamic> para reconstruirImagenBase64
      final List<String> fragmentsList = reconstructedImage['fragments'] as List<String>;
      final Map<String, dynamic> fragmentsMap = {};
      for (int i = 0; i < fragmentsList.length; i++) {
        fragmentsMap['fragment_$i'] = fragmentsList[i];
      }
      
      final Map<String, dynamic> reconstructionData = {
        'fragments': fragmentsMap,
        'totalFragments': reconstructedImage['totalFragments'],
        'header': reconstructedImage['header'],
        'tipo': reconstructedImage['tipo'],
      };
      
      // Reconstruir la imagen
      final result = StorageService.reconstruirImagenBase64(reconstructionData);
      
      if (mounted) {
        setState(() {
          _loadedExternalImage = result;
          _isLoadingExternalImage = false;
        });
      }
    } catch (e) {
      print('Error cargando imagen fragmentada externamente: $e');
      if (mounted) {
        setState(() {
          _isLoadingExternalImage = false;
        });
      }
    }
  }

  void _toggleValueMode() {
    setState(() {
      _showValueMode = !_showValueMode;
      if (!_showValueMode) {
        _valorNumerico = 0.0;
        _valorController.clear();
      }
    });
    if (!_showValueMode) {
      _notifyValueChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    // Obtener imagen correctamente, manejando fragmentadas
    String imagen = '';
    bool showLoadingIndicator = false;
    
    try {
      if (widget.imageData['tipo'] == 'fragmentada_externa') {
        // Imagen fragmentada externa - usar la imagen cargada asincrónicamente
        if (_isLoadingExternalImage) {
          showLoadingIndicator = true;
        } else if (_loadedExternalImage != null) {
          imagen = _loadedExternalImage!;
        }
      } else if (widget.imageData['tipo'] == 'fragmentada' &&
          widget.imageData.containsKey('fragments')) {
        // Imagen fragmentada interna
        imagen = StorageService.obtenerImagenCompleta(widget.imageData);
      } else {
        // Imagen normal
        imagen = widget.imageData['imagen'] ?? '';
      }
    } catch (e) {
      print('Error obteniendo imagen en ExpenseImageWidget: $e');
      imagen = widget.imageData['imagen'] ?? '';
    }
    final String fecha = widget.imageData['fecha'] ?? '';

    // Envolver en RepaintBoundary para optimizar el rendimiento durante el drag
    return RepaintBoundary(
      child: _buildCardContent(context, colorProvider, imagen, fecha, showLoadingIndicator),
    );
  }

  Widget _buildCardContent(BuildContext context, ColorProvider colorProvider, String imagen, String fecha, bool showLoadingIndicator) {

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorProvider.colors.backgroundColor,
          width: 1,
        ),
      ),
      color: colorProvider.colors.backgroundColor,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorProvider.colors.backgroundColor,
          border: Border.all(
            color: colorProvider.colors.backgroundColor,
            width: 0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna de imagen y fecha
            Container(
              width: 100,
              child: Column(
                children: [
                  // Imagen
                  Container(
                    width: 100,
                    height: 80,
                    margin: const EdgeInsets.all(8),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showFullScreenImage(context, imagen),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (widget.imageData['loading'] == true || showLoadingIndicator)
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : RepaintBoundary(
                                    child: ProfileImage(
                                      imageData: showLoadingIndicator ? null : (imagen.isNotEmpty ? {'imagen': imagen} : widget.imageData),
                                      width: 100,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Fecha bajo la imagen
                  if (fecha.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: colorProvider.colors.primaryTextColor,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              _formatDate(fecha),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorProvider.colors.primaryTextColor,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Campo de descripción y valor
            Expanded(
              child: Container(
                // height: 150,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // Campo de descripción
                          Expanded(
                            flex: _showValueMode ? 1 : 3,
                            child: TextField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                hintText: 'Descripción',
                                hintStyle: TextStyle(
                                  color: colorProvider.colors.primaryTextColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color:
                                        colorProvider.colors.primaryTextColor,
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color:
                                        colorProvider.colors.primaryTextColor,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: colorProvider.colors.appBarColor,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: colorProvider.colors.primaryTextColor,
                              ),
                              maxLines: _showValueMode ? 1 : null,
                              expands: !_showValueMode,
                              textAlignVertical: TextAlignVertical.top,
                              onChanged: _notifyDescriptionChanged,
                            ),
                          ),
                          // Controles de valor (solo si está en modo valor)
                          if (_showValueMode) ...[
                            const SizedBox(height: 10),
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: _esAFavor
                                          ? colorProvider.colors.positiveColor
                                          : colorProvider
                                              .colors.primaryTextColor
                                              .withOpacity(0.3),
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _esAFavor = true;
                                      });
                                      _notifyValueChanged();
                                    },
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    constraints: BoxConstraints(),
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: !_esAFavor
                                          ? colorProvider.colors.negativeColor
                                          : colorProvider
                                              .colors.primaryTextColor
                                              .withOpacity(0.3),
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _esAFavor = false;
                                      });
                                      _notifyValueChanged();
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _valorController,
                                      keyboardType: TextInputType.number,
                                      onChanged: _onValorChanged,
                                      decoration: InputDecoration(
                                        labelText: 'Monto',
                                        labelStyle: TextStyle(
                                          color: colorProvider
                                              .colors.primaryTextColor,
                                          // fontSize: 12,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: colorProvider
                                                .colors.appBarColor,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: colorProvider
                                                .colors.appBarColor,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: colorProvider
                                            .colors.primaryTextColor,
                                        // fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // Columna con iconos de control

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icono de arrastre para reordenar
                        ReorderableDragStartListener(
                          index: widget.index ?? 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorProvider.colors.appBarColor
                                  .withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.drag_handle,
                              size: 16,
                              color: colorProvider.colors.appBarColor,
                            ),
                          ),
                        ),
                        // const SizedBox(height: 8),
                        // Icono de opciones para cambiar modo
                        PopupMenuButton<String>(
                          tooltip: '',
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorProvider.colors.appBarColor
                                  .withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.more_vert,
                              size: 16,
                              color: colorProvider.colors.appBarColor,
                            ),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'toggle_mode',
                              child: Row(
                                children: [
                                  Text(
                                    _showValueMode
                                        ? 'Solo descripción'
                                        : 'Descripción y valor',
                                    style: TextStyle(
                                      color:
                                          colorProvider.colors.primaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'toggle_mode') {
                              _toggleValueMode();
                            }
                          },
                          color: colorProvider.colors.backgroundColor,
                        ),
                        // const SizedBox(height: 8),
                        // Botón para eliminar toda la imagen (mapa completo)
                        if (widget.onDelete != null)
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorProvider.colors.negativeColor
                                    .withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete,
                                size: 16,
                                color: colorProvider.colors.negativeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String base64Image) {
    if (base64Image.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: ProfileImage(
                imageData:
                    base64Image, // Usar el parámetro base64Image directamente
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
