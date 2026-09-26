// DDE-Mart provider app — workforce auth API (original).
//
// OTP-only login with role=provider. Mirrors POST /api/v1/work/auth/*.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class ProviderAuthApi {
  ProviderAuthApi(this._dio);

  final Dio _dio;

  Future<String?> otpRequest(String phone) async {
    final response = await _dio.post(
      '/work/auth/otp/request',
      data: {'phone': phone, 'role': 'provider'},
    );
    final data = (response.data as Map)['data'] as Map;
    return data['debug_code'] as String?;
  }

  Future<Map<String, dynamic>> otpVerify({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post(
      '/work/auth/otp/verify',
      data: {'phone': phone, 'role': 'provider', 'code': code},
    );
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> logout() async {
    await _dio.post('/provider/logout');
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/provider/me');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }
}

final providerAuthApiProvider = Provider<ProviderAuthApi>(
  (ref) => ProviderAuthApi(ref.watch(dioProvider)),
);
