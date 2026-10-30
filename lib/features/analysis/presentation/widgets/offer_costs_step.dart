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
    final isExpanded = MediaQuery.sizeOf(context).width >= 1024;
    final overCapacity = controller.pricingMode == PricingMode.perTon &&
        controller.activeVehicle != null &&
        controller.tons > controller.activeVehicle!.capacityTons;

    final offerSection = personal
        ? null
        : _FormSection(
            title: 'Lo que te ofrecen',
            children: [
              SegmentedButton<PricingMode>(
                segments: PricingMode.values
                    .map((mode) =>
                        ButtonSegment(value: mode, label: Text(mode.label)))
                    .toList(),
                selected: {controller.pricingMode},
                onSelectionChanged: (selected) =>
                    controller.setPricingMode(selected.first),
              ),
              const SizedBox(height: 10),
              if (controller.pricingMode == PricingMode.flatRate)
                _NumberField(
                  controller: flatRateController,
                  label: 'Precio del viaje',
                  unit: r'$/viaje',
                  onChanged: controller.setFlatRate,
                )
              else ...[
                _NumberField(
                  controller: tonsController,
                  label: 'Toneladas',
                  unit: 'tn',
                  onChanged: controller.setTons,
                ),
                const SizedBox(height: 10),
                _NumberField(
                  controller: pricePerTonController,
                  label: 'Precio por tonelada',
                  unit: r'$/tn',
                  onChanged: controller.setPricePerTon,
                ),
              ],
              if (overCapacity) ...[
                const SizedBox(height: 10),
                Text(
                  'Tu vehículo tiene capacidad para ${decimal(controller.activeVehicle!.capacityTons)} toneladas. Ajustá la carga o el vehículo.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (controller.pricingMode == PricingMode.perTon) ...[
                const SizedBox(height: 12),
                MetricTile(
                  label: 'Ingreso estimado',
                  value: money(controller.grossIncome),
                ),
              ],
            ],
          );

    final expenseSection = _FormSection(
      title: 'Gastos del viaje',
      children: [
        _NumberField(
          controller: fuelPriceController,
          label: 'Combustible por litro',
          unit: r'$/litro',
          onChanged: controller.setFuelPrice,
        ),
        const SizedBox(height: 10),
        _NumberField(
          controller: tollsController,
          label: 'Peajes (total del viaje, incluida la vuelta si corresponde)',
          unit: r'$/viaje',
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
        if (controller.costs.tolls == 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Sin peajes cargados. Si tu ruta tiene, cargá peajes.'),
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
          label: personal ? 'Otros gastos (comida, alojamiento)' : 'Viáticos',
          unit: r'$',
          onChanged: controller.setAllowances,
        ),
        if (personal) ...[
          const SizedBox(height: 10),
          TextField(
            controller: travelersController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad de personas que comparten los gastos',
              helperText: 'Mínimo: 1 persona.',
              suffixText: 'personas',
            ),
            onChanged: (value) => controller.setTravelers(
              int.tryParse(value) ?? 1,
            ),
          ),
        ],
      ],
    );

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
            if (isExpanded && offerSection != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: offerSection),
                  const SizedBox(width: 18),
                  Expanded(child: expenseSection),
                ],
              )
            else ...[
              if (offerSection != null) ...[
                offerSection,
                const SizedBox(height: 18),
              ],
              expenseSection,
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final ValueChanged<double> onChanged;
  final Widget? trailing;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  bool hasEdited = false;

  @override
  Widget build(BuildContext context) {
    final parsed = parseAmount(widget.controller.text);
    final isInvalid = hasEdited && parsed == null;
    return TextField(
      controller: widget.controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.unit,
        suffixIcon: widget.trailing,
        errorText: isInvalid ? 'Ingresá un importe válido.' : null,
        helperText: !isInvalid && _hasMoreThanNineDigits(parsed)
            ? 'El importe supera las 9 cifras; revisá si está bien.'
            : null,
      ),
      onChanged: (value) {
        hasEdited = true;
        final amount = parseAmount(value);
        if (amount != null) widget.onChanged(amount);
        setState(() {});
      },
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

bool _hasMoreThanNineDigits(double? value) =>
    value != null && value.abs() >= 1000000000;

String _numberText(double value) => value == 0
    ? ''
    : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
