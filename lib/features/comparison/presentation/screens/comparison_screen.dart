import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../analysis/presentation/controllers/trip_quote_controller.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../domain/models/comparison_trip.dart';
import '../controllers/comparison_controller.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({
    required this.tripController,
    super.key,
  });

  final TripQuoteController tripController;

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late final ComparisonController comparisonController;

  @override
  void initState() {
    super.initState();
    comparisonController = ComparisonController();
  }

  @override
  void dispose() {
    comparisonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar viajes')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: comparisonController,
          builder: (context, _) {
            final trips = comparisonController.trips;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Compará tus mejores opciones antes de elegir una carga.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 20),
                for (final trip in trips) ...[
                  _TripSelectionCard(
                    trip: trip,
                    onRemove: () => comparisonController.remove(trip),
                  ),
                  const SizedBox(height: 12),
                ],
                if (trips.length < comparisonController.maxTrips)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addFromHistory,
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('Elegir del historial'),
                      ),
                    ],
                  ),
                if (comparisonController.canCompare) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _openResult,
                    icon: const Icon(Icons.compare_arrows_outlined),
                    label: const Text('Comparar viajes'),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  const Text('Agregá dos viajes para ver cuál conviene más.'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openResult() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ComparisonResultScreen(
          comparisonController: comparisonController,
        ),
      ),
    );
  }

  Future<void> _addFromHistory() async {
    widget.tripController.loadHistory();
    final selected = await showModalBottomSheet<TripRecord>(
      context: context,
      showDragHandle: true,
      builder: (context) => _HistoryTripPicker(
        tripController: widget.tripController,
        addedTripIds:
            comparisonController.trips.map((trip) => trip.record.id).toSet(),
        selectedPurpose: comparisonController.trips.isEmpty
            ? null
            : comparisonController.trips.first.record.trip.purpose,
      ),
    );
    if (!mounted || selected == null) {
      return;
    }

    final analysis = widget.tripController.analysisForRecord(selected)!;
    comparisonController.add(
      ComparisonTrip(label: '', record: selected, analysis: analysis),
    );
  }
}

enum _ComparisonSort { profit, margin, costPerKm }

class ComparisonResultScreen extends StatefulWidget {
  const ComparisonResultScreen({
    required this.comparisonController,
    super.key,
  });

  final ComparisonController comparisonController;

  @override
  State<ComparisonResultScreen> createState() => _ComparisonResultScreenState();
}

class _ComparisonResultScreenState extends State<ComparisonResultScreen> {
  _ComparisonSort _sort = _ComparisonSort.profit;

  @override
  Widget build(BuildContext context) {
    final trips = [...widget.comparisonController.trips]..sort(_sortTrips);
    final personal = trips.first.record.trip.purpose == TripPurpose.personal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado comparativo'),
        actions: [
          PopupMenuButton<_ComparisonSort>(
            tooltip: 'Ordenar viajes',
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              if (personal)
                const PopupMenuItem(
                    value: _ComparisonSort.profit,
                    child: Text('Ordenar por costo total'))
              else ...[
                const PopupMenuItem(
                    value: _ComparisonSort.profit,
                    child: Text('Ordenar por ganancia')),
                const PopupMenuItem(
                    value: _ComparisonSort.margin,
                    child: Text('Ordenar por margen')),
              ],
              const PopupMenuItem(
                  value: _ComparisonSort.costPerKm,
                  child: Text('Ordenar por costo/km')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Cada indicador destaca el viaje con el valor más conveniente. La elección también depende de tus tiempos, costos y necesidades operativas.'),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  return Column(
                    children: [
                      for (final trip in trips) ...[
                        _TripMetricsCard(
                          trip: trip,
                          comparedTrips: trips,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < trips.length; index++) ...[
                      Expanded(
                        child: _TripMetricsCard(
                          trip: trips[index],
                          comparedTrips: trips,
                        ),
                      ),
                      if (index < trips.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _sortTrips(ComparisonTrip first, ComparisonTrip second) =>
      switch (_sort) {
        _ComparisonSort.profit =>
          first.record.trip.purpose == TripPurpose.personal
              ? first.record.totalCosts.compareTo(second.record.totalCosts)
              : second.record.netProfit.compareTo(first.record.netProfit),
        _ComparisonSort.margin =>
          second.record.marginPercent.compareTo(first.record.marginPercent),
        _ComparisonSort.costPerKm =>
          first.costPerKm.compareTo(second.costPerKm),
      };
}

class _TripSelectionCard extends StatelessWidget {
  const _TripSelectionCard({required this.trip, required this.onRemove});

  final ComparisonTrip trip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final summary = trip.record.trip.purpose == TripPurpose.personal
        ? '${money(trip.record.totalCosts)} de costo'
        : '${money(trip.record.netProfit)} de ganancia';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(trip.label),
        subtitle: Text(
          '${trip.record.route.originName} → ${trip.record.route.destinationName}\n'
          '${decimal(trip.distanceKm)} km · $summary',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Quitar ${trip.label}',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

class _HistoryTripPicker extends StatelessWidget {
  const _HistoryTripPicker({
    required this.tripController,
    required this.addedTripIds,
    required this.selectedPurpose,
  });

  final TripQuoteController tripController;
  final Set<String> addedTripIds;
  final TripPurpose? selectedPurpose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.68,
      child: AnimatedBuilder(
        animation: tripController,
        builder: (context, _) {
          if (tripController.isHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = tripController.history;
          if (records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay simulaciones guardadas para comparar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Elegí un viaje guardado',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final alreadyAdded = addedTripIds.contains(record.id);
                    final purposeMismatch = selectedPurpose != null &&
                        record.trip.purpose != selectedPurpose;
                    return Card(
                      child: ListTile(
                        enabled: !alreadyAdded && !purposeMismatch,
                        leading: const Icon(Icons.route_outlined),
                        title: Text(
                          '${record.route.originName} → ${record.route.destinationName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(record.createdAt)} · ${decimal(record.route.distanceKm)} km\n${money(record.netProfit)} de ganancia',
                        ),
                        isThreeLine: true,
                        trailing: alreadyAdded
                            ? const Text('Agregado')
                            : purposeMismatch
                                ? const Text('Otro modo')
                                : const Icon(Icons.add_circle_outline),
                        onTap: alreadyAdded || purposeMismatch
                            ? null
                            : () => Navigator.of(context).pop(record),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TripMetricsCard extends StatelessWidget {
  const _TripMetricsCard({
    required this.trip,
    required this.comparedTrips,
  });

  final ComparisonTrip trip;
  final List<ComparisonTrip> comparedTrips;

  String? _bestLabel(num value, Iterable<num> values, {bool higher = true}) {
    final all = values.toList();
    if (all.length < 2) return null;
    final best = higher
        ? all.reduce((a, b) => a > b ? a : b)
        : all.reduce((a, b) => a < b ? a : b);
    return value == best ? (higher ? 'Mayor' : 'Menor') : null;
  }

  @override
  Widget build(BuildContext context) {
    final personal = trip.record.trip.purpose == TripPurpose.personal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MetricList(
              children: [
                if (!personal)
                  _MetricItem(
                      'Ganancia neta',
                      money(trip.record.netProfit),
                      _bestLabel(trip.record.netProfit,
                          comparedTrips.map((t) => t.record.netProfit))),
                if (!personal)
                  _MetricItem(
                      'Margen',
                      '${decimal(trip.record.marginPercent)}%',
                      _bestLabel(trip.record.marginPercent,
                          comparedTrips.map((t) => t.record.marginPercent))),
                _MetricItem(
                    'Costo total',
                    money(trip.record.totalCosts),
                    _bestLabel(trip.record.totalCosts,
                        comparedTrips.map((t) => t.record.totalCosts),
                        higher: false)),
                if (!personal)
                  _MetricItem('Ingreso', money(trip.record.income)),
                _MetricItem('Kilómetros', '${decimal(trip.distanceKm)} km'),
                _MetricItem(
                    'Tiempo',
                    '${decimal(trip.durationHours)} h',
                    _bestLabel(trip.durationHours,
                        comparedTrips.map((t) => t.durationHours),
                        higher: false)),
                if (!personal)
                  _MetricItem(
                      'Ganancia/km',
                      money(trip.profitPerKm),
                      _bestLabel(trip.profitPerKm,
                          comparedTrips.map((t) => t.profitPerKm))),
                if (!personal)
                  _MetricItem(
                      'Ganancia/hora',
                      money(trip.profitPerHour),
                      _bestLabel(trip.profitPerHour,
                          comparedTrips.map((t) => t.profitPerHour))),
                if (!personal)
                  _MetricItem('ROI', '${decimal(trip.roiPercent)}%'),
                _MetricItem(
                    'Costo/km',
                    money(trip.costPerKm),
                    _bestLabel(
                        trip.costPerKm, comparedTrips.map((t) => t.costPerKm),
                        higher: false)),
                if (!personal)
                  _MetricItem(
                      'Ingreso/km',
                      money(trip.incomePerKm),
                      _bestLabel(trip.incomePerKm,
                          comparedTrips.map((t) => t.incomePerKm))),
                if (!personal)
                  _MetricItem(
                      'Rentabilidad/litro',
                      trip.record.vehicleProfile == null
                          ? 'Dato no disponible'
                          : money(trip.profitabilityPerLiter),
                      trip.record.vehicleProfile == null
                          ? null
                          : _bestLabel(
                              trip.profitabilityPerLiter,
                              comparedTrips
                                  .where((t) => t.record.vehicleProfile != null)
                                  .map((t) => t.profitabilityPerLiter))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricList extends StatelessWidget {
  const _MetricList({required this.children});

  final List<_MetricItem> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in children)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MetricTile(
                label: item.bestLabel == null
                    ? item.label
                    : '${item.label} · ${item.bestLabel}',
                value: item.value),
          ),
      ],
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value, [this.bestLabel]);

  final String label;
  final String value;
  final String? bestLabel;
}
