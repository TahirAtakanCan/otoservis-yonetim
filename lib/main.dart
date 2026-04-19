import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/app.dart';
import 'package:otoservis_app/firebase_options.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/providers/connectivity_notifier.dart';
import 'package:otoservis_app/providers/inventory_provider.dart';
import 'package:otoservis_app/providers/service_provider.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint('STACK: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('ASYNC ERROR (PlatformDispatcher): $error');
    debugPrint('STACK: $stack');
    return true;
  };

  runZonedGuarded(
    () async {
      try {
        // Web (ve bazı ortamlarda) DateFormat('...', 'tr_TR') için gerekli.
        await initializeDateFormatting('tr_TR', null);

        debugPrint('ADIM 1: Firebase başlatılıyor...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('ADIM 2: Firebase başlatıldı');

        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
        debugPrint('ADIM 3: Firestore ayarları yapıldı');

        runApp(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ConnectivityNotifier>(
                create: (_) => ConnectivityNotifier(),
              ),
              ChangeNotifierProvider<AuthProvider>(
                create: (_) => AuthProvider(),
              ),
              ChangeNotifierProvider<VehicleProvider>(
                create: (_) => VehicleProvider(),
              ),
              ChangeNotifierProvider<InventoryProvider>(
                create: (_) => InventoryProvider(),
              ),
              ChangeNotifierProvider<ServiceProvider>(
                create: (_) => ServiceProvider(),
              ),
            ],
            child: const App(),
          ),
        );
        debugPrint('ADIM 4: App başlatıldı');
      } catch (e, stack) {
        debugPrint('KRITIK HATA: $e');
        debugPrint('STACK TRACE: $stack');
      }
    },
    (error, stack) {
      debugPrint('ZONE HATASI: $error');
      debugPrint('STACK: $stack');
    },
  );
}
