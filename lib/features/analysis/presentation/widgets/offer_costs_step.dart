import 'package:flutter/material.dart';

import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../controllers/trip_quote_controller.dart';

class OfferCostsStep extends StatefulWidget {
  const OfferCostsStep({required this.controller, super.key});

  final TripQuoteController controller;

  @override
  State<OfferCostsStep> createState() => _OfferCostsStepState();
}

class _OfferCostsStepState extends State<OfferCostsStep> {
  late final TextEditingController flatRateController;
  late final TextEditingController tonsController;
  late final TextEditingController pricePerTonController;
  late final TextEditingController fuelPriceController;
  late final TextEditingController tollsController;
  late final TextEditingController allowancesController;
  bool showAdjustments = false;

  TripQuoteController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    flatRateController = TextEditingController(text: _numberText(controller.flatRate));
    tonsController = TextEditingController(text: _numberText(controller.tons));
    pricePerTonController = TextEditingController(text: _numberText(controller.pricePerTon));
    fuelPriceController = TextEditingController(text: _numberText(controller.costs.fuelPricePerLiter));
    tollsController = TextEditingController(text: _numberText(controller.costs.tolls));
    allowancesController = TextEditingController(text: _numberText(controller.costs.allowances));
  }

  @override
  void dispose() {
    flatRateController.dispose();
    tonsController.dispose();
    pricePerTonController.dispose();
    fuelPriceController.dispose();
    tollsController.dispose();
    allowancesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tollEstimate = controller.tollEstimate;
    final overCapacity = controller.pricingMode == PricingMode.perTon &&
        controller.vehicleProfile != null &&
        controller.tons > controller.vehicleProfile!.capacityTons;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mi oferta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Ingresá cuánto te pagan y el costo de combustible.'),
            const SizedBox(height: 12),
            SegmentedButton<PricingMode>(
              segments: PricingMode.values
                  .map((mode) => ButtonSegment(value: mode, label: Text(mode.label)))
                  .toList(),
              selected: {controller.pricingMode},
              onSelectionChanged: (selected) => controller.setPricingMode(selected.first),
            ),
            const SizedBox(height: 10),
            if (controller.pricingMode == PricingMode.flatRate)
              _NumberField(
                controller: flatRateController,
                label: 'Precio del viaje',
                onChanged: controller.setFlatRate,
              )
            else ...[
              _NumberField(
                controller: tonsController,
                label: 'Toneladas',
                onChanged: controller.setTons,
              ),
              const SizedBox(height: 10),
              _NumberField(
                controller: pricePerTonController,
                label: 'Precio por tonelada',
                onChanged: controller.setPricePerTon,
              ),
            ],
            if (overCapacity) ...[
              const SizedBox(height: 10),
              Text(
                'Tu vehículo tiene capacidad para ${decimal(controller.vehicleProfile!.capacityTons)} toneladas. Ajustá la carga o el vehículo.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            _NumberField(
              controller: fuelPriceController,
              label: 'Combustible por litro',
              onChanged: controller.setFuelPrice,
            ),
            const SizedBox(height: 12),
            MetricTile(label: 'Ingreso estimado', value: money(controller.grossIncome)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => showAdjustments = !showAdjustments),
              icon: Icon(showAdjustments ? Icons.expand_less : Icons.tune),
              label: Text(showAdjustments ? 'Ocultar costos y ajustes' : 'Mostrar costos y ajustes'),
            ),
            if (showAdjustments) ...[
              if (tollEstimate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Peajes estimados para ${decimal(tollEstimate.distanceKm)} km.'),
                ),
              _NumberField(
                controller: tollsController,
                label: controller.tollsEditedManually ? 'Peajes editados' : 'Peajes estimados',
                onChanged: controller.setTolls,
                trailing: tollEstimate == null
                    ? null
                    : IconButton(
                        tooltip: 'Usar peaje estimado',
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          controller.useEstimatedTolls();
                          tollsController.text = _numberText(controller.costs.tolls);
                        },
                      ),
              ),
              const SizedBox(height: 10),
              _NumberField(
                controller: allowancesController,
                label: 'Viáticos',
                onChanged: controller.setAllowances,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<double> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixIcon: trailing),
      onChanged: (value) => onChanged(_parseNumber(value)),
    );
  }
}

double _parseNumber(String value) => double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;

String _numberText(double value) => value == 0
    ? ''
    : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
