import 'package:flutter/material.dart';

import '../core/ui_kit.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'YES',
  String cancelLabel = 'NO',
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xCC000000),
    builder: (BuildContext context) => _GoldDialog(
      title: title,
      message: message,
      actions: <Widget>[
        PlaqueButton(
          label: cancelLabel,
          height: 52,
          fontSize: 17,
          onTap: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: 8),
        PlaqueButton(
          label: confirmLabel,
          height: 52,
          fontSize: 17,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC000000),
    builder: (BuildContext context) => _GoldDialog(
      title: title,
      message: message,
      actions: <Widget>[
        PlaqueButton(
          label: buttonLabel,
          height: 52,
          fontSize: 17,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

class _GoldDialog extends StatelessWidget {
  const _GoldDialog({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: goldPanelDecoration(radius: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StrokedText(
                  title,
                  size: 21,
                  color: AppPalette.goldLight,
                  strokeWidth: 4,
                  letterSpacing: 1.4,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE4CCA3),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
