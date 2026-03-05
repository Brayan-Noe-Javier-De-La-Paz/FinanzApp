import 'package:flutter/material.dart';

class AppTheme {
  // --- PALETA DE COLORES (Definida por ti) ---
  
  // Colores Base
  static const Color naranjaCTA = Color(0xFFFD5F00); // Tu Acento principal
  static const Color verdeFinanciero = Color(0xFF2ECC71); // Para ganancias/éxito
  
  // Modo Claro
  static const Color lightFondo = Color(0xFFF4F7F6); // Gris Nube
  static const Color lightSuperficie = Color(0xFFFFFFFF); // Blanco
  static const Color lightTexto = Color(0xFF092032); // Azul Profundo
  
  // Modo Oscuro
  static const Color darkFondo = Color(0xFF05101A); // Azul Ébano
  static const Color darkSuperficie = Color(0xFF092032); // Tu Azul Original
  static const Color darkTexto = Color(0xFFECF0F1); // Gris Platino

  // --- TEMA CLARO (Light Mode) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightFondo,
      primaryColor: naranjaCTA,
      
      // Configuración de textos
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: lightTexto), // Texto normal
        headlineMedium: TextStyle(color: lightTexto, fontWeight: FontWeight.bold), // Títulos
      ),

      // Configuración de Tarjetas
      cardTheme: const CardThemeData(
        color: lightSuperficie,
        elevation: 2,
        shadowColor: Colors.black12,
      ),

      // Configuración de Inputs (Cajas de texto)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSuperficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),

      // Configuración de Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: naranjaCTA,
          foregroundColor: Colors.white, // Texto del botón
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // --- TEMA OSCURO (Dark Mode) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkFondo,
      primaryColor: naranjaCTA,
      
      // Configuración de textos
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: darkTexto),
        headlineMedium: TextStyle(color: darkTexto, fontWeight: FontWeight.bold),
      ),

      // Configuración de Tarjetas
      //aqui empieza el error 
      cardTheme: const CardThemeData(
        color: darkSuperficie, // Tu azul original
        elevation: 0,
      ),
      //termina aqui 
      // Configuración de Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSuperficie,
        hintStyle: TextStyle(color: darkTexto.withOpacity(0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),

      // Botones (Iguales en ambos modos por consistencia de marca)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: naranjaCTA,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}