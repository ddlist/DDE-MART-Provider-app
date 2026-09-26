// DDE-Mart provider app — payouts + profile (original).
//
// GET /provider/payouts (history) + POST /provider/payouts (request).
// Sign out via POST /provider/logout.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/push.dart';
import '../auth/provider_auth_api.dart';

class ProviderPayoutsApi {
  ProviderPayoutsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _dio.get('/provider/payouts');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> request({required double amount, required String method}) async {
    await _dio.post('/provider/payouts', data: {
      'amount': amount,
      'method': method,
    });
  }
}

final providerPayoutsApiProvider = Provider<ProviderPayoutsApi>(
  (ref) => ProviderPayoutsApi(ref.watch(dioProvider)),
);

final providerPayoutsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerPayoutsApiProvider).list();
});

const _methods = ['bank', 'paypal', 'stripe', 'razorpay', 'flutterwave', 'cash'];

class ProviderPayoutsScreen extends ConsumerStatefulWidget {
  const ProviderPayoutsScreen({super.key});

  @override
  ConsumerState<ProviderPayoutsScreen> createState() =>
      _ProviderPayoutsScreenState();
}

class _ProviderPayoutsScreenState
    extends ConsumerState<ProviderPayoutsScreen> {
  final _amount = TextEditingController();
  String _method = _methods.first;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payouts = ref.watch(providerPayoutsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Request payout', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _method,
          items: [
            for (final m in _methods) DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (value) => setState(() => _method = value ?? _methods.first),
          decoration: const InputDecoration(labelText: 'Method'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final amount = double.tryParse(_amount.text.trim()) ?? 0;
                  if (amount < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter an amount of at least 1.')),
                    );
                    return;
                  }
                  setState(() => _busy = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(providerPayoutsApiProvider)
                        .request(amount: amount, method: _method);
                    ref.invalidate(providerPayoutsProvider);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Payout requested.')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(apiMessage(e))),
                    );
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Sending…' : 'Request'),
        ),
        const SizedBox(height: 16),
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        payouts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(apiMessage(e)),
          data: (rows) => Column(
            children: [
              if (rows.isEmpty) const Text('No payouts yet.'),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['amount']} · ${row['method']}'),
                    trailing: Text('${row['status']}'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(providerAuthApiProvider).me(),
      builder: (context, snapshot) {
        final me = snapshot.data;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${me?['name'] ?? auth.name ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (snapshot.hasError) Text(apiMessage(snapshot.error!)),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await ref.read(providerAuthApiProvider).logout();
                } finally {
                  await ref.read(pushServiceProvider).unregister();
                  await ref.read(authStoreProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}
