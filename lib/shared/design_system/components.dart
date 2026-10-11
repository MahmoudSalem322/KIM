import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class WalletButton extends StatelessWidget {
  const WalletButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 10)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return secondary
        ? OutlinedButton(onPressed: onPressed, child: content)
        : FilledButton(onPressed: onPressed, child: content);
  }
}

class WalletTextField extends StatelessWidget {
  const WalletTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
  });
  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool enabled, obscureText;
  @override
  Widget build(BuildContext context) => TextFormField(
    enabled: enabled,
    obscureText: obscureText,
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label),
  );
}

Future<void> showWalletInfo(
  BuildContext context, {
  required String title,
  required String body,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: SingleChildScrollView(child: Text(body)),
    actions: [
      WalletButton(
        label: AppStrings.of(context)('close'),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  ),
);

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon = Icons.check_circle_outline_rounded,
  });
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
