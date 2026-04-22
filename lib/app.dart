import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/providers/connectivity_notifier.dart';
import 'package:otoservis_app/screens/dashboard/dashboard_screen.dart';
import 'package:otoservis_app/screens/inventory/inventory_screen.dart';
import 'package:otoservis_app/screens/login/login_screen.dart';
import 'package:otoservis_app/screens/pdf/pdf_preview_screen.dart';
import 'package:otoservis_app/screens/reports/reports_screen.dart';
import 'package:otoservis_app/screens/service/service_entry_screen.dart';
import 'package:otoservis_app/screens/vehicle/vehicle_add_screen.dart';
import 'package:otoservis_app/screens/vehicle/vehicle_history_screen.dart';
import 'package:otoservis_app/screens/vehicle/vehicles_list_screen.dart';
import 'package:otoservis_app/utils/constants.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectivity = context.watch<ConnectivityNotifier>();

    _router ??= GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        final loc = state.matchedLocation;

        if (!auth.authStateKnown) {
          return loc == '/loading' ? null : '/loading';
        }

        if (loc == '/loading') {
          return auth.currentUser != null ? '/' : '/login';
        }

        final isLoggedIn = auth.currentUser != null;
        final isLoginRoute = loc == '/login';
        final isInventoryRoute = loc == '/inventory';
        final isAdmin = auth.currentUser?.role == 'admin';

        if (!isLoggedIn) {
          return isLoginRoute ? null : '/login';
        }

        if (isLoginRoute) {
          return '/';
        }

        if (isInventoryRoute && !isAdmin) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/loading',
          builder: (context, state) => const _AuthLoadingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/vehicles/new',
          builder:
              (context, state) => VehicleAddScreen(
                initialPlate: state.uri.queryParameters['plate'],
              ),
        ),
        GoRoute(
          path: '/vehicles',
          builder: (context, state) => const VehiclesListScreen(),
        ),
        GoRoute(
          path: '/vehicle/:plate/history',
          builder: (context, state) {
            final plate = state.pathParameters['plate'] ?? '';
            return VehicleHistoryScreen(plate: plate);
          },
        ),
        GoRoute(
          path: '/service/new',
          builder: (context, state) {
            final plate = state.uri.queryParameters['plate'];
            return ServiceEntryScreen(initialPlate: plate);
          },
        ),
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/pdf/preview/:serviceId',
          builder: (context, state) {
            final id = state.pathParameters['serviceId'] ?? '';
            return PdfPreviewScreen(serviceId: id);
          },
        ),
      ],
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryNavy,
      primary: AppColors.primaryNavy,
      secondary: AppColors.secondaryOrange,
      brightness: Brightness.light,
    );

    return MaterialApp.router(
      title: BusinessInfo.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surfaceMuted,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondaryOrange,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: BorderSide(
              color: AppColors.secondaryOrange.withValues(alpha: 0.9),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          selectedColor: AppColors.secondaryOrange,
          backgroundColor: Colors.white,
          labelStyle: const TextStyle(color: Colors.black87),
          side: const BorderSide(color: Color(0xFFE4D67A)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      routerConfig: _router!,
      builder: (context, child) {
        return Column(
          children: [
            if (!connectivity.isOnline)
              Material(
                color: Colors.orange.shade900,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'İnternet bağlantısı yok. Firestore çevrimdışı önbelleği kullanılıyor; veriler senkronize olmayabilir.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
