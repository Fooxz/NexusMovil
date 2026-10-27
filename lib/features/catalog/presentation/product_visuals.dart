import 'package:flutter/material.dart';

import '../domain/product.dart';
import '../../../theme/nexus_theme.dart';

class ProductVisuals {
  const ProductVisuals({
    required this.icon,
    required this.gradientColors,
    required this.shortCategoryLabel,
    required this.categoryLabel,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final String shortCategoryLabel;
  final String categoryLabel;

  static const _generic = ProductVisuals(
    icon: Icons.devices_other,
    gradientColors: [Color(0xFF151B20), Color(0xFF24343C)],
    shortCategoryLabel: 'PRODUCTO',
    categoryLabel: 'PRODUCTOS',
  );

  /// Etiqueta corta del tipo de pieza para los chips de filtro.
  static String chipLabel(ProductCategory category) => switch (category) {
    ProductCategory.cpu => 'CPU',
    ProductCategory.gpu => 'GPU',
    ProductCategory.ram => 'RAM',
    ProductCategory.motherboard => 'Motherboard',
    ProductCategory.storage => 'Almacenamiento',
    ProductCategory.psu => 'Fuente',
    ProductCategory.pcCase => 'Gabinete',
    ProductCategory.cooling => 'Refrigeración',
  };

  /// Nombre en singular de una pieza, como las ranuras del PC Builder.
  static String partLabel(ProductCategory category) => switch (category) {
    ProductCategory.cpu => 'Procesador',
    ProductCategory.gpu => 'Tarjeta gráfica',
    ProductCategory.ram => 'Memoria RAM',
    ProductCategory.motherboard => 'Placa madre',
    ProductCategory.storage => 'Almacenamiento',
    ProductCategory.psu => 'Fuente de poder',
    ProductCategory.pcCase => 'Gabinete',
    ProductCategory.cooling => 'Refrigeración',
  };

  static ProductVisuals forCategory(ProductCategory? category) =>
      switch (category) {
        ProductCategory.cpu => const ProductVisuals(
          icon: Icons.memory,
          gradientColors: [Color(0xFF101010), Color(0xFF1B1B1B)],
          shortCategoryLabel: 'CPU',
          categoryLabel: 'PROCESADORES',
        ),
        ProductCategory.gpu => const ProductVisuals(
          icon: Icons.videogame_asset,
          gradientColors: [Color(0xFF1A1A1A), Color(0xFF8A1C1C)],
          shortCategoryLabel: 'GPU',
          categoryLabel: 'TARJETAS GRÁFICAS',
        ),
        ProductCategory.ram => const ProductVisuals(
          icon: Icons.memory,
          gradientColors: [Color(0xFF14101C), Color(0xFF351A50)],
          shortCategoryLabel: 'RAM',
          categoryLabel: 'MEMORIA RAM',
        ),
        ProductCategory.motherboard => const ProductVisuals(
          icon: Icons.developer_board,
          gradientColors: [Color(0xFF14101C), Color(0xFF241735)],
          shortCategoryLabel: 'MB',
          categoryLabel: 'TARJETAS MADRE',
        ),
        ProductCategory.storage => const ProductVisuals(
          icon: Icons.storage,
          gradientColors: [Color(0xFF102022), Color(0xFF174044)],
          shortCategoryLabel: 'STORAGE',
          categoryLabel: 'ALMACENAMIENTO',
        ),
        ProductCategory.psu => const ProductVisuals(
          icon: Icons.bolt,
          gradientColors: [Color(0xFF262016), Color(0xFF55401D)],
          shortCategoryLabel: 'PSU',
          categoryLabel: 'FUENTES DE PODER',
        ),
        ProductCategory.pcCase => const ProductVisuals(
          icon: Icons.computer,
          gradientColors: [Color(0xFF101820), Color(0xFF213446)],
          shortCategoryLabel: 'CASE',
          categoryLabel: 'GABINETES',
        ),
        ProductCategory.cooling => const ProductVisuals(
          icon: Icons.ac_unit,
          gradientColors: [Color(0xFF0F1B2E), Color(0xFF14314A)],
          shortCategoryLabel: 'LIQUID AIO',
          categoryLabel: 'REFRIGERACIÓN',
        ),
        null => _generic,
      };

  static String stockLabel(StockLevel stockLevel) => stockLevel.tagLabel;

  static Color stockColor(StockLevel stockLevel) => switch (stockLevel) {
    StockLevel.stable => NexusColors.cyan,
    StockLevel.critical => NexusColors.pink,
    StockLevel.outOfStock => NexusColors.textFaint,
  };
}
