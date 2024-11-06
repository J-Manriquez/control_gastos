String FormatNumberFrench(double number) {
  // Convertir a entero ya que estamos usando .round()
  String numStr = number.round().toString();
  String result = '';
  int count = 0;
  
  // Recorrer los dígitos de derecha a izquierda
  for (int i = numStr.length - 1; i >= 0; i--) {
    if (count != 0 && count % 3 == 0) {
      result = ' $result'; // Agregar espacio como separador
    }
    result = numStr[i] + result;
    count++;
  }
  
  return result;
}