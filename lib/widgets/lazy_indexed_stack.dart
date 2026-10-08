import 'package:flutter/material.dart';

class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _visited = List.filled(widget.children.length, false);

  @override
  Widget build(BuildContext context) {
    _visited[widget.index] = true;

    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _visited[i]
              ? TickerMode(enabled: i == widget.index, child: widget.children[i])
              : const SizedBox.shrink(),
      ],
    );
  }
}
