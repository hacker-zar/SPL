import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../../core/theme/app_theme.dart';
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
  final flatRateController = TextEditingController();
  final tonsController = TextEditingController();
  final pricePerTonController = TextEditingController();
  final fuelPriceController = TextEditingController();
  final tollsController = TextEditingController();
  final allowancesController = TextEditingController();

  final flatRateFocus = FocusNode();
  final tonsFocus = FocusNode();
  final pricePerTonFocus = FocusNode();
  final fuelPriceFocus = FocusNode();
  final tollsFocus = FocusNode();
  final allowancesFocus = FocusNode();
  _RoutePickTarget routePickTarget = _RoutePickTarget.origin;

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
    flatRateController.dispose();
    tonsController.dispose();
    pricePerTonController.dispose();
    fuelPriceController.dispose();
    tollsController.dispose();
    allowancesController.dispose();
    flatRateFocus.dispose();
    tonsFocus.dispose();
    pricePerTonFocus.dispose();
    fuelPriceFocus.dispose();
    tollsFocus.dispose();
    allowancesFocus.dispose();
    super.dispose();
  }

  void _syncControllers() {
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
                _VehicleSection(
                  profile: profile,
                  onPressed: _showVehicleProfile,
                ),
                const SizedBox(height: 12),
                _RouteSection(
                  controller: controller,
                  pickTarget: routePickTarget,
                  onPickTargetChanged: (target) {
                    setState(() => routePickTarget = target);
                  },
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
                FilledButton.icon(
                  onPressed: controller.isRouteLoading
                      ? null
                      : _calculateTripAndOpenResults,
                  icon: controller.isRouteLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: const Text('Calcular viaje'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _calculateTripAndOpenResults() async {
    final canOpenResults = await controller.prepareAnalysis();
    if (!mounted || !canOpenResults) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripResultScreen(controller: controller),
      ),
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
                    if (controller.analysis != null) {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (context) =>
                              TripResultScreen(controller: controller),
                        ),
                      );
                    }
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

class TripResultScreen extends StatelessWidget {
  const TripResultScreen({
    required this.controller,
    super.key,
  });

  final TripQuoteController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Resultado del viaje'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (controller.errorMessage != null)
                  _ErrorBanner(message: controller.errorMessage!),
                _ResultSection(controller: controller),
                const SizedBox(height: 12),
                _Section(
                  title: 'Acciones',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modificar datos'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () {
                          controller.resetSimulation();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.add_road_outlined),
                        label: const Text('Nueva simulacion'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({
    required this.controller,
    required this.pickTarget,
    required this.onPickTargetChanged,
  });

  final TripQuoteController controller;
  final _RoutePickTarget pickTarget;
  final ValueChanged<_RoutePickTarget> onPickTargetChanged;

  @override
  Widget build(BuildContext context) {
    final route = controller.effectiveRoute;
    return _Section(
      title: 'Ruta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_RoutePickTarget>(
            segments: const [
              ButtonSegment<_RoutePickTarget>(
                value: _RoutePickTarget.origin,
                icon: Icon(Icons.trip_origin),
                label: Text('Origen'),
              ),
              ButtonSegment<_RoutePickTarget>(
                value: _RoutePickTarget.destination,
                icon: Icon(Icons.place_outlined),
                label: Text('Destino'),
              ),
            ],
            selected: {pickTarget},
            onSelectionChanged: (selected) {
              onPickTargetChanged(selected.first);
            },
          ),
          const SizedBox(height: 10),
          _RoutePickerMap(
            origin: controller.originPoint,
            destination: controller.destinationPoint,
            routePoints: route?.polyline ?? const [],
            pickTarget: pickTarget,
            onPointPicked: (point) {
              if (pickTarget == _RoutePickTarget.origin) {
                controller.setOriginPoint(point);
                onPickTargetChanged(_RoutePickTarget.destination);
              } else {
                controller.setDestinationPoint(point);
              }
            },
          ),
          const SizedBox(height: 10),
          _SelectedRoutePoints(
            origin: controller.origin,
            destination: controller.destination,
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
    final tollEstimate = controller.tollEstimate;
    final tollsLabel = tollEstimate == null
        ? 'Peajes'
        : controller.tollsEditedManually
            ? 'Peajes editados'
            : 'Peajes estimados';
    final tollsHelper = tollEstimate == null
        ? 'Auto al calcular'
        : '${decimal(tollEstimate.distanceKm)} km';

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
                  decoration: InputDecoration(
                    labelText: tollsLabel,
                    helperText: tollsHelper,
                    prefixIcon:
                        const Icon(Icons.confirmation_number_outlined),
                    suffixIcon: tollEstimate == null
                        ? null
                        : IconButton(
                            tooltip: 'Usar peaje estimado',
                            icon: const Icon(Icons.refresh),
                            onPressed: controller.useEstimatedTolls,
                          ),
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
    final route = controller.effectiveRoute;
    if (analysis == null) {
      return const _Section(
        title: 'Resultado',
        child: Text('Completa ruta, oferta y perfil para decidir.'),
      );
    }

    final minimumLabel = controller.pricingMode == PricingMode.perTon
        ? 'Minimo/tn'
        : 'Minimo para no perder';
    final minimumValue = controller.pricingMode == PricingMode.perTon
        ? analysis.minimumPricePerTon
        : analysis.breakEvenPrice;
    final fuelAndMaintenance = analysis.fuelCost + analysis.maintenanceCost;
    final conclusion = switch (analysis.status) {
      ProfitabilityStatus.profitable =>
        'El viaje cubre los costos y deja una ganancia saludable.',
      ProfitabilityStatus.low =>
        'El viaje deja ganancia, pero el margen es bajo. Conviene negociar precio o revisar costos.',
      ProfitabilityStatus.loss =>
        'El viaje no cubre los costos estimados. No conviene aceptarlo con estos datos.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DecisionHeader(status: analysis.status),
        const SizedBox(height: 12),
        _Section(
          title: 'Resumen general',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricGrid(
                children: [
                  if (route != null)
                    MetricTile(
                      label: 'Kilometros',
                      value: decimal(route.distanceKm),
                    ),
                  if (route != null)
                    MetricTile(
                      label: 'Tiempo',
                      value: '${decimal(route.durationMinutes / 60)} h',
                    ),
                  MetricTile(
                    label: 'Ingreso esperado',
                    value: money(analysis.grossIncome),
                  ),
                  MetricTile(
                    label: 'Costos totales',
                    value: money(analysis.totalCosts),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(conclusion),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Costos desglosados',
          child: _MetricGrid(
            children: [
              MetricTile(
                label: 'Combustible',
                value: money(analysis.fuelCost),
              ),
              MetricTile(
                label: 'Mantenimiento',
                value: money(analysis.maintenanceCost),
              ),
              MetricTile(
                label: 'Peajes',
                value: money(controller.costs.tolls),
              ),
              MetricTile(
                label: 'Viaticos',
                value: money(controller.costs.allowances),
              ),
              MetricTile(
                label: 'Km sensibles',
                value: money(fuelAndMaintenance),
              ),
              MetricTile(
                label: 'Total costos',
                value: money(analysis.totalCosts),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Rentabilidad',
          child: _MetricGrid(
            children: [
              MetricTile(
                label: 'Ganancia',
                value: money(analysis.netProfit),
                accentColor: analysis.status.color,
              ),
              MetricTile(
                label: 'Margen',
                value: '${decimal(analysis.marginPercent)}%',
                accentColor: analysis.status.color,
              ),
              MetricTile(
                label: 'Ingreso/km',
                value: money(analysis.incomePerKm),
              ),
              MetricTile(
                label: 'Costo/km',
                value: money(analysis.costPerKm),
              ),
              MetricTile(
                label: 'Ganancia/km',
                value: money(analysis.profitPerKm),
                accentColor: analysis.status.color,
              ),
              MetricTile(label: minimumLabel, value: money(minimumValue)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Guardar',
          child: FilledButton.icon(
            onPressed: controller.isSaving ? null : controller.saveCurrentTrip,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              controller.isSaving ? 'Guardando...' : 'Guardar simulacion',
            ),
          ),
        ),
      ],
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

class _DecisionHeader extends StatelessWidget {
  const _DecisionHeader({required this.status});

  final ProfitabilityStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Row(
          children: [
            Icon(
              switch (status) {
                ProfitabilityStatus.profitable => Icons.check_circle,
                ProfitabilityStatus.low => Icons.warning_amber_rounded,
                ProfitabilityStatus.loss => Icons.cancel,
              },
              color: AppColors.asphalt,
              size: 36,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                switch (status) {
                  ProfitabilityStatus.profitable => 'TE CONVIENE',
                  ProfitabilityStatus.low => 'MARGEN BAJO',
                  ProfitabilityStatus.loss => 'NO ACEPTES',
                },
                style: GoogleFonts.oswald(
                  color: AppColors.asphalt,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleSection extends StatelessWidget {
  const _VehicleSection({
    required this.profile,
    required this.onPressed,
  });

  final VehicleProfile? profile;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final currentProfile = profile;
    if (currentProfile == null || !currentProfile.isComplete) {
      return _Section(
        title: 'Vehiculo',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Carga consumo, mantenimiento y capacidad una vez.'),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Cargar vehiculo'),
            ),
          ],
        ),
      );
    }

    return _Section(
      title: 'Vehiculo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricGrid(
            children: [
              MetricTile(
                label: 'Consumo',
                value:
                    '${decimal(currentProfile.consumptionLitersPer100Km)} L/100',
              ),
              MetricTile(
                label: 'Mantenimiento',
                value: money(currentProfile.maintenanceCostPerKm),
              ),
              MetricTile(
                label: 'Capacidad',
                value: '${decimal(currentProfile.capacityTons)} tn',
              ),
              MetricTile(
                label: 'Patente',
                value: currentProfile.plate.isEmpty
                    ? 'Sin cargar'
                    : currentProfile.plate,
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar vehiculo'),
          ),
        ],
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
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  color: AppColors.roadYellow,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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

class _ManualCoordinatesForm extends StatefulWidget {
  const _ManualCoordinatesForm({
    required this.title,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onCoordinatesSubmitted,
  });

  final String title;
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(double latitude, double longitude) onCoordinatesSubmitted;

  @override
  State<_ManualCoordinatesForm> createState() => _ManualCoordinatesFormState();
}

class _ManualCoordinatesFormState extends State<_ManualCoordinatesForm> {
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;
  String? latitudeError;
  String? longitudeError;

  @override
  void initState() {
    super.initState();
    latitudeController = TextEditingController(
      text: widget.initialLatitude?.toString() ?? '',
    );
    longitudeController = TextEditingController(
      text: widget.initialLongitude?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(_ManualCoordinatesForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLatitude != widget.initialLatitude) {
      latitudeController.text = widget.initialLatitude?.toString() ?? '';
    }
    if (oldWidget.initialLongitude != widget.initialLongitude) {
      longitudeController.text = widget.initialLongitude?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  String? _validateLatitude(String value) {
    if (value.trim().isEmpty) {
      return 'La latitud es requerida';
    }
    final lat = double.tryParse(value);
    if (lat == null) {
      return 'Ingresa un número válido';
    }
    if (lat < -90 || lat > 90) {
      return 'Latitud debe estar entre -90 y 90';
    }
    return null;
  }

  String? _validateLongitude(String value) {
    if (value.trim().isEmpty) {
      return 'La longitud es requerida';
    }
    final lng = double.tryParse(value);
    if (lng == null) {
      return 'Ingresa un número válido';
    }
    if (lng < -180 || lng > 180) {
      return 'Longitud debe estar entre -180 y 180';
    }
    return null;
  }

  void _submitCoordinates() {
    setState(() {
      latitudeError = _validateLatitude(latitudeController.text);
      longitudeError = _validateLongitude(longitudeController.text);
    });

    if (latitudeError == null && longitudeError == null) {
      final lat = double.parse(latitudeController.text);
      final lng = double.parse(longitudeController.text);
      widget.onCoordinatesSubmitted(lat, lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: latitudeController,
                decoration: InputDecoration(
                  labelText: 'Latitud',
                  hintText: '-34.6037',
                  prefixIcon: const Icon(Icons.public),
                  errorText: latitudeError,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) {
                  setState(() {
                    latitudeError = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: longitudeController,
                decoration: InputDecoration(
                  labelText: 'Longitud',
                  hintText: '-58.3816',
                  prefixIcon: const Icon(Icons.public),
                  errorText: longitudeError,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) {
                  setState(() {
                    longitudeError = null;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _submitCoordinates,
          icon: const Icon(Icons.check_circle_outlined),
          label: const Text('Aplicar coordenadas'),
        ),
      ],
    );
  }
}

enum _RoutePickTarget { origin, destination }

class _SelectedRoutePoints extends StatelessWidget {
  const _SelectedRoutePoints({
    required this.origin,
    required this.destination,
  });

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Origen',
            value: origin.isEmpty ? 'Toca el mapa' : origin,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(
            label: 'Destino',
            value: destination.isEmpty ? 'Toca el mapa' : destination,
          ),
        ),
      ],
    );
  }
}

class _RoutePickerMap extends StatelessWidget {
  const _RoutePickerMap({
    required this.origin,
    required this.destination,
    required this.routePoints,
    required this.pickTarget,
    required this.onPointPicked,
  });

  final LatLngValue? origin;
  final LatLngValue? destination;
  final List<LatLngValue> routePoints;
  final _RoutePickTarget pickTarget;
  final ValueChanged<LatLngValue> onPointPicked;

  @override
  Widget build(BuildContext context) {
    final initialCenter = _toLatLng(origin) ??
        _toLatLng(destination) ??
        const ll.LatLng(-34.6037, -58.3816);
    final polylinePoints = routePoints.map(_toLatLng).nonNulls.toList();
    final markers = <Marker>[
      if (origin != null)
        Marker(
          point: _toLatLng(origin)!,
          width: 44,
          height: 44,
          child: const Icon(
            Icons.trip_origin,
            color: AppColors.decisionGo,
            size: 32,
          ),
        ),
      if (destination != null)
        Marker(
          point: _toLatLng(destination)!,
          width: 44,
          height: 44,
          child: const Icon(
            Icons.place,
            color: AppColors.roadYellow,
            size: 34,
          ),
        ),
    ];

    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 5,
            onTap: (_, point) {
              onPointPicked(
                LatLngValue(
                  latitude: point.latitude,
                  longitude: point.longitude,
                ),
              );
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rentabilidad_flete.app',
            ),
            if (polylinePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 5,
                    color: AppColors.roadYellow,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.asphalt.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      '(c) OpenStreetMap',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.roadYellow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      pickTarget == _RoutePickTarget.origin
                          ? 'Toca el origen'
                          : 'Toca el destino',
                      style: const TextStyle(
                        color: AppColors.textOnYellow,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ll.LatLng? _toLatLng(LatLngValue? point) {
    if (point == null) {
      return null;
    }
    return ll.LatLng(point.latitude, point.longitude);
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
