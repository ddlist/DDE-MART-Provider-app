// DDE-Mart provider app — bookings inbox.
//
// GET /provider/bookings (+status filter), detail with timeline,
// machine moves: placed → accepted|rejected|cancelled,
// accepted → ongoing|cancelled, ongoing → completed.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/media_api.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

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

final bookingsFilterProvider = StateProvider<String?>((ref) => null);

final bookingsProvider = FutureProvider<List<ProviderBooking>>((ref) async {
  return ref
      .watch(bookingsApiProvider)
      .bookings(status: ref.watch(bookingsFilterProvider));
});

const _bookingTabs = <String?>[
  null,
  'placed',
  'accepted',
  'ongoing',
  'completed',
  'cancelled'
];

String _tabLabel(String? status) {
  return switch (status) {
    null => 'All',
    'placed' => 'New',
    'accepted' => 'Accepted',
    'ongoing' => 'Ongoing',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(bookingsFilterProvider);
    final bookings = ref.watch(bookingsProvider);
    final stories = ref.watch(storiesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        GradientHeader(
          title: 'Bookings',
          subtitle: bookings.valueOrNull == null
              ? 'Your service requests'
              : '${bookings.valueOrNull!.length} request${bookings.valueOrNull!.length == 1 ? '' : 's'}',
          trailing: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.event_note_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        stories.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (rows) => StoryStrip(stories: rows),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final tab in _bookingTabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_tabLabel(tab)),
                    selected: filter == tab,
                    selectedColor:
                        scheme.primary.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          DdeProviderTheme.radiusPill),
                    ),
                    onSelected: (_) => ref
                        .read(bookingsFilterProvider.notifier)
                        .state = tab,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: bookings.when(
            loading: () => const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ShimmerList(count: 4),
            ),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(bookingsProvider),
            ),
            data: (rows) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(bookingsProvider),
              child: rows.isEmpty
                  ? const EmptyState(
                      message:
                          'No bookings here. New requests pop up automatically.',
                      icon: Icons.event_note_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final booking = rows[index];
                        return SleekCard(
                          padding: EdgeInsets.zero,
                          onTap: () => context.safePush(
                              '/booking/${booking.id}'),
                          child: Padding(
                            padding:
                                const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${booking.number} · ${booking.customer}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    StatusChip(
                                        status:
                                            booking.status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5),
                                      decoration: BoxDecoration(
                                        color: scheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(
                                                DdeProviderTheme
                                                    .radiusPill),
                                      ),
                                      child: Text(
                                        'Total ${booking.total.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color:
                                                  scheme.primary,
                                            ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: scheme
                                            .onSurfaceVariant),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
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
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ShimmerList(count: 3, itemHeight: 110),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final booking = snapshot.data!;
          final status = '${booking['status']}';
          final timeline = ((booking['timeline'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bookingsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient:
                        DdeProviderTheme.headerGradient(context)
                            .gradient,
                    borderRadius: BorderRadius.circular(
                        DdeProviderTheme.radiusCardLarge),
                    boxShadow:
                        DdeProviderTheme.softShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${booking['number'] ?? 'Booking #${booking['id']}'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ),
                          StatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total ${booking['total'] ?? ''}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Colors.white
                                  .withValues(alpha: 0.9),
                            ),
                      ),
                      if ('${booking['customer'] ?? ''}'
                          .isNotEmpty)
                        Text(
                          '${booking['customer']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.white
                                    .withValues(alpha: 0.8),
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SleekCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                      ),
                    ),
                    title: Text(
                        '${booking['customer'] ?? 'Customer'}'),
                    subtitle: Text(
                        '${booking['address'] ?? 'No address on file'}'),
                  ),
                ),
                if (nextMoves(status).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SleekCard(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Next step',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final move
                                in nextMoves(status))
                              FilledButton.tonal(
                                onPressed: _busy
                                    ? null
                                    : () => _move(move),
                                child: Text(move),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (timeline.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SleekCard(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Timeline',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                        const SizedBox(height: 12),
                        TimelineDots(entries: timeline),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
