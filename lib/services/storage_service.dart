import 'dart:convert';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class StorageService {
  /// Convierte una imagen XFile a Base64 con data URL
  /// Comprime automáticamente si es necesario
  /// Retorna: 'data:image/jpeg;base64,/9j/4AAQ...'
  Future<String> convertirImagenABase64({
    required XFile imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      // Reportar progreso inicial
      onProgress?.call(0.1);
      
      // Leer bytes de la imagen
      final Uint8List imageBytes = await imageFile.readAsBytes();
      onProgress?.call(0.3);
      
      // Comprimir imagen si es necesaria
      final Uint8List compressedBytes = await _comprimirImagen(imageBytes);
      onProgress?.call(0.7);
      
      // Detectar tipo MIME
      final String mimeType = _detectMimeType(imageFile.name);
      
      // Convertir a Base64
      final String base64String = base64Encode(compressedBytes);
      onProgress?.call(0.9);
      
      // Crear data URL
      final String dataUrl = 'data:$mimeType;base64,$base64String';
      onProgress?.call(1.0);
      
      return dataUrl;
    } catch (e) {
      throw Exception('Error al convertir imagen a Base64: $e');
    }
  }
  
  /// Comprime imágenes grandes manteniendo calidad
  Future<Uint8List> _comprimirImagen(Uint8List imageBytes) async {
    try {
      // Decodificar imagen
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }
      
      // Determinar si necesita compresión
      final int originalSize = imageBytes.length;
      const int maxSize = 1024 * 1024; // 1MB
      
      if (originalSize <= maxSize) {
        return imageBytes; // No necesita compresión
      }
      
      // Calcular nuevo tamaño manteniendo proporción
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (image.width > 1920 || image.height > 1920) {
        final double ratio = image.width / image.height;
        if (image.width > image.height) {
          newWidth = 1920;
          newHeight = (1920 / ratio).round();
        } else {
          newHeight = 1920;
          newWidth = (1920 * ratio).round();
        }
      }
      
      // Redimensionar imagen
      final img.Image resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
      
      // Determinar calidad basada en el tamaño
      int quality = 85;
      if (originalSize > 2 * 1024 * 1024) quality = 70; // >2MB
      if (originalSize > 5 * 1024 * 1024) quality = 60; // >5MB
      
      // Codificar como JPEG con compresión
      final List<int> compressedBytes = img.encodeJpg(
        resizedImage,
        quality: quality,
      );
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      throw Exception('Error al comprimir imagen: $e');
    }
  }
  
  /// Detecta el tipo MIME basado en la extensión del archivo
  String _detectMimeType(String fileName) {
    final String extension = fileName.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Por defecto
    }
  }
  
  /// Extrae solo la parte Base64 de un data URL para usar con Image.memory
  static String extractBase64FromDataUrl(String dataUrl) {
    if (dataUrl.contains(',')) {
      return dataUrl.split(',').last;
    }
    return dataUrl;
  }
  
  /// Valida si una cadena es un data URL válido
  static bool isValidDataUrl(String dataUrl) {
    return dataUrl.startsWith('data:image/') && dataUrl.contains('base64,');
  }

  /// Fragmenta una imagen base64 en múltiples partes para evitar límites de Firestore
  static Map<String, dynamic> fragmentarImagenBase64(String base64Image, {int maxFragmentSize = 800000}) {
    try {
      // Extraer el header del data URL (data:image/jpeg;base64,)
      String header = '';
      String base64Data = base64Image;
      
      if (base64Image.contains(',')) {
        final parts = base64Image.split(',');
        header = parts[0] + ',';
        base64Data = parts[1];
      }

      // Calcular número de fragmentos necesarios
      final int totalLength = base64Data.length;
      final int numFragments = (totalLength / maxFragmentSize).ceil();
      
      Map<String, dynamic> fragmentedImage = {
        'header': header,
        'totalFragments': numFragments,
        'totalLength': totalLength,
        'fragments': <String, String>{},
      };

      // Dividir en fragmentos
      for (int i = 0; i < numFragments; i++) {
        final int start = i * maxFragmentSize;
        final int end = Math.min(start + maxFragmentSize, totalLength);
        final String fragment = base64Data.substring(start, end);
        fragmentedImage['fragments']['fragment_$i'] = fragment;
      }

      print('Imagen fragmentada en $numFragments partes (tamaño original: ${totalLength} caracteres)');
      return fragmentedImage;
      
    } catch (e) {
      print('Error al fragmentar imagen: $e');
      rethrow;
    }
  }

  /// Reconstruye una imagen base64 desde sus fragmentos
  /// Retorna el data URL completo
  static String reconstruirImagenBase64(Map<String, dynamic> fragmentedImage) {
    try {
      final String header = fragmentedImage['header'] ?? '';
      final int totalFragments = fragmentedImage['totalFragments'] ?? 0;
      final Map<String, dynamic> fragments = fragmentedImage['fragments'] ?? {};
      
      // Reconstruir la imagen ordenando los fragmentos
      StringBuffer reconstructed = StringBuffer();
      
      for (int i = 0; i < totalFragments; i++) {
        final String fragmentKey = 'fragment_$i';
        if (fragments.containsKey(fragmentKey)) {
          reconstructed.write(fragments[fragmentKey]);
        } else {
          throw Exception('Fragmento faltante: $fragmentKey');
        }
      }
      
      final String completeImage = header + reconstructed.toString();
      // print('Imagen reconstruida desde $totalFragments fragmentos');
      return completeImage;
      
    } catch (e) {
      print('Error al reconstruir imagen: $e');
      rethrow;
    }
  }

  /// Convierte una imagen a formato fragmentado para Firestore
  Future<Map<String, dynamic>> procesarImagenFragmentada({
    required XFile imageFile,
    String descripcion = '',
    Function(double)? onProgress,
  }) async {
    try {
      if (onProgress != null) onProgress(0.1);
      
      // Convertir imagen a base64
      final String base64Image = await convertirImagenABase64(
        imageFile: imageFile,
        onProgress: (progress) {
          if (onProgress != null) onProgress(0.1 + (progress * 0.7));
        },
      );
      
      if (onProgress != null) onProgress(0.8);
      
      // Fragmentar la imagen
      final Map<String, dynamic> fragmentedImage = fragmentarImagenBase64(base64Image);
      
      if (onProgress != null) onProgress(0.9);
      
      // Agregar metadatos
      fragmentedImage['descripcion'] = descripcion;
      fragmentedImage['fecha'] = DateTime.now().toIso8601String();
      fragmentedImage['tipo'] = 'fragmentada';
      
      if (onProgress != null) onProgress(1.0);
      
      return fragmentedImage;
      
    } catch (e) {
      print('Error al procesar imagen fragmentada: $e');
      rethrow;
    }
  }

  /// Valida si una imagen es fragmentada
  static bool esImagenFragmentada(Map<String, dynamic> imageData) {
    return (imageData['tipo'] == 'fragmentada' && 
           imageData.containsKey('fragments') && 
           imageData.containsKey('totalFragments')) ||
           imageData['tipo'] == 'fragmentada_externa';
  }

  /// Obtiene una imagen desde datos fragmentados o normales
  static String obtenerImagenCompleta(Map<String, dynamic> imageData) {
    if (esImagenFragmentada(imageData)) {
      return reconstruirImagenBase64(imageData);
    } else {
      // Imagen normal (retrocompatibilidad)
      return imageData['imagen'] ?? '';
    }
  }
}