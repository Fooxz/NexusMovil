import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_error_state.dart';
import '../../../widgets/nexus_loading.dart';
import '../../../widgets/nexus_page.dart';
import '../../../widgets/nexus_product_image.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../account/account_providers.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_visuals.dart';
import '../domain/portal_models.dart';
import '../provider_portal_providers.dart';
import 'my_offer_screen.dart';
import 'offer_form_screen.dart';
import 'portal_widgets.dart';

class _ImageItem {
  const _ImageItem({required this.path, this.bytes, this.url});

  final String path;

  /// La imagen recién subida, para mostrarla sin descargarla.
  final Uint8List? bytes;
  final String? url;
}

/// Ficha técnica de un producto: registrar uno nuevo con la oferta de la
/// tienda (se publica en cuanto pasa las validaciones) o editar una ficha que
/// la tienda registró y nadie más vende. Los atributos salen de la plantilla
/// de la categoría; la ficha para mostrar se arma con ellos.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen.create({super.key}) : current = null;

  const ProductFormScreen.edit({super.key, required MyOfferDetail this.current});

  final MyOfferDetail? current;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.current?.offer.name ?? '');
  late final _brand = TextEditingController(text: widget.current?.offer.brand ?? '');
  late final _model = TextEditingController(text: widget.current?.offer.model ?? '');
  late final _summary = TextEditingController(text: widget.current?.summary ?? '');
  late ProductCategory? _category = widget.current?.offer.category;
  late final Map<String, Object?> _attributes = {...?widget.current?.attributes};
  final _attributeText = <String, TextEditingController>{};
  late final List<_ImageItem> _images = [
    for (final image in widget.current?.images ?? const <ProductImageRef>[])
      if (image.path != null) _ImageItem(path: image.path!, url: image.url),
  ];
  late final OfferFieldsData? _offer = widget.current == null ? OfferFieldsData() : null;
  var _uploading = false;
  String? _imagesError;

  bool get _editing => widget.current != null;

  @override
  void dispose() {
    for (final controller in [_name, _brand, _model, _summary, ..._attributeText.values]) {
      controller.dispose();
    }
    _offer?.dispose();
    super.dispose();
  }

  TextEditingController _textFor(AttributeDefinition definition) =>
      _attributeText.putIfAbsent(definition.key, () {
        final value = _attributes[definition.key];
        return TextEditingController(text: value == null ? '' : _formatNumber(value));
      });

  static String _formatNumber(Object value) =>
      value is num && value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  Future<void> _addImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // La carpeta de las imágenes es la de la tienda de la cuenta.
      final storeId = (await ref.read(accountProvider.future))?.store?.id;
      if (storeId == null) throw const ForbiddenFailure();
      final picked = await ref.read(productImagePickerProvider).pick();
      if (picked == null) return;
      setState(() => _uploading = true);
      final path = await ref
          .read(providerPortalRepositoryProvider)
          .uploadImage(
            storeId: storeId,
            bytes: picked.bytes,
            extension: picked.extension,
            contentType: picked.contentType,
          );
      if (mounted) {
        setState(() {
          _images.add(_ImageItem(path: path, bytes: picked.bytes));
          _imagesError = null;
        });
      }
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(AuthErrorBanner.messageFor(error))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Atributos de la plantilla con valor. Los que quedan vacíos no se envían.
  Map<String, Object?> _collectAttributes(List<AttributeDefinition> template) {
    final values = <String, Object?>{};
    for (final definition in template) {
      switch (definition.type) {
        case AttributeType.number:
          final text = _textFor(definition).text.trim().replaceAll(',', '.');
          final number = num.tryParse(text);
          if (number != null) values[definition.key] = number == number.roundToDouble() ? number.toInt() : number;
        case AttributeType.text:
          final text = _textFor(definition).text.trim();
          if (text.isNotEmpty) values[definition.key] = text;
        case AttributeType.boolean || AttributeType.choice:
          if (_attributes[definition.key] != null) values[definition.key] = _attributes[definition.key];
        case AttributeType.choices:
          final list = _attributes[definition.key];
          if (list is List && list.isNotEmpty) values[definition.key] = list;
      }
    }
    return values;
  }

  static String _display(AttributeDefinition definition, Object value) {
    final text = switch (value) {
      bool flag => flag ? 'Sí' : 'No',
      List<Object?> list => list.join(', '),
      num number => _formatNumber(number),
      _ => '$value',
    };
    return definition.unit == null ? text : '$text ${definition.unit}';
  }

  ProductInput _product(List<AttributeDefinition> template) {
    final attributes = _collectAttributes(template);
    final shown = [
      for (final definition in template)
        if (attributes[definition.key] case final value?) (definition, _display(definition, value)),
    ];
    return ProductInput(
      category: _category!,
      name: _name.text,
      brand: _brand.text,
      model: _model.text,
      summary: _summary.text,
      // La ficha para mostrar sale de los atributos.
      specs: [
        for (final (definition, text) in shown)
          if (text.length <= 120) ProductSpec(label: definition.label.toUpperCase(), value: text),
      ],
      quickSpecs: [
        for (final (_, text) in shown.take(4))
          if (text.length <= 30) text.toUpperCase(),
      ],
      attributes: attributes,
      images: [for (final image in _images) image.path],
    );
  }

  Future<void> _submit(List<AttributeDefinition> template, {bool confirmDistinct = false}) async {
    final valid = _formKey.currentState!.validate();
    setState(() => _imagesError = _images.isEmpty ? 'Agrega al menos una imagen.' : null);
    if (!valid || _images.isEmpty) return;

    final product = _product(template);
    final actions = ref.read(portalActionControllerProvider.notifier);
    final result = await actions.run(
      (repository) => _editing
          ? repository.updateProduct(widget.current!.offer.productId, product)
          : repository.createProduct(product, _offer!.toInput(), confirmDistinct: confirmDistinct),
    );
    if (!mounted) return;

    if (result != null) {
      final navigator = Navigator.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_editing ? 'Ficha actualizada.' : 'Producto publicado.')));
      if (_editing) {
        navigator.pop();
      } else {
        navigator.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => MyOfferScreen(productId: result.offer.productId)),
        );
      }
      return;
    }

    switch (ref.read(portalActionControllerProvider).error) {
      case ProductExistsFailure(:final productId?, :final productName):
        actions.clearError();
        final sell = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ya está en el catálogo'),
            content: Text(
              '${productName ?? 'Este producto'} ya existe. Publica tu oferta sobre él: '
              'así aparece tu tarjeta junto a las de otras tiendas.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Revisar datos')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Publicar mi oferta')),
            ],
          ),
        );
        if (sell == true && mounted) _sellExisting(productId, productName ?? product.name);
      case PossibleDuplicateFailure(:final candidates):
        actions.clearError();
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => _DuplicateDialog(candidates: candidates),
        );
        if (!mounted || choice == null) return;
        if (choice == _DuplicateDialog.distinct) {
          await _submit(template, confirmDistinct: true);
        } else {
          final candidate = candidates.firstWhere((c) => c.productId == choice);
          _sellExisting(candidate.productId, candidate.name);
        }
      default:
        break;
    }
  }

  void _sellExisting(String productId, String productName) => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => OfferFormScreen(productId: productId, productName: productName)),
  );

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(portalActionControllerProvider);
    final category = _category;
    final template = category == null ? null : ref.watch(attributeTemplateProvider(category));

    return NexusPage(
      title: _editing ? 'EDITAR FICHA' : 'PRODUCTO NUEVO',
      showBack: true,
      showCart: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (action.error case final error?) AuthErrorBanner(error),
              const NexusUnderlineTitle('TIPO DE PIEZA'),
              const SizedBox(height: 8),
              if (_editing)
                Text(
                  ProductVisuals.forCategory(category!).categoryLabel,
                  style: const TextStyle(fontSize: 12.5, color: NexusColors.text),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in ProductCategory.values)
                      ChoiceChip(
                        label: Text(ProductVisuals.chipLabel(option)),
                        selected: category == option,
                        onSelected: (_) => setState(() {
                          // Los atributos son de cada categoría.
                          _category = option;
                          _attributes.clear();
                          for (final controller in _attributeText.values) {
                            controller.clear();
                          }
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
                  hint: 'Ej. NVIDIA GeForce RTX 5070 12 GB',
                  controller: _name,
                  validator: Validators.text(field: 'el nombre', min: 3, max: 160),
                ),
              ),
              AuthField(
                label: 'MARCA',
                field: NexusTextField(
                  hint: 'Ej. NVIDIA',
                  controller: _brand,
                  validator: Validators.text(field: 'la marca', max: 60),
                ),
              ),
              AuthField(
                label: 'MODELO',
                field: NexusTextField(
                  hint: 'Ej. RTX 5070 (sirve para no duplicar productos)',
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
              if (category != null) ...[
                const NexusUnderlineTitle('FICHA TÉCNICA'),
                const SizedBox(height: 8),
                template!.when(
                  loading: () => const NexusLoading(),
                  error: (error, _) => NexusErrorState(
                    message: 'No se pudo cargar la plantilla.\n${AuthErrorBanner.messageFor(error)}',
                    onRetry: () => ref.invalidate(attributeTemplateProvider(category)),
                  ),
                  data: (definitions) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final definition in definitions) _attributeField(definition)],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const NexusUnderlineTitle('IMÁGENES'),
              const SizedBox(height: 8),
              _ImagesEditor(
                images: _images,
                category: category,
                uploading: _uploading,
                error: _imagesError,
                onAdd: _images.length >= 8 || _uploading ? null : _addImage,
                onRemove: (index) => setState(() => _images.removeAt(index)),
              ),
              if (_offer case final offer?) ...[
                const SizedBox(height: 16),
                const NexusUnderlineTitle('TU OFERTA'),
                const SizedBox(height: 8),
                OfferFields(
                  data: offer,
                  onStatusChanged: (status) => setState(() => offer.status = status),
                ),
              ],
              const SizedBox(height: 8),
              NexusPrimaryButton(
                label: _editing ? 'GUARDAR FICHA' : 'PUBLICAR PRODUCTO',
                loading: action.isLoading,
                enabled: category != null && (template?.hasValue ?? false) && !_uploading,
                onPressed: () => _submit(template!.requireValue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _attributeField(AttributeDefinition definition) {
    final label = [
      definition.label.toUpperCase(),
      if (definition.unit != null) '(${definition.unit})',
      if (!definition.isRequired) '· OPCIONAL',
    ].join(' ');

    return switch (definition.type) {
      AttributeType.number || AttributeType.text => AuthField(
        label: label,
        field: NexusTextField(
          hint: definition.type == AttributeType.number ? 'Número' : 'Texto',
          controller: _textFor(definition),
          keyboardType: definition.type == AttributeType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return definition.isRequired ? 'Completa «${definition.label}».' : null;
            if (definition.type == AttributeType.number &&
                (num.tryParse(text.replaceAll(',', '.')) ?? -1) < 0) {
              return 'Escribe un número.';
            }
            return text.length > 120 ? 'Admite hasta 120 caracteres.' : null;
          },
        ),
      ),
      AttributeType.boolean => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(definition.label, style: const TextStyle(fontSize: 12.5, color: NexusColors.text)),
        value: _attributes[definition.key] == true,
        onChanged: (value) => setState(() => _attributes[definition.key] = value),
      ),
      AttributeType.choice => AuthField(
        label: label,
        field: DropdownButtonFormField<String>(
          initialValue: definition.allowedValues.contains(_attributes[definition.key])
              ? _attributes[definition.key] as String
              : null,
          dropdownColor: NexusColors.bgAlt,
          items: [
            for (final value in definition.allowedValues) DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: (value) => setState(() => _attributes[definition.key] = value),
          validator: (value) =>
              definition.isRequired && value == null ? 'Elige «${definition.label}».' : null,
        ),
      ),
      AttributeType.choices => FormField<List<String>>(
        initialValue: [
          for (final value in (_attributes[definition.key] as List<Object?>? ?? const []))
            if (value is String) value,
        ],
        validator: (values) =>
            definition.isRequired && (values == null || values.isEmpty) ? 'Elige al menos una opción.' : null,
        builder: (field) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NexusFieldLabel(label),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final value in definition.allowedValues)
                    FilterChip(
                      label: Text(value),
                      selected: field.value?.contains(value) ?? false,
                      onSelected: (selected) {
                        final next = [...?field.value];
                        selected ? next.add(value) : next.remove(value);
                        field.didChange(next);
                        setState(() => _attributes[definition.key] = next);
                      },
                    ),
                ],
              ),
              if (field.errorText case final error?)
                Text(error, style: const TextStyle(fontSize: 10, color: NexusColors.pink)),
            ],
          ),
        ),
      ),
    };
  }
}

class _ImagesEditor extends StatelessWidget {
  const _ImagesEditor({
    required this.images,
    required this.category,
    required this.uploading,
    required this.error,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_ImageItem> images;
  final ProductCategory? category;
  final bool uploading;
  final String? error;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final visuals = ProductVisuals.forCategory(category ?? ProductCategory.gpu);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < images.length; index++)
              Stack(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: images[index].bytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(images[index].bytes!, fit: BoxFit.cover),
                          )
                        : NexusProductImage(
                            imageUrl: images[index].url,
                            icon: visuals.icon,
                            gradientColors: visuals.gradientColors,
                            height: 84,
                            borderRadius: 8,
                          ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => onRemove(index),
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: NexusColors.bg,
                        child: Icon(Icons.close, size: 14, color: NexusColors.pink),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        NexusOutlineButton(
          label: uploading ? 'SUBIENDO...' : 'AGREGAR IMAGEN (${images.length}/8)',
          onPressed: onAdd,
        ),
        const SizedBox(height: 4),
        Text(
          error ?? 'JPG, PNG o WEBP de hasta 5 MB. Lo que subes no se reemplaza: si una imagen no sirve, quítala y sube otra.',
          style: TextStyle(fontSize: 10.5, color: error == null ? NexusColors.textDim : NexusColors.pink),
        ),
      ],
    );
  }
}

class _DuplicateDialog extends StatelessWidget {
  const _DuplicateDialog({required this.candidates});

  static const distinct = '__distinto__';

  final List<DuplicateCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Es alguno de estos?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('En el catálogo hay productos parecidos de la misma marca.'),
          const SizedBox(height: 8),
          for (final candidate in candidates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(candidate.name),
              subtitle: candidate.model == null ? null : Text(candidate.model!),
              trailing: const Text('Vender este'),
              onTap: () => Navigator.of(context).pop(candidate.productId),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(context).pop(distinct), child: const Text('Es otro producto')),
      ],
    );
  }
}
