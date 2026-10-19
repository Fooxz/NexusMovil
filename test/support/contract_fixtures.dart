import 'dart:convert';

/// Ejemplos de docs/API_CONTRATO.md (secciones 2 y 5), copiados tal cual.
/// Si el contrato cambia, se actualizan aquí y las pruebas muestran qué se rompe.

final Map<String, Object?> contractDetailFixture =
    jsonDecode(_detailJson) as Map<String, Object?>;

final Map<String, Object?> contractListingFixture =
    jsonDecode(_listingJson) as Map<String, Object?>;

const _detailJson = '''
{
  "id": "gpu-rtx-5090",
  "name": "NVIDIA GeForce RTX 5090",
  "brand": "NVIDIA",
  "family": "part",
  "category": "gpu",
  "priceCents": 799600000,
  "oldPriceCents": 919600000,
  "stockLevel": "stable",
  "imageUrl": "https://cdn.example.com/products/gpu-rtx-5090/thumb.webp",
  "summary": "24 GB GDDR6X, 2.5K, Ray tracing",
  "quickSpecs": ["ADALACE", "16384 CORES", "24GB GDDR6X", "450W"],
  "specs": [
    { "label": "VRAM", "value": "24GB GDDR6X" },
    { "label": "TDP", "value": "450W" }
  ],
  "offers": [
    {
      "id": "off-1001",
      "providerId": "prov-12",
      "providerName": "TecnoPartes SAS",
      "priceCents": 799600000,
      "oldPriceCents": 919600000,
      "stockLevel": "stable"
    }
  ]
}
''';

const _listingJson = '''
{
  "items": [
    {
      "id": "gpu-rtx-5090",
      "name": "NVIDIA GeForce RTX 5090",
      "brand": "NVIDIA",
      "family": "part",
      "category": "gpu",
      "priceCents": 799600000,
      "oldPriceCents": 919600000,
      "stockLevel": "stable",
      "imageUrl": "https://cdn.example.com/products/gpu-rtx-5090/thumb.webp",
      "summary": "24 GB GDDR6X, 2.5K, Ray tracing",
      "quickSpecs": ["ADALACE", "16384 CORES", "24GB GDDR6X", "450W"],
      "specs": [
        { "label": "VRAM", "value": "24GB GDDR6X" },
        { "label": "TDP", "value": "450W" }
      ],
      "offers": []
    },
    {
      "id": "cpu-ryzen-9-9950x",
      "name": "AMD Ryzen 9 9950X",
      "brand": "AMD",
      "family": "part",
      "category": "cpu",
      "priceCents": 259600000,
      "oldPriceCents": 279600000,
      "stockLevel": "stable",
      "imageUrl": null,
      "summary": "16 nucleos, 5.7 GHz, Zen 5",
      "quickSpecs": [],
      "specs": [],
      "offers": []
    }
  ],
  "total": 2,
  "page": 0,
  "pageSize": 20
}
''';
