import 'package:flutter/material.dart';
import 'package:otoservis_app/utils/constants.dart';
import 'package:otoservis_app/widgets/common/app_sidebar.dart';

/// Raporlar (yer tutucu). İleride grafik / dışa aktarma bağlanacak.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future<void>.delayed(Duration.zero),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSidebar(),
              Expanded(
                child: ColoredBox(
                  color: AppColors.surfaceMuted,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Raporlama modülü yakında eklenecek.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
