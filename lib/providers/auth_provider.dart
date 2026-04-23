import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:otoservis_app/models/app_user.dart';
import 'package:otoservis_app/services/firestore_cache_warmer.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _authSub = _auth.authStateChanges().listen(
      (user) {
        _handleAuthChanged(user);
      },
      onError: (Object e, StackTrace stack) {
        debugPrint('AUTH STREAM HATASI: $e');
        debugPrint('STACK: $stack');
      },
    );
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSub;

  AppUser? _currentUser;
  bool _isLoading = false;

  /// İlk [authStateChanges] işlemi (Firebase kullanıcı + Firestore profili) tamamlanana kadar false.
  bool _authStateKnown = false;
  bool get authStateKnown => _authStateKnown;

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
      if (!_authStateKnown) {
        _authStateKnown = true;
      }
      notifyListeners();
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (!userDoc.exists) {
        debugPrint('Kullanıcı belgesi bulunamadı: ${firebaseUser.uid}');
      }

      final data = userDoc.data() ?? <String, dynamic>{};

      _currentUser = AppUser.fromMap({
        ...data,
        'uid': firebaseUser.uid,
        'email': data['email'] ?? firebaseUser.email ?? '',
        'name': data['name'] ?? '',
        'role': data['role'] ?? 'technician',
      });
    } catch (e, stack) {
      debugPrint('Kullanıcı bilgisi çekilemedi: $e');
      debugPrint('STACK: $stack');
      _currentUser = AppUser.fromMap({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'name': '',
        'role': 'technician',
      });
    } finally {
      unawaited(FirestoreCacheWarmer.warmUp(_firestore));
      if (!_authStateKnown) {
        _authStateKnown = true;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
