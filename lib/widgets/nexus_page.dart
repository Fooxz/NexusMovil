import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';
import 'nexus_top_bar.dart';

class NexusPage extends StatelessWidget {
  const NexusPage({
    super.key,
    required this.title,
    this.children = const <Widget>[],
    this.showBack = false,
    this.showCart = true,
    this.trailingBadge,
    this.horizontalPadding = 16,
    this.slivers,
  });

  const NexusPage.slivers({
    super.key,
    required this.title,
    required this.slivers,
    this.showBack = false,
    this.showCart = true,
    this.trailingBadge,
    this.horizontalPadding = 16,
  }) : children = const <Widget>[];

  final String title;
  final bool showBack;
  final bool showCart;
  final String? trailingBadge;
  final List<Widget> children;
  final List<Widget>? slivers;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final slivers = this.slivers;

    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: slivers == null
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NexusTopBar(
                      title: title,
                      showBack: showBack,
                      showCart: showCart,
                      trailingBadge: trailingBadge,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: NexusTopBar(
                      title: title,
                      showBack: showBack,
                      showCart: showCart,
                      trailingBadge: trailingBadge,
                    ),
                  ),
                  ...slivers,
                ],
              ),
      ),
    );
  }
}
