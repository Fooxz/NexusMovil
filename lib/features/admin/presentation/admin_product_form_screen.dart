import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../../provider_portal/domain/portal_models.dart';
import '../../provider_portal/presentation/attribute_fields.dart';
import '../../provider_portal/provider_portal_providers.dart';
import '../admin_console_providers.dart';
import '../domain/admin_console_models.dart';

/// El administrador corrige la ficha compartida de un producto: datos,
/// categoría y atributos técnicos contra la plantilla. Cambia la ficha de
/// todas las tiendas que lo venden; las imágenes no se tocan.
class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({super.key, required this.detail});

  final AdminOfferDetail detail;

  @override
  ConsumerState<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends ConsumerState<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.detail.offer.productName);
  late final _brand = TextEditingController(text: widget.detail.offer.brand);
  late final _model = TextEditingController(text: widget.detail.offer.model ?? '');
  late final _summary = TextEditingController(text: widget.detail.summary ?? '');
  late ProductCategory _category = widget.detail.offer.category!;
  late final _attributes = AttributeValues(widget.detail.attributes);

  @override
  void dispose() {
    for (final controller in [_name, _brand, _model, _summary]) {
      controller.dispose();
    }
    _attributes.dispose();
    super.dispose();
  }

  Future<void> _submit(List<AttributeDefinition> template) async {
    if (!_formKey.currentState!.validate()) return;
    final attributes = _attributes.collect(template);
    final sheet = sheetFromAttributes(template, attributes);
    final result = await ref
        .read(adminConsoleActionProvider.notifier)
        .updateProduct(
          widget.detail.offer.productId,
          AdminProductInput(
            category: _category,
            name: _name.text,
            brand: _brand.text,
            model: _model.text,
            summary: _summary.text,
            attributes: attributes,
            specs: sheet.specs,
            quickSpecs: sheet.quickSpecs,
          ),
        );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.length == 1
                ? 'Ficha corregida.'
                : 'Ficha corregida para las ${result.length} tiendas que venden el producto.',
          ),
        ),
      );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(adminConsoleActionProvider);
    final template = ref.watch(attributeTemplateProvider(_category));

    return NexusPage(
      title: 'CORREGIR FICHA',
      showBack: true,
      showCart: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              const Text(
                'El cambio se ve en todas las tiendas que venden este producto.',
                style: TextStyle(fontSize: 11.5, color: NexusColors.textDim),
              ),
              const SizedBox(height: 12),
              const NexusUnderlineTitle('TIPO DE PIEZA'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in ProductCategory.values)
                    ChoiceChip(
                      label: Text(ProductVisuals.chipLabel(option)),
                      selected: _category == option,
                      onSelected: (_) => setState(() {
                        if (option == _category) return;
                        // Los atributos son de cada categoría.
                        _category = option;
                        _attributes.clear();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const NexusUnderlineTitle('PRODUCTO'),
              const SizedBox(height: 8),
              AuthField(
                label: 'NOMBRE',
                field: NexusTextField(
                  hint: 'Nombre del producto',
                  controller: _name,
                  validator: Validators.text(field: 'el nombre', min: 3, max: 160),
                ),
              ),
              AuthField(
                label: 'MARCA',
                field: NexusTextField(
                  hint: 'Marca',
                  controller: _brand,
                  validator: Validators.text(field: 'la marca', max: 60),
                ),
              ),
              AuthField(
                label: 'MODELO',
                field: NexusTextField(
                  hint: 'Modelo',
                  controller: _model,
                  validator: Validators.text(field: 'el modelo', max: 80),
                ),
              ),
              AuthField(
                label: 'RESUMEN (OPCIONAL)',
                field: NexusTextField(
                  hint: 'Una línea corta para la tarjeta',
                  controller: _summary,
                  validator: (value) => Validators.optionalText(value, max: 200),
                ),
              ),
              const NexusUnderlineTitle('FICHA TÉCNICA'),
              const SizedBox(height: 8),
              template.when(
                loading: () => const NexusLoading(),
                error: (error, _) => NexusErrorState(
                  message: 'No se pudo cargar la plantilla.\n${AuthErrorBanner.messageFor(error)}',
                  onRetry: () => ref.invalidate(attributeTemplateProvider(_category)),
                ),
                data: (definitions) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final definition in definitions)
                      AttributeField(
                        key: ValueKey('${_category.name}-${definition.key}'),
                        definition: definition,
                        values: _attributes,
                        onChanged: () => setState(() {}),
                      ),
                    const SizedBox(height: 8),
                    NexusPrimaryButton(
                      label: 'GUARDAR FICHA',
                      loading: action.isLoading,
                      onPressed: () => _submit(definitions),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}
