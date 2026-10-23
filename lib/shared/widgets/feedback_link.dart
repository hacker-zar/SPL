import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

class FeedbackLink extends StatelessWidget {
  const FeedbackLink({required this.phoneNumber, super.key});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    if (!RegExp(r'^[0-9]+$').hasMatch(phoneNumber)) {
      return const SizedBox.shrink();
    }

    final uri = Uri.https('wa.me', '/$phoneNumber', {
      'text': 'Hola, quiero contarte algo sobre Netokm: ',
    });
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        child: const Text('¿Algo no cierra? Contanos'),
      ),
    );
  }
}
