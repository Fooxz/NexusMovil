import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/format_price.dart';
import '../../../theme/nexus_theme.dart';
import '../domain/admin_console_models.dart';

/// Color de las marcas de los gráficos: el cian de NEXUS un paso más oscuro,
/// para quedar dentro de la banda de luminosidad sobre la tarjeta oscura
/// (validado con el contraste mínimo de 3:1). El texto nunca lo usa.
const chartColor = Color(0xFF22A8A3);

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "28 oct".
String shortDate(DateTime date) => '${date.day} ${_months[date.month - 1]}';

/// Pesos en corto para los ejes: "$0", "$850 mil", "$2,9 M".
String compactPrice(int cents) {
  final pesos = cents / 100;
  String decimal(double value) {
    final text = value >= 10 ? value.round().toString() : value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text.replaceAll('.', ',');
  }

  if (pesos >= 1000000) return '\$${decimal(pesos / 1000000)} M';
  if (pesos >= 1000) return '\$${decimal(pesos / 1000)} mil';
  return '\$${pesos.round()}';
}

/// Ventas de cada día de los últimos 30: columnas con la punta redondeada.
/// Tocar o deslizar sobre el gráfico muestra el día; "Ver tabla" lista los
/// valores para quien no lee el gráfico.
class DailySalesChart extends StatefulWidget {
  const DailySalesChart({super.key, required this.series});

  final List<DailyPoint> series;

  @override
  State<DailySalesChart> createState() => _DailySalesChartState();
}

class _DailySalesChartState extends State<DailySalesChart> {
  int? _selected;
  var _table = false;

  static const _height = 150.0;
  static const _axisWidth = 52.0;

  void _select(Offset position, double width) {
    final count = widget.series.length;
    if (count == 0) return;
    final plotWidth = width - _axisWidth;
    final index = ((position.dx - _axisWidth) / plotWidth * count).floor().clamp(0, count - 1);
    if (index != _selected) setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final total = series.fold(0, (sum, day) => sum + day.salesCents);
    final selected = _selected == null ? null : series[_selected!];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: NexusColors.card,
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El detalle del día tocado reemplaza al total de los 30 días.
          Text(
            selected == null
                ? 'Últimos 30 días: ${formatPrice(total)}'
                : '${shortDate(selected.date)}: ${formatPrice(selected.salesCents)} · '
                      '${selected.orders == 1 ? '1 pedido' : '${selected.orders} pedidos'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: NexusColors.text),
          ),
          Text(
            selected == null
                ? 'Toca una columna para ver el día.'
                : 'Comisión de NEXUS: ${formatPrice(selected.commissionCents)}',
            style: const TextStyle(fontSize: 10.5, color: NexusColors.textDim),
          ),
          const SizedBox(height: 10),
          if (_table)
            _SalesTable(series: series)
          else
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _select(details.localPosition, constraints.maxWidth),
                onHorizontalDragUpdate: (details) => _select(details.localPosition, constraints.maxWidth),
                child: Semantics(
                  label: 'Ventas diarias de los últimos 30 días. Total ${formatPrice(total)}.',
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, _height + 18),
                    painter: _ColumnsPainter(series: series, selected: _selected, axisWidth: _axisWidth),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _table = !_table;
                _selected = null;
              }),
              child: Text(_table ? 'Ver gráfico' : 'Ver tabla', style: const TextStyle(fontSize: 11.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTable extends StatelessWidget {
  const _SalesTable({required this.series});

  final List<DailyPoint> series;

  @override
  Widget build(BuildContext context) {
    final days = series.where((day) => day.salesCents > 0 || day.orders > 0).toList().reversed;
    if (days.isEmpty) {
      return const Text('Sin ventas en estos 30 días.', style: TextStyle(fontSize: 12, color: NexusColors.textDim));
    }
    const style = TextStyle(fontSize: 11.5, color: NexusColors.text, fontFeatures: [FontFeature.tabularFigures()]);
    return Column(
      children: [
        for (final day in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(shortDate(day.date), style: style)),
                Expanded(child: Text(day.orders == 1 ? '1 pedido' : '${day.orders} pedidos', style: style)),
                Text(formatPrice(day.salesCents), style: style),
              ],
            ),
          ),
      ],
    );
  }
}

class _ColumnsPainter extends CustomPainter {
  _ColumnsPainter({required this.series, required this.selected, required this.axisWidth});

  final List<DailyPoint> series;
  final int? selected;
  final double axisWidth;

  static const _labelHeight = 18.0;

  /// Máximo redondeado hacia arriba a 1, 2 o 5 por potencia de diez, para
  /// que las marcas del eje sean números limpios.
  static int _niceMax(int value) {
    if (value <= 0) return 100000000;
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toInt();
    for (final step in const [1, 2, 5, 10]) {
      if (step * magnitude >= value) return step * magnitude;
    }
    return 10 * magnitude;
  }

  void _text(Canvas canvas, String text, Offset at, {TextAlign align = TextAlign.left, double width = 60}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 9.5, color: NexusColors.textFaint),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final plotHeight = size.height - _labelHeight;
    final plotWidth = size.width - axisWidth;
    final maxValue = _niceMax(series.map((day) => day.salesCents).reduce(math.max));

    // Cuadrícula: tres líneas finas y sus valores.
    final grid = Paint()
      ..color = NexusColors.border
      ..strokeWidth = 1;
    for (var step = 0; step <= 2; step++) {
      final y = plotHeight - plotHeight * step / 2;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), grid);
      _text(canvas, compactPrice(maxValue * step ~/ 2), Offset(0, y - 6), width: axisWidth - 6, align: TextAlign.right);
    }

    // Columnas: de hasta 24 px, con 2 px de aire entre vecinas.
    final slot = plotWidth / series.length;
    final width = math.min(24.0, slot - 2);
    final radius = Radius.circular(math.min(4, width / 2));
    for (var i = 0; i < series.length; i++) {
      final value = series[i].salesCents;
      if (value <= 0) continue;
      final height = math.max(2.0, plotHeight * value / maxValue);
      final left = axisWidth + slot * i + (slot - width) / 2;
      final paint = Paint()
        ..color = selected == null || selected == i ? chartColor : chartColor.withValues(alpha: 0.45);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, plotHeight - height, width, height),
          topLeft: radius,
          topRight: radius,
        ),
        paint,
      );
    }

    // Fechas: la primera, la del medio y la última.
    for (final i in {0, series.length ~/ 2, series.length - 1}) {
      final center = axisWidth + slot * i + slot / 2;
      final align = i == 0
          ? TextAlign.left
          : i == series.length - 1
          ? TextAlign.right
          : TextAlign.center;
      final left = switch (align) {
        TextAlign.left => center - slot / 2,
        TextAlign.right => center + slot / 2 - 60,
        _ => center - 30,
      };
      _text(canvas, shortDate(series[i].date), Offset(left, plotHeight + 4), align: align);
    }
  }

  @override
  bool shouldRepaint(_ColumnsPainter oldDelegate) => oldDelegate.series != series || oldDelegate.selected != selected;
}

/// Ventas por tipo de pieza: barras horizontales con el valor en la punta.
class CategoryBars extends StatelessWidget {
  const CategoryBars({super.key, required this.rows, required this.labelFor});

  final List<CategorySales> rows;
  final String Function(CategorySales) labelFor;

  static const _valueStyle = TextStyle(fontSize: 11, color: NexusColors.textDim);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text(
        'Sin ventas en los últimos 30 días.',
        style: TextStyle(fontSize: 12, color: NexusColors.textDim),
      );
    }
    final maxValue = rows.map((row) => row.salesCents).reduce(math.max);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NexusColors.card,
        border: Border.all(color: NexusColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${labelFor(row)} · ${row.units == 1 ? '1 unidad' : '${row.units} unidades'}',
                    style: const TextStyle(fontSize: 11.5, color: NexusColors.text),
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Se mide el valor para que quepa entero en la punta.
                      final value = TextPainter(
                        text: TextSpan(text: formatPrice(row.salesCents), style: _valueStyle),
                        textDirection: TextDirection.ltr,
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout();
                      final barWidth = math.max(
                        4.0,
                        (constraints.maxWidth - value.width - 8) * (maxValue == 0 ? 0 : row.salesCents / maxValue),
                      );
                      return Row(
                        children: [
                          Container(
                            width: barWidth,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: chartColor,
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // El tema puede usar otra fuente que la medida: el valor cede
                          // esos píxeles antes que desbordar.
                          Flexible(child: Text(formatPrice(row.salesCents), style: _valueStyle, softWrap: false)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
