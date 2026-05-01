import 'package:flutter/material.dart';

Color getStatusColor(String status) {
  switch (status) {
    case 'pending': return Colors.orange;
    case 'confirmed': return Colors.green;
    case 'active': return Colors.blue;
    case 'completed': return Colors.grey;
    case 'cancelled': return Colors.red;
    case 'rejected': return Colors.red;
    case 'expired': return Colors.red;
    case 'flagged': return Colors.purple;
    case 'decided': return Colors.amber.shade700;
    default: return Colors.grey;
  }
}

String getStatusLabel(String status) {
  switch (status) {
    case 'pending': return '⏱ Awaiting Host';
    case 'confirmed': return '✅ Confirmed';
    case 'active': return '🚗 Trip Active';
    case 'completed': return '✓ Completed';
    case 'cancelled': return '✗ Cancelled';
    case 'rejected': return '✗ Declined by Host';
    case 'expired': return '✗ Request Expired';
    case 'flagged': return '⚠ Under Review';
    case 'decided': return '⚖ Admin Decision Posted';
    default: return 'Unknown';
  }
}

String getStatusDescription(String status) {
  switch (status) {
    case 'pending':
      return 'Waiting for host to accept or decline';
    case 'confirmed':
      return 'Booking accepted — prepare cash for pickup';
    case 'active':
      return 'Trip in progress — deposit collected';
    case 'completed':
      return 'Trip finished — all cash settled';
    case 'cancelled':
      return 'Booking was cancelled';
    case 'rejected':
      return 'Host declined this request';
    case 'expired':
      return 'Host did not respond in time';
    case 'flagged':
      return 'RozRides is reviewing this trip. You will be notified of the outcome.';
    case 'decided':
      return 'Admin has posted a decision. Open the booking to confirm your settlement.';
    default:
      return '';
  }
}
