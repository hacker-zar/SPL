import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../analysis/presentation/controllers/trip_quote_controller.dart';
import '../../../analysis/presentation/screens/trip_quote_screen.dart';
import '../../../analysis/presentation/widgets/trip_wizard.dart';
import '../../../history/domain/models/trip_record.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.controller,
    this.personalModeEnabled = false,
    super.key,
  });

  final TripQuoteController controller;
  final bool personalModeEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 42, 24, 32),
              children: [
                const _BrandHeader(),
                const SizedBox(height: 40),
                _HomeActionCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Flete',
                  description: 'Calculá si te conviene aceptar un viaje.',
                  onTap: () => _openTripFlow(context, TripPurpose.freight),
                ),
                if (personalModeEnabled) ...[
                  const SizedBox(height: 14),
                  _HomeActionCard(
                    icon: Icons.directions_car_outlined,
                    title: 'Viaje personal',
                    description: 'Calculá cuánto vas a gastar en un viaje.',
                    badge: 'Beta',
                    onTap: () => _openTripFlow(context, TripPurpose.personal),
                  ),
                ],
                const SizedBox(height: 14),
                _HomeActionCard(
                  icon: Icons.history,
                  title: 'Historial',
                  description: 'Consultá simulaciones guardadas.',
                  onTap: () => _openHistory(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTripFlow(BuildContext context,
      [TripPurpose purpose = TripPurpose.freight]) {
    if (purpose == TripPurpose.personal && !personalModeEnabled) {
      return Future<void>.value();
    }
    controller.startTrip(purpose);
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripQuoteScreen(
          controller: controller,
          personalModeEnabled: personalModeEnabled,
        ),
      ),
    );
  }

  Future<void> _openHistory(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => HistoryScreen(
          controller: controller,
          showPersonalTrips: personalModeEnabled,
          onOpenTrip: (trip) => _openSavedTrip(context, trip),
          onDuplicateTrip: (trip) => _duplicateTrip(context, trip),
          onStartTrip: () => _openTripFlow(context),
        ),
      ),
    );
  }

  Future<void> _openSavedTrip(BuildContext context, TripRecord trip) async {
    if (!personalModeEnabled && trip.trip.purpose == TripPurpose.personal) {
      return;
    }
    controller.openTrip(trip);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripResultScreen(
          controller: controller,
          onNewSimulation: () {},
        ),
      ),
    );
  }

  Future<void> _duplicateTrip(BuildContext context, TripRecord trip) async {
    if (!personalModeEnabled && trip.trip.purpose == TripPurpose.personal) {
      return;
    }
    controller.openTrip(trip);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TripQuoteScreen(
          controller: controller,
          personalModeEnabled: personalModeEnabled,
          initialStep: WizardStep.review,
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.roadYellow,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'NetoKM',
              style: TextStyle(
                color: AppColors.textOnYellow,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Calculá cuánto cuesta cada kilómetro.',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Costos claros para cada viaje.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Semantics(
      button: isEnabled,
      enabled: isEnabled,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? AppColors.roadYellowDim
                        : AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      icon,
                      color: isEnabled
                          ? AppColors.roadYellow
                          : AppColors.textSecondary,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.roadYellowDim,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                child: Text(
                                  badge!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.roadYellow,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isEnabled) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, color: AppColors.roadYellow),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
