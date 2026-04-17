import 'package:flutter/material.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

/// Raporlar sayfası (placeholder). Sidebar ile ana layout tutarlılığı için.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF1F5F9),
              child: Center(
                child: Text(
                  'Raporlar',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
