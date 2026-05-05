import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'lib/models/booking_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Just get all bookings to see if ANY fail
  final snap = await FirebaseFirestore.instance.collection('bookings').get();
  int success = 0;
  for (var doc in snap.docs) {
    try {
      final b = BookingModel.fromMap(doc.data(), doc.id);
      success++;
    } catch (e, stack) {
      print("Error for ${doc.id}: $e\n$stack");
    }
  }
  print("Successfully parsed $success bookings");
}
