import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../domain/models/profitability_status.dart';
import '../controllers/trip_quote_controller.dart';
import '../widgets/trip_wizard.dart';

class TripQuoteScreen extends StatefulWidget {
  const TripQuoteScreen({
    required this.controller,
    this.openHistoryOnStart = false,
    super.key,
  });

  final TripQuoteController controller;
  final bool openHistoryOnStart;

  @override
  State<TripQuoteScreen> createState() => _TripQuoteScreenState();
}

class _TripQuoteScreenState extends State<TripQuoteScreen> {
  WizardStep _step = WizardStep.vehicle;

  TripQuoteController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (widget.openHistoryOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showHistory();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conviene este viaje?'),
        actions: [
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history),
            onPressed: _showHistory,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: TripWizard(
          controller: controller,
          step: _step,
          onStepChanged: (step) => setState(() => _step = step),
          onCalculate: _calculateTripAndOpenResults,
        ),
      ),
    );
  }

  Future<void> _calculateTripAndOpenResults() async {
    final canOpenResults = await controller.prepareAnalysis();
    if (!mounted || !canOpenResults) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripResultScreen(
          controller: controller,
          onNewSimulation: () => setState(() => _step = WizardStep.vehicle),
        ),
      ),
    );
  }

  void _showHistory() {
    controller.loadHistory();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isHistoryLoading) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (controller.history.isEmpty) {
            return const SizedBox(
              height: 220,
              child: Center(child: Text('Todavía no hay simulaciones.')),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: controller.history.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final trip = controller.history[index];
              return _HistoryTile(
                trip: trip,
                onTap: () {
                  controller.openTrip(trip);
                  setState(() => _step = WizardStep.review);
                  Navigator.of(context).pop();
                  Navigator.of(this.context).push<void>(
                    MaterialPageRoute(
                      builder: (context) => TripResultScreen(
                        controller: controller,
                        onNewSimulation: () => setState(
                          () => _step = WizardStep.vehicle,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class TripResultScreen extends StatelessWidget {
  const TripResultScreen({
    required this.controller,
    required this.onNewSimulation,
    super.key,
  });

  final TripQuoteController controller;
  final VoidCallback onNewSimulation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final analysis = controller.analysis;
        if (analysis == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Resultado del viaje')),
            body: const Center(
              child:
                  Text('No hay datos suficientes para mostrar el resultado.'),
            ),
          );
        }
        final route = controller.effectiveRoute;
        final conclusion = switch (analysis.status) {
          ProfitabilityStatus.profitable =>
            'El viaje cubre los costos y deja una ganancia saludable.',
          ProfitabilityStatus.low =>
            'El viaje deja ganancia, pero el margen es bajo. Conviene negociar precio o revisar costos.',
          ProfitabilityStatus.loss =>
            'El viaje no cubre los costos estimados. No conviene aceptarlo con estos datos.',
        };
        return Scaffold(
          appBar: AppBar(title: const Text('Resultado del viaje')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _DecisionHeader(status: analysis.status),
                const SizedBox(height: 12),
                _ResultCard(
                  title: 'Resumen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricGrid(
                        children: [
                          if (route != null)
                            MetricTile(
                              label: 'Kilómetros',
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
                      const SizedBox(height: 12),
                      Text(conclusion),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ResultCard(
                  title: 'Costos y rentabilidad',
                  child: _MetricGrid(
                    children: [
                      MetricTile(
                          label: 'Combustible',
                          value: money(analysis.fuelCost)),
                      MetricTile(
                          label: 'Mantenimiento',
                          value: money(analysis.maintenanceCost)),
                      MetricTile(
                          label: 'Peajes',
                          value: money(controller.costs.tolls)),
                      MetricTile(
                          label: 'Viáticos',
                          value: money(controller.costs.allowances)),
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
                          value: money(analysis.incomePerKm)),
                      MetricTile(
                          label: 'Costo/km', value: money(analysis.costPerKm)),
                      MetricTile(
                        label: 'Mínimo para no perder',
                        value: money(analysis.breakEvenPrice),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modificar datos'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      controller.isSaving ? null : controller.saveCurrentTrip,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    controller.isSaving ? 'Guardando...' : 'Guardar simulación',
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    controller.resetSimulation();
                    onNewSimulation();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.add_road_outlined),
                  label: const Text('Nueva simulación'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DecisionHeader extends StatelessWidget {
  const _DecisionHeader({required this.status});

  final ProfitabilityStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      ProfitabilityStatus.profitable => ('TE CONVIENE', Icons.check_circle),
      ProfitabilityStatus.low => ('MARGEN BAJO', Icons.warning_amber_rounded),
      ProfitabilityStatus.loss => ('NO ACEPTES', Icons.cancel),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Row(
          children: [
            Icon(icon, color: AppColors.asphalt, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.asphalt,
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.child});

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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.trip, required this.onTap});

  final TripRecord trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${trip.route.originName} → ${trip.route.destinationName}'),
      subtitle: Text(
          '${decimal(trip.route.distanceKm)} km · ${decimal(trip.marginPercent)}%'),
      trailing: Text(money(trip.netProfit)),
      onTap: onTap,
    );
  }
}
