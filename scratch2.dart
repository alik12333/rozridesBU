import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'lib/models/booking_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snap = await FirebaseFirestore.instance.collection('bookings').limit(5).get();
  for (var doc in snap.docs) {
    try {
      final b = BookingModel.fromMap(doc.data(), doc.id);
      print("Success for ${b.id}");
    } catch (e, stack) {
      print("Error for ${doc.id}: $e\n$stack");
    }
  }
}
