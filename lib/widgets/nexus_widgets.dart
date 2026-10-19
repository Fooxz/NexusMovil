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
          color: filled ? NexusColors.onCyan : color,
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

class NexusDiscountBadge extends StatelessWidget {
  const NexusDiscountBadge({super.key, required this.label, this.fontSize = 9});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: NexusColors.pink,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
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
        // Flexible: en pantallas angostas el título pasa a dos líneas en vez
        // de desbordar la fila.
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '[ $label ]',
              style: NexusText.sectionLabel,
              textAlign: TextAlign.center,
            ),
          ),
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
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor.withValues(alpha: 0.85),
      ),
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
  const NexusPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = NexusColors.cyan,
    this.foregroundColor = NexusColors.onCyan,
    this.icon,
    this.fullWidth = true,
    this.fontSize = 13,
    this.padding,
    this.borderRadius,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color foregroundColor;
  final IconData? icon;
  final bool fullWidth;
  final double fontSize;
  final EdgeInsets? padding;
  final double? borderRadius;

  /// Muestra un indicador y bloquea el botón (por ejemplo, mientras se envía
  /// un formulario), para evitar envíos repetidos.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: color.withValues(alpha: 0.6),
      disabledForegroundColor: foregroundColor,
      padding:
          padding ??
          (fullWidth
              ? const EdgeInsets.symmetric(vertical: 15)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          borderRadius ?? (fullWidth ? 8 : 7),
        ),
      ),
      elevation: 0,
    );
    final Widget labelWidget = loading
        ? SizedBox.square(
            dimension: fontSize + 3,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          )
        : Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          );
    // TODO: Pass null when disabled buttons should become truly disabled.
    final VoidCallback? pressed = loading ? null : (onPressed ?? () {});
    final button = icon == null || loading
        ? ElevatedButton(
            onPressed: pressed,
            style: buttonStyle,
            child: labelWidget,
          )
        : ElevatedButton.icon(
            onPressed: pressed,
            icon: Icon(icon, size: 15),
            label: labelWidget,
            style: buttonStyle,
          );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
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
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.autofillHints,
  });

  final String hint;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // The caller owns a supplied controller; TextFormField manages its internal one.
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      autofillHints: autofillHints,
      style: const TextStyle(fontSize: 13, color: NexusColors.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: NexusColors.textFaint),
        hintStyle: const TextStyle(
          fontSize: 12.5,
          color: NexusColors.textFaint,
        ),
        filled: true,
        fillColor: NexusColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NexusColors.pink),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NexusColors.pink),
        ),
        errorStyle: const TextStyle(fontSize: 10, color: NexusColors.pink),
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
    this.borderColor,
    this.compact = false,
    this.fullWidth = true,
    this.padding,
    this.fontSize,
    this.borderRadius,
    this.bold = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color? borderColor;
  final bool compact;
  final bool fullWidth;
  final EdgeInsets? padding;
  final double? fontSize;
  final double? borderRadius;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      // TODO: Pass null when disabled buttons should become truly disabled.
      onPressed: onPressed ?? () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: borderColor ?? color.withValues(alpha: 0.6)),
        padding: padding ?? EdgeInsets.symmetric(vertical: compact ? 9 : 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            borderRadius ?? (compact ? 6 : 8),
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize ?? (compact ? 10.5 : 12.5),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
