import 'package:flutter/material.dart';

import '../../../theme/nexus_theme.dart';
import '../../../widgets/nexus_widgets.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../catalog/domain/product.dart';
import '../domain/portal_models.dart';

/// Valores de los atributos técnicos de una ficha mientras se editan. Lo
/// usan el formulario de la tienda y la corrección del administrador.
class AttributeValues {
  AttributeValues([Map<String, Object?>? initial]) : _values = {...?initial};

  final Map<String, Object?> _values;
  final _text = <String, TextEditingController>{};

  Object? operator [](String key) => _values[key];

  void operator []=(String key, Object? value) => _values[key] = value;

  TextEditingController textFor(AttributeDefinition definition) => _text.putIfAbsent(definition.key, () {
    final value = _values[definition.key];
    return TextEditingController(text: value == null ? '' : formatNumber(value));
  });

  /// Al cambiar de categoría: los atributos son de cada una.
  void clear() {
    _values.clear();
    for (final controller in _text.values) {
      controller.clear();
    }
  }

  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
  }

  /// Atributos de la plantilla con valor. Los que quedan vacíos no se envían.
  Map<String, Object?> collect(List<AttributeDefinition> template) {
    final values = <String, Object?>{};
    for (final definition in template) {
      switch (definition.type) {
        case AttributeType.number:
          final text = textFor(definition).text.trim().replaceAll(',', '.');
          final number = num.tryParse(text);
          if (number != null) values[definition.key] = number == number.roundToDouble() ? number.toInt() : number;
        case AttributeType.text:
          final text = textFor(definition).text.trim();
          if (text.isNotEmpty) values[definition.key] = text;
        case AttributeType.boolean || AttributeType.choice:
          if (_values[definition.key] != null) values[definition.key] = _values[definition.key];
        case AttributeType.choices:
          final list = _values[definition.key];
          if (list is List && list.isNotEmpty) values[definition.key] = list;
      }
    }
    return values;
  }

  static String formatNumber(Object value) =>
      value is num && value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  static String display(AttributeDefinition definition, Object value) {
    final text = switch (value) {
      bool flag => flag ? 'Sí' : 'No',
      List<Object?> list => list.join(', '),
      num number => formatNumber(number),
      _ => '$value',
    };
    return definition.unit == null ? text : '$text ${definition.unit}';
  }
}

/// Ficha para mostrar y etiquetas cortas que salen de los atributos.
({List<ProductSpec> specs, List<String> quickSpecs}) sheetFromAttributes(
  List<AttributeDefinition> template,
  Map<String, Object?> attributes,
) {
  final shown = [
    for (final definition in template)
      if (attributes[definition.key] case final value?) (definition, AttributeValues.display(definition, value)),
  ];
  return (
    specs: [
      for (final (definition, text) in shown)
        if (text.length <= 120) ProductSpec(label: definition.label.toUpperCase(), value: text),
    ],
    quickSpecs: [
      for (final (_, text) in shown.take(4))
        if (text.length <= 30) text.toUpperCase(),
    ],
  );
}

/// Campo de un atributo según su tipo en la plantilla. [onChanged] avisa al
/// formulario para que se redibuje.
class AttributeField extends StatelessWidget {
  const AttributeField({super.key, required this.definition, required this.values, required this.onChanged});

  final AttributeDefinition definition;
  final AttributeValues values;
  final VoidCallback onChanged;

  void _set(Object? value) {
    values[definition.key] = value;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
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
          controller: values.textFor(definition),
          keyboardType: definition.type == AttributeType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return definition.isRequired ? 'Completa «${definition.label}».' : null;
            if (definition.type == AttributeType.number && (num.tryParse(text.replaceAll(',', '.')) ?? -1) < 0) {
              return 'Escribe un número.';
            }
            return text.length > 120 ? 'Admite hasta 120 caracteres.' : null;
          },
        ),
      ),
      AttributeType.boolean => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(definition.label, style: const TextStyle(fontSize: 12.5, color: NexusColors.text)),
        value: values[definition.key] == true,
        onChanged: _set,
      ),
      AttributeType.choice => AuthField(
        label: label,
        field: DropdownButtonFormField<String>(
          initialValue: definition.allowedValues.contains(values[definition.key])
              ? values[definition.key] as String
              : null,
          dropdownColor: NexusColors.bgAlt,
          items: [for (final value in definition.allowedValues) DropdownMenuItem(value: value, child: Text(value))],
          onChanged: _set,
          validator: (value) => definition.isRequired && value == null ? 'Elige «${definition.label}».' : null,
        ),
      ),
      AttributeType.choices => FormField<List<String>>(
        initialValue: [
          for (final value in (values[definition.key] as List<Object?>? ?? const []))
            if (value is String) value,
        ],
        validator: (selected) =>
            definition.isRequired && (selected == null || selected.isEmpty) ? 'Elige al menos una opción.' : null,
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
                        _set(next);
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
