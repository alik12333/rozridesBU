import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { idle, loading, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  UserModel? currentUser;
  String? errorMessage;
  AuthStatus status = AuthStatus.idle;

  get firebaseUser => _authService.currentUser;

  StreamSubscription<UserModel?>? _userProfileSubscription;

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _userProfileSubscription?.cancel();
      currentUser = null;
      status = AuthStatus.idle;
      notifyListeners();
    } else {
      status = AuthStatus.loading;
      notifyListeners();
      
      // Initial load
      await loadUserProfile(user.uid);
      
      // Listen for updates
      _userProfileSubscription?.cancel();
      _userProfileSubscription = _authService.getUserProfileStream(user.uid).listen((updatedUser) {
        if (updatedUser != null) {
          // Check for Admin Role
          if (updatedUser.roles?.isAdmin == true) {
             _authService.signOut();
             currentUser = null;
             // We can't easily throw here as it's a listener, but we can update status to error
             errorMessage = 'Admins cannot login here.';
             status = AuthStatus.error;
             notifyListeners();
             return;
          }
          currentUser = updatedUser;
          notifyListeners();
        }
      });

      // Initial check after load
      // Initial check after load
      if (currentUser != null && currentUser!.roles?.isAdmin == true) {
        await _authService.signOut();
        currentUser = null;
        errorMessage = 'Admins cannot login here. Please use the Admin Panel.';
        status = AuthStatus.error;
        notifyListeners();
        return;
      }

      status = AuthStatus.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userProfileSubscription?.cancel();
    super.dispose();
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String city,
    required String area,
    String? cnicNumber,
    File? cnicFront,
    File? cnicBack,
  }) async {
    try {
      status = AuthStatus.loading;
      errorMessage = null;
      notifyListeners();

      final cred = await _authService.signUpWithEmail(email: email, password: password);

      await _authService.createUserProfile(
        userId: cred.user!.uid,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        city: city,
        area: area,
        cnicNumber: cnicNumber,
        cnicFront: cnicFront,
        cnicBack: cnicBack,
      );

      await loadUserProfile(cred.user!.uid);

      status = AuthStatus.idle;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = _parseAuthError(e);
      status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = e.toString();
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail({required String email, required String password}) async {
    try {
      status = AuthStatus.loading;
      errorMessage = null;
      notifyListeners();

      final cred = await _authService.signInWithEmail(email: email, password: password);
      await loadUserProfile(cred.user!.uid);

      if (currentUser == null) {
        throw Exception('User profile not found');
      }

      // Check for Admin Role
      if (currentUser != null && currentUser!.roles?.isAdmin == true) {
        await _authService.signOut();
        currentUser = null;
        throw Exception('Admins cannot login here. Please use the Admin Panel.');
      }

      status = AuthStatus.idle;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = _parseAuthError(e);
      status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  String _parseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }

  Future<void> loadUserProfile(String userId) async {
    try {
      print('DEBUG: Loading profile for $userId');
      currentUser = await _authService.getUserProfile(userId);
      print('DEBUG: User profile loaded: $currentUser');
      if (currentUser == null) {
        print('DEBUG: User profile is NULL for $userId');
      }
      notifyListeners();
    } catch (e) {
      print('DEBUG: Error loading profile: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (currentUser == null) return;
    await _authService.updateUserProfile(currentUser!.id, updates);
    await loadUserProfile(currentUser!.id);
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    currentUser = null;
    notifyListeners();
  }
}
