import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:otoservis_app/providers/auth_provider.dart';
import 'package:otoservis_app/utils/constants.dart';

/// Sol sabit sidebar (220px). Rol bazlı menü ve çıkış.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  static const double width = 220;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final role = user?.role ?? '';
    final location = GoRouterState.of(context).uri.path;

    final showInventory = role == 'admin';

    return Container(
      width: width,
      color: AppColors.primaryNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 78,
                        color: const Color(0xFF1A1A1A),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.car_repair,
                                color: Colors.white70,
                                size: 34,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      BusinessInfo.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _SidebarTile(
                  icon: Icons.home_outlined,
                  label: 'Ana Sayfa',
                  selected: location == '/',
                  onTap: () => context.go('/'),
                ),
                _SidebarTile(
                  icon: Icons.add_circle_outline,
                  label: 'Araç Ekle',
                  selected: location == '/vehicles/new',
                  onTap: () => context.go('/vehicles/new'),
                ),
                _SidebarTile(
                  icon: Icons.directions_car_outlined,
                  label: 'Araçlar',
                  selected:
                      location == '/vehicles' ||
                      location.startsWith('/vehicle/'),
                  onTap: () => context.go('/vehicles'),
                ),
                if (showInventory)
                  _SidebarTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stok Yönetimi',
                    selected: location == '/inventory',
                    onTap: () => context.go('/inventory'),
                  ),
                _SidebarTile(
                  icon: Icons.assessment_outlined,
                  label: 'Raporlar',
                  selected: location == '/reports',
                  onTap: () => context.go('/reports'),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name.isNotEmpty == true ? user!.name : 'Kullanıcı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _roleLabel(role),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
              },
              icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
              label: const Text(
                'Çıkış',
                style: TextStyle(color: Colors.white70),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Yönetici';
      case 'technician':
        return 'Teknisyen';
      case 'cashier':
        return 'Kasiyer';
      default:
        return role.isEmpty ? '—' : role;
    }
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.secondaryOrange : Colors.transparent;
    final fg = selected ? Colors.black : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
