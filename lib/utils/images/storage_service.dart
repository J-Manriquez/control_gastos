import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'package:control_gastos/widgets/profile_image.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;



class StorageService {
  // Convertir imagen a Base64
  Future<String> convertirImagenABase64({
    required dynamic imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      // print(
      //   'Iniciando conversión a Base64. Tipo de archivo: ${imageFile.runtimeType}',
      // );

      if (onProgress != null) {
        onProgress(0.1);
      }

      if (kIsWeb) {
        // print('Ejecutando en entorno Web');

        // Verificar el tipo de archivo para web
        if (imageFile is html.File) {
          // print('Procesando html.File en Web');
          try {
            final reader = html.FileReader();
            reader.readAsDataUrl(imageFile);
            await reader.onLoad.first;
            String result = reader.result as String;

            // Eliminar el prefijo de data URL si existe
            if (result.contains(',')) {
              // print('Datos leídos como DataURL. Extrayendo parte Base64...');
              result = result.split(',')[1];
            }

            if (onProgress != null) {
              onProgress(1.0);
            }

            // print('Base64 extraído correctamente. Longitud: ${result.length}');
            
            // Detectar el tipo de imagen basado en los primeros bytes
            String mimeType = 'image/jpeg';
            if (result.startsWith('UklGR')) {
              mimeType = 'image/webp';
            } else if (result.startsWith('iVBOR')) {
              mimeType = 'image/png';
            }
            
            return 'data:$mimeType;base64,$result';
          } catch (e) {
            // print('Error al procesar html.File: $e');
            throw Exception('Error al procesar archivo web: $e');
          }
        } else if (imageFile is XFile) {
          // Manejar XFile en entorno web
          try {
            // print('Procesando XFile en Web. Leyendo bytes...');
            final bytes = await imageFile.readAsBytes();
            // print('Bytes leídos correctamente. Tamaño: ${bytes.length} bytes');
            
            // Comprimir la imagen
            if (onProgress != null) {
              onProgress(0.3);
            }
            
            // print('Iniciando compresión de imagen...');
            final compressedBytes = await comprimirImagen(bytes);
            // print(
            //   'Compresión completada. Tamaño original: ${bytes.length} bytes, Tamaño comprimido: ${compressedBytes.length} bytes',
            // );
            
            if (onProgress != null) {
              onProgress(0.7);
            }
            
            // Convertir a base64
            // print('Convirtiendo bytes a Base64...');
            final base64String = base64Encode(compressedBytes);
            // print(
            //   'Conversión a Base64 completada. Longitud del string: ${base64String.length}',
            // );
            
            if (base64String.length > 30) {
              // print('Muestra de los primeros 30 caracteres: ${base64String.substring(0, 30)}');
            }
            
            if (onProgress != null) {
              onProgress(1.0);
            }
            
            // Detectar el tipo de imagen basado en los primeros bytes
            String mimeType = 'image/jpeg';
            if (base64String.startsWith('UklGR')) {
              mimeType = 'image/webp';
            } else if (base64String.startsWith('iVBOR')) {
              mimeType = 'image/png';
            }
            
            return 'data:$mimeType;base64,$base64String';
          } catch (e) {
            print('Error al procesar XFile en Web: $e');
            throw Exception('Error al procesar XFile en Web: $e');
          }
        } else if (imageFile is Uint8List) {
          try {
            // print('Procesando Uint8List en Web. Tamaño: ${imageFile.length} bytes');
            final base64String = base64Encode(imageFile);
            
            if (onProgress != null) {
              onProgress(1.0);
            }
            
            // print('Conversión a Base64 completada. Longitud: ${base64String.length}');
            
            // Detectar el tipo de imagen basado en los primeros bytes
            String mimeType = 'image/jpeg';
            if (base64String.startsWith('UklGR')) {
              mimeType = 'image/webp';
            } else if (base64String.startsWith('iVBOR')) {
              mimeType = 'image/png';
            }
            
            return 'data:$mimeType;base64,$base64String';
          } catch (e) {
            print('Error al procesar Uint8List: $e');
            throw Exception('Error al procesar bytes en Web: $e');
          }
        } else {
          // print('Formato no soportado para Web: ${imageFile.runtimeType}');
          throw Exception('Formato de archivo no soportado para web: ${imageFile.runtimeType}');
        }
      } else {
        // Código para plataformas móviles/desktop
        // print('Ejecutando en entorno móvil/desktop');

        try {
          // Obtener bytes de la imagen
          Uint8List bytes;

          if (imageFile is File) {
            // print('Procesando File en móvil. Leyendo bytes...');
            bytes = await imageFile.readAsBytes();
          } else if (imageFile is XFile) {
            // print('Procesando XFile en móvil. Leyendo bytes...');
            bytes = await imageFile.readAsBytes();
          } else if (imageFile is Uint8List) {
            // print('Procesando Uint8List en móvil');
            bytes = imageFile;
          } else {
            print('Formato no soportado para móvil: ${imageFile.runtimeType}');
            throw Exception(
              'Formato de archivo no soportado para móvil: ${imageFile.runtimeType}',
            );
          }

          print('Bytes leídos correctamente. Tamaño: ${bytes.length} bytes');

          if (onProgress != null) {
            onProgress(0.3);
          }

          // Comprimir la imagen
          // print('Iniciando compresión de imagen...');
          final compressedBytes = await comprimirImagen(bytes);
          // print(
          //   'Compresión completada. Tamaño original: ${bytes.length} bytes, Tamaño comprimido: ${compressedBytes.length} bytes',
          // );

          if (onProgress != null) {
            onProgress(0.7);
          }

          // Convertir a base64
          // print('Convirtiendo bytes a Base64...');
          final base64String = base64Encode(compressedBytes);
          // print(
          //   'Conversión a Base64 completada. Longitud del string: ${base64String.length}',
          // );
          // print(
          //   'Muestra de los primeros 30 caracteres del Base64: ${base64String.substring(0, Math.min(30, base64String.length))}',
          // );

          // Detectar el tipo de imagen basado en los primeros bytes
          String mimeType = 'image/jpeg';
          if (base64String.startsWith('UklGR')) {
            mimeType = 'image/webp';
          } else if (base64String.startsWith('iVBOR')) {
            mimeType = 'image/png';
          }

          // Crear el formato data URL completo
          final dataUrl = 'data:$mimeType;base64,$base64String';
          // print(
          //   'Data URL generada. Primeros 30 caracteres: ${dataUrl.substring(0, Math.min(30, dataUrl.length))}',
          // );

          if (onProgress != null) {
            onProgress(1.0);
          }

          return dataUrl;
        } catch (e) {
          print('Error en procesamiento móvil: $e');
          throw Exception('Error al procesar imagen en móvil: $e');
        }
      }
    } catch (e) {
      print('Error al convertir imagen a base64: $e');
      if (onProgress != null) {
        onProgress(0);
      }
      throw e; // Propagar el error para manejarlo en el nivel superior
    }
  }

  // Comprimir imagen para reducir tamaño
  Future<Uint8List> comprimirImagen(Uint8List bytes) async {
    // Limitar el tamaño máximo a 300KB para imágenes de perfil
    const maxSizeInBytes = 300 * 1024;

    // print('Iniciando compresión. Tamaño original: ${bytes.length} bytes');

    if (bytes.length <= maxSizeInBytes) {
      // print('La imagen ya es pequeña, no se comprime');
      return bytes; // No comprimir si ya es pequeña
    }

    // Calcular calidad de compresión basada en tamaño actual
    int quality = 80;
    if (bytes.length > 1 * 1024 * 1024) {
      // > 1MB
      quality = 50;
      // print('Imagen grande (>1MB), usando calidad: $quality');
    } else if (bytes.length > 2 * 1024 * 1024) {
      // > 2MB
      quality = 30;
      // print('Imagen muy grande (>2MB), usando calidad: $quality');
    } else {
      print('Imagen mediana, usando calidad: $quality');
    }

    // Comprimir la imagen
    try {
      // print('Aplicando compresión con calidad: $quality');
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      // print('Compresión completada. Tamaño final: ${result.length} bytes');
      return result;
    } catch (e) {
      print('Error durante la compresión: $e');
      // Si falla la compresión, devolver los bytes originales
      return bytes;
    }
  }

  // Convertir Base64 a imagen
  Widget mostrarImagenDesdeBase64(String base64String) {
    return ProfileImage(
      imageData: base64String,
      width: 100,
      height: 100,
      radius: 50,
    );
  }

  // Método para descargar imagen desde URL
  Future<Uint8List?> descargarImagenDesdeUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('Error al descargar imagen: $e');
      return null;
    }
  }

  /// Valida si una cadena es un data URL válido
  static bool isValidDataUrl(String dataUrl) {
    return dataUrl.startsWith('data:image/') && dataUrl.contains('base64,');
  }

  /// Fragmenta una imagen base64 en múltiples partes para evitar el límite de Firestore
  /// Retorna un mapa con los fragmentos y metadatos
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
  /// Retorna un mapa optimizado que evita el límite de 1MB
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
    return (imageData['tipo'] == 'fragmentada' || imageData['tipo'] == 'fragmentada_externa') && 
           imageData.containsKey('totalFragments');
  }

  /// Obtiene una imagen desde datos fragmentados o normales
  static String obtenerImagenCompleta(Map<String, dynamic> imageData) {
    if (esImagenFragmentada(imageData) || imageData['tipo'] == 'fragmentada_externa') {
      return reconstruirImagenBase64(imageData);
    } else {
      // Imagen normal (retrocompatibilidad)
      return imageData['imagen'] ?? '';
    }
  }
}