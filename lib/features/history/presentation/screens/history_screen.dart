import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../analysis/domain/models/profitability_status.dart';
import '../../../analysis/presentation/controllers/trip_quote_controller.dart';
import '../../../comparison/presentation/screens/comparison_screen.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../domain/models/trip_record.dart';

enum HistoryFilter { all, profitable, low, loss }

enum HistorySort { newest, oldest, highestProfit, lowestProfit }

typedef HistoryTripAction = Future<void> Function(TripRecord trip);
typedef HistoryAction = Future<void> Function();

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.controller,
    required this.onOpenTrip,
    required this.onDuplicateTrip,
    required this.onStartTrip,
    this.showPersonalTrips = false,
    super.key,
  });

  final TripQuoteController controller;
  final HistoryTripAction onOpenTrip;
  final HistoryTripAction onDuplicateTrip;
  final HistoryAction onStartTrip;
  final bool showPersonalTrips;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final searchController = TextEditingController();
  HistoryFilter filter = HistoryFilter.all;
  HistorySort sort = HistorySort.newest;

  TripQuoteController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.loadHistory();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Comparar viajes guardados',
            icon: const Icon(Icons.compare_arrows_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ComparisonScreen(tripController: controller),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 900,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (controller.isHistoryLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final trips = _visibleTrips;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _HistoryControls(
                      searchController: searchController,
                      filter: filter,
                      sort: sort,
                      onQueryChanged: (_) => setState(() {}),
                      onFilterChanged: (value) =>
                          setState(() => filter = value),
                      onSortChanged: (value) => setState(() => sort = value),
                    ),
                  ),
                  if (controller.historyErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.cloud_off_outlined),
                          title: Text(controller.historyErrorMessage!),
                          trailing: IconButton(
                            tooltip: 'Reintentar',
                            icon: const Icon(Icons.refresh),
                            onPressed: () => controller.loadHistory(),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: controller.history.isEmpty
                        ? _EmptyHistory(onStartTrip: widget.onStartTrip)
                        : trips.isEmpty
                            ? const _NoMatches()
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: trips.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _HistoryTripCard(
                                    trip: trips[index],
                                    status: trips[index].trip.purpose ==
                                            TripPurpose.personal
                                        ? null
                                        : _statusFor(trips[index]),
                                    onOpen: () =>
                                        widget.onOpenTrip(trips[index]),
                                    onDuplicate: () =>
                                        widget.onDuplicateTrip(trips[index]),
                                    onDelete: () =>
                                        _confirmDelete(trips[index]),
                                    onShare: () => _showSharePlaceholder(),
                                  ),
                                ),
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<TripRecord> get _visibleTrips {
    final query = searchController.text.trim().toLowerCase();
    final trips = controller.history.where((trip) {
      if (!widget.showPersonalTrips &&
          trip.trip.purpose == TripPurpose.personal) {
        return false;
      }
      final matchesQuery = query.isEmpty ||
          trip.route.originName.toLowerCase().contains(query) ||
          trip.route.destinationName.toLowerCase().contains(query);
      final isPersonal = trip.trip.purpose == TripPurpose.personal;
      final status =
          trip.trip.purpose == TripPurpose.personal ? null : _statusFor(trip);
      final matchesFilter = isPersonal
          ? filter == HistoryFilter.all
          : switch (filter) {
              HistoryFilter.all => true,
              HistoryFilter.profitable =>
                status == ProfitabilityStatus.profitable,
              HistoryFilter.low => status == ProfitabilityStatus.low,
              HistoryFilter.loss => status == ProfitabilityStatus.loss,
            };
      return matchesQuery && matchesFilter;
    }).toList();

    trips.sort((first, second) => switch (sort) {
          HistorySort.newest => second.createdAt.compareTo(first.createdAt),
          HistorySort.oldest => first.createdAt.compareTo(second.createdAt),
          HistorySort.highestProfit =>
            second.netProfit.compareTo(first.netProfit),
          HistorySort.lowestProfit =>
            first.netProfit.compareTo(second.netProfit),
        });
    return trips;
  }

  ProfitabilityStatus _statusFor(TripRecord trip) =>
      trip.savedStatus ??
      controller.calculator.statusForValues(
        netProfit: trip.netProfit,
        marginPercent: trip.marginPercent,
      );

  Future<void> _confirmDelete(TripRecord trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar viaje guardado'),
        content: Text(
            '¿Querés eliminar ${trip.route.originName} → ${trip.route.destinationName} del historial?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await controller.deleteTrip(trip.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Viaje eliminado.')));
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No se pudo eliminar el viaje. Revisá tu conexión e intentá de nuevo.')));
      }
    }
  }

  void _showSharePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Compartir estará disponible próximamente.')),
    );
  }
}

class _HistoryControls extends StatelessWidget {
  const _HistoryControls({
    required this.searchController,
    required this.filter,
    required this.sort,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final HistoryFilter filter;
  final HistorySort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<HistoryFilter> onFilterChanged;
  final ValueChanged<HistorySort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Buscar origen o destino',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final segments = <Widget>[
              for (final entry in const [
                (HistoryFilter.all, 'Todos'),
                (HistoryFilter.profitable, 'Conviene'),
                (HistoryFilter.low, 'Margen bajo'),
                (HistoryFilter.loss, 'No conviene'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: filter == entry.$1,
                  onSelected: (_) => onFilterChanged(entry.$1),
                ),
            ];
            if (constraints.maxWidth < 420) {
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: segments,
              );
            }
            return SizedBox(
              width: double.infinity,
              child: SegmentedButton<HistoryFilter>(
                segments: const [
                  ButtonSegment(value: HistoryFilter.all, label: Text('Todos')),
                  ButtonSegment(
                    value: HistoryFilter.profitable,
                    label: Text('Conviene'),
                  ),
                  ButtonSegment(
                    value: HistoryFilter.low,
                    label: Text('Margen bajo'),
                  ),
                  ButtonSegment(
                    value: HistoryFilter.loss,
                    label: Text('No conviene'),
                  ),
                ],
                selected: {filter},
                showSelectedIcon: false,
                onSelectionChanged: (selected) =>
                    onFilterChanged(selected.first),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<HistorySort>(
          // Keep compatibility with the Flutter 3.27.4 SDK used by Vercel.
          // ignore: deprecated_member_use
          value: sort,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Ordenar por',
            prefixIcon: Icon(Icons.sort),
          ),
          items: const [
            DropdownMenuItem(
              value: HistorySort.newest,
              child: Text('Más reciente'),
            ),
            DropdownMenuItem(
              value: HistorySort.oldest,
              child: Text('Más antiguo'),
            ),
            DropdownMenuItem(
              value: HistorySort.highestProfit,
              child: Text('Mayor ganancia'),
            ),
            DropdownMenuItem(
              value: HistorySort.lowestProfit,
              child: Text('Menor ganancia'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onSortChanged(value);
            }
          },
        ),
      ],
    );
  }
}

class _HistoryTripCard extends StatelessWidget {
  const _HistoryTripCard({
    required this.trip,
    required this.status,
    required this.onOpen,
    required this.onDuplicate,
    required this.onDelete,
    required this.onShare,
  });

  final TripRecord trip;
  final ProfitabilityStatus? status;
  final Future<void> Function() onOpen;
  final Future<void> Function() onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isPersonal = trip.trip.purpose == TripPurpose.personal;
    final statusColor = status?.color ?? AppColors.roadYellow;
    final statusLabel = isPersonal ? 'Personal' : _historyStatusLabel(status!);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<_QuickAction>(
                    tooltip: 'Acciones rápidas',
                    onSelected: (action) {
                      switch (action) {
                        case _QuickAction.duplicate:
                          onDuplicate();
                        case _QuickAction.delete:
                          onDelete();
                        case _QuickAction.share:
                          onShare();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _QuickAction.duplicate,
                        child: Text('Duplicar simulación'),
                      ),
                      PopupMenuItem(
                        value: _QuickAction.delete,
                        child: Text('Eliminar'),
                      ),
                      PopupMenuItem(
                        value: _QuickAction.share,
                        child: Text('Compartir'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${trip.route.originName} → ${trip.route.destinationName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy · HH:mm').format(trip.createdAt),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  if (isPersonal)
                    _QuickMetric(
                      'Costo total',
                      money(trip.totalCosts),
                      AppColors.roadYellow,
                    )
                  else ...[
                    _QuickMetric(
                        'Ganancia', money(trip.netProfit), statusColor),
                    _QuickMetric(
                      'Margen',
                      '${decimal(trip.marginPercent)}%',
                      AppColors.textPrimary,
                    ),
                  ],
                  _QuickMetric(
                    'Distancia',
                    '${decimal(_effectiveDistance(trip))} km',
                    AppColors.textPrimary,
                  ),
                  if (!isPersonal)
                    _QuickMetric(
                        'Precio', money(trip.income), AppColors.textPrimary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _effectiveDistance(TripRecord item) =>
      item.emptyReturn ? item.route.distanceKm * 2 : item.route.distanceKm;
}

String _historyStatusLabel(ProfitabilityStatus status) => status.label;

class _QuickMetric extends StatelessWidget {
  const _QuickMetric(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onStartTrip});

  final Future<void> Function() onStartTrip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.history_toggle_off_outlined,
                      color: AppColors.roadYellow,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aún no realizaste ninguna simulación.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => onStartTrip(),
              icon: const Icon(Icons.add_road_outlined),
              label: const Text('Hacer mi primera simulación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No encontramos simulaciones con esos filtros.'),
    );
  }
}

enum _QuickAction { duplicate, delete, share }
