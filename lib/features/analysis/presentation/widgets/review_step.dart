import 'package:flutter/material.dart';

import '../../../../core/utils/money_format.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../controllers/trip_quote_controller.dart';
import 'trip_wizard.dart';

class ReviewStep extends StatelessWidget {
  const ReviewStep({
    required this.controller,
    required this.onEdit,
    super.key,
  });

  final TripQuoteController controller;
  final ValueChanged<WizardStep> onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = controller.vehicleProfile;
    final route = controller.effectiveRoute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Revisá los datos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('La recomendación se calculará con esta información.'),
        const SizedBox(height: 12),
        _ReviewCard(
          title: 'Vehículo',
          onEdit: () => onEdit(WizardStep.vehicle),
          child: profile == null
              ? const Text('Vehículo sin configurar')
              : Text(
                  '${decimal(profile.consumptionLitersPer100Km)} L/100 km · ${money(profile.maintenanceCostPerKm)}/km · ${decimal(profile.capacityTons)} tn',
                ),
        ),
        const SizedBox(height: 10),
        _ReviewCard(
          title: 'Ruta',
          onEdit: () => onEdit(WizardStep.route),
          child: route == null
              ? const Text('Ruta sin calcular')
              : Text(
                  '${route.originName} → ${route.destinationName}\n${decimal(route.distanceKm)} km · ${decimal(route.durationMinutes / 60)} h${controller.emptyReturn ? ' · Vuelvo vacío' : ''}',
                ),
        ),
        const SizedBox(height: 10),
        _ReviewCard(
          title: 'Oferta y costos',
          onEdit: () => onEdit(WizardStep.offer),
          child: Text(
            '${controller.pricingMode == PricingMode.flatRate ? 'Precio del viaje' : 'Ingreso por carga'}: ${money(controller.grossIncome)}\n'
            'Combustible: ${money(controller.costs.fuelPricePerLiter)}/l · Peajes: ${money(controller.costs.tolls)} · Viáticos: ${money(controller.costs.allowances)}',
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.child,
    required this.onEdit,
  });

  final String title;
  final Widget child;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}
