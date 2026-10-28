import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_empty_state.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/vendor_models.dart';
import '../vendor_providers.dart';
import 'vendor_widgets.dart';

/// Existencias de la tienda (HU-018): disponible, reservado, vendido y stock
/// mínimo, con alertas. Cada producto registra entradas, salidas y ajustes
/// con su motivo, y tiene su historial.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => ref.read(inventoryQueryProvider.notifier).setSearch(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(inventoryQueryProvider);
    final inventory = ref.watch(inventoryProvider);
    final counts = inventory.value;

    return NexusPage(
      title: 'INVENTARIO',
      showCart: false,
      children: [
        NexusOutlineButton(
          label: 'Historial de movimientos',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const StockMovementsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        NexusTextField(
          hint: 'Buscar por nombre o código interno',
          prefixIcon: Icons.search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, alert, count) in [
              ('Todos', null, counts?.allCount),
              ('Stock bajo', StockAlert.low, counts?.lowCount),
              ('Agotados', StockAlert.out, counts?.outCount),
            ])
              ChoiceChip(
                label: Text(count == null ? label : '$label ($count)'),
                selected: query.alert == alert,
                onSelected: (_) => ref.read(inventoryQueryProvider.notifier).setAlert(alert),
              ),
          ],
        ),
        const SizedBox(height: 12),
        switch (inventory) {
          AsyncValue(value: final page?) when page.items.isEmpty => NexusEmptyState(
            message: query.alert == null && query.search.isEmpty
                ? 'Todavía no tienes publicaciones. Publica un producto para controlar su inventario.'
                : 'No hay productos con ese filtro.',
          ),
          AsyncValue(value: final page?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in page.items) _InventoryCard(key: ValueKey(item.offerId), item: item),
              if (page.hasMore)
                NexusOutlineButton(
                  label: 'Ver más',
                  onPressed: () => ref.read(inventoryProvider.notifier).loadMore(),
                ),
              const SizedBox(height: 20),
            ],
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudo cargar el inventario.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(inventoryProvider),
          ),
          _ => const NexusLoading(),
        },
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final alertColor = switch (item.alert) {
      StockAlert.out => NexusColors.pink,
      StockAlert.low => const Color(0xFFFFC857),
      null => NexusColors.green,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NexusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NexusColors.text),
                        ),
                        Text('Código ${item.externalSku}',
                            style: const TextStyle(fontSize: 10.5, color: NexusColors.textFaint)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${item.stockUnits}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: alertColor)),
                      Text(
                        switch (item.alert) {
                          StockAlert.out => 'AGOTADO',
                          StockAlert.low => 'STOCK BAJO',
                          null => 'DISPONIBLES',
                        },
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: alertColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Mínimo ${item.minStock} · Reservadas ${item.reservedUnits} · Vendidas ${item.soldUnits}',
                style: const TextStyle(fontSize: 11, color: NexusColors.textDim),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: NexusPrimaryButton(
                      label: 'MOVER STOCK',
                      fontSize: 11,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: NexusColors.bgAlt,
                        builder: (_) => StockMovementSheet(item: item),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Stock mínimo',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _MinStockDialog(item: item),
                    ),
                    icon: const Icon(Icons.tune, color: NexusColors.textDim),
                  ),
                  IconButton(
                    tooltip: 'Historial',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StockMovementsScreen(productId: item.productId, productName: item.name),
                      ),
                    ),
                    icon: const Icon(Icons.history, color: NexusColors.textDim),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrada, salida o ajuste al conteo real, con el motivo.
class StockMovementSheet extends ConsumerStatefulWidget {
  const StockMovementSheet({super.key, required this.item});

  final InventoryItem item;

  @override
  ConsumerState<StockMovementSheet> createState() => _StockMovementSheetState();
}

class _StockMovementSheetState extends ConsumerState<StockMovementSheet> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  var _kind = StockMovementKind.entry;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_quantity.text);

  /// Cómo queda el stock con lo escrito.
  int? get _result {
    final amount = _amount;
    if (amount == null) return null;
    return switch (_kind) {
      StockMovementKind.entry => widget.item.stockUnits + amount,
      StockMovementKind.exit => widget.item.stockUnits - amount,
      _ => amount,
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref
        .read(stockActionControllerProvider.notifier)
        .adjust(widget.item.productId, _kind, _amount!, _reason.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(stockActionControllerProvider);
    final result = _result;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.item.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: NexusColors.text)),
            Text('Stock actual: ${widget.item.stockUnits}',
                style: const TextStyle(fontSize: 12, color: NexusColors.textDim)),
            const SizedBox(height: 12),
            SegmentedButton<StockMovementKind>(
              segments: [
                for (final kind in StockMovementKind.manual) ButtonSegment(value: kind, label: Text(kind.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (value) => setState(() => _kind = value.single),
            ),
            const SizedBox(height: 12),
            if (action.error case final error?) AuthErrorBanner(error),
            AuthField(
              label: _kind == StockMovementKind.adjustment ? 'CONTEO REAL' : 'CANTIDAD',
              field: TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _kind == StockMovementKind.adjustment ? 'Unidades que hay de verdad' : 'Unidades',
                  helperText: result == null ? null : 'El stock quedará en $result',
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null) return 'Escribe un número.';
                  if (_kind != StockMovementKind.adjustment && amount == 0) return 'Debe ser al menos 1.';
                  if (_kind == StockMovementKind.exit && amount > widget.item.stockUnits) {
                    return 'Solo hay ${widget.item.stockUnits} unidades.';
                  }
                  return null;
                },
              ),
            ),
            AuthField(
              label: 'MOTIVO',
              field: TextFormField(
                controller: _reason,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: switch (_kind) {
                    StockMovementKind.entry => 'Llegó mercancía del distribuidor',
                    StockMovementKind.exit => 'Producto dañado, muestra…',
                    _ => 'Conteo físico de la bodega',
                  },
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3 ? 'Escribe el motivo.' : null,
              ),
            ),
            const SizedBox(height: 4),
            NexusPrimaryButton(label: 'REGISTRAR MOVIMIENTO', loading: action.isLoading, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _MinStockDialog extends ConsumerStatefulWidget {
  const _MinStockDialog({required this.item});

  final InventoryItem item;

  @override
  ConsumerState<_MinStockDialog> createState() => _MinStockDialogState();
}

class _MinStockDialogState extends ConsumerState<_MinStockDialog> {
  late final _value = TextEditingController(text: '${widget.item.minStock}');

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_value.text);
    if (value == null) return;
    final ok = await ref.read(stockActionControllerProvider.notifier).setMinStock(widget.item.productId, value);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(stockActionControllerProvider);
    return AlertDialog(
      title: const Text('Stock mínimo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Con esta cantidad o menos, el producto aparece con alerta de stock bajo.',
              style: TextStyle(fontSize: 12)),
          if (action.error case final error?) AuthErrorBanner(error),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Unidades'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: action.isLoading ? null : _save, child: const Text('Guardar')),
      ],
    );
  }
}

/// Historial de movimientos: de un producto, o de toda la tienda.
class StockMovementsScreen extends ConsumerWidget {
  const StockMovementsScreen({super.key, this.productId, this.productName});

  final String? productId;
  final String? productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(stockMovementsProvider(productId));

    return NexusPage(
      title: 'MOVIMIENTOS',
      showBack: true,
      showCart: false,
      children: [
        if (productName case final name?)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NexusColors.text)),
          ),
        switch (movements) {
          AsyncValue(value: final page?) when page.items.isEmpty =>
            const NexusEmptyState(message: 'Todavía no hay movimientos.'),
          AsyncValue(value: final page?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final movement in page.items) _MovementRow(movement: movement, showProduct: productId == null),
              if (page.total > page.items.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  child: Text(
                    'Se muestran los ${page.items.length} más recientes de ${page.total}.',
                    style: const TextStyle(fontSize: 11, color: NexusColors.textFaint),
                  ),
                ),
            ],
          ),
          AsyncValue(:final error?) => NexusErrorState(
            message: 'No se pudo cargar el historial.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(stockMovementsProvider(productId)),
          ),
          _ => const NexusLoading(),
        },
      ],
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.showProduct});

  final StockMovement movement;
  final bool showProduct;

  @override
  Widget build(BuildContext context) {
    final positive = movement.quantityDelta > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NexusColors.card,
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movement.kind.label,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NexusColors.text)),
                if (showProduct)
                  Text(movement.productName, style: const TextStyle(fontSize: 11, color: NexusColors.text)),
                if (movement.reason case final reason?)
                  Text(reason, style: const TextStyle(fontSize: 11, color: NexusColors.textDim)),
                Text(
                  [formatDateTime(movement.createdAt), ?movement.actorName].join(' · '),
                  style: const TextStyle(fontSize: 10.5, color: NexusColors.textFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${movement.quantityDelta}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: positive ? NexusColors.green : NexusColors.pink,
                ),
              ),
              Text('${movement.stockBefore} → ${movement.stockAfter}',
                  style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim)),
            ],
          ),
        ],
      ),
    );
  }
}
