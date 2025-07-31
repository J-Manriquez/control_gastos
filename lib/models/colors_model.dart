import 'package:flutter/material.dart';

class AppColorsModel {
  Color backgroundColor;
  Color appBarColor;
  Color primaryTextColor;
  Color secondaryTextColor;
  Color positiveColor;
  Color negativeColor;

  // Constructor con valores por defecto (tema claro)
  AppColorsModel({
    this.backgroundColor = const Color.fromARGB(255, 255, 255, 255), // Blanco smoke fondo
    this.appBarColor = const Color(0xFF3B5998),     // Azul oscuro pastel fondo appbar, botones aceptar y resalte de iconos
    this.primaryTextColor = Colors.black,            // Negro texto cuando el fondo es blanco
    this.secondaryTextColor = const Color(0xFFF5F5F5), // Blanco smoke texto para apbar o iconos con fondo azul
    this.positiveColor = const Color(0xFF8BC34A),    // Verde pastel saldos a favor, iconos suma
    this.negativeColor = const Color(0xFFF44336),    // Rojo pastel  iconos eliminar, resta, botones cancelar, saldos negativos y cerrar sesion
  });

  // Constructor para tema oscuro
  AppColorsModel.dark({
    this.backgroundColor =  Colors.black,  // Fondo oscuro
    this.appBarColor = const Color(0xFF3B5998),     // Mantener el azul para consistencia
    this.primaryTextColor = const Color(0xFFE0E0E0), // Texto blanco opaco
    this.secondaryTextColor = const Color(0xFFF5F5F5), // Blanco smoke texto para apbar o iconos con fondo azul
    this.positiveColor = const Color(0xFF8BC34A),    // Verde pastel saldos a favor, iconos suma
    this.negativeColor = const Color(0xFFF44336),    // Rojo pastel  iconos eliminar, resta, botones cancelar, saldos negativos y cerrar sesion
  });


}
