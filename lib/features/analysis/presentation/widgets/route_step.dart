import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/layout/breakpoints.dart';
import '../../../route_planning/domain/models/lat_lng_value.dart';
import '../../../route_planning/domain/models/route_info.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
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
    final personal = controller.purpose == TripPurpose.personal;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isExpanded = Breakpoints.isExpanded(viewportWidth);
    final isCompact = Breakpoints.isCompact(viewportWidth);

    final routeDetails = _routeDetails(context, route, personal);
    final map = _RoutePickerMap(
      origin: controller.originPoint,
      destination: controller.destinationPoint,
      routePoints: route?.polyline ?? const [],
      pickTarget: pickTarget,
      isLoading: controller.isRouteLoading,
      height: isExpanded ? 420 : 220,
      allowSingleFingerDrag: !isCompact,
      onPointPicked: (point) {
        if (pickTarget == _RoutePickTarget.origin) {
          controller.setOriginPoint(point);
          setState(() => pickTarget = _RoutePickTarget.destination);
        } else {
          controller.setDestinationPoint(point);
        }
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mi viaje', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'Elegí origen y destino para calcular kilómetros y tiempo.'),
            const SizedBox(height: 12),
            if (isExpanded)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: routeDetails),
                  const SizedBox(width: 16),
                  Expanded(child: map),
                ],
              )
            else ...[
              routeDetails,
              const SizedBox(height: 12),
              map,
            ],
          ],
        ),
      ),
    );
  }

  Widget _routeDetails(
    BuildContext context,
    RouteInfo? route,
    bool personal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_RoutePickTarget>(
          segments: const [
            ButtonSegment(
                value: _RoutePickTarget.origin, label: Text('Origen')),
            ButtonSegment(
              value: _RoutePickTarget.destination,
              label: Text('Destino'),
            ),
          ],
          selected: {pickTarget},
          onSelectionChanged: (selected) =>
              setState(() => pickTarget = selected.first),
        ),
        const SizedBox(height: 10),
        _LocationInput(
          label: 'Origen',
          controller: originController,
          isLoading: controller.isOriginResolving,
          detail: _pointDetail(controller.originPoint),
          confirmationMessage:
              controller.originNeedsConfirmation ? 'Confirmá el origen.' : null,
          onChanged: controller.setOriginText,
          onSearch: () async {
            await controller.resolveOrigin(originController.text);
            if (mounted) {
              setState(() => pickTarget = _RoutePickTarget.destination);
            }
          },
        ),
        const SizedBox(height: 10),
        _LocationInput(
          label: 'Destino',
          controller: destinationController,
          isLoading: controller.isDestinationResolving,
          detail: _pointDetail(controller.destinationPoint),
          confirmationMessage: controller.destinationNeedsConfirmation
              ? 'Confirmá el destino.'
              : null,
          onChanged: controller.setDestinationText,
          onSearch: () =>
              controller.resolveDestination(destinationController.text),
        ),
        const SizedBox(height: 10),
        if (personal)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Incluir la vuelta'),
            value: controller.emptyReturn,
            onChanged: controller.setEmptyReturn,
          )
        else
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Solo ida')),
              ButtonSegment(
                value: true,
                label: Text('Ida y vuelta vacío'),
              ),
            ],
            selected: {controller.emptyReturn},
            onSelectionChanged: (selected) =>
                controller.setEmptyReturn(selected.first),
          ),
        if (!personal)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
                'Se estima con el mismo consumo que cargado; el real suele ser menor.'),
          ),
        if (!personal && controller.tollsEditedManually)
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 4),
            child: Text('Revisá si el monto de peajes incluye la vuelta.'),
          ),
        if (controller.isRouteLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Calculando kilómetros y tiempo…'),
        ],
        if (route != null) ...[
          const SizedBox(height: 10),
          Text('${route.originName} → ${route.destinationName}'),
          Text(
            '${decimal(route.distanceKm)} km en total · ${route.durationDays} ${route.durationDays == 1 ? 'día' : 'días'} estimados',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ],
    );
  }
}

class _LocationInput extends StatelessWidget {
  const _LocationInput({
    required this.label,
    required this.controller,
    required this.isLoading,
    required this.detail,
    required this.confirmationMessage,
    required this.onChanged,
    required this.onSearch,
  });

  final String label;
  final TextEditingController controller;
  final bool isLoading;
  final String? detail;
  final String? confirmationMessage;
  final ValueChanged<String> onChanged;
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
        helperText: confirmationMessage ?? detail,
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                tooltip: 'Buscar $label',
                icon: const Icon(Icons.search),
                onPressed: isLoading ? null : () async => onSearch(),
              ),
      ),
      onChanged: onChanged,
      onSubmitted: isLoading ? null : (_) async => onSearch(),
    );
  }
}

String? _pointDetail(LatLngValue? point) => point == null
    ? null
    : 'Coordenadas: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

class _RoutePickerMap extends StatelessWidget {
  const _RoutePickerMap({
    required this.origin,
    required this.destination,
    required this.routePoints,
    required this.pickTarget,
    required this.isLoading,
    required this.height,
    required this.allowSingleFingerDrag,
    required this.onPointPicked,
  });

  final LatLngValue? origin;
  final LatLngValue? destination;
  final List<LatLngValue> routePoints;
  final _RoutePickTarget pickTarget;
  final bool isLoading;
  final double height;
  final bool allowSingleFingerDrag;
  final ValueChanged<LatLngValue> onPointPicked;

  @override
  Widget build(BuildContext context) {
    final center = _toLatLng(origin) ??
        _toLatLng(destination) ??
        const ll.LatLng(-34.6037, -58.3816);
    final points = routePoints.map(_toLatLng).nonNulls.toList();
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 5,
                interactionOptions: InteractionOptions(
                  flags: allowSingleFingerDrag
                      ? InteractiveFlag.all
                      : InteractiveFlag.pinchZoom,
                ),
                onTap: (_, point) => onPointPicked(
                  LatLngValue(
                      latitude: point.latitude, longitude: point.longitude),
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
                      Polyline(
                          points: points,
                          strokeWidth: 5,
                          color: AppColors.roadYellow),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (origin != null)
                      Marker(
                        point: _toLatLng(origin)!,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.trip_origin,
                            color: AppColors.decisionGo, size: 32),
                      ),
                    if (destination != null)
                      Marker(
                        point: _toLatLng(destination)!,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.place,
                            color: AppColors.roadYellow, size: 34),
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
                  decoration: BoxDecoration(
                      color: AppColors.roadYellow,
                      borderRadius: BorderRadius.circular(4)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      pickTarget == _RoutePickTarget.origin
                          ? 'Tocá el origen'
                          : 'Tocá el destino',
                      style: const TextStyle(
                          color: AppColors.textOnYellow,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE60B0E10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text(
                    '© colaboradores de OpenStreetMap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  ll.LatLng? _toLatLng(LatLngValue? value) =>
      value == null ? null : ll.LatLng(value.latitude, value.longitude);
}

enum _RoutePickTarget { origin, destination }
