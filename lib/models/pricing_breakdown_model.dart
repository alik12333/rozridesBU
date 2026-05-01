/// Data class representing the full cash payment breakdown for a booking.
/// All amounts are in PKR.
class CashPricingBreakdown {
  final int totalDays;
  final double pricePerDay;

  /// Driver fee per day (0 if no driver)
  final double driverFeePerDay;

  /// Total rental cost = (pricePerDay + driverFeePerDay) × totalDays
  final double totalRent;

  /// Fixed security deposit set by the platform
  final double securityDeposit;

  /// Amount renter must bring to pickup (= securityDeposit)
  final double depositAtPickup;

  /// Amount renter pays to host at the time of car return (= totalRent)
  final double payAtReturn;

  /// Amount renter receives back from host at return if no damage (= securityDeposit)
  final double receiveAtReturn;

  /// Actual cost to the renter after deposit is returned (= totalRent)
  final double netCostToRenter;

  const CashPricingBreakdown({
    required this.totalDays,
    required this.pricePerDay,
    required this.driverFeePerDay,
    required this.totalRent,
    required this.securityDeposit,
    required this.depositAtPickup,
    required this.payAtReturn,
    required this.receiveAtReturn,
    required this.netCostToRenter,
  });
}
