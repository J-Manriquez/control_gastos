class Validators {
  static bool isValidShortId(String shortId) {
    // Verificar longitud
    if (shortId.length != 5) return false;
    
    // Verificar caracteres permitidos (letras y números)
    final validChars = RegExp(r'^[A-Za-z0-9]+$');
    return validChars.hasMatch(shortId);
  }
}