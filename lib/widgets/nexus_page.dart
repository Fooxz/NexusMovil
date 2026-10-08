import 'package:flutter/material.dart';

import '../theme/nexus_theme.dart';
import 'nexus_top_bar.dart';

class NexusPage extends StatelessWidget {
  const NexusPage({
    super.key,
    required this.title,
    required this.children,
    this.showBack = false,
    this.showCart = true,
    this.trailingBadge,
    this.bottomNavigationBar,
    this.horizontalPadding = 16,
  });

  final String title;
  final bool showBack;
  final bool showCart;
  final String? trailingBadge;
  final List<Widget> children;
  final Widget? bottomNavigationBar;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
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
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
