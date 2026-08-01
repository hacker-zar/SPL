import 'package:flutter/material.dart';

import '../controllers/trip_quote_controller.dart';
import 'offer_costs_step.dart';
import 'review_step.dart';
import 'route_step.dart';
import 'vehicle_step.dart';
import 'wizard_progress_header.dart';

enum WizardStep { vehicle, route, offer, review }

class TripWizard extends StatelessWidget {
  const TripWizard({
    required this.controller,
    required this.step,
    required this.onStepChanged,
    required this.onCalculate,
    super.key,
  });

  final TripQuoteController controller;
  final WizardStep step;
  final ValueChanged<WizardStep> onStepChanged;
  final Future<void> Function() onCalculate;

  static const _labels = ['Vehículo', 'Ruta', 'Oferta', 'Revisar'];

  int get _index => step.index;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        children: [
          WizardProgressHeader(currentStep: _index, labels: _labels),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (controller.errorMessage != null)
                  _ErrorBanner(message: controller.errorMessage!),
                switch (step) {
                  WizardStep.vehicle => VehicleStep(controller: controller),
                  WizardStep.route => RouteStep(controller: controller),
                  WizardStep.offer => OfferCostsStep(controller: controller),
                  WizardStep.review => ReviewStep(
                      controller: controller,
                      onEdit: onStepChanged,
                    ),
                },
              ],
            ),
          ),
          _WizardActions(
            step: step,
            isRouteLoading: controller.isRouteLoading,
            onBack: _index == 0
                ? null
                : () => onStepChanged(WizardStep.values[_index - 1]),
            onContinue: _continue,
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    if (step == WizardStep.review) {
      await onCalculate();
      return;
    }
    final canAdvance = switch (step) {
      WizardStep.vehicle => controller.validateVehicleStep(),
      WizardStep.route => controller.validateRouteStep(),
      WizardStep.offer => controller.validateOfferStep(),
      WizardStep.review => false,
    };
    if (canAdvance) {
      onStepChanged(WizardStep.values[_index + 1]);
    }
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.step,
    required this.isRouteLoading,
    required this.onBack,
    required this.onContinue,
  });

  final WizardStep step;
  final bool isRouteLoading;
  final VoidCallback? onBack;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final isReview = step == WizardStep.review;
    final blocked = step == WizardStep.route && isRouteLoading;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2C3338))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              if (onBack != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Atrás'),
                  ),
                )
              else
                const Spacer(),
              if (onBack != null) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: blocked ? null : () async => onContinue(),
                  icon: Icon(
                    isReview ? Icons.analytics_outlined : Icons.arrow_forward,
                  ),
                  label: Text(isReview ? 'Calcular viaje' : 'Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}
