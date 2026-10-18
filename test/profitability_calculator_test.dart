import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/analysis/domain/models/profitability_status.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  const calculator = ProfitabilityCalculator(
    marginThresholds: ProfitabilityThresholds(lowMarginPercent: 10),
  );
  const route = RouteInfo(
    originName: 'Rosario',
    destinationName: 'Cordoba',
    origin: LatLngValue(latitude: -32.9442, longitude: -60.6505),
    destination: LatLngValue(latitude: -31.4201, longitude: -64.1888),
    distanceKm: 400,
    durationMinutes: 360,
  );
  const trip = TripInputs(
    pricingMode: PricingMode.perTon,
    tons: 20,
    pricePerTon: 50000,
  );
  const vehicleProfile = VehicleProfile(
    plate: 'AA123BB',
    consumptionLitersPer100Km: 30,
    maintenanceCostPerKm: 100,
    capacityTons: 28,
  );

  test('calculates a profitable trip', () {
    final analysis = calculator.calculate(
      route: route,
      trip: trip,
      costs: const CostInputs(
        fuelPricePerLiter: 1000,
        tolls: 50000,
        allowances: 30000,
      ),
      vehicleProfile: vehicleProfile,
      emptyReturn: false,
    );

    expect(analysis.grossIncome, 1000000);
    expect(analysis.fuelCost, 120000);
    expect(analysis.maintenanceCost, 40000);
    expect(analysis.totalCosts, 240000);
    expect(analysis.netProfit, 760000);
    expect(analysis.status, ProfitabilityStatus.profitable);
  });

  test('empty return doubles distance-sensitive costs', () {
    final outbound = calculator.calculate(
      route: route,
      trip: trip,
      costs: const CostInputs(
        fuelPricePerLiter: 1000,
      ),
      vehicleProfile: vehicleProfile,
      emptyReturn: false,
    );

    final withReturn = calculator.calculate(
      route: route,
      trip: trip,
      costs: const CostInputs(
        fuelPricePerLiter: 1000,
      ),
      vehicleProfile: vehicleProfile,
      emptyReturn: true,
    );

    expect(withReturn.fuelCost, outbound.fuelCost * 2);
    expect(withReturn.maintenanceCost, outbound.maintenanceCost * 2);
    expect(withReturn.costPerKm, outbound.costPerKm);
  });

  test('marks trips with negative utility as loss', () {
    final analysis = calculator.calculate(
      route: route,
      trip: const TripInputs(
        pricingMode: PricingMode.flatRate,
        flatRate: 1000,
      ),
      costs: const CostInputs(
        fuelPricePerLiter: 1000,
      ),
      vehicleProfile: vehicleProfile,
      emptyReturn: false,
    );

    expect(analysis.status, ProfitabilityStatus.loss);
  });

  test('zero income has zero margin and flat rate zero per ton is safe', () {
    final analysis = calculator.calculate(
      route: route,
      trip: const TripInputs(pricingMode: PricingMode.flatRate, flatRate: 0),
      costs: const CostInputs(),
      vehicleProfile: vehicleProfile,
      emptyReturn: false,
    );
    expect(analysis.marginPercent, 0);
    expect(analysis.minimumPricePerTon, 0);
  });

  test('marks positive margin below ten percent as low', () {
    final analysis = calculator.calculate(
      route: route,
      trip:
          const TripInputs(pricingMode: PricingMode.flatRate, flatRate: 170000),
      costs: const CostInputs(fuelPricePerLiter: 1000),
      vehicleProfile: vehicleProfile,
      emptyReturn: false,
    );
    expect(analysis.marginPercent, greaterThan(0));
    expect(analysis.marginPercent, lessThan(10));
    expect(analysis.status, ProfitabilityStatus.low);
  });

  test('daily fixed cost uses effective route duration, including return', () {
    const profile = VehicleProfile(
      consumptionLitersPer100Km: 30,
      maintenanceCostPerKm: 100,
      capacityTons: 28,
      dailyFixedCost: 12000,
    );
    const longRoute = RouteInfo(
      originName: 'Rosario',
      destinationName: 'Cordoba',
      origin: LatLngValue(latitude: -32.9442, longitude: -60.6505),
      destination: LatLngValue(latitude: -31.4201, longitude: -64.1888),
      distanceKm: 400,
      durationMinutes: 1500,
    );
    final outbound = calculator.calculate(
        route: longRoute,
        trip: trip,
        costs: const CostInputs(),
        vehicleProfile: profile,
        emptyReturn: false);
    final withReturn = calculator.calculate(
        route: longRoute,
        trip: trip,
        costs: const CostInputs(),
        vehicleProfile: profile,
        emptyReturn: true);
    expect(outbound.timeCost, 12500);
    expect(withReturn.timeCost, 25000);
    expect(withReturn.totalCosts, greaterThan(outbound.totalCosts));
  });

  test('daily fixed cost zero preserves prior cost totals', () {
    final analysis = calculator.calculate(
        route: route,
        trip: trip,
        costs: const CostInputs(
            fuelPricePerLiter: 1000, tolls: 50000, allowances: 30000),
        vehicleProfile: vehicleProfile,
        emptyReturn: false);
    expect(analysis.timeCost, 0);
    expect(analysis.totalCosts, 240000);
  });
}
