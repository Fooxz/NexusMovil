// lib/theme/nexus_theme.dart
//
// Paleta y estilos compartidos por toda la app NEXUS.
// Centralizar esto aquí evita repetir colores "mágicos" en cada pantalla.

import 'package:flutter/material.dart';

class NexusColors {
  NexusColors._();

  static const bg = Color(0xFF0B0D10);
  static const bgAlt = Color(0xFF12151A);
  static const card = Color(0xFF161A20);
  static const cardAlt = Color(0xFF1B2027);
  static const border = Color(0xFF232830);

  static const cyan = Color(0xFF3EE6E0);
  static const cyanDim = Color(0xFF2BB8B3);
  static const pink = Color(0xFFFF4D6D);
  static const green = Color(0xFF3DDC84);

  static const text = Color(0xFFF2F4F6);
  static const textDim = Color(0xFF9AA4AE);
  static const textFaint = Color(0xFF5C6570);
}

class NexusText {
  NexusText._();

  /// Título grande tipo display (encabezados de pantalla).
  static const display = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.05,
    color: Colors.white,
  );

  static const sectionLabel = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.4,
    color: NexusColors.textDim,
  );

  static const body = TextStyle(
    fontSize: 11.5,
    height: 1.5,
    color: NexusColors.textDim,
  );
}

/// Tema Material compartido por el MaterialApp.
ThemeData buildNexusTheme() {
  return ThemeData(
    scaffoldBackgroundColor: NexusColors.bg,
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    colorScheme: const ColorScheme.dark(
      primary: NexusColors.cyan,
      secondary: NexusColors.pink,
      surface: NexusColors.bg,
    ),
    dividerColor: NexusColors.border,
  );
}
