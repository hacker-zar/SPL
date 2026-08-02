import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../analysis/presentation/controllers/trip_quote_controller.dart';
import '../../../analysis/presentation/screens/trip_quote_screen.dart';
import '../../../history/domain/models/trip_record.dart';
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
                        onPressed: _addTrip,
                        icon: const Icon(Icons.add_road_outlined),
                        label: Text(
                          'Agregar ${comparisonController.nextLabel}',
                        ),
                      ),
                      const SizedBox(height: 8),
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

  Future<void> _addTrip() {
    widget.tripController.resetSimulation();
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripQuoteScreen(
          controller: widget.tripController,
          onComparisonTripReady: comparisonController.add,
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
      ),
    );
    if (!mounted || selected == null) {
      return;
    }

    final analysis = widget.tripController.analysisForRecord(selected);
    if (analysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurá tu camión para comparar este viaje.'),
        ),
      );
      return;
    }
    comparisonController.add(
      ComparisonTrip(label: '', record: selected, analysis: analysis),
    );
  }
}

class ComparisonResultScreen extends StatelessWidget {
  const ComparisonResultScreen({
    required this.comparisonController,
    super.key,
  });

  final ComparisonController comparisonController;

  @override
  Widget build(BuildContext context) {
    final decision = comparisonController.decision;
    final trips = comparisonController.trips;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado comparativo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _RecommendationCard(decision: decision),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  return Column(
                    children: [
                      for (final trip in trips) ...[
                        _TripMetricsCard(
                          trip: trip,
                          isRecommended: trip == decision.recommended,
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
                          isRecommended: trips[index] == decision.recommended,
                        ),
                      ),
                      if (index < trips.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _DifferenceCard(decision: decision),
          ],
        ),
      ),
    );
  }
}

class _TripSelectionCard extends StatelessWidget {
  const _TripSelectionCard({required this.trip, required this.onRemove});

  final ComparisonTrip trip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(trip.label),
        subtitle: Text(
          '${trip.record.route.originName} → ${trip.record.route.destinationName}\n'
          '${decimal(trip.distanceKm)} km · ${money(trip.record.netProfit)} de ganancia',
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
  });

  final TripQuoteController tripController;
  final Set<String> addedTripIds;

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
                    return Card(
                      child: ListTile(
                        enabled: !alreadyAdded,
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
                            : const Icon(Icons.add_circle_outline),
                        onTap: alreadyAdded
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

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.decision});

  final ComparisonDecision decision;

  @override
  Widget build(BuildContext context) {
    final headline = decision.bothAreLosses
        ? 'Ningún viaje cubre los costos estimados.'
        : 'Conviene aceptar el ${decision.recommended.label}.';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.roadYellow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: AppColors.asphalt),
                SizedBox(width: 8),
                Text(
                  'RECOMENDACIÓN',
                  style: TextStyle(
                    color: AppColors.asphalt,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              headline,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.asphalt,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            if (decision.bothAreLosses)
              const Text(
                'El viaje recomendado pierde menos dinero, pero conviene renegociar ambas ofertas.',
                style: TextStyle(color: AppColors.asphalt),
              )
            else
              Text(
                'Motivos: ${decision.reasons.join(', ')}.',
                style: const TextStyle(color: AppColors.asphalt),
              ),
            if (decision.isClose) ...[
              const SizedBox(height: 8),
              const Text(
                'La diferencia económica es pequeña. Otros factores operativos también pueden influir en la decisión.',
                style: TextStyle(
                  color: AppColors.asphalt,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripMetricsCard extends StatelessWidget {
  const _TripMetricsCard({
    required this.trip,
    required this.isRecommended,
  });

  final ComparisonTrip trip;
  final bool isRecommended;

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
                Expanded(
                  child: Text(
                    trip.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isRecommended)
                  const Icon(Icons.emoji_events_outlined,
                      color: AppColors.roadYellow),
              ],
            ),
            const SizedBox(height: 10),
            _MetricList(
              children: [
                _MetricItem('Ganancia estimada', money(trip.record.netProfit)),
                _MetricItem('Margen', '${decimal(trip.record.marginPercent)}%'),
                _MetricItem('Costo total', money(trip.record.totalCosts)),
                _MetricItem('Ingreso', money(trip.record.income)),
                _MetricItem('Kilómetros', '${decimal(trip.distanceKm)} km'),
                _MetricItem('Tiempo', '${decimal(trip.durationHours)} h'),
                _MetricItem('Ganancia/km', money(trip.profitPerKm)),
                _MetricItem('Ganancia/hora', money(trip.profitPerHour)),
                _MetricItem('ROI', '${decimal(trip.roiPercent)}%'),
                _MetricItem('Costo/km', money(trip.costPerKm)),
                _MetricItem('Ingreso/km', money(trip.incomePerKm)),
                _MetricItem(
                    'Rentabilidad/litro', money(trip.profitabilityPerLiter)),
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
            child: MetricTile(label: item.label, value: item.value),
          ),
      ],
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value);

  final String label;
  final String value;
}

class _DifferenceCard extends StatelessWidget {
  const _DifferenceCard({required this.decision});

  final ComparisonDecision decision;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Diferencia económica',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${decision.recommended.label} supera a ${decision.alternative.label} por ${money(decision.absoluteDifference)} (${decimal(decision.percentageDifference)}%).',
            ),
          ],
        ),
      ),
    );
  }
}
