// DDE-Mart provider app — staged OTP sign-in.
//
// Stage 1 collects the phone and sends the code; stage 2 verifies it with
// a resend cooldown. Debug codes surface outside production only.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'provider_auth_api.dart';

class ProviderLoginScreen extends ConsumerStatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  ConsumerState<ProviderLoginScreen> createState() =>
      _ProviderLoginScreenState();
}

class _ProviderLoginScreenState
    extends ConsumerState<ProviderLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busySend = false;
  bool _busyVerify = false;
  String? _error;
  String? _debugCode;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (phone.length < 7) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() {
      _busySend = true;
      _error = null;
    });
    try {
      final debug =
          await ref.read(providerAuthApiProvider).otpRequest(phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _debugCode = debug;
      });
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = apiMessage(e));
    } finally {
      if (mounted) setState(() => _busySend = false);
    }
  }

  Future<void> _verify() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code we sent you.');
      return;
    }
    setState(() {
      _busyVerify = true;
      _error = null;
    });
    try {
      final payload =
          await ref.read(providerAuthApiProvider).otpVerify(
                phone: phone,
                code: code,
              );
      await ref.read(authStoreProvider.notifier).signIn(
            token: '${payload['token']}',
            name: '${payload['name'] ?? ''}',
            phone: phone,
          );
      if (mounted) context.go('/bookings');
    } catch (e) {
      if (mounted) setState(() => _error = apiMessage(e));
    } finally {
      if (mounted) setState(() => _busyVerify = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: BoxDecoration(
              gradient:
                  DdeProviderTheme.headerGradient(context).gradient,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(DdeProviderTheme.radiusSheet),
              ),
              boxShadow: DdeProviderTheme.softShadow(context),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.handyman_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Provider sign in',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back — sign in with a one-time code to manage your services.',
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Colors.white.withValues(alpha: 0.85),
                            ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SleekCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    enabled: !_codeSent,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: _codeSent
                          ? TextButton(
                              onPressed: () => setState(() {
                                _codeSent = false;
                                _debugCode = null;
                              }),
                              child: const Text('Change'),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_codeSent)
                    FilledButton(
                      onPressed: _busySend ? null : _send,
                      child: Text(
                          _busySend ? 'Sending…' : 'Send code'),
                    )
                  else ...[
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '6-digit code',
                        prefixIcon:
                            Icon(Icons.lock_outline),
                      ),
                      onChanged: (value) {
                        if (value.trim().length >= 6 && !_busyVerify) {
                          _verify();
                        }
                      },
                    ),
                    if (_debugCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                DdeProviderTheme.radiusCard),
                          ),
                          child: Text(
                            'Debug code: $_debugCode',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.primary),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busyVerify ? null : _verify,
                      child: Text(_busyVerify
                          ? 'Verifying…'
                          : 'Verify & sign in'),
                    ),
                    TextButton(
                      onPressed:
                          (_busySend || _cooldown > 0) ? null : _send,
                      child: Text(_cooldown > 0
                          ? 'Resend in $_cooldown s'
                          : 'Resend code'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.error
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                            DdeProviderTheme.radiusCard),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
