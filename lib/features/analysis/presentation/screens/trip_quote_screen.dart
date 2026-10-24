import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../shared/layout/breakpoints.dart';
import '../../../../shared/widgets/metric_tile.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/feedback_link.dart';
import '../../../comparison/domain/models/comparison_trip.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../domain/models/profitability_status.dart';
import '../../domain/models/trip_analysis.dart';
import '../controllers/trip_quote_controller.dart';
import '../widgets/trip_wizard.dart';

class TripQuoteScreen extends StatefulWidget {
  const TripQuoteScreen({
    required this.controller,
    this.personalModeEnabled = false,
    this.feedbackWhatsAppNumber = '',
    this.initialStep,
    this.onComparisonTripReady,
    super.key,
  });

  final TripQuoteController controller;
  final bool personalModeEnabled;
  final String feedbackWhatsAppNumber;
  final WizardStep? initialStep;
  final ValueChanged<ComparisonTrip>? onComparisonTripReady;

  @override
  State<TripQuoteScreen> createState() => _TripQuoteScreenState();
}

class _TripQuoteScreenState extends State<TripQuoteScreen> {
  late WizardStep _step;

  TripQuoteController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep ?? _firstStep;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.purpose.label),
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
          onNewSimulation: () => setState(() => _step = _firstStep),
          feedbackWhatsAppNumber: widget.feedbackWhatsAppNumber,
          onAddToComparison: widget.onComparisonTripReady == null
              ? null
              : _completeComparisonTrip,
        ),
      ),
    );
  }

  void _completeComparisonTrip(ComparisonTrip trip) {
    widget.onComparisonTripReady?.call(trip);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      controller.resetSimulation();
      Navigator.of(context).pop();
    });
  }

  Future<void> _showHistory() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => HistoryScreen(
          controller: controller,
          showPersonalTrips: widget.personalModeEnabled,
          onOpenTrip: _openSavedTrip,
          onDuplicateTrip: _duplicateSavedTrip,
          onStartTrip: _startNewTrip,
        ),
      ),
    );
  }

  Future<void> _openSavedTrip(TripRecord trip) async {
    if (!widget.personalModeEnabled &&
        trip.trip.purpose == TripPurpose.personal) {
      return;
    }
    controller.openTrip(trip);
    setState(() => _step = WizardStep.review);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripResultScreen(
          controller: controller,
          onNewSimulation: () => setState(() => _step = _firstStep),
          feedbackWhatsAppNumber: widget.feedbackWhatsAppNumber,
        ),
      ),
    );
  }

  Future<void> _duplicateSavedTrip(TripRecord trip) async {
    if (!widget.personalModeEnabled &&
        trip.trip.purpose == TripPurpose.personal) {
      return;
    }
    controller.openTrip(trip);
    setState(() => _step = WizardStep.review);
    Navigator.of(context).pop();
  }

  Future<void> _startNewTrip() async {
    controller.resetSimulation();
    setState(() => _step = _firstStep);
    Navigator.of(context).pop();
  }

  WizardStep get _firstStep => controller.purpose == TripPurpose.personal
      ? WizardStep.vehicle
      : WizardStep.route;
}

class TripResultScreen extends StatelessWidget {
  const TripResultScreen({
    required this.controller,
    required this.onNewSimulation,
    this.feedbackWhatsAppNumber = '',
    this.onAddToComparison,
    super.key,
  });

  final TripQuoteController controller;
  final VoidCallback onNewSimulation;
  final ValueChanged<ComparisonTrip>? onAddToComparison;
  final String feedbackWhatsAppNumber;

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
        final personal = controller.purpose == TripPurpose.personal;
        final route = controller.effectiveRoute;
        final isExpanded = Breakpoints.isExpanded(
          MediaQuery.sizeOf(context).width,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(personal ? 'Viaje personal' : 'Resultado del viaje'),
          ),
          body: SafeArea(
            child: ResponsiveBody(
              maxWidth: isExpanded ? 1120 : 720,
              child: personal
                  ? _personalResult(context, analysis)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final useWideLayout = constraints.maxWidth >=
                            Breakpoints.expandedMinWidth;
                        if (!useWideLayout) {
                          return _compactFreightResult(
                            context,
                            analysis,
                            route?.distanceKm,
                            route?.durationDays,
                          );
                        }
                        return SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          child: _expandedFreightResult(
                            context,
                            analysis,
                            route?.distanceKm,
                            route?.durationDays,
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _personalResult(BuildContext context, TripAnalysis analysis) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        _ResultCard(
          title: 'Costo total del viaje',
          child: MetricTile(
            label: 'Costo total',
            value: money(analysis.totalCosts),
            accentColor: AppColors.roadYellow,
          ),
        ),
        const SizedBox(height: 12),
        _ResultCard(
          title: 'Desglose de costos',
          child: _MetricGrid(
            children: [
              MetricTile(
                label: 'Combustible (${decimal(_estimatedFuelLiters())} L)',
                value: money(analysis.fuelCost),
              ),
              MetricTile(
                label: 'Mantenimiento',
                value: money(analysis.maintenanceCost),
              ),
              MetricTile(
                label: 'Peajes',
                value: controller.costs.tolls == 0
                    ? 'No cargados'
                    : money(controller.costs.tolls),
              ),
              MetricTile(
                label: 'Otros gastos',
                value: money(controller.costs.allowances),
              ),
              if (controller.travelers > 1)
                MetricTile(
                  label: 'Costo por persona',
                  value: money(controller.costPerPerson),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Es una estimación. El consumo real cambia según la carga, la velocidad y el tránsito.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Estimación orientativa. Depende de los datos que cargaste y de las condiciones reales del viaje.',
        ),
        const SizedBox(height: 12),
        _resultActions(context, analysis),
        FeedbackLink(phoneNumber: feedbackWhatsAppNumber),
      ],
    );
  }

  Widget _compactFreightResult(
    BuildContext context,
    TripAnalysis analysis,
    double? distanceKm,
    double? durationDays,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasOutOfScaleValues(analysis)) ...[
                  _outOfScaleNotice(context),
                  const SizedBox(height: 12),
                ],
                _DecisionHeader(
                  status: analysis.status,
                  label: _statusLabel(analysis.status),
                  marginPercent: analysis.marginPercent,
                ),
                const SizedBox(height: 12),
                _ProfitSummary(
                  analysis: analysis,
                  distanceKm: distanceKm,
                  durationDays: durationDays,
                ),
                const SizedBox(height: 12),
                _ResultFinancialRow(analysis: analysis),
                const SizedBox(height: 12),
                _breakEvenCard(context, analysis),
                const SizedBox(height: 12),
                _costBreakdown(context, analysis),
                _unconfiguredCostNotice(),
                const SizedBox(height: 12),
                const Text(
                  'Estimación orientativa. Depende de los datos que cargaste y de las condiciones reales del viaje.',
                ),
                FeedbackLink(phoneNumber: feedbackWhatsAppNumber),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _resultActions(context, analysis),
        ),
      ],
    );
  }

  Widget _expandedFreightResult(
    BuildContext context,
    TripAnalysis analysis,
    double? distanceKm,
    double? durationDays,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasOutOfScaleValues(analysis)) ...[
                _outOfScaleNotice(context),
                const SizedBox(height: 12),
              ],
              _DecisionHeader(
                status: analysis.status,
                label: _statusLabel(analysis.status),
                marginPercent: analysis.marginPercent,
              ),
              const SizedBox(height: 12),
              _ProfitSummary(
                analysis: analysis,
                distanceKm: distanceKm,
                durationDays: durationDays,
              ),
              const SizedBox(height: 12),
              _ResultFinancialRow(analysis: analysis),
              const SizedBox(height: 12),
              _breakEvenCard(context, analysis),
              const SizedBox(height: 12),
              _resultActions(context, analysis),
              const SizedBox(height: 12),
              const Text(
                'Estimación orientativa. Depende de los datos que cargaste y de las condiciones reales del viaje.',
              ),
              FeedbackLink(phoneNumber: feedbackWhatsAppNumber),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _costBreakdown(context, analysis),
              _unconfiguredCostNotice(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _breakEvenCard(BuildContext context, TripAnalysis analysis) {
    final perTon = controller.pricingMode == PricingMode.perTon;
    return _ResultCard(
      title: perTon ? 'Precio mínimo por tonelada' : 'Precio de equilibrio',
      child: Text(
        perTon
            ? '${money(analysis.minimumPricePerTon)} por tonelada'
            : 'A ${money(analysis.breakEvenPrice)} cubrís los costos: no ganás ni perdés.',
      ),
    );
  }

  bool _hasOutOfScaleValues(TripAnalysis analysis) {
    final costs = analysis.totalCosts;
    if (costs <= 0) return false;
    return analysis.netProfit > 20 * costs ||
        analysis.marginPercent > 90 ||
        analysis.grossIncome < 0.01 * costs;
  }

  Widget _outOfScaleNotice(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Estos números parecen fuera de lo normal. Revisá los importes que cargaste.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Revisar importes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _costBreakdown(BuildContext context, TripAnalysis analysis) {
    return _ResultCard(
      title: 'Adónde se va la plata',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total ${money(analysis.totalCosts)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          _CostBreakdownRow(
            label: 'Combustible',
            amount: analysis.fuelCost,
            total: analysis.totalCosts,
          ),
          _CostBreakdownRow(
            label: 'Mantenimiento',
            amount: analysis.maintenanceCost,
            total: analysis.totalCosts,
          ),
          _CostBreakdownRow(
            label: 'Costos del camión por tiempo',
            amount: analysis.timeCost,
            total: analysis.totalCosts,
          ),
          _CostBreakdownRow(
            label: 'Peajes',
            amount: controller.costs.tolls,
            total: analysis.totalCosts,
            zeroLabel: 'No cargados',
          ),
          _CostBreakdownRow(
            label: 'Viáticos',
            amount: controller.costs.allowances,
            total: analysis.totalCosts,
          ),
        ],
      ),
    );
  }

  Widget _unconfiguredCostNotice() {
    if ((controller.vehicleProfile?.dailyFixedCost ?? 0) != 0) {
      return const SizedBox.shrink();
    }
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text(
        'No incluye costos que no cargaste, como seguro, amortización o sueldo.',
      ),
    );
  }

  Widget _resultActions(BuildContext context, TripAnalysis analysis) {
    final personal = controller.purpose == TripPurpose.personal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modificar datos'),
        ),
        const SizedBox(height: 8),
        if (onAddToComparison == null || personal)
          FilledButton.icon(
            onPressed: controller.isSaving
                ? null
                : () => _saveTripAndReturnHome(context),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              controller.isSaving ? 'Guardando...' : 'Guardar simulación',
            ),
          )
        else
          FilledButton.icon(
            onPressed: () => _addToComparison(context, analysis),
            icon: const Icon(Icons.add_chart_outlined),
            label: const Text('Agregar a comparación'),
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
    );
  }

  String _statusLabel(ProfitabilityStatus status) => switch (status) {
        ProfitabilityStatus.profitable => 'Margen saludable',
        ProfitabilityStatus.low => 'Margen bajo',
        ProfitabilityStatus.loss => 'No cubre los costos',
      };

  double _estimatedFuelLiters() {
    final profile = controller.activeVehicle;
    final route = controller.effectiveRoute;
    if (profile == null || route == null) return 0;
    return route.distanceKm * profile.consumptionLitersPer100Km / 100;
  }

  void _addToComparison(BuildContext context, TripAnalysis analysis) {
    final record = controller.createCurrentTripRecord();
    if (record == null) {
      return;
    }
    onAddToComparison?.call(
      ComparisonTrip(label: '', record: record, analysis: analysis),
    );
    Navigator.of(context).pop();
  }

  Future<void> _saveTripAndReturnHome(BuildContext context) async {
    await controller.saveCurrentTrip();
    if (!context.mounted || controller.errorMessage != null) {
      return;
    }

    controller.resetSimulation();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ProfitSummary extends StatelessWidget {
  const _ProfitSummary({
    required this.analysis,
    required this.distanceKm,
    required this.durationDays,
  });

  final TripAnalysis analysis;
  final double? distanceKm;
  final double? durationDays;

  @override
  Widget build(BuildContext context) {
    final days = durationDays?.ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(analysis.netProfit < 0 ? 'Te faltan' : 'Te quedan',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(money(analysis.netProfit.abs()),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: analysis.status.color,
                )),
        const SizedBox(height: 4),
        Text([
          '${money(analysis.profitPerKm)} por km',
          if (days != null) '$days ${days == 1 ? 'día' : 'días'} de viaje',
        ].join(' · ')),
      ],
    );
  }
}

class _ResultFinancialRow extends StatelessWidget {
  const _ResultFinancialRow({required this.analysis});

  final TripAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Oferta', analysis.grossIncome),
      ('Costos totales', analysis.totalCosts),
      ('Te quedan', analysis.netProfit),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics[index].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(metrics[index].$2),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CostBreakdownRow extends StatelessWidget {
  const _CostBreakdownRow({
    required this.label,
    required this.amount,
    required this.total,
    this.zeroLabel,
  });

  final String label;
  final double amount;
  final double total;
  final String? zeroLabel;

  @override
  Widget build(BuildContext context) {
    final proportion = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodyLarge)),
              Text(
                  amount == 0 && zeroLabel != null ? zeroLabel! : money(amount),
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: proportion,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: AppColors.roadYellow,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionHeader extends StatelessWidget {
  const _DecisionHeader({
    required this.status,
    required this.label,
    required this.marginPercent,
  });

  final ProfitabilityStatus status;
  final String label;
  final double marginPercent;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      ProfitabilityStatus.profitable => Icons.check_circle,
      ProfitabilityStatus.low => Icons.warning_amber_rounded,
      ProfitabilityStatus.loss => Icons.cancel,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.asphalt, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label · ${decimal(marginPercent)}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
