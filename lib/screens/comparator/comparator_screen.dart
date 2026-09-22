// lib/screens/comparator/comparator_screen.dart
//
// Comparador de celulares. Los dos dispositivos y la tabla son fijos
// (mockup): la selección real de "Celular A" / "Celular B" y el cálculo
// de diferencias llegarán cuando el comparador use datos del catálogo.

import 'package:flutter/material.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_top_bar.dart';

class ComparatorScreen extends StatelessWidget {
  const ComparatorScreen({super.key});

  static const _categories = [
    'PRECIO',
    'PANTALLA',
    'PROCESADOR',
    'RAM',
    'ALMACENAMIENTO',
    'CÁMARA',
    'BATERÍA',
    'NFC',
    '5G',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NexusTopBar(title: 'COMPARADOR'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'SELECCIONA DOS CELULARES Y DESCUBRE CUÁL DOMINA EN CADA ASPECTO.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                        color: NexusColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: const [
                            Expanded(
                              child: _PhoneSlot(
                                label: 'CELULAR A',
                                accent: NexusColors.cyan,
                                name: 'Samsung S26 Ultra',
                              ),
                            ),
                            SizedBox(width: 44),
                            Expanded(
                              child: _PhoneSlot(
                                label: 'CELULAR B',
                                accent: NexusColors.pink,
                                name: 'iPhone 17 Pro Max',
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: NexusColors.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: NexusColors.border, width: 1.4),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: NexusColors.card,
                        border: Border.all(color: NexusColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            color: NexusColors.bgAlt,
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'CATEGORÍA',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: NexusColors.textDim),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'CELULAR A',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: NexusColors.cyan),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'CELULAR B',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: NexusColors.pink),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final c in _categories) _ComparisonRow(label: c),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: NexusColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '// ANÁLISIS EN VIVO',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: NexusColors.cyan),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'La tabla se actualizará automáticamente cuando ambos dispositivos estén cargados.',
                            style: TextStyle(fontSize: 10.5, height: 1.5, color: NexusColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NexusBottomNav(currentIndex: 3),
    );
  }
}

class _PhoneSlot extends StatelessWidget {
  const _PhoneSlot({required this.label, required this.accent, required this.name});

  final String label;
  final Color accent;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: accent),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(5)),
                child: const Icon(Icons.add, size: 15, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
              color: NexusColors.bgAlt,
            ),
            child: Icon(Icons.smartphone, size: 30, color: accent.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: NexusColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 10, color: NexusColors.textDim)),
          ),
          const Expanded(
            child: Text('-', textAlign: TextAlign.center, style: TextStyle(color: NexusColors.cyan, fontWeight: FontWeight.bold)),
          ),
          const Expanded(
            child: Text('-', textAlign: TextAlign.center, style: TextStyle(color: NexusColors.pink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
