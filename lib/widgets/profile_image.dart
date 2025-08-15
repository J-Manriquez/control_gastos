import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:control_gastos/services/storage_service.dart';
import 'package:control_gastos/services/provider_colors.dart';
import 'package:provider/provider.dart';

class ProfileImage extends StatelessWidget {
  final dynamic imageData; // Puede ser String (base64) o Map (fragmentada)
  final double width;
  final double height;
  final BoxFit fit;
  final double? radius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

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
        base64Image = StorageService.obtenerImagenCompleta(imageData as Map<String, dynamic>);
      }
      
      // Si no hay imagen válida, mostrar placeholder
      if (base64Image.isEmpty || !StorageService.isValidDataUrl(base64Image)) {
        return _buildPlaceholder();
      }

      // Extraer la parte Base64 del data URL
      final String base64String = StorageService.extractBase64FromDataUrl(base64Image);
      final Uint8List imageBytes = base64Decode(base64String);

      Widget imageWidget = Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder ?? (context, error, stackTrace) {
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
  final int? index;

  const ExpenseImageWidget({
    Key? key,
    required this.imageData,
    this.onDelete,
    this.onDescriptionChanged,
    this.index,
  }) : super(key: key);

  @override
  State<ExpenseImageWidget> createState() => _ExpenseImageWidgetState();
}

class _ExpenseImageWidgetState extends State<ExpenseImageWidget> {
  late TextEditingController _descriptionController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.imageData['descripcion'] ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    
    // Obtener imagen correctamente, manejando fragmentadas
    String imagen = '';
    try {
      if (widget.imageData['tipo'] == 'fragmentada' && widget.imageData.containsKey('fragments')) {
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
                            child: ProfileImage(
                              imageData: widget.imageData,
                              width: 100,
                              height: 80,
                              fit: BoxFit.cover,
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
            // Campo de descripción que usa todo el alto disponible
            Expanded(
              child: Container(
                height: 140,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Descripción (opcional)',
                          hintStyle: TextStyle(
                            color: colorProvider.colors.primaryTextColor,
                            // fontSize: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: colorProvider.colors.primaryTextColor,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: colorProvider.colors.primaryTextColor,
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
                          // fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorProvider.colors.primaryTextColor,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (value) {
                           // Solo llamar al callback sin setState innecesario
                           if (widget.onDescriptionChanged != null) {
                             widget.onDescriptionChanged!(value);
                           }
                         },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Columna con icono de arrastre y botón de eliminar
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Icono de arrastre para reordenar
                        ReorderableDragStartListener(
                          index: widget.index ?? 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorProvider.colors.appBarColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.drag_handle,
                              size: 16,
                              color: colorProvider.colors.appBarColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Botón para eliminar toda la imagen (mapa completo)
                        if (widget.onDelete != null)
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colorProvider.colors.negativeColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
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
                imageData: base64Image, // Usar el parámetro base64Image directamente
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