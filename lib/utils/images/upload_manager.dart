import 'package:flutter/foundation.dart';

class UploadItem {
  final String tipo;
  final String userId;
  final String nombreArchivo;
  double progreso;
  bool completado;

  UploadItem({
    required this.tipo,
    required this.userId,
    required this.nombreArchivo,
    this.progreso = 0.0,
    this.completado = false,
  });
}

class UploadManager with ChangeNotifier {
  // Singleton
  static final UploadManager _instance = UploadManager._internal();
  static UploadManager get instance => _instance;
  
  UploadManager._internal();
  
  // Lista de elementos en proceso de subida
  final List<UploadItem> _uploads = [];
  
  // Getters
  List<UploadItem> get uploads => List.unmodifiable(_uploads);
  List<UploadItem> get uploadsEnProgreso => _uploads.where((item) => !item.completado).toList();
  List<UploadItem> get uploadsCompletados => _uploads.where((item) => item.completado).toList();
  
  // Iniciar una nueva subida
  void iniciarSubida({
    required String tipo,
    required String userId,
    required String nombreArchivo,
  }) {
    final newUpload = UploadItem(
      tipo: tipo,
      userId: userId,
      nombreArchivo: nombreArchivo,
    );
    
    _uploads.add(newUpload);
    notifyListeners();
  }
  
  // Actualizar el progreso de una subida
  void actualizarProgreso({
    required String tipo,
    required String userId,
    required double progreso,
  }) {
    final index = _uploads.indexWhere(
      (item) => item.tipo == tipo && item.userId == userId && !item.completado
    );
    
    if (index != -1) {
      _uploads[index].progreso = progreso;
      notifyListeners();
    }
  }
  
  // Marcar una subida como completada
  void completarSubida({
    required String tipo,
    required String userId,
  }) {
    final index = _uploads.indexWhere(
      (item) => item.tipo == tipo && item.userId == userId && !item.completado
    );
    
    if (index != -1) {
      _uploads[index].completado = true;
      _uploads[index].progreso = 1.0;
      notifyListeners();
    }
  }
  
  // Eliminar todas las subidas completadas
  void limpiarCompletados() {
    _uploads.removeWhere((item) => item.completado);
    notifyListeners();
  }
  
  // Eliminar una subida específica
  void eliminarSubida({
    required String tipo,
    required String userId,
  }) {
    _uploads.removeWhere(
      (item) => item.tipo == tipo && item.userId == userId
    );
    notifyListeners();
  }
}