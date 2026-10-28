import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../domain/portal_models.dart';
import '../provider_portal_providers.dart';
import 'my_offer_screen.dart';
import 'offer_form_screen.dart';
import 'portal_widgets.dart';
import 'product_form_screen.dart';

/// "Publicar un producto": primero se busca en el catálogo. Si el producto ya
/// existe, la tienda publica su oferta sobre la misma ficha (así se comparan
/// los precios); si no, registra uno nuevo.
class SellProductScreen extends ConsumerStatefulWidget {
  const SellProductScreen({super.key});

  @override
  ConsumerState<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends ConsumerState<SellProductScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  SheetQuery _query = (search: '', category: null);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = (search: value.trim(), category: _query.category));
    });
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(sheetSearchProvider(_query));

    return NexusPage(
      title: 'PUBLICAR',
      showBack: true,
      showCart: false,
      children: [
        const Text(
          'Busca el producto en el catálogo. Si ya existe, publica tu oferta sobre él: '
          'así los clientes comparan tu precio con el de otras tiendas.',
          style: TextStyle(fontSize: 12, color: NexusColors.textDim),
        ),
        const SizedBox(height: 12),
        NexusTextField(
          hint: 'Nombre, marca o modelo',
          prefixIcon: Icons.search,
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todo'),
              selected: _query.category == null,
              onSelected: (_) => setState(() => _query = (search: _query.search, category: null)),
            ),
            for (final category in ProductCategory.values)
              ChoiceChip(
                label: Text(ProductVisuals.chipLabel(category)),
                selected: _query.category == category,
                onSelected: (selected) => setState(
                  () => _query = (search: _query.search, category: selected ? category : null),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        NexusCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '¿No está en el catálogo?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Regístralo con su ficha técnica. Se publica en cuanto pasa las validaciones.',
                  style: TextStyle(fontSize: 11.5, color: NexusColors.textDim),
                ),
                const SizedBox(height: 10),
                NexusOutlineButton(
                  label: 'REGISTRAR PRODUCTO NUEVO',
                  onPressed: () => _open(const ProductFormScreen.create()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        results.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudo buscar en el catálogo.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(sheetSearchProvider(_query)),
          ),
          data: (page) => page.items.isEmpty
              ? const NexusEmptyState(message: 'No encontramos productos con esa búsqueda.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sheet in page.items)
                      _SheetTile(
                        key: ValueKey(sheet.productId),
                        sheet: sheet,
                        onSell: () => _open(OfferFormScreen(productId: sheet.productId, productName: sheet.name)),
                        onOpenMine: () => _open(MyOfferScreen(productId: sheet.productId)),
                      ),
                    if (page.total > page.items.length)
                      Text(
                        'Mostrando ${page.items.length} de ${page.total}. Afina la búsqueda para encontrarlo.',
                        style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({super.key, required this.sheet, required this.onSell, required this.onOpenMine});

  final CatalogSheet sheet;
  final VoidCallback onSell;
  final VoidCallback onOpenMine;

  @override
  Widget build(BuildContext context) {
    final status = sheet.myOfferStatus;
    final selling = status != null && status != OfferStatus.retired;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NexusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      [sheet.brand, sheet.model].whereType<String>().join(' · '),
                      style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
                    ),
                    Text(
                      sheet.sellers == 1 ? '1 tienda lo vende' : '${sheet.sellers} tiendas lo venden',
                      style: const TextStyle(fontSize: 10.5, color: NexusColors.textFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selling)
                TextButton(onPressed: onOpenMine, child: Text('Ya publicada (${offerStatusLabel(status).toLowerCase()})'))
              else
                TextButton(
                  onPressed: onSell,
                  child: Text(status == OfferStatus.retired ? 'Volver a publicar' : 'Vender'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
