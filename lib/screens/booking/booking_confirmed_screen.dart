import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingConfirmedScreen extends StatelessWidget {
  final String bookingId;
  final String hostName;
  final String carName;
  final double depositAmount;
  final DateTime expiresAt;

  const BookingConfirmedScreen({
    super.key,
    required this.bookingId,
    required this.hostName,
    required this.carName,
    required this.depositAmount,
    required this.expiresAt,
  });

  String _formatPKR(double amount) =>
      'PKR ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Green checkmark ──────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 60,
                  color: Colors.green.shade600,
                ),
              ),

              const SizedBox(height: 28),

              // ── Title ────────────────────────────────────────────────────
              const Text(
                'Request Sent!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // ── Body ─────────────────────────────────────────────────────
              Text(
                'Your booking request has been sent to $hostName. They have 24 hours to respond. You will be notified the moment they accept or decline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // ── Deposit info card ────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.amber.shade800, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'While you wait, have ${_formatPKR(depositAmount)} cash ready for the security deposit in case your request is accepted.',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber.shade900,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Expiry note ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Request expires: ${DateFormat('MMM d, yyyy • h:mm a').format(expiresAt)}',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // ── Buttons ──────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to MyBookingsScreen
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                    // TODO: switch tab to "My Bookings" when tab navigation is added
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'VIEW MY BOOKINGS',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    foregroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'BACK TO HOME',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
