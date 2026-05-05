import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snap = await FirebaseFirestore.instance.collection('bookings').limit(5).get();
  for (var doc in snap.docs) {
    print(doc.data());
  }
}
