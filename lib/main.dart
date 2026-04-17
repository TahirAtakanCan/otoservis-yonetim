import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/app.dart';
import 'package:otoservis_app/firebase_options.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/providers/inventory_provider.dart';
import 'package:otoservis_app/providers/service_provider.dart';
import 'package:otoservis_app/providers/vehicle_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
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
}
