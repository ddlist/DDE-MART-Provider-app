// DDE-Mart provider app — session guard tests (original).

import 'package:dde_provider/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('401 outside auth signs out', () {
    expect(
        shouldForceSignOut(status: 401, path: '/provider/bookings'), true);
    expect(shouldForceSignOut(status: 401, path: '/provider/me'), true);
  });

  test('401 on auth endpoints keeps the session', () {
    expect(
        shouldForceSignOut(
            status: 401, path: '/work/auth/otp/verify'),
        false);
    expect(
        shouldForceSignOut(status: 401, path: '/auth/login'), false);
  });

  test('non-401 never signs out', () {
    expect(
        shouldForceSignOut(status: 422, path: '/provider/bookings'),
        false);
    expect(
        shouldForceSignOut(status: 500, path: '/provider/bookings'),
        false);
    expect(shouldForceSignOut(status: null, path: '/provider/me'),
        false);
  });
}
