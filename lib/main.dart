// DDE-Mart provider app — entry point (original, clean-room rebuild).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: DdeProviderApp()));
}

class DdeProviderApp extends ConsumerWidget {
  const DdeProviderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Instantiates the session watcher; syncs push once per sign-in.
    ref.watch(pushSyncProvider);

    return MaterialApp.router(
      title: 'DDE Provider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0D9488),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF0D9488),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
