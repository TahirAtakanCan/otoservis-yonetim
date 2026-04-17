import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _auth.authStateChanges().listen(_handleAuthChanged);
    _handleAuthChanged(_auth.currentUser);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _handleAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    final userDoc =
        await _firestore.collection('users').doc(firebaseUser.uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};

    _currentUser = AppUser.fromMap({
      ...data,
      'uid': firebaseUser.uid,
      'email': data['email'] ?? firebaseUser.email ?? '',
      'name': data['name'] ?? '',
      'role': data['role'] ?? 'technician',
    });
    notifyListeners();
  }
}

