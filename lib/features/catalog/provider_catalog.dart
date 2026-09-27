// DDE-Mart provider app — services + workers management (original).
//
// Own bookable services (CRUD + active toggle) and staff workers (CRUD +
// toggle). Matches GET|POST|PUT /provider/services|workers (+toggle).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';

Map<String, dynamic> _item(Map e) => Map<String, dynamic>.from(e);

List<Map<String, dynamic>> _list(Object? data) =>
    ((data as List?) ?? []).map((e) => _item(e as Map)).toList();

/// POST bodies / query maps without null/blank values.
Map<String, Object> _clean(Map<String, Object?> values) {
  values.removeWhere((key, value) => value == null || value == '');
  return values.cast<String, Object>();
}

class ProviderCatalogApi {
  ProviderCatalogApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> services() async {
    final r = await _dio.get('/provider/services');
    return _list((r.data as Map)['data']);
  }

  Future<void> serviceStore({
    required String title,
    required double price,
    String? description,
    double? discountPrice,
  }) async {
    await _dio.post('/provider/services', data: _clean({
      'title': title,
      'price': price,
      'description': description,
      'discount_price': discountPrice,
    }));
  }

  Future<void> serviceUpdate({required int id, required Map<String, Object> fields}) async {
    await _dio.put('/provider/services/$id', data: fields);
  }

  Future<void> serviceToggle(int id) async {
    await _dio.post('/provider/services/$id/toggle');
  }

  Future<List<Map<String, dynamic>>> workers() async {
    final r = await _dio.get('/provider/workers');
    return _list((r.data as Map)['data']);
  }

  Future<void> workerStore({required String name, String? phone}) async {
    await _dio.post('/provider/workers', data: _clean({
      'name': name,
      'phone': phone,
    }));
  }

  Future<void> workerUpdate({required int id, required Map<String, Object> fields}) async {
    await _dio.put('/provider/workers/$id', data: fields);
  }

  Future<void> workerToggle(int id) async {
    await _dio.post('/provider/workers/$id/toggle');
  }
}

final providerCatalogApiProvider = Provider<ProviderCatalogApi>(
  (ref) => ProviderCatalogApi(ref.watch(dioProvider)),
);

final providerServicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerCatalogApiProvider).services();
});

final providerWorkersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(providerCatalogApiProvider).workers();
});

class ProviderCatalogScreen extends ConsumerStatefulWidget {
  const ProviderCatalogScreen({super.key});

  @override
  ConsumerState<ProviderCatalogScreen> createState() =>
      _ProviderCatalogScreenState();
}

class _ProviderCatalogScreenState
    extends ConsumerState<ProviderCatalogScreen> {
  final _serviceTitle = TextEditingController();
  final _servicePrice = TextEditingController();
  final _workerName = TextEditingController();
  final _workerPhone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _serviceTitle.dispose();
    _servicePrice.dispose();
    _workerName.dispose();
    _workerPhone.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() call) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await call();
      ref.invalidate(providerServicesProvider);
      ref.invalidate(providerWorkersProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(providerServicesProvider);
    final workers = ref.watch(providerWorkersProvider);
    final api = ref.watch(providerCatalogApiProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(providerServicesProvider);
        ref.invalidate(providerWorkersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Services', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serviceTitle,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _servicePrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _busy
                    ? null
                    : () {
                        final price =
                            double.tryParse(_servicePrice.text.trim()) ?? -1;
                        if (_serviceTitle.text.trim().isEmpty || price < 0) {
                          return;
                        }
                        _guard(() => api.serviceStore(
                              title: _serviceTitle.text.trim(),
                              price: price,
                            )).then((_) {
                          _serviceTitle.clear();
                          _servicePrice.clear();
                        });
                      },
              ),
            ],
          ),
          services.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (rows) {
            if (rows.isEmpty) {
              return const EmptyState(
                message: 'No services yet. Add your first one above.',
                icon: Icons.home_repair_service_outlined,
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('${row['title']}',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w700)),
                                Text(
                                    '${row['price'] ?? ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              ],
                            ),
                          ),
                          StatusChip(
                              status: (row['is_active'] ??
                                          false) ==
                                      true
                                  ? 'active'
                                  : 'paused'),
                          Switch(
                            value: (row['is_active'] ??
                                    false) ==
                                true,
                            onChanged: (_) => _guard(
                              () => api.serviceToggle(
                                  row['id'] as int),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          ),
          const SizedBox(height: 16),
          Text('Workers', style: Theme.of(context).textTheme.titleMedium),
          workers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (rows) {
            if (rows.isEmpty) {
              return const EmptyState(
                message: 'No workers yet. Add your team below.',
                icon: Icons.group_outlined,
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                            '${row['name'] ?? '?'}'.isEmpty
                                ? '?'
                                : '${row['name']}'
                                    .trim()[0]
                                    .toUpperCase()),
                      ),
                      title: Text('${row['name']}'),
                      subtitle:
                          Text('${row['phone'] ?? ''}'),
                      trailing: Switch(
                        value:
                            (row['is_active'] ?? false) ==
                                true,
                        onChanged: (_) => _guard(
                          () => api.workerToggle(
                              row['id'] as int),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _workerName,
                  decoration: const InputDecoration(labelText: 'Worker name'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _workerPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _busy
                    ? null
                    : () {
                        if (_workerName.text.trim().isEmpty) return;
                        _guard(() => api.workerStore(
                              name: _workerName.text.trim(),
                              phone: _workerPhone.text.trim(),
                            )).then((_) {
                          _workerName.clear();
                          _workerPhone.clear();
                        });
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
