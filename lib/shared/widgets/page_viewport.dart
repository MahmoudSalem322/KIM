import 'package:flutter/material.dart';

/// Scroll inside each route. A ShellRoute's Navigator must stay bounded.
class PageViewport extends StatelessWidget {
  const PageViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 900 ? 32 : 20),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: child,
      ),
    ),
  );
}
