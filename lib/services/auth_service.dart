import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String fullName,
    required String phoneNumber,
    required String city,
    required String area,
    String? cnicNumber,
    File? cnicFront,
    File? cnicBack,
  }) async {
    String? frontUrl;
    String? backUrl;

    if (cnicFront != null) {
      frontUrl = await _uploadToStorage(userId, cnicFront, 'cnic/front.jpg');
    }
    if (cnicBack != null) {
      backUrl = await _uploadToStorage(userId, cnicBack, 'cnic/back.jpg');
    }

    final userData = {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePhoto': null,
      'cnic': cnicNumber != null ? {
        'number': cnicNumber,
        'frontImage': frontUrl,
        'backImage': backUrl,
        'verificationStatus': 'pending',
      } : null,
      'location': {
        'city': city,
        'area': area,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'roles': {'isRenter': true, 'isOwner': false},
    };

    await _firestore.collection('users').doc(userId).set(userData);

    // Add notification if CNIC was submitted
    if (cnicNumber != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Verification Pending',
        'message': 'Your CNIC verification is under review. We\'ll notify you once it\'s approved.',
        'type': 'info',
        'isUnread': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    return null;
  }

  Stream<UserModel?> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      return null;
    });
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(userId).update(updates);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String> _uploadToStorage(String uid, File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child('users/$uid/$path');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
