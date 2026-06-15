import 'package:flutter/material.dart';
import 'package:orbit/core/theme/layout_breakpoints.dart';

/// Shows a bottom sheet on narrow screens and a centred [Dialog] on wider
/// ones (width >= [kNarrowDialogBreakpoint]).
///
/// [isScrollControlled] is forwarded to [showModalBottomSheet] on narrow
/// screens; it has no effect in dialog mode.
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= kNarrowDialogBreakpoint) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: builder(dialogContext),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}
