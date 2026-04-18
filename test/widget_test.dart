import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:otoservis_app/app.dart';
import 'package:otoservis_app/models/app_user.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/providers/connectivity_notifier.dart';
import 'package:otoservis_app/utils/constants.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  FakeAuthProvider({this.currentUser});

  @override
  final AppUser? currentUser;

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  bool get isLoading => false;

  @override
  bool get authStateKnown => true;

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
        providers: [
          ChangeNotifierProvider<ConnectivityNotifier>(
            create: (_) => ConnectivityNotifier(),
          ),
          ChangeNotifierProvider<AuthProvider>.value(
            value: FakeAuthProvider(),
          ),
        ],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Giriş yap'), findsWidgets);
    expect(find.text(BusinessInfo.name.toUpperCase()), findsOneWidget);
  });
}
