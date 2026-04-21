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
    case 'disputed': return Colors.purple;
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
    case 'disputed': return '⚠ Under Review';
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
    case 'disputed':
      return 'RozRides support is reviewing this trip';
    default:
      return '';
  }
}
