import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../../route_planning/domain/models/lat_lng_value.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../../vehicle_profile/domain/models/vehicle_profile.dart';
import '../../domain/models/profitability_status.dart';
import '../controllers/trip_quote_controller.dart';

class TripQuoteScreen extends StatefulWidget {
  const TripQuoteScreen({
    required this.controller,
    super.key,
  });

  final TripQuoteController controller;

  @override
  State<TripQuoteScreen> createState() => _TripQuoteScreenState();
}

class _TripQuoteScreenState extends State<TripQuoteScreen> {
  final originController = TextEditingController();
  final destinationController = TextEditingController();
  final flatRateController = TextEditingController();
  final tonsController = TextEditingController();
  final pricePerTonController = TextEditingController();
  final fuelPriceController = TextEditingController();
  final tollsController = TextEditingController();
  final allowancesController = TextEditingController();

  final originFocus = FocusNode();
  final destinationFocus = FocusNode();
  final flatRateFocus = FocusNode();
  final tonsFocus = FocusNode();
  final pricePerTonFocus = FocusNode();
  final fuelPriceFocus = FocusNode();
  final tollsFocus = FocusNode();
  final allowancesFocus = FocusNode();

  TripQuoteController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_syncControllers);
    _syncControllers();
  }

  @override
  void dispose() {
    controller.removeListener(_syncControllers);
    originController.dispose();
    destinationController.dispose();
    flatRateController.dispose();
    tonsController.dispose();
    pricePerTonController.dispose();
    fuelPriceController.dispose();
    tollsController.dispose();
    allowancesController.dispose();
    originFocus.dispose();
    destinationFocus.dispose();
    flatRateFocus.dispose();
    tonsFocus.dispose();
    pricePerTonFocus.dispose();
    fuelPriceFocus.dispose();
    tollsFocus.dispose();
    allowancesFocus.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _setText(originController, originFocus, controller.origin);
    _setText(destinationController, destinationFocus, controller.destination);
    _setText(flatRateController, flatRateFocus, _textNumber(controller.flatRate));
    _setText(tonsController, tonsFocus, _textNumber(controller.tons));
    _setText(
      pricePerTonController,
      pricePerTonFocus,
      _textNumber(controller.pricePerTon),
    );
    _setText(
      fuelPriceController,
      fuelPriceFocus,
      _textNumber(controller.costs.fuelPricePerLiter),
    );
    _setText(tollsController, tollsFocus, _textNumber(controller.costs.tolls));
    _setText(
      allowancesController,
      allowancesFocus,
      _textNumber(controller.costs.allowances),
    );
  }

  void _setText(
    TextEditingController textController,
    FocusNode focusNode,
    String value,
  ) {
    if (focusNode.hasFocus || textController.text == value) {
      return;
    }
    textController.text = value;
    textController.selection = TextSelection.collapsed(offset: value.length);
  }

  String _textNumber(double value) {
    if (value == 0) {
      return '';
    }
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final analysis = controller.analysis;
        final profile = controller.vehicleProfile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Conviene este viaje?'),
            actions: [
              IconButton(
                tooltip: 'Perfil del vehiculo',
                icon: const Icon(Icons.local_shipping_outlined),
                onPressed: _showVehicleProfile,
              ),
              IconButton(
                tooltip: 'Historial',
                icon: const Icon(Icons.history),
                onPressed: _showHistory,
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (controller.errorMessage != null)
                  _ErrorBanner(message: controller.errorMessage!),
                if (analysis != null) ...[
                  _DecisionHeader(status: analysis.status),
                  const SizedBox(height: 12),
                ],
                if (profile == null || !profile.isComplete) ...[
                  _ProfileBanner(onPressed: _showVehicleProfile),
                  const SizedBox(height: 12),
                ],
                _RouteSection(
                  controller: controller,
                  originController: originController,
                  destinationController: destinationController,
                  originFocus: originFocus,
                  destinationFocus: destinationFocus,
                ),
                const SizedBox(height: 12),
                _OfferSection(
                  controller: controller,
                  flatRateController: flatRateController,
                  tonsController: tonsController,
                  pricePerTonController: pricePerTonController,
                  fuelPriceController: fuelPriceController,
                  tollsController: tollsController,
                  allowancesController: allowancesController,
                  flatRateFocus: flatRateFocus,
                  tonsFocus: tonsFocus,
                  pricePerTonFocus: pricePerTonFocus,
                  fuelPriceFocus: fuelPriceFocus,
                  tollsFocus: tollsFocus,
                  allowancesFocus: allowancesFocus,
                ),
                const SizedBox(height: 12),
                _ResultSection(controller: controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVehicleProfile() async {
    final current = controller.vehicleProfile;
    final result = await showModalBottomSheet<VehicleProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _VehicleProfileSheet(profile: current),
    );
    if (result != null) {
      await controller.saveVehicleProfile(result);
    }
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.history.isEmpty) {
              return const SizedBox(
                height: 220,
                child: Center(child: Text('Todavia no hay simulaciones.')),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemBuilder: (context, index) {
                final trip = controller.history[index];
                return _HistoryTile(
                  trip: trip,
                  onTap: () {
                    controller.openTrip(trip);
                    Navigator.of(context).pop();
                  },
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: controller.history.length,
            );
          },
        );
      },
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({
    required this.controller,
    required this.originController,
    required this.destinationController,
    required this.originFocus,
    required this.destinationFocus,
  });

  final TripQuoteController controller;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final FocusNode originFocus;
  final FocusNode destinationFocus;

  @override
  Widget build(BuildContext context) {
    final route = controller.effectiveRoute;
    return _Section(
      title: 'Ruta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: originController,
            focusNode: originFocus,
            decoration: const InputDecoration(
              labelText: 'Origen',
              prefixIcon: Icon(Icons.trip_origin),
            ),
            textInputAction: TextInputAction.next,
            onChanged: controller.setOrigin,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: destinationController,
            focusNode: destinationFocus,
            decoration: const InputDecoration(
              labelText: 'Destino',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            onChanged: controller.setDestination,
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vuelvo vacio'),
            value: controller.emptyReturn,
            onChanged: controller.setEmptyReturn,
          ),
          FilledButton.icon(
            onPressed:
                controller.isRouteLoading ? null : controller.calculateRoute,
            icon: controller.isRouteLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.route),
            label: const Text('Calcular kilometros'),
          ),
          if (route != null) ...[
            const SizedBox(height: 10),
            _RouteSummary(
              routeKm: route.distanceKm,
              minutes: route.durationMinutes,
            ),
            const SizedBox(height: 10),
            _MapPreview(points: route.polyline),
          ],
        ],
      ),
    );
  }
}

class _OfferSection extends StatelessWidget {
  const _OfferSection({
    required this.controller,
    required this.flatRateController,
    required this.tonsController,
    required this.pricePerTonController,
    required this.fuelPriceController,
    required this.tollsController,
    required this.allowancesController,
    required this.flatRateFocus,
    required this.tonsFocus,
    required this.pricePerTonFocus,
    required this.fuelPriceFocus,
    required this.tollsFocus,
    required this.allowancesFocus,
  });

  final TripQuoteController controller;
  final TextEditingController flatRateController;
  final TextEditingController tonsController;
  final TextEditingController pricePerTonController;
  final TextEditingController fuelPriceController;
  final TextEditingController tollsController;
  final TextEditingController allowancesController;
  final FocusNode flatRateFocus;
  final FocusNode tonsFocus;
  final FocusNode pricePerTonFocus;
  final FocusNode fuelPriceFocus;
  final FocusNode tollsFocus;
  final FocusNode allowancesFocus;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Oferta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<PricingMode>(
            segments: PricingMode.values
                .map(
                  (mode) => ButtonSegment<PricingMode>(
                    value: mode,
                    label: Text(mode.label),
                  ),
                )
                .toList(),
            selected: {controller.pricingMode},
            onSelectionChanged: (selected) {
              controller.setPricingMode(selected.first);
            },
          ),
          const SizedBox(height: 10),
          if (controller.pricingMode == PricingMode.flatRate)
            TextField(
              controller: flatRateController,
              focusNode: flatRateFocus,
              decoration: const InputDecoration(
                labelText: 'Precio ofertado',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => controller.setFlatRate(_parseDouble(value)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tonsController,
                    focusNode: tonsFocus,
                    decoration: const InputDecoration(
                      labelText: 'Toneladas',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        controller.setTons(_parseDouble(value)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: pricePerTonController,
                    focusNode: pricePerTonFocus,
                    decoration: const InputDecoration(
                      labelText: 'Precio/tn',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        controller.setPricePerTon(_parseDouble(value)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          TextField(
            controller: fuelPriceController,
            focusNode: fuelPriceFocus,
            decoration: const InputDecoration(
              labelText: 'Combustible por litro',
              prefixIcon: Icon(Icons.local_gas_station_outlined),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => controller.setFuelPrice(_parseDouble(value)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tollsController,
                  focusNode: tollsFocus,
                  decoration: const InputDecoration(
                    labelText: 'Peajes',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      controller.setTolls(_parseDouble(value)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: allowancesController,
                  focusNode: allowancesFocus,
                  decoration: const InputDecoration(
                    labelText: 'Viaticos',
                    prefixIcon: Icon(Icons.restaurant_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      controller.setAllowances(_parseDouble(value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MetricTile(
            label: 'Ingreso',
            value: money(controller.grossIncome),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.controller});

  final TripQuoteController controller;

  @override
  Widget build(BuildContext context) {
    final analysis = controller.analysis;
    if (analysis == null) {
      return _Section(
        title: 'Resultado',
        child: const Text('Completa ruta, oferta y perfil para decidir.'),
      );
    }

    final minimumLabel = controller.pricingMode == PricingMode.perTon
        ? 'Minimo/tn'
        : 'Minimo para no perder';
    final minimumValue = controller.pricingMode == PricingMode.perTon
        ? analysis.minimumPricePerTon
        : analysis.breakEvenPrice;

    return _Section(
      title: 'Resultado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
            childAspectRatio: 1.45,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              MetricTile(label: 'Ingreso', value: money(analysis.grossIncome)),
              MetricTile(label: 'Costos', value: money(analysis.totalCosts)),
              MetricTile(
                label: 'Ganancia neta',
                value: money(analysis.netProfit),
                accentColor: analysis.status.color,
              ),
              MetricTile(
                label: 'Ganancia/km',
                value: money(analysis.profitPerKm),
                accentColor: analysis.status.color,
              ),
              MetricTile(
                label: 'Margen',
                value: '${decimal(analysis.marginPercent)}%',
              ),
              MetricTile(label: minimumLabel, value: money(minimumValue)),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed:
                controller.isSaving ? null : controller.saveCurrentTrip,
            icon: const Icon(Icons.save_outlined),
            label: Text(controller.isSaving ? 'Guardando...' : 'Guardar simulacion'),
          ),
        ],
      ),
    );
  }
}

class _DecisionHeader extends StatelessWidget {
  const _DecisionHeader({required this.status});

  final ProfitabilityStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ProfitabilityStatus.profitable => 'Si, te conviene.',
      ProfitabilityStatus.low => 'Margen bajo.',
      ProfitabilityStatus.loss => 'No aceptes este viaje.',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        border: Border.all(color: status.color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.circle, color: status.color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('Carga tu vehiculo una vez.')),
            TextButton(
              onPressed: onPressed,
              child: const Text('Abrir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

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
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.routeKm,
    required this.minutes,
  });

  final double routeKm;
  final double minutes;

  @override
  Widget build(BuildContext context) {
    final hours = minutes / 60;
    return Row(
      children: [
        Expanded(
          child: MetricTile(label: 'Kilometros', value: decimal(routeKm)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(label: 'Tiempo', value: '${decimal(hours)} h'),
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.points});

  final List<LatLngValue> points;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || points.isEmpty) {
      return const SizedBox.shrink();
    }
    final latLngPoints = points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    return SizedBox(
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: latLngPoints.first,
            zoom: 7,
          ),
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: latLngPoints,
              width: 5,
              color: Theme.of(context).colorScheme.primary,
            ),
          },
          markers: {
            Marker(
              markerId: const MarkerId('origin'),
              position: latLngPoints.first,
            ),
            Marker(
              markerId: const MarkerId('destination'),
              position: latLngPoints.last,
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

class _VehicleProfileSheet extends StatefulWidget {
  const _VehicleProfileSheet({required this.profile});

  final VehicleProfile? profile;

  @override
  State<_VehicleProfileSheet> createState() => _VehicleProfileSheetState();
}

class _VehicleProfileSheetState extends State<_VehicleProfileSheet> {
  late final TextEditingController consumptionController;
  late final TextEditingController maintenanceController;
  late final TextEditingController capacityController;
  late final TextEditingController plateController;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    consumptionController = TextEditingController(
      text: _initialNumber(profile?.consumptionLitersPer100Km ?? 0),
    );
    maintenanceController = TextEditingController(
      text: _initialNumber(profile?.maintenanceCostPerKm ?? 0),
    );
    capacityController = TextEditingController(
      text: _initialNumber(profile?.capacityTons ?? 0),
    );
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
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mi vehiculo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: consumptionController,
            decoration: const InputDecoration(
              labelText: 'Consumo L/100 km',
              prefixIcon: Icon(Icons.local_gas_station_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: maintenanceController,
            decoration: const InputDecoration(
              labelText: 'Mantenimiento por km',
              prefixIcon: Icon(Icons.build_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: capacityController,
            decoration: const InputDecoration(
              labelText: 'Capacidad tn',
              prefixIcon: Icon(Icons.scale_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: plateController,
            decoration: const InputDecoration(
              labelText: 'Patente opcional',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                VehicleProfile(
                  consumptionLitersPer100Km:
                      _parseDouble(consumptionController.text),
                  maintenanceCostPerKm:
                      _parseDouble(maintenanceController.text),
                  capacityTons: _parseDouble(capacityController.text),
                  plate: plateController.text.trim(),
                ),
              );
            },
            child: const Text('Guardar perfil'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.trip,
    required this.onTap,
  });

  final TripRecord trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${trip.route.originName} -> ${trip.route.destinationName}'),
      subtitle: Text(
        '${decimal(trip.route.distanceKm)} km - ${decimal(trip.marginPercent)}%',
      ),
      trailing: Text(money(trip.netProfit)),
      onTap: onTap,
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

String _initialNumber(double value) {
  if (value == 0) {
    return '';
  }
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}

double _parseDouble(String value) {
  final normalized = value.replaceAll(',', '.').trim();
  return double.tryParse(normalized) ?? 0;
}
