import 'package:flutter/material.dart';

import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/parse_amount.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../../vehicle_profile/domain/models/vehicle_profile.dart';
import '../controllers/trip_quote_controller.dart';

class VehicleStep extends StatelessWidget {
  const VehicleStep({required this.controller, super.key});

  final TripQuoteController controller;

  @override
  Widget build(BuildContext context) {
    final personal = controller.purpose == TripPurpose.personal;
    final profile = controller.activeVehicle;
    final isComplete = profile?.isCompleteFor(controller.purpose) ?? false;
    return _StepCard(
      title: personal ? 'Mi vehículo' : 'Mi camión',
      child: isComplete
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(personal
                    ? 'Vehículo configurado ✓'
                    : 'Camión configurado ✓'),
                const SizedBox(height: 12),
                _MetricGrid(
                  children: [
                    MetricTile(
                      label: 'Consumo',
                      value:
                          '${decimal(profile!.consumptionLitersPer100Km)} L/100',
                    ),
                    MetricTile(
                      label: 'Mantenimiento',
                      value: '${money(profile.maintenanceCostPerKm)}/km',
                    ),
                    if (!personal)
                      MetricTile(
                        label: 'Capacidad',
                        value: '${decimal(profile.capacityTons)} tn',
                      ),
                  ],
                ),
                if (!personal) ...[
                  const SizedBox(height: 10),
                  _PlateSummary(plate: profile.plate),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _editProfile(context, profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(personal ? 'Editar vehículo' : 'Editar camión'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  personal
                      ? 'Cargá los datos de consumo y mantenimiento de tu vehículo.'
                      : 'Cargá el consumo, mantenimiento y capacidad una sola vez.',
                ),
                if (personal) ...[
                  const SizedBox(height: 4),
                  const Text(
                      'Si no sabés el consumo, usá el dato del manual o de la ficha de tu auto.'),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _editProfile(context, profile),
                  icon: Icon(personal
                      ? Icons.directions_car_outlined
                      : Icons.local_shipping_outlined),
                  label: Text(
                      personal ? 'Cargar mi vehículo' : 'Cargar mi camión'),
                ),
              ],
            ),
    );
  }

  Future<void> _editProfile(
      BuildContext context, VehicleProfile? profile) async {
    final result = await showModalBottomSheet<VehicleProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => VehicleProfileSheet(
        profile: profile,
        isPersonal: controller.purpose == TripPurpose.personal,
      ),
    );
    if (result != null) {
      if (controller.purpose == TripPurpose.personal) {
        controller.savePersonalVehicle(result);
      } else {
        await controller.saveVehicleProfile(result);
      }
    }
  }
}

class VehicleProfileSheet extends StatefulWidget {
  const VehicleProfileSheet(
      {required this.profile, this.isPersonal = false, super.key});

  final VehicleProfile? profile;
  final bool isPersonal;

  @override
  State<VehicleProfileSheet> createState() => _VehicleProfileSheetState();
}

class _VehicleProfileSheetState extends State<VehicleProfileSheet> {
  bool get isPersonal => widget.isPersonal;

  late final TextEditingController consumptionController;
  late final TextEditingController maintenanceController;
  late final TextEditingController capacityController;
  late final TextEditingController plateController;
  late final TextEditingController dailyFixedCostController;
  String? validationMessage;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    consumptionController = TextEditingController(
        text: _numberText(profile?.consumptionLitersPer100Km ?? 0));
    maintenanceController = TextEditingController(
        text: _numberText(profile?.maintenanceCostPerKm ?? 0));
    capacityController =
        TextEditingController(text: _numberText(profile?.capacityTons ?? 0));
    plateController = TextEditingController(text: profile?.plate ?? '');
    dailyFixedCostController =
        TextEditingController(text: _numberText(profile?.dailyFixedCost ?? 0));
  }

  @override
  void dispose() {
    consumptionController.dispose();
    maintenanceController.dispose();
    capacityController.dispose();
    plateController.dispose();
    dailyFixedCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isPersonal ? 'Mi vehículo' : 'Mi camión',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _VehicleNumberField(
            controller: consumptionController,
            label: 'Consumo L/100 km',
            positive: true,
            currency: false,
            hint: isPersonal
                ? 'Si no sabés el consumo, usá el dato del manual o de la ficha de tu auto.'
                : null,
          ),
          const SizedBox(height: 10),
          _VehicleNumberField(
            controller: maintenanceController,
            label: 'Mantenimiento por km',
          ),
          const Text('Incluye neumáticos, aceite, service y reparaciones.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: _showMaintenanceHelper,
                child: const Text('Calcular mantenimiento por km')),
          ),
          if (!isPersonal)
            _VehicleNumberField(
              controller: dailyFixedCostController,
              label:
                  'Costos fijos por día (seguro, amortización, sueldo del chofer)',
              hint: 'Se multiplica por los días estimados del viaje.',
            ),
          if (!isPersonal) const SizedBox(height: 10),
          if (!isPersonal)
            _VehicleNumberField(
              controller: capacityController,
              label: 'Capacidad tn',
              currency: false,
              positive: true,
            ),
          if (!isPersonal) const SizedBox(height: 10),
          if (!isPersonal)
            TextField(
              controller: plateController,
              textCapitalization: TextCapitalization.characters,
              decoration:
                  const InputDecoration(labelText: 'Patente (opcional)'),
            ),
          if (validationMessage != null) ...[
            const SizedBox(height: 8),
            Text(validationMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: const Text('Guardar vehículo')),
        ],
      ),
    );
  }

  void _save() {
    final consumption = parseAmount(consumptionController.text);
    final maintenance = parseAmount(maintenanceController.text);
    final capacity = parseAmount(capacityController.text);
    final dailyFixedCost = parseAmount(dailyFixedCostController.text);
    if (consumption == null ||
        consumption <= 0 ||
        maintenance == null ||
        maintenance < 0 ||
        (!isPersonal &&
            (capacity == null ||
                capacity <= 0 ||
                dailyFixedCost == null ||
                dailyFixedCost < 0))) {
      setState(() {
        validationMessage = isPersonal
            ? 'Ingresá consumo mayor a cero y mantenimiento igual o mayor a cero.'
            : 'Ingresá consumo y capacidad mayores a cero, y mantenimiento igual o mayor a cero.';
      });
      return;
    }
    Navigator.of(context).pop(
      VehicleProfile(
        consumptionLitersPer100Km: consumption,
        maintenanceCostPerKm: maintenance,
        capacityTons: isPersonal ? 0 : capacity!,
        plate: isPersonal ? '' : plateController.text.trim(),
        dailyFixedCost: isPersonal ? 0 : dailyFixedCost!,
      ),
    );
  }

  Future<void> _showMaintenanceHelper() async {
    final expenseController = TextEditingController();
    final kmController = TextEditingController();
    double? result;
    bool invalidKm = false;
    bool invalidExpense = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mantenimiento por km'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _VehicleNumberField(
              controller: expenseController,
              label: 'Gasto de mantenimiento del último año',
              error: invalidExpense,
              onEdited: () => setDialogState(() => invalidExpense = false),
            ),
            _VehicleNumberField(
              controller: kmController,
              label: 'Km recorridos en el año',
              positive: true,
              currency: false,
              error: invalidKm,
              onEdited: () => setDialogState(() => invalidKm = false),
            ),
            if (invalidKm)
              const Text('Los kilómetros deben ser mayores a cero.'),
            if (result != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Resultado: ${money(result!)}/km')),
          ]),
          actions: [
            TextButton(
                onPressed: () {
                  final expense = parseAmount(expenseController.text);
                  final km = parseAmount(kmController.text);
                  setDialogState(() {
                    invalidKm = km == null || km <= 0;
                    invalidExpense = expense == null || expense < 0;
                    result =
                        !invalidKm && !invalidExpense ? expense! / km! : null;
                  });
                },
                child: const Text('Calcular')),
            if (result != null)
              FilledButton(
                  onPressed: () {
                    maintenanceController.text = _numberText(result!);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Usar este valor')),
          ],
        ),
      ),
    );
    expenseController.dispose();
    kmController.dispose();
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
      childAspectRatio: 1.45,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: children,
    );
  }
}

class _PlateSummary extends StatelessWidget {
  const _PlateSummary({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final hasPlate = plate.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.pin_outlined, size: 20),
            const SizedBox(width: 10),
            const Text('PATENTE',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              hasPlate ? plate : 'Sin cargar',
              style: TextStyle(
                color: hasPlate
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleNumberField extends StatefulWidget {
  const _VehicleNumberField({
    required this.controller,
    required this.label,
    this.currency = true,
    this.positive = false,
    this.hint,
    this.error = false,
    this.onEdited,
  });

  final TextEditingController controller;
  final String label;
  final bool currency;
  final bool positive;
  final String? hint;
  final bool error;
  final VoidCallback? onEdited;

  @override
  State<_VehicleNumberField> createState() => _VehicleNumberFieldState();
}

class _VehicleNumberFieldState extends State<_VehicleNumberField> {
  double? value;
  bool invalid = false;

  @override
  void initState() {
    super.initState();
    value = parseAmount(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: invalid
              ? null
              : value == null
                  ? widget.hint
                  : widget.currency
                      ? money(value!)
                      : decimal(value!),
          errorText:
              (invalid || widget.error) ? 'Ingresá un número válido.' : null,
        ),
        onChanged: (text) {
          final parsed = parseAmount(text);
          final valid =
              parsed != null && (widget.positive ? parsed > 0 : parsed >= 0);
          setState(() {
            value = parsed;
            invalid = !valid;
          });
          widget.onEdited?.call();
        },
      );
}

String _numberText(double value) => value == 0
    ? ''
    : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
