// DDE-Mart provider app — shell, router + launch gate (original).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/api_client.dart';
import 'core/auth_store.dart';
import 'core/config.dart';
import 'core/gate.dart';
import 'core/widgets.dart';
import 'features/account/payouts_profile.dart';
import 'features/auth/provider_login_screen.dart';
import 'features/bookings/bookings.dart';
import 'features/catalog/provider_catalog.dart';

final launchGateProvider = FutureProvider<GateDecision>((ref) async {
  final dio = ref.watch(dioProvider);
  final info = await PackageInfo.fromPlatform();

  try {
    final response = await dio.get('/app-config');
    final config = LaunchConfig.fromJson(
      Map<String, dynamic>.from((response.data as Map)['data'] as Map),
    );
    return gateStatus(
      current: info.version,
      minimum: config.minVersions[AppConfig.audience] ?? '1.0.0',
      maintenance: config.maintenance,
    );
  } on DioException {
    return GateDecision.ok;
  }
});

/// Bumps when auth or the launch gate changes so the router re-runs its
/// redirect without ever recreating the [GoRouter] itself. Recreating the
/// router mid-session swaps Navigator delegates under live pages and
/// corrupts the tree with duplicate keys.
final _routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final bump = ValueNotifier(0);
  ref.listen<AuthState>(authStoreProvider, (prev, next) {
    if (prev?.signedIn != next.signedIn) bump.value++;
  });
  ref.listen<AsyncValue<GateDecision>>(
      launchGateProvider, (prev, next) {
    if (prev?.valueOrNull != next.valueOrNull) bump.value++;
  });
  ref.onDispose(bump.dispose);
  return bump;
});

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/bookings',
    refreshListenable: ref.watch(_routerRefreshProvider),
    onException: (context, state, router) {
      router.go('/bookings');
    },
    redirect: (context, state) {
      final auth = ref.read(authStoreProvider);
      final gate = ref.read(launchGateProvider);
      final location = state.matchedLocation;

      if (gate.valueOrNull == GateDecision.maintenance && location != '/maintenance') {
        return '/maintenance';
      }
      if (gate.valueOrNull == GateDecision.updateRequired && location != '/update') {
        return '/update';
      }

      const public = ['/login', '/maintenance', '/update'];
      if (!auth.signedIn && !public.any(location.startsWith)) {
        return '/login';
      }
      if (auth.signedIn && (location == '/login' || location == '/')) {
        return '/bookings';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => ProviderShell(child: child),
        routes: [
          GoRoute(path: '/bookings', builder: (context, state) => const BookingsScreen()),
          GoRoute(
            path: '/booking/:id',
            builder: (context, state) => BookingDetailScreen(
              bookingId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const ProviderCatalogScreen(),
          ),
          GoRoute(
            path: '/payouts',
            builder: (context, state) => const ProviderPayoutsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProviderProfileScreen(),
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const ProviderLoginScreen()),
      GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
      GoRoute(path: '/update', builder: (context, state) => const UpdateScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    var index = 0;
    if (location.startsWith('/catalog')) {
      index = 1;
    } else if (location.startsWith('/payouts')) {
      index = 2;
    } else if (location.startsWith('/profile')) {
      index = 3;
    }

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: SleekNavBar(
        index: index,
        onTap: (value) {
          switch (value) {
            case 0:
              context.go('/bookings');
            case 1:
              context.go('/catalog');
            case 2:
              context.go('/payouts');
            case 3:
              context.go('/profile');
          }
        },
      ),
    );
  }
}

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('DDE-Mart is under maintenance', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(launchGateProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'Please update DDE Provider to continue.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
