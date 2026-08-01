import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../route_planning/domain/models/lat_lng_value.dart';
import '../controllers/trip_quote_controller.dart';

class RouteStep extends StatefulWidget {
  const RouteStep({required this.controller, super.key});

  final TripQuoteController controller;

  @override
  State<RouteStep> createState() => _RouteStepState();
}

class _RouteStepState extends State<RouteStep> {
  late final TextEditingController originController;
  late final TextEditingController destinationController;
  _RoutePickTarget pickTarget = _RoutePickTarget.origin;

  TripQuoteController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    originController = TextEditingController(text: controller.origin);
    destinationController = TextEditingController(text: controller.destination);
    controller.addListener(_syncLocationText);
  }

  @override
  void dispose() {
    controller.removeListener(_syncLocationText);
    originController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  void _syncLocationText() {
    if (originController.text != controller.origin) {
      originController.text = controller.origin;
      originController.selection = TextSelection.collapsed(
        offset: originController.text.length,
      );
    }
    if (destinationController.text != controller.destination) {
      destinationController.text = controller.destination;
      destinationController.selection = TextSelection.collapsed(
        offset: destinationController.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = controller.effectiveRoute;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mi viaje', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Elegí origen y destino para calcular kilómetros y tiempo.'),
            const SizedBox(height: 12),
            SegmentedButton<_RoutePickTarget>(
              segments: const [
                ButtonSegment(value: _RoutePickTarget.origin, label: Text('Origen')),
                ButtonSegment(value: _RoutePickTarget.destination, label: Text('Destino')),
              ],
              selected: {pickTarget},
              onSelectionChanged: (selected) => setState(() => pickTarget = selected.first),
            ),
            const SizedBox(height: 10),
            _RoutePickerMap(
              origin: controller.originPoint,
              destination: controller.destinationPoint,
              routePoints: route?.polyline ?? const [],
              pickTarget: pickTarget,
              isLoading: controller.isRouteLoading,
              onPointPicked: (point) {
                if (pickTarget == _RoutePickTarget.origin) {
                  controller.setOriginPoint(point);
                  setState(() => pickTarget = _RoutePickTarget.destination);
                } else {
                  controller.setDestinationPoint(point);
                }
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LocationInput(
                    label: 'Origen',
                    controller: originController,
                    isLoading: controller.isOriginResolving,
                    onSearch: () async {
                      await controller.resolveOrigin(originController.text);
                      if (mounted) setState(() => pickTarget = _RoutePickTarget.destination);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LocationInput(
                    label: 'Destino',
                    controller: destinationController,
                    isLoading: controller.isDestinationResolving,
                    onSearch: () => controller.resolveDestination(destinationController.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vuelvo vacío'),
              value: controller.emptyReturn,
              onChanged: controller.setEmptyReturn,
            ),
            if (controller.isRouteLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Calculando kilómetros y tiempo…'),
            ],
            if (route != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Kilómetros', value: decimal(route.distanceKm))),
                  const SizedBox(width: 8),
                  Expanded(child: MetricTile(label: 'Tiempo', value: '${decimal(route.durationMinutes / 60)} h')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationInput extends StatelessWidget {
  const _LocationInput({
    required this.label,
    required this.controller,
    required this.isLoading,
    required this.onSearch,
  });

  final String label;
  final TextEditingController controller;
  final bool isLoading;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      minLines: 1,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Escribí o tocá el mapa',
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                tooltip: 'Buscar $label',
                icon: const Icon(Icons.search),
                onPressed: () async => onSearch(),
              ),
      ),
      onSubmitted: (_) async => onSearch(),
    );
  }
}

class _RoutePickerMap extends StatelessWidget {
  const _RoutePickerMap({
    required this.origin,
    required this.destination,
    required this.routePoints,
    required this.pickTarget,
    required this.isLoading,
    required this.onPointPicked,
  });

  final LatLngValue? origin;
  final LatLngValue? destination;
  final List<LatLngValue> routePoints;
  final _RoutePickTarget pickTarget;
  final bool isLoading;
  final ValueChanged<LatLngValue> onPointPicked;

  @override
  Widget build(BuildContext context) {
    final center = _toLatLng(origin) ?? _toLatLng(destination) ?? const ll.LatLng(-34.6037, -58.3816);
    final points = routePoints.map(_toLatLng).nonNulls.toList();
    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 5,
                onTap: (_, point) => onPointPicked(
                  LatLngValue(latitude: point.latitude, longitude: point.longitude),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rentabilidad_flete.app',
                ),
                if (points.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: points, strokeWidth: 5, color: AppColors.roadYellow),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (origin != null)
                      Marker(
                        point: _toLatLng(origin)!,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.trip_origin, color: AppColors.decisionGo, size: 32),
                      ),
                    if (destination != null)
                      Marker(
                        point: _toLatLng(destination)!,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.place, color: AppColors.roadYellow, size: 34),
                      ),
                  ],
                ),
              ],
            ),
            if (isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x990B0E10),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.roadYellow, borderRadius: BorderRadius.circular(4)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      pickTarget == _RoutePickTarget.origin ? 'Tocá el origen' : 'Tocá el destino',
                      style: const TextStyle(color: AppColors.textOnYellow, fontWeight: FontWeight.w700),
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

  ll.LatLng? _toLatLng(LatLngValue? value) => value == null ? null : ll.LatLng(value.latitude, value.longitude);
}

enum _RoutePickTarget { origin, destination }
