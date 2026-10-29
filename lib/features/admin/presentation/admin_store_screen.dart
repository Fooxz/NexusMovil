import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/staff_account_screen.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../vendor/domain/vendor_models.dart';
import '../../vendor/presentation/vendor_widgets.dart';
import '../admin_console_providers.dart';
import '../admin_providers.dart';
import '../domain/admin_console_models.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repository.dart';
import 'admin_order_screen.dart';
import 'admin_store_form_screen.dart';
import 'admin_widgets.dart';
import 'temporary_password_dialog.dart';

/// Ficha de una tienda: sus datos, el estado (habilitar, suspender, bloquear
/// o desactivar, con motivo), su desempeño, inventario y pedidos, el
/// historial administrativo, y la cuenta (crearla o regenerar la contraseña).
class AdminStoreScreen extends ConsumerWidget {
  const AdminStoreScreen({super.key, required this.storeId});

  final String storeId;

  Future<bool> _confirm(BuildContext context, String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  void _showError(BuildContext context, Object? error) {
    if (error == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AuthErrorBanner.messageFor(error))));
  }

  static String _statusAction(StoreStatus status) => switch (status) {
    StoreStatus.active => 'Habilitar',
    StoreStatus.suspended => 'Suspender',
    StoreStatus.blocked => 'Bloquear',
    StoreStatus.deactivated => 'Desactivar',
    StoreStatus.pending || StoreStatus.rejected => storeStatusLabel(status),
  };

  static String _statusEffect(StoreStatus status, String name) => switch (status) {
    StoreStatus.active => '$name podrá publicar y sus ofertas publicadas volverán al catálogo.',
    StoreStatus.suspended => 'Temporal: las ofertas de $name salen del catálogo y la tienda no puede operar.',
    StoreStatus.blocked => 'Por incumplir las políticas: sus ofertas salen del catálogo y la tienda no puede operar.',
    StoreStatus.deactivated => 'La tienda dejó de operar con NEXUS: sus ofertas salen del catálogo.',
    StoreStatus.pending || StoreStatus.rejected => '',
  };

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, AdminStore store) async {
    final status = await showModalBottomSheet<StoreStatus>(
      context: context,
      backgroundColor: NexusColors.bgAlt,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in adminStoreStatuses)
              if (status != store.status)
                ListTile(
                  leading: Icon(Icons.circle, size: 12, color: storeStatusColor(status)),
                  title: Text(_statusAction(status)),
                  subtitle: Text(_statusEffect(status, store.displayName), style: const TextStyle(fontSize: 11.5)),
                  onTap: () => Navigator.of(context).pop(status),
                ),
          ],
        ),
      ),
    );
    if (status == null || !context.mounted) return;

    final String? reason;
    if (status == StoreStatus.active) {
      final confirmed = await _confirm(
        context,
        'Habilitar tienda',
        _statusEffect(status, store.displayName),
        'Habilitar',
      );
      if (!confirmed) return;
      reason = null;
    } else {
      reason = await showReasonDialog(
        context,
        title: '${_statusAction(status)} tienda',
        message: _statusEffect(status, store.displayName),
        label: 'Motivo (queda en el historial)',
        action: _statusAction(status),
        maxLength: 500,
      );
      if (reason == null) return;
    }
    if (!context.mounted) return;
    final action = ref.read(adminConsoleActionProvider.notifier);
    await action.setStoreStatus(store.id, status, reason: reason);
    if (context.mounted) _showError(context, ref.read(adminConsoleActionProvider).error);
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final kind = await showModalBottomSheet<ProviderNoteKind>(
      context: context,
      backgroundColor: NexusColors.bgAlt,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in ProviderNoteKind.manual)
              ListTile(title: Text(kind.label), onTap: () => Navigator.of(context).pop(kind)),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;
    final message = await showReasonDialog(
      context,
      title: kind.label,
      label: 'Detalle',
      action: 'Registrar',
      maxLength: 500,
    );
    if (message == null || !context.mounted) return;
    await ref.read(adminConsoleActionProvider.notifier).addProviderNote(storeId, kind, message);
    if (context.mounted) _showError(context, ref.read(adminConsoleActionProvider).error);
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, AdminStore store) async {
    final confirmed = await _confirm(
      context,
      'Regenerar contraseña',
      'La contraseña actual de ${store.accountEmail} deja de servir. La tienda debe cambiar la nueva en su próximo ingreso.',
      'Regenerar',
    );
    if (!confirmed || !context.mounted) return;
    final result = await ref
        .read(adminActionControllerProvider.notifier)
        .run((repository) => repository.resetPassword(store.id), storeId: (result) => result.store.id);
    if (!context.mounted) return;
    if (result == null) {
      _showError(context, ref.read(adminActionControllerProvider).error);
      return;
    }
    await showTemporaryPassword(
      context,
      storeName: result.store.displayName,
      accountEmail: result.store.accountEmail ?? '',
      password: result.temporaryPassword,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(adminStoreProvider(storeId));
    final overview = ref.watch(providerOverviewProvider(storeId));
    final busy = ref.watch(adminActionControllerProvider).isLoading || ref.watch(adminConsoleActionProvider).isLoading;

    return NexusPage(
      title: 'TIENDA',
      showBack: true,
      showCart: false,
      children: [
        store.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudo cargar la tienda.\n${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(adminStoreProvider(storeId)),
          ),
          data: (store) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                store.displayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 10),
              NexusCard(
                child: Column(
                  children: [
                    NexusSpecRow('RAZÓN SOCIAL', store.legalName),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('NIT', store.taxId),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('CONTACTO', store.contactEmail),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('ESTADO', storeStatusLabel(store.status), valueColor: storeStatusColor(store.status)),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('CUENTA', store.accountEmail ?? 'Sin cuenta'),
                    const Divider(color: NexusColors.border, height: 1),
                    NexusSpecRow('OFERTAS PUBLICADAS', '${store.publishedOffers}'),
                    if (store.verificationNote case final note?) ...[
                      const Divider(color: NexusColors.border, height: 1),
                      NexusSpecRow('VERIFICACIÓN', note),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              NexusPrimaryButton(
                label: 'CAMBIAR ESTADO',
                loading: busy,
                onPressed: () => _changeStatus(context, ref, store),
              ),
              const SizedBox(height: 10),
              NexusOutlineButton(
                label: 'EDITAR DATOS',
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => AdminStoreFormScreen.edit(current: store))),
              ),
              const SizedBox(height: 10),
              if (store.hasAccount)
                NexusOutlineButton(
                  label: 'REGENERAR CONTRASEÑA TEMPORAL',
                  onPressed: busy ? null : () => _resetPassword(context, ref, store),
                )
              else
                NexusOutlineButton(
                  label: 'CREAR CUENTA PARA LA TIENDA',
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => AdminAccountFormScreen(store: store))),
                ),
            ],
          ),
        ),
        switch (overview) {
          AsyncValue(value: final data?) => _Overview(data: data, onAddNote: () => _addNote(context, ref)),
          AsyncValue(:final error?) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: NexusErrorState(
              message: 'No se pudo cargar el desempeño.\n${AuthErrorBanner.messageFor(error)}',
              onRetry: () => ref.invalidate(providerOverviewProvider(storeId)),
            ),
          ),
          _ => const Padding(padding: EdgeInsets.only(top: 16), child: NexusLoading()),
        },
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data, required this.onAddNote});

  final ProviderOverview data;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    final metrics = data.metrics;
    final inventory = data.inventory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VendorSectionTitle('DESEMPEÑO'),
        StatGrid(
          tiles: [
            StatTile(
              label: 'Ventas 30 días',
              value: formatPrice(metrics.sales30dCents),
              caption: 'Comisión: ${formatPrice(metrics.commission30dCents)}',
            ),
            StatTile(label: 'Pedidos', value: '${metrics.orders}', caption: '${metrics.openOrders} abiertos'),
            StatTile(
              label: 'Entregas cumplidas',
              value: percentLabel(metrics.deliveredRate),
              caption: 'De los pedidos cerrados',
            ),
            StatTile(
              label: 'Cancelados o rechazados',
              value: percentLabel(metrics.cancelRate),
              color: (metrics.cancelRate ?? 0) > 0.2 ? NexusColors.pink : NexusColors.text,
            ),
            StatTile(
              label: 'Incidencias abiertas',
              value: '${metrics.incidents}',
              color: metrics.incidents > 0 ? NexusColors.pink : NexusColors.text,
            ),
            StatTile(
              label: 'Advertencias',
              value: '${metrics.warnings}',
              color: metrics.warnings > 0 ? amber : NexusColors.text,
            ),
          ],
        ),
        const VendorSectionTitle('INVENTARIO'),
        AdminInfoCard(
          rows: [
            ('PUBLICADAS', '${inventory.published}'),
            ('STOCK BAJO', '${inventory.lowStock}'),
            ('AGOTADAS', '${inventory.outOfStock}'),
            ('OCULTAS POR NEXUS', '${inventory.hidden}'),
            ('RECHAZADAS', '${inventory.rejected}'),
          ],
        ),
        if (data.ordersByStatus.isNotEmpty) ...[
          const VendorSectionTitle('PEDIDOS POR ESTADO'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final status in VendorOrderStatus.values)
                if (data.ordersByStatus[status] case final count?)
                  NexusTag('${status.label.toUpperCase()}: $count', color: statusColor(status)),
            ],
          ),
        ],
        if (data.recentOrders.isNotEmpty) ...[
          const VendorSectionTitle('ÚLTIMOS PEDIDOS'),
          for (final row in data.recentOrders)
            VendorOrderTile(
              order: row.order,
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => AdminOrderScreen(orderId: row.orderId))),
            ),
        ],
        VendorSectionTitle(
          'HISTORIAL ADMINISTRATIVO',
          trailing: TextButton.icon(
            onPressed: onAddNote,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Registrar'),
          ),
        ),
        if (data.notes.isEmpty)
          const Text(
            'Sin advertencias, incidencias ni cambios de estado.',
            style: TextStyle(fontSize: 12, color: NexusColors.textDim),
          )
        else
          for (final note in data.notes) _NoteTile(note: note),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final ProviderNote note;

  static String _status(String? name) =>
      name == null ? '—' : storeStatusLabel(StoreStatus.values.asNameMap()[name] ?? StoreStatus.suspended);

  @override
  Widget build(BuildContext context) {
    final title = note.kind == ProviderNoteKind.statusChange
        ? '${_status(note.fromStatus)} → ${_status(note.toStatus)}'
        : note.kind.label;
    final color = switch (note.kind) {
      ProviderNoteKind.note || ProviderNoteKind.statusChange => NexusColors.textDim,
      ProviderNoteKind.warning => amber,
      ProviderNoteKind.incident || ProviderNoteKind.policyViolation => NexusColors.pink,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NexusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NexusColors.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(note.message, style: const TextStyle(fontSize: 12, color: NexusColors.text)),
              const SizedBox(height: 4),
              Text(
                [formatDateTime(note.createdAt), ?note.actorName].join(' · '),
                style: const TextStyle(fontSize: 10.5, color: NexusColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
