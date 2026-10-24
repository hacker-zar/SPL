import 'package:flutter/material.dart';

import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/parse_amount.dart';
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
  late final TextEditingController travelersController;

  TripQuoteController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    flatRateController =
        TextEditingController(text: _numberText(controller.flatRate));
    tonsController = TextEditingController(text: _numberText(controller.tons));
    pricePerTonController =
        TextEditingController(text: _numberText(controller.pricePerTon));
    fuelPriceController = TextEditingController(
        text: _numberText(controller.costs.fuelPricePerLiter));
    tollsController =
        TextEditingController(text: _numberText(controller.costs.tolls));
    allowancesController =
        TextEditingController(text: _numberText(controller.costs.allowances));
    travelersController =
        TextEditingController(text: controller.travelers.toString());
  }

  @override
  void dispose() {
    flatRateController.dispose();
    tonsController.dispose();
    pricePerTonController.dispose();
    fuelPriceController.dispose();
    tollsController.dispose();
    allowancesController.dispose();
    travelersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personal = controller.purpose == TripPurpose.personal;
    final tollEstimate = controller.tollEstimate;
    final overCapacity = controller.pricingMode == PricingMode.perTon &&
        controller.activeVehicle != null &&
        controller.tons > controller.activeVehicle!.capacityTons;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(personal ? 'Costos del viaje' : 'Mi oferta',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(personal
                ? 'Ingresá los gastos estimados de tu viaje.'
                : 'Ingresá cuánto te pagan y el costo de combustible.'),
            const SizedBox(height: 12),
            if (!personal)
              SegmentedButton<PricingMode>(
                segments: PricingMode.values
                    .map((mode) =>
                        ButtonSegment(value: mode, label: Text(mode.label)))
                    .toList(),
                selected: {controller.pricingMode},
                onSelectionChanged: (selected) =>
                    controller.setPricingMode(selected.first),
              ),
            if (!personal) const SizedBox(height: 10),
            if (!personal && controller.pricingMode == PricingMode.flatRate)
              _NumberField(
                controller: flatRateController,
                label: 'Precio del viaje',
                onChanged: (value) =>
                    _setValue('flatRate', value, controller.setFlatRate),
              )
            else if (!personal) ...[
              _NumberField(
                controller: tonsController,
                label: 'Toneladas',
                currency: false,
                onChanged: (value) =>
                    _setValue('tons', value, controller.setTons),
              ),
              const SizedBox(height: 10),
              _NumberField(
                controller: pricePerTonController,
                label: 'Precio por tonelada',
                onChanged: (value) =>
                    _setValue('pricePerTon', value, controller.setPricePerTon),
              ),
            ],
            if (overCapacity) ...[
              const SizedBox(height: 10),
              Text(
                'Tu vehículo tiene capacidad para ${decimal(controller.activeVehicle!.capacityTons)} toneladas. Ajustá la carga o el vehículo.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            _NumberField(
              controller: fuelPriceController,
              label: 'Combustible por litro',
              positive: true,
              onChanged: (value) => _setValue(
                  'fuelPrice', value, controller.setFuelPrice,
                  positive: true),
            ),
            if (!personal && controller.pricingMode == PricingMode.perTon) ...[
              const SizedBox(height: 12),
              MetricTile(
                label: 'Ingreso estimado',
                value: money(controller.grossIncome),
              ),
            ],
            const SizedBox(height: 10),
            _NumberField(
              controller: tollsController,
              label:
                  'Peajes (total del viaje, incluida la vuelta si corresponde)',
              onChanged: (value) =>
                  _setValue('tolls', value, controller.setTolls),
              trailing: tollEstimate == null
                  ? null
                  : IconButton(
                      tooltip: 'Usar peaje estimado',
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        controller.useEstimatedTolls();
                        tollsController.text =
                            _numberText(controller.costs.tolls);
                      },
                    ),
            ),
            if (controller.costs.tolls == 0)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Sin peajes cargados. Si tu ruta tiene, cargalos.'),
              )
            else if (!personal && tollEstimate != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'Peajes estimados para ${decimal(tollEstimate.distanceKm)} km.'),
              ),
            if (!personal && controller.tollsEditedManually)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Revisá si el monto de peajes incluye la vuelta.'),
              ),
            const SizedBox(height: 10),
            _NumberField(
              controller: allowancesController,
              label:
                  personal ? 'Otros gastos (comida, alojamiento)' : 'Viáticos',
              onChanged: (value) =>
                  _setValue('allowances', value, controller.setAllowances),
            ),
            if (personal) ...[
              const SizedBox(height: 10),
              _TravelerField(
                controller: travelersController,
                onChanged: controller.setTravelers,
                onValidityChanged: (valid) =>
                    controller.setOfferFieldValidity('travelers', valid),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setValue(String name, double? value, ValueChanged<double> setter,
      {bool positive = false}) {
    final valid = value != null && (positive ? value > 0 : value >= 0);
    controller.setOfferFieldValidity(name, valid);
    if (valid) setter(value);
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.currency = true,
    this.positive = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<double?> onChanged;
  final bool currency;
  final bool positive;
  final Widget? trailing;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  double? parsed;
  bool invalid = false;

  @override
  void initState() {
    super.initState();
    parsed = parseAmount(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: widget.trailing,
          errorText: invalid ? 'Ingresá un número válido.' : null,
          helperText: !invalid && parsed != null
              ? (widget.currency ? money(parsed!) : decimal(parsed!))
              : null,
        ),
        onChanged: (text) {
          final value = parseAmount(text);
          final valid =
              value != null && (widget.positive ? value > 0 : value >= 0);
          setState(() {
            parsed = value;
            invalid = !valid;
          });
          widget.onChanged(valid ? value : null);
        },
      );
}

class _TravelerField extends StatefulWidget {
  const _TravelerField(
      {required this.controller,
      required this.onChanged,
      required this.onValidityChanged});
  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  final ValueChanged<bool> onValidityChanged;
  @override
  State<_TravelerField> createState() => _TravelerFieldState();
}

class _TravelerFieldState extends State<_TravelerField> {
  bool invalid = false;
  int? parsed;
  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Cantidad de personas que comparten los gastos',
          helperText: invalid
              ? null
              : 'Mínimo: 1 persona${parsed == null ? '' : ' · $parsed'}',
          errorText:
              invalid ? 'Ingresá una cantidad entera de al menos 1.' : null,
        ),
        onChanged: (text) {
          final amount = parseAmount(text);
          final count = amount?.toInt();
          final valid =
              amount != null && count != null && count == amount && count >= 1;
          setState(() {
            invalid = !valid;
            parsed = valid ? count : null;
          });
          widget.onValidityChanged(valid);
          if (valid) widget.onChanged(count);
        },
      );
}

String _numberText(double value) => value == 0
    ? ''
    : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
