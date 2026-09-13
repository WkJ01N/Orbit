import 'package:flutter/material.dart';

/// Reserve enough height for translated titles without squeezing the actions.
AppBar settingsAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  final style =
      Theme.of(context).appBarTheme.titleTextStyle ??
      Theme.of(context).textTheme.titleLarge!;
  final painter =
      TextPainter(
        text: TextSpan(text: title, style: style),
        maxLines: 2,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(
        maxWidth:
            (MediaQuery.sizeOf(context).width -
                    (actions?.isNotEmpty == true ? 168 : 112))
                .clamp(32.0, double.infinity),
      );
  final height = (painter.height + 16).clamp(kToolbarHeight, double.infinity);
  painter.dispose();
  return AppBar(
    toolbarHeight: height,
    title: Text(title, maxLines: 2, textAlign: TextAlign.center),
    actions: actions,
  );
}
