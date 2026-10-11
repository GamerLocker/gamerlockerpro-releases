import 'dart:async';

import 'package:flutter/material.dart';

import 'app_localizations.dart' show gl;
import 'plan_service.dart';

class PlanValidity extends StatefulWidget {
  final PlanInfo plan;
  const PlanValidity({super.key, required this.plan});

  @override
  State<PlanValidity> createState() => _PlanValidityState();
}

class _PlanValidityState extends State<PlanValidity> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    if (gamerLockerMicrosoftStoreBuild) return const SizedBox.shrink();
    if (plan.isLifetime) return Text(gl('PRO vitalício — sem vencimento'));
    final days = plan.remainingDaysAt(DateTime.now());
    if (days == null) return const SizedBox.shrink();
    if (days == 0) return Text(gl('Seu período PRO terminou.'));
    final date = plan.expiresAt!.toLocal();
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gl('$days dias restantes de PRO')),
        Text('${gl('Válido até')}: $formatted'),
      ],
    );
  }
}
