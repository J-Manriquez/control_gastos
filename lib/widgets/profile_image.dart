import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:control_gastos/services/storage_service.dart';

class ProfileImage extends StatelessWidget {
  final String base64Image;
  final double width;
  final double height;
  final BoxFit fit;
  final double? radius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ProfileImage({
    Key? key,
    required this.base64Image,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si no hay imagen, mostrar placeholder
    if (base64Image.isEmpty || !StorageService.isValidDataUrl(base64Image)) {
      return _buildPlaceholder();
    }

    try {
      // Extraer la parte Base64 del data URL
      final String base64String = StorageService.extractBase64FromDataUrl(base64Image);
      final Uint8List imageBytes = base64Decode(base64String);

      Widget imageWidget = Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
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

  const ExpenseImageWidget({
    Key? key,
    required this.imageData,
    this.onDelete,
    this.onDescriptionChanged,
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
    final String imagen = widget.imageData['imagen'] ?? '';
    final String fecha = widget.imageData['fecha'] ?? '';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ProfileImage(
                      base64Image: imagen,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Botón de eliminar
                  if (widget.onDelete != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Información y descripción editable
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campo de descripción editable
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              hintText: 'Descripción (opcional)',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            onChanged: (value) {
                               setState(() {}); // Actualizar estado para mostrar/ocultar botón de limpiar
                               if (widget.onDescriptionChanged != null) {
                                 widget.onDescriptionChanged!(value);
                               }
                             },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Botón para limpiar descripción
                        if (_descriptionController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _descriptionController.clear();
                              });
                              if (widget.onDescriptionChanged != null) {
                                widget.onDescriptionChanged!('');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Fecha
                    if (fecha.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(fecha),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
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

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}