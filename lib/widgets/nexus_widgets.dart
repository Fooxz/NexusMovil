// lib/widgets/nexus_widgets.dart
//
// Piezas visuales pequeñas que se repiten en varias pantallas:
// chips/etiquetas, títulos de sección y cajas "placeholder" que
// simulan imágenes de producto (no hay assets reales todavía).

import 'package:flutter/material.dart';
import '../theme/nexus_theme.dart';

/// Etiqueta pequeña con borde de color (ej: "NVIDIA", "EN STOCK", "Compatible").
class NexusTag extends StatelessWidget {
  const NexusTag(
    this.label, {
    super.key,
    this.color = NexusColors.cyan,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: filled ? const Color(0xFF04211F) : color,
        ),
      ),
    );
  }
}

/// Punto de estado + texto, ej: "• ESTABLE" / "• CRÍTICO".
class NexusStatusDot extends StatelessWidget {
  const NexusStatusDot(this.label, {super.key, this.color = NexusColors.cyan});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Título de sección con líneas a los lados: "[ EXPLORAR CATEGORÍAS ]".
class NexusBracketTitle extends StatelessWidget {
  const NexusBracketTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: NexusColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('[ $label ]', style: NexusText.sectionLabel),
        ),
        const Expanded(child: Divider(color: NexusColors.border, height: 1)),
      ],
    );
  }
}

/// Título de sección simple con una línea debajo, ej: "ESPECIFICACIONES COMPLETAS".
class NexusUnderlineTitle extends StatelessWidget {
  const NexusUnderlineTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: NexusText.sectionLabel),
        const SizedBox(height: 8),
        const Divider(color: NexusColors.border, height: 1),
      ],
    );
  }
}

/// Caja con degradado + icono, usada como placeholder de imagen de producto
/// mientras no hay fotos reales conectadas al catálogo.
class NexusPlaceholderBox extends StatelessWidget {
  const NexusPlaceholderBox({
    super.key,
    required this.icon,
    this.gradientColors = const [NexusColors.card, NexusColors.bgAlt],
    this.iconColor = NexusColors.text,
    this.height = 70,
    this.borderRadius = 10,
    this.iconSize = 28,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final Color iconColor;
  final double height;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Icon(icon, size: iconSize, color: iconColor.withValues(alpha: 0.85)),
    );
  }
}

/// Contenedor tipo "card" estándar (fondo, borde y radio compartidos).
class NexusCard extends StatelessWidget {
  const NexusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = NexusColors.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

/// Fila etiqueta/valor usada en "Especificaciones completas" y "Resumen".
class NexusSpecRow extends StatelessWidget {
  const NexusSpecRow(
    this.label,
    this.value, {
    super.key,
    this.valueColor = NexusColors.text,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón primario cian de ancho completo, reutilizado en varias pantallas.
class NexusPrimaryButton extends StatelessWidget {
  const NexusPrimaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: NexusColors.cyan,
          foregroundColor: const Color(0xFF04211F),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña sobre un campo de formulario, ej: "EMAIL".
class NexusFieldLabel extends StatelessWidget {
  const NexusFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: NexusColors.textDim,
        ),
      ),
    );
  }
}

/// Campo de texto con el estilo oscuro estándar de NEXUS (login, registro, búsqueda).
class NexusTextField extends StatelessWidget {
  const NexusTextField({
    super.key,
    required this.hint,
    this.obscure = false,
    this.prefixIcon,
  });

  final String hint;
  final bool obscure;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      style: const TextStyle(fontSize: 13, color: NexusColors.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: NexusColors.textFaint),
        hintStyle: const TextStyle(fontSize: 12.5, color: NexusColors.textFaint),
        filled: true,
        fillColor: NexusColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NexusColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NexusColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NexusColors.cyan),
        ),
      ),
    );
  }
}

/// Botón secundario con borde, usado para acciones destructivas o alternas.
class NexusOutlineButton extends StatelessWidget {
  const NexusOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = NexusColors.text,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed ?? () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
