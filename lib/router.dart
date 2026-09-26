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

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStoreProvider);
  final gate = ref.watch(launchGateProvider);

  return GoRouter(
    initialLocation: '/bookings',
    redirect: (context, state) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payouts'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
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
