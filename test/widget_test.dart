import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:otoservis_app/app.dart';
import 'package:otoservis_app/main.dart';
import 'package:otoservis_app/models/app_user.dart';
import 'package:otoservis_app/providers/auth_provider.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  FakeAuthProvider({this.currentUser});

  @override
  final AppUser? currentUser;

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  bool get isLoading => false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('shows login screen when user is not authenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider<AuthProvider>.value(value: FakeAuthProvider())],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Giris Yap'), findsOneWidget);
    expect(find.text('OTO SERVIS'), findsOneWidget);
  });
}
