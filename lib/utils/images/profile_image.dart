import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProfileImage extends StatefulWidget {
  final String base64Image;
  final double width;
  final double height;
  final BoxFit fit;
  final double radius;

  const ProfileImage({
    Key? key,
    required this.base64Image,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.cover,
    this.radius = 50,
  }) : super(key: key);

  @override
  State<ProfileImage> createState() => _ProfileImageState();
}

class _ProfileImageState extends State<ProfileImage> {
  bool _isLoading = true;
  bool _hasError = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  @override
  void didUpdateWidget(ProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Image != widget.base64Image) {
      _processImage();
    }
  }

  Future<void> _processImage() async {
    if (widget.base64Image.isEmpty || widget.base64Image.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      // Verificar si es una URL de blob codificada en base64
      String cleanBase64 = widget.base64Image.trim();
      
      // Validar que la cadena no esté vacía después del trim
      if (cleanBase64.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
      }
      
      // Si contiene comas (como en data:image/jpeg;base64,), tomar solo la parte después de la coma
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      
      // Eliminar espacios en blanco o saltos de línea que puedan estar presentes
      cleanBase64 = cleanBase64.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
      
      // Validar que la cadena tenga una longitud mínima válida para base64
      if (cleanBase64.length < 4) {
        throw Exception('Cadena Base64 demasiado corta');
      }
      
      // Validar que la longitud sea múltiplo de 4 (requerimiento de base64)
      while (cleanBase64.length % 4 != 0) {
        cleanBase64 += '=';
      }
      
      // Decodificar la cadena base64
      try {
        // Intentamos decodificar directamente como imagen
        final bytes = base64Decode(cleanBase64);
        
        // Verificar que los bytes sean suficientes para una imagen
        if (bytes.length > 100) {
          if (mounted) {
            setState(() {
              _imageBytes = bytes;
              _isLoading = false;
            });
          }
          return;
        } else {
          throw Exception('Datos de imagen insuficientes: ${bytes.length} bytes');
        }
      } catch (e) {
        print('Error al decodificar Base64: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error general al procesar imagen: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPlaceholder() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: _hasError ? Colors.red[100] : Colors.grey[300],
      child: Icon(
        _hasError ? Icons.error : Icons.person,
        size: widget.radius,
        color: _hasError ? Colors.red : Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const CircularProgressIndicator(),
      );
    }

    if (_hasError || widget.base64Image.isEmpty || _imageBytes == null) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          print('Error al mostrar imagen: $error');
          return _buildPlaceholder();
        },
      ),
    );
  }
}