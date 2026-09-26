// DDE-Mart provider app — bookings inbox (original).
//
// GET /provider/bookings (+status filter), detail with timeline,
// machine moves: placed → accepted|rejected|cancelled,
// accepted → ongoing|cancelled, ongoing → completed.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

class ProviderBooking {
  ProviderBooking({
    required this.id,
    required this.number,
    required this.customer,
    required this.total,
    required this.status,
  });

  factory ProviderBooking.fromJson(Map<String, dynamic> json) => ProviderBooking(
        id: json['id'] as int,
        number: '${json['number'] ?? ''}',
        customer: '${json['customer'] ?? ''}',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        status: '${json['status']}',
      );

  final int id;
  final String number;
  final String customer;
  final double total;
  final String status;
}

/// Legal next moves per status (mirrors the backend machine).
List<String> nextMoves(String status) {
  return switch (status) {
    'placed' => ['accepted', 'rejected', 'cancelled'],
    'accepted' => ['ongoing', 'cancelled'],
    'ongoing' => ['completed'],
    _ => [],
  };
}

class BookingsApi {
  BookingsApi(this._dio);

  final Dio _dio;

  Future<List<ProviderBooking>> bookings({String? status}) async {
    final response = await _dio.get('/provider/bookings', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => ProviderBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> booking(int id) async {
    final response = await _dio.get('/provider/bookings/$id');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> transition({required int id, required String to}) async {
    await _dio.post('/provider/bookings/$id/transition', data: {'to': to});
  }
}

final bookingsApiProvider = Provider<BookingsApi>(
  (ref) => BookingsApi(ref.watch(dioProvider)),
);

final bookingsProvider = FutureProvider<List<ProviderBooking>>((ref) async {
  return ref.watch(bookingsApiProvider).bookings();
});

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);

    return bookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiMessage(e)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(bookingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(bookingsProvider),
        child: rows.isEmpty
            ? const Center(child: Text('No bookings.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final booking in rows)
                    Card(
                      child: ListTile(
                        title: Text('${booking.number} · ${booking.customer}'),
                        subtitle: Text(
                          '${booking.status} · ${booking.total.toStringAsFixed(2)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/booking/${booking.id}'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _busy = false;

  Future<void> _move(String to) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(bookingsApiProvider)
          .transition(id: widget.bookingId, to: to);
      ref.invalidate(bookingsProvider);
      if (mounted) setState(() {});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(bookingsApiProvider).booking(widget.bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final booking = snapshot.data!;
          final status = '${booking['status']}';
          final timeline = ((booking['timeline'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${booking['number'] ?? ''} · $status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Customer: ${booking['customer'] ?? '—'}'),
              Text('Address: ${booking['address'] ?? '—'}'),
              Text('Total ${booking['total']}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final move in nextMoves(status))
                    FilledButton.tonal(
                      onPressed: _busy ? null : () => _move(move),
                      child: Text(move),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
              for (final entry in timeline)
                ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('${entry['to'] ?? entry['to_status']}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
