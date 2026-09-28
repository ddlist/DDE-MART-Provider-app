// DDE-Mart provider app — payouts + profile.
//
// GET /provider/payouts (history) + POST /provider/payouts (request).
// Sign out via POST /provider/logout. Avatar uploads via
// POST /provider/uploads.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/media_api.dart';
import '../../core/nav.dart';
import '../../core/permissions.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          title: 'Payouts',
          subtitle: payouts.valueOrNull == null
              ? 'Request and track earnings'
              : '${payouts.valueOrNull!.length} payout${payouts.valueOrNull!.length == 1 ? '' : 's'} on record',
          trailing: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SleekCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Request payout',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon:
                            Icon(Icons.currency_exchange_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      items: [
                        for (final m in _methods)
                          DropdownMenuItem(
                              value: m, child: Text(m)),
                      ],
                      onChanged: (value) => setState(
                          () => _method = value ?? _methods.first),
                      decoration: const InputDecoration(
                        labelText: 'Method',
                        prefixIcon:
                            Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final amount = double.tryParse(
                                      _amount.text.trim()) ??
                                  0;
                              if (amount < 1) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Enter an amount of at least 1.')),
                                );
                                return;
                              }
                              setState(() => _busy = true);
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                await ref
                                    .read(
                                        providerPayoutsApiProvider)
                                    .request(
                                        amount: amount,
                                        method: _method);
                                ref.invalidate(
                                    providerPayoutsProvider);
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Payout requested.')),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(apiMessage(e))),
                                );
                              } finally {
                                if (mounted) {
                                  setState(
                                      () => _busy = false);
                                }
                              }
                            },
                      child: Text(
                          _busy ? 'Sending…' : 'Request'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('History',
                  style:
                      Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              payouts.when(
                loading: () => const ShimmerList(count: 3),
                error: (e, _) => Text(apiMessage(e)),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const EmptyState(
                      message:
                          'No payouts yet. Request one above.',
                      icon: Icons.payments_outlined,
                    );
                  }
                  final pending = rows
                      .where((r) =>
                          '${r['status']}'.toLowerCase() ==
                              'pending' ||
                          '${r['status']}'.toLowerCase() ==
                              'placed')
                      .length;
                  return Column(
                    children: [
                      Row(
                        children: [
                          StatCard(
                            label: 'Total',
                            value: '${rows.length}',
                            icon: Icons.receipt_long_outlined,
                          ),
                          const SizedBox(width: 12),
                          StatCard(
                            label: 'Pending',
                            value: '$pending',
                            icon: Icons.hourglass_top_outlined,
                            tint: DdeProviderTheme.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final row in rows)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: SleekCard(
                            padding:
                                const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.all(
                                              10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: scheme.primary
                                            .withValues(
                                                alpha: 0.12),
                                      ),
                                      child: Icon(
                                        Icons
                                            .account_balance_outlined,
                                        size: 20,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${row['method'] ?? 'Payout'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    StatusChip(
                                        status:
                                            '${row['status'] ?? ''}'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                BillRow(
                                  label: 'Amount',
                                  value: '${row['amount']}',
                                  strong: true,
                                ),
                                if ('${row['created_at'] ?? row['at'] ?? ''}'
                                    .isNotEmpty)
                                  BillRow(
                                    label: 'Requested',
                                    value:
                                        '${row['created_at'] ?? row['at']}',
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}

class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  ConsumerState<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState
    extends ConsumerState<ProviderProfileScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;
  String? _avatarUrl;

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final granted = await ref
        .read(permissionServiceProvider)
        .ensure(context, AppPermission.photos);
    if (!mounted || !granted) return;
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(providerUploadsApiProvider)
          .uploadFile(picked.path, folder: 'avatars');
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo uploaded.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStoreProvider);
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.watch(providerAuthApiProvider).me(),
      builder: (context, snapshot) {
        final me = snapshot.data;
        final name = '${me?['name'] ?? auth.name ?? 'Provider'}';
        final initial =
            name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
        final remoteAvatar =
            '${me?['avatar'] ?? me?['photo'] ?? me?['image'] ?? ''}';
        final avatarUrl =
            _avatarUrl ?? (remoteAvatar.isEmpty ? null : remoteAvatar);
        final resolvedAvatar = resolveAsset(avatarUrl);

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                gradient:
                    DdeProviderTheme.headerGradient(context)
                        .gradient,
                borderRadius: const BorderRadius.vertical(
                  bottom:
                      Radius.circular(DdeProviderTheme.radiusSheet),
                ),
                boxShadow: DdeProviderTheme.softShadow(context),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    if (snapshot.hasError)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 8),
                        child: Text(
                          apiMessage(snapshot.error!),
                          style: const TextStyle(
                              color: Colors.white),
                        ),
                      ),
                    GestureDetector(
                      onTap: _uploading ? null : _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white
                                .withValues(alpha: 0.25),
                            backgroundImage:
                                resolvedAvatar != null
                                    ? NetworkImage(
                                        resolvedAvatar)
                                    : null,
                            child: resolvedAvatar != null
                                ? null
                                : _uploading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        initial,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.w800,
                                            ),
                                      ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding:
                                  const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.secondary,
                                border: Border.all(
                                    color: Colors.white,
                                    width: 2),
                              ),
                              child: Icon(
                                _uploading
                                    ? Icons
                                        .hourglass_top_outlined
                                    : Icons
                                        .photo_camera_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    Text(
                      '${me?['phone'] ?? auth.phone ?? ''}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Colors.white.withValues(
                                alpha: 0.85),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the photo to upload a new one',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Colors.white.withValues(
                                alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SleekCard(
                    padding: EdgeInsets.zero,
                    onTap: () =>
                        context.safePush('/bookings'),
                    child: const ListTile(
                      leading:
                          Icon(Icons.event_note_outlined),
                      title: Text('Bookings inbox'),
                      trailing:
                          Icon(Icons.chevron_right),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SleekCard(
                    padding: EdgeInsets.zero,
                    onTap: () =>
                        context.safePush('/catalog'),
                    child: const ListTile(
                      leading: Icon(
                          Icons.inventory_2_outlined),
                      title: Text('Catalog'),
                      trailing:
                          Icon(Icons.chevron_right),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SleekCard(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Appearance',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('Auto')),
                            ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('Light')),
                            ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('Dark')),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (set) => ref
                              .read(themeModeProvider
                                  .notifier)
                              .set(set.first),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () async {
                        final confirm =
                            await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title:
                                const Text('Sign out?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(
                                        context, false),
                                child:
                                    const Text('Stay'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(
                                        context, true),
                                child: const Text(
                                    'Sign out'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true ||
                            !context.mounted) {
                          return;
                        }
                        try {
                          await ref
                              .read(
                                  providerAuthApiProvider)
                              .logout();
                        } finally {
                          await ref
                              .read(pushServiceProvider)
                              .unregister();
                          await ref
                              .read(authStoreProvider
                                  .notifier)
                              .signOut();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, info) => Center(
                      child: Text(
                        (info.data?.version ?? '').isEmpty
                            ? ''
                            : 'v${info.data!.version}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
