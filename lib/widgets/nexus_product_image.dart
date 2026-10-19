import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';
import 'nexus_widgets.dart';

/// Imagen de producto con caché en memoria y disco (R8). Sin URL, mientras
/// carga o si falla, muestra el icono de la categoría sobre su degradado.
class NexusProductImage extends StatelessWidget {
  const NexusProductImage({
    super.key,
    required this.imageUrl,
    required this.icon,
    required this.gradientColors,
    required this.height,
    this.iconColor = NexusColors.text,
    this.iconSize = 28,
    this.borderRadius = 0,
  });

  final String? imageUrl;
  final IconData icon;
  final List<Color> gradientColors;
  final double height;
  final Color iconColor;
  final double iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = NexusPlaceholderBox(
      icon: icon,
      iconColor: iconColor,
      iconSize: iconSize,
      gradientColors: gradientColors,
      height: height,
      borderRadius: borderRadius,
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return placeholder;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Decodifica al tamaño mostrado, no a la resolución original (R8).
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth * pixelRatio).round()
            : null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CachedNetworkImage(
            imageUrl: url,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            memCacheWidth: cacheWidth,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          ),
        );
      },
    );
  }
}
