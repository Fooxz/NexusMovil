// lib/screens/pc_builder/pc_builder_screen.dart
//
// PC Builder. Los componentes, el progreso y el resumen de precio están
// fijos (mockup) — el motor de reglas de compatibilidad real (RN-10 del
// documento de negocio) se conectará más adelante.

import 'package:flutter/material.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_top_bar.dart';
import '../../widgets/nexus_widgets.dart';

class PcBuilderScreen extends StatelessWidget {
  const PcBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NexusTopBar(title: 'PC BUILDER', trailingBadge: 'NXS.v1.0'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Arma tu PC ideal. Verificamos compatibilidad en tiempo real.',
                      style: NexusText.body,
                    ),
                    const SizedBox(height: 16),
                    const _ViewerBox(),
                    const SizedBox(height: 20),
                    const NexusBracketTitle('SELECCIÓN DE COMPONENTES'),
                    const SizedBox(height: 12),
                    const _ComponentCard(
                      category: 'CPU',
                      name: 'AMD Ryzen 7 9800X3D',
                      price: '\$799.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(
                      category: 'Motherboard',
                      name: 'ASRock X670E Taichi',
                      price: '\$499.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(
                      category: 'GPU',
                      name: 'NVIDIA GeForce RTX 5080',
                      price: '\$1,249.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(
                      category: 'RAM Slot 1',
                      name: 'Corsair Vengeance 16GB DDR5',
                      price: '\$69.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(
                      category: 'RAM Slot 2',
                      name: 'Corsair Vengeance 16GB DDR5',
                      price: '\$69.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(
                      category: 'Almacenamiento',
                      name: 'WD Black SN850X 2TB',
                      price: '\$249.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(
                      category: 'PSU',
                      name: 'EVGA 850 GA, 80+ Gold',
                      price: '\$139.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(
                      category: 'Refrigeración',
                      name: 'Noctua NH-U14S TR4-SP3',
                      price: '\$39.00',
                    ),
                    const SizedBox(height: 10),
                    const _ComponentCard(category: 'Gabinete', isEmpty: true),
                    const SizedBox(height: 24),
                    const NexusBracketTitle('RESUMEN'),
                    const SizedBox(height: 16),
                    const _ProgressSummary(),
                    const SizedBox(height: 18),
                    NexusCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'COMPONENTES REQUERIDOS',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: NexusColors.textDim),
                          ),
                          SizedBox(height: 6),
                          NexusSpecRow('CPU', 'OK', valueColor: NexusColors.cyan),
                          NexusSpecRow('Motherboard', 'OK', valueColor: NexusColors.cyan),
                          NexusSpecRow('GPU', 'OK', valueColor: NexusColors.cyan),
                          NexusSpecRow('RAM', 'OK', valueColor: NexusColors.cyan),
                          NexusSpecRow('Almacenamiento', 'OK', valueColor: NexusColors.cyan),
                          NexusSpecRow('PSU', 'OK', valueColor: NexusColors.cyan),
                          NexusSpecRow('Refrigeración', 'OK', valueColor: NexusColors.cyan),
                          NexusSpecRow('Gabinete', 'Vacío', valueColor: NexusColors.pink),
                          Divider(color: NexusColors.border, height: 22),
                          Text(
                            'DESGLOSE DE PRECIO',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: NexusColors.textDim),
                          ),
                          SizedBox(height: 6),
                          NexusSpecRow('CPU', '\$799.00'),
                          NexusSpecRow('Motherboard', '\$499.00'),
                          NexusSpecRow('GPU', '\$1,249.00'),
                          NexusSpecRow('RAM', '\$138.00'),
                          NexusSpecRow('Almacenamiento', '\$249.00'),
                          NexusSpecRow('PSU', '\$139.00'),
                          NexusSpecRow('Refrigeración', '\$39.00'),
                          NexusSpecRow('Gabinete', '\$0.00'),
                          Divider(color: NexusColors.border, height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text(
                                '\$3,412.00',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NexusColors.cyan),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          NexusSpecRow('Consumo estimado', '580W // 850W MAX'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        _StatusDotLabel(label: 'Compatible', color: NexusColors.green),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const NexusPrimaryButton(label: 'Comprar ahora'),
                    const SizedBox(height: 10),
                    const NexusOutlineButton(label: 'Agregar al carrito', color: NexusColors.pink),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const NexusBottomNav(currentIndex: 2),
    );
  }
}

class _ViewerBox extends StatelessWidget {
  const _ViewerBox();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF10161B), Color(0xFF0A0D10)],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.dvr, size: 56, color: NexusColors.cyan),
            ),
            const _CornerBracket(alignment: Alignment.topLeft),
            const _CornerBracket(alignment: Alignment.topRight),
            const _CornerBracket(alignment: Alignment.bottomLeft),
            const _CornerBracket(alignment: Alignment.bottomRight),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'VISTA 3D // GABINETE',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: NexusColors.textDim),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 13, color: NexusColors.textDim),
                SizedBox(width: 4),
                Text('Rotar', style: TextStyle(fontSize: 9, color: NexusColors.textDim)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            border: Border(
              top: isTop ? const BorderSide(color: NexusColors.cyan, width: 2) : BorderSide.none,
              bottom: !isTop ? const BorderSide(color: NexusColors.cyan, width: 2) : BorderSide.none,
              left: isLeft ? const BorderSide(color: NexusColors.cyan, width: 2) : BorderSide.none,
              right: !isLeft ? const BorderSide(color: NexusColors.cyan, width: 2) : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.category,
    this.name,
    this.price,
    this.isEmpty = false,
  });

  final String category;
  final String? name;
  final String? price;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: NexusColors.textDim),
              ),
              NexusTag(isEmpty ? 'Vacío' : 'Compatible', color: isEmpty ? NexusColors.pink : NexusColors.cyan),
            ],
          ),
          const SizedBox(height: 6),
          if (isEmpty) ...[
            const Text(
              'Haz clic para seleccionar',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: NexusColors.pink),
            ),
            const SizedBox(height: 10),
            const NexusOutlineButton(label: 'Seleccionar', color: NexusColors.pink),
          ] else ...[
            Text(
              name!,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 3),
            Text(
              price!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: NexusColors.cyan),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NexusColors.text,
                      side: const BorderSide(color: NexusColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Editar', style: TextStyle(fontSize: 10.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NexusColors.pink,
                      side: BorderSide(color: NexusColors.pink.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Eliminar', style: TextStyle(fontSize: 10.5)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: 8 / 9,
                  strokeWidth: 8,
                  backgroundColor: NexusColors.border,
                  valueColor: const AlwaysStoppedAnimation(NexusColors.cyan),
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('8 / 9', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('89%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NexusColors.cyan)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '1 componente pendiente',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: NexusColors.pink),
        ),
      ],
    );
  }
}

class _StatusDotLabel extends StatelessWidget {
  const _StatusDotLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          'Estado de compatibilidad: $label',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
