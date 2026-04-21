import '../models/pricing_breakdown_model.dart';

class PricingCalculator {
  static CashPricingBreakdown calculate({
    required DateTime startDate,
    required DateTime endDate,
    required double pricePerDay,
    double securityDeposit = 10000.0,
  }) {
    final int totalDays = endDate.difference(startDate).inDays + 1;

    if (totalDays <= 0) {
      throw Exception('Invalid date range: totalDays must be greater than zero.');
    }

    final double totalRent = pricePerDay * totalDays;

    return CashPricingBreakdown(
      totalDays: totalDays,
      pricePerDay: pricePerDay,
      totalRent: totalRent,
      securityDeposit: securityDeposit,
      depositAtPickup: securityDeposit,  // Renter brings this cash to give host at pickup
      payAtReturn: totalRent,            // Renter pays this cash to host when returning car
      receiveAtReturn: securityDeposit,  // Host gives this back if no damage
      netCostToRenter: totalRent,        // Actual cost — deposit is refundable
    );
  }
}
