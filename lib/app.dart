import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/screens/dashboard/dashboard_screen.dart';
import 'package:otoservis_app/screens/login/login_screen.dart';
import 'package:otoservis_app/screens/pdf/pdf_preview_screen.dart';
import 'package:otoservis_app/screens/reports/reports_screen.dart';
import 'package:otoservis_app/screens/service/service_entry_screen.dart';
import 'package:otoservis_app/screens/vehicle/vehicle_history_screen.dart';
import 'package:otoservis_app/screens/vehicle/vehicle_search_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoggedIn = authProvider.currentUser != null;
        final isLoginRoute = state.matchedLocation == '/login';
        final isInventoryRoute = state.matchedLocation == '/inventory';
        final isAdmin = authProvider.currentUser?.role == 'admin';

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
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/vehicle-search',
          builder: (context, state) => const VehicleSearchScreen(),
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

    return MaterialApp.router(
      title: 'Otoservis App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      routerConfig: router,
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Inventory Screen')),
    );
  }
}
