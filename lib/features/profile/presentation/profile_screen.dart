import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routes.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/auth_providers.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../domain/profile_models.dart';
import '../profile_providers.dart';
import 'address_form_screen.dart';
import 'edit_profile_screen.dart';

/// Pestaña PERFIL: invita a entrar sin sesión; con sesión muestra datos
/// personales y direcciones de entrega (HU-003).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      currentUserProvider.select((user) => user != null),
    );

    return NexusPage(
      title: 'MI CUENTA',
      children: [
        if (signedIn) const _SignedInContent() else const _SignedOutContent(),
      ],
    );
  }
}

class _SignedOutContent extends StatelessWidget {
  const _SignedOutContent();

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_outline, size: 40, color: NexusColors.cyan),
            const SizedBox(height: 12),
            const Text(
              'Inicia sesión para comprar, guardar tus direcciones y seguir '
              'tus pedidos. Puedes ver el catálogo sin cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: NexusColors.text),
            ),
            const SizedBox(height: 16),
            NexusPrimaryButton(
              label: 'INICIAR SESIÓN',
              onPressed: () => Navigator.of(context).pushNamed(NexusRoutes.login),
            ),
            const SizedBox(height: 10),
            NexusOutlineButton(
              label: 'CREAR CUENTA',
              onPressed: () =>
                  Navigator.of(context).pushNamed(NexusRoutes.signup),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInContent extends ConsumerWidget {
  const _SignedInContent();

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorBanner.messageFor(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ProfileSection(),
        const SizedBox(height: 22),
        const _AddressesSection(),
        const SizedBox(height: 22),
        NexusOutlineButton(
          label: 'CERRAR SESIÓN',
          color: NexusColors.pink,
          borderColor: NexusColors.pink,
          onPressed: () => _signOut(context, ref),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return profile.when(
      loading: () => const NexusLoading(),
      error: (error, _) => NexusErrorState(
        message: 'No se pudo cargar tu perfil.\n'
            '${AuthErrorBanner.messageFor(error)}',
        onRetry: () => ref.invalidate(profileProvider),
      ),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NexusUnderlineTitle('DATOS PERSONALES'),
            const SizedBox(height: 4),
            NexusCard(
              child: Column(
                children: [
                  NexusSpecRow('NOMBRE', profile.fullName),
                  const Divider(color: NexusColors.border, height: 1),
                  NexusSpecRow('EMAIL', profile.email),
                  const Divider(color: NexusColors.border, height: 1),
                  NexusSpecRow('TELÉFONO', profile.phone ?? 'Sin registrar'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            NexusOutlineButton(
              label: 'EDITAR DATOS',
              compact: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EditProfileScreen(profile: profile),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AddressesSection extends ConsumerWidget {
  const _AddressesSection();

  void _openForm(BuildContext context, {Address? address}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddressFormScreen(address: address),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NexusUnderlineTitle('DIRECCIONES DE ENTREGA'),
        const SizedBox(height: 8),
        addresses.when(
          loading: () => const NexusLoading(),
          error: (error, _) => NexusErrorState(
            message: 'No se pudieron cargar tus direcciones.\n'
                '${AuthErrorBanner.messageFor(error)}',
            onRetry: () => ref.invalidate(addressesProvider),
          ),
          data: (addresses) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Aún no tienes direcciones. Agrega una para agilizar tus compras.',
                    style: TextStyle(fontSize: 12, color: NexusColors.textDim),
                  ),
                ),
              for (final address in addresses)
                _AddressCard(
                  key: ValueKey(address.id),
                  address: address,
                  onEdit: () => _openForm(context, address: address),
                ),
            ],
          ),
        ),
        NexusPrimaryButton(
          label: 'AGREGAR DIRECCIÓN',
          icon: Icons.add_location_alt_outlined,
          onPressed: () => _openForm(context),
        ),
      ],
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({super.key, required this.address, required this.onEdit});

  final Address address;
  final VoidCallback onEdit;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Eliminar "${address.label}"? No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, ref, (controller) => controller.delete(address.id));
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(AddressFormController) action,
  ) async {
    final controller = ref.read(addressListActionsProvider.notifier);
    final ok = await action(controller);
    if (ok || !context.mounted) return;
    final error = ref.read(addressListActionsProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AuthErrorBanner.messageFor(error ?? Object()))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el controlador mientras se ejecuta una acción.
    ref.watch(addressListActionsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NexusCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      address.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (address.isDefault)
                    const NexusTag('PREDETERMINADA', color: NexusColors.cyan),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                address.summary,
                style: const TextStyle(fontSize: 12, color: NexusColors.text),
              ),
              if (address.details != null)
                Text(
                  address.details!,
                  style: const TextStyle(fontSize: 11.5, color: NexusColors.textDim),
                ),
              const SizedBox(height: 4),
              Text(
                '${address.recipientName} · ${address.phone}',
                style: const TextStyle(fontSize: 11.5, color: NexusColors.textDim),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  TextButton(onPressed: onEdit, child: const Text('Editar')),
                  if (!address.isDefault)
                    TextButton(
                      onPressed: () => _run(
                        context,
                        ref,
                        (controller) => controller.makeDefault(address),
                      ),
                      child: const Text('Usar como predeterminada'),
                    ),
                  TextButton(
                    onPressed: () => _delete(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: NexusColors.pink,
                    ),
                    child: const Text('Eliminar'),
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
