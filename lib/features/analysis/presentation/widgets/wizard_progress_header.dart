import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class WizardProgressHeader extends StatelessWidget {
  const WizardProgressHeader({
    required this.currentStep,
    required this.labels,
    super.key,
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final label = labels[currentStep];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso ${currentStep + 1} de ${labels.length} · $label',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(labels.length, (index) {
              final isComplete = index < currentStep;
              final isCurrent = index == currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isComplete || isCurrent
                              ? AppColors.roadYellow
                              : AppColors.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < labels.length - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          if (!compact) ...[
            const SizedBox(height: 7),
            Row(
              children: List.generate(
                labels.length,
                (index) => Expanded(
                  child: Text(
                    index < currentStep ? '${labels[index]} ✓' : labels[index],
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: index == currentStep
                              ? AppColors.roadYellow
                              : AppColors.textSecondary,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
