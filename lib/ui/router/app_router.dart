import 'package:go_router/go_router.dart';

import 'package:livecoding/ui/screens/home_screen.dart';
import 'package:livecoding/ui/screens/settings_screen.dart';
import 'package:livecoding/ui/screens/slots_screen.dart';
import 'package:livecoding/ui/widgets/app_nav_shell.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const booking = '/booking';
  static const settings = '/settings';
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppNavShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.booking,
                builder: (context, state) => const SlotsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
