import 'package:flutter/material.dart';

import '../core/utils/format_price.dart';
import '../theme/nexus_theme.dart';
import 'nexus_product_image.dart';
import 'nexus_widgets.dart';

class NexusProductCard extends StatelessWidget {
  const NexusProductCard({
    super.key,
    required this.icon,
    required this.gradientColors,
    required this.name,
    required this.priceCents,
    this.iconColor = NexusColors.text,
    this.imageHeight = 84,
    this.oldPriceCents,
    this.discountLabel,
    this.brand,
    this.status,
    this.statusColor = NexusColors.cyan,
    this.specs,
    this.tags,
    this.actions,
    this.onTap,
    this.priceFontSize = 12,
    this.imageUrl,
  });

  /// Miniatura del producto; sin ella se muestra [icon] sobre [gradientColors].
  final String? imageUrl;
  final IconData icon;
  final List<Color> gradientColors;
  final Color iconColor;
  final double imageHeight;
  final String name;
  final int priceCents;
  final int? oldPriceCents;
  final String? discountLabel;
  final String? brand;
  final String? status;
  final Color statusColor;
  final String? specs;
  final List<String>? tags;
  final Widget? actions;
  final VoidCallback? onTap;
  final double priceFontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: NexusColors.card,
          border: Border.all(color: NexusColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                NexusProductImage(
                  imageUrl: imageUrl,
                  icon: icon,
                  iconColor: iconColor,
                  gradientColors: gradientColors,
                  height: imageHeight,
                ),
                if (discountLabel != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: NexusDiscountBadge(
                      label: discountLabel!,
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brand != null || status != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (brand != null)
                          Expanded(
                            child: Text(
                              brand!,
                              style: const TextStyle(
                                fontSize: 8,
                                color: NexusColors.textFaint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (status != null)
                          NexusStatusDot(status!, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                  if (tags != null) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [for (final tag in tags!) NexusTag(tag)],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tags == null ? 11 : 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (specs != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      specs!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8,
                        color: NexusColors.textDim,
                      ),
                    ),
                  ],
                  if (oldPriceCents != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatPrice(oldPriceCents!),
                          style: const TextStyle(
                            fontSize: 9,
                            color: NexusColors.textFaint,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: _priceText()),
                      ],
                    ),
                  ] else ...[
                    SizedBox(height: tags == null ? 0 : 4),
                    _priceText(),
                  ],
                  if (actions != null) ...[const SizedBox(height: 8), actions!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceText() {
    return Text(
      formatPrice(priceCents),
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: priceFontSize,
        fontWeight: FontWeight.bold,
        color: NexusColors.cyan,
      ),
    );
  }
}
