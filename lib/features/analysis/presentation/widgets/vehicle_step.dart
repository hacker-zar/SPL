import 'package:flutter/material.dart';

import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../vehicle_profile/domain/models/vehicle_profile.dart';
import '../controllers/trip_quote_controller.dart';

class VehicleStep extends StatelessWidget {
  const VehicleStep({required this.controller, super.key});

  final TripQuoteController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.vehicleProfile;
    final isComplete = profile?.isComplete ?? false;
    return _StepCard(
      title: 'Mi camión',
      child: isComplete
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Camión configurado ✓'),
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
                    MetricTile(
                      label: 'Capacidad',
                      value: '${decimal(profile.capacityTons)} tn',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PlateSummary(plate: profile.plate),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _editProfile(context, profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar vehículo'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cargá el consumo, mantenimiento y capacidad una sola vez.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _editProfile(context, profile),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Cargar mi vehículo'),
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
      builder: (context) => VehicleProfileSheet(profile: profile),
    );
    if (result != null) {
      await controller.saveVehicleProfile(result);
    }
  }
}

class VehicleProfileSheet extends StatefulWidget {
  const VehicleProfileSheet({required this.profile, super.key});

  final VehicleProfile? profile;

  @override
  State<VehicleProfileSheet> createState() => _VehicleProfileSheetState();
}

class _VehicleProfileSheetState extends State<VehicleProfileSheet> {
  late final TextEditingController consumptionController;
  late final TextEditingController maintenanceController;
  late final TextEditingController capacityController;
  late final TextEditingController plateController;
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
  }

  @override
  void dispose() {
    consumptionController.dispose();
    maintenanceController.dispose();
    capacityController.dispose();
    plateController.dispose();
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
          Text('Mi camión', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: consumptionController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Consumo L/100 km'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: maintenanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Mantenimiento por km'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: capacityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Capacidad tn'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: plateController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Patente (opcional)'),
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
    final consumption = _parseNumber(consumptionController.text);
    final maintenance = _parseNumber(maintenanceController.text);
    final capacity = _parseNumber(capacityController.text);
    if (consumption <= 0 || maintenance < 0 || capacity <= 0) {
      setState(() {
        validationMessage =
            'Ingresá consumo y capacidad mayores a cero, y mantenimiento igual o mayor a cero.';
      });
      return;
    }
    Navigator.of(context).pop(
      VehicleProfile(
        consumptionLitersPer100Km: consumption,
        maintenanceCostPerKm: maintenance,
        capacityTons: capacity,
        plate: plateController.text.trim(),
      ),
    );
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

double _parseNumber(String value) =>
    double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;

String _numberText(double value) => value == 0
    ? ''
    : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
