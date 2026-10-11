import 'package:flutter/material.dart';

Future<String?> askSteamGuardCode(
  BuildContext context, {
  required String hint,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SteamGuardDialog(hint: hint),
);

class _SteamGuardDialog extends StatefulWidget {
  final String hint;
  const _SteamGuardDialog({required this.hint});
  @override
  State<_SteamGuardDialog> createState() => _SteamGuardDialogState();
}

class _SteamGuardDialogState extends State<_SteamGuardDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Steam Guard'),
    content: TextField(
      controller: controller,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(labelText: widget.hint),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Continuar'),
      ),
    ],
  );
}
